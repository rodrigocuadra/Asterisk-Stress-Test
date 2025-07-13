from fastapi import FastAPI, WebSocket, Request, Form, Response
from fastapi.responses import JSONResponse, HTMLResponse, PlainTextResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from ws_manager import manager
from state import test_state

import requests
import os
import json
from pathlib import Path
from openai import OpenAI
import subprocess
import asyncio
import paramiko
from dotenv import load_dotenv
import time

# Load environment variables from .env file
load_dotenv()

# Environment-based configuration
progress_file = Path(os.getenv("PROGRESS_FILE", "/opt/stresstest_monitor/results.json"))
index_html_path = Path(os.getenv("INDEX_HTML_PATH", "/var/www/stresstest_monitor/index.html"))
CALLS_THRESHOLD = int(os.getenv("CALLS_THRESHOLD", "500"))
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4")
SSH_USER = os.getenv("SSH_USER", "root")
TERMINAL1_IP = os.getenv("TERMINAL1_IP", "192.168.10.31")
TERMINAL2_IP = os.getenv("TERMINAL2_IP", "192.168.10.33")
DEMO_USER = os.getenv("DEMO_USER", "admin")
DEMO_PASS = os.getenv("DEMO_PASS", "1234")

# ✅ Instanciar la app ANTES de usarla
app = FastAPI()

# Montar archivos estáticos (solo CSS, JS, etc.)
app.mount("/static", StaticFiles(directory="static"), name="static")

# 👉 Página de login
@app.get("/login.html")
async def get_login():
    with open("login.html") as f:
        return HTMLResponse(f.read())

# 👉 Página protegida
@app.get("/index.html")
async def get_index(request: Request):
    if request.cookies.get("auth") != "ok":
        return RedirectResponse("/login.html")
    with open("index.html") as f:
        return HTMLResponse(f.read())

# 👉 Validación de credenciales
@app.post("/api/login")
async def do_login(response: Response, username: str = Form(...), password: str = Form(...)):
    if username == DEMO_USER and password == DEMO_PASS:
        response = RedirectResponse("/index.html", status_code=302)
        response.set_cookie("auth", "ok", max_age=60*60*24*2, path="/")
        return response
    return HTMLResponse("<h3>Credenciales inválidas. <a href='/login.html'>Volver</a></h3>", status_code=401)

# Initialize OpenAI client
client = OpenAI(api_key=OPENAI_API_KEY)

# Runtime result buffer
test_results = {"asterisk": [], "freeswitch": []}
exploded_services = set()
analysis_sent = False
start_time = time.time()

# ------------------------
# Modelos de datos
# ------------------------

class ProgressData(BaseModel):
    test_type: str
    ip: str
    step: int
    calls: int
    active_calls: int
    cpu: float
    load: str
    memory: str
    bw_tx: float
    bw_rx: float
    timestamp: str

class ExplosionData(BaseModel):
    test_type: str
    ip: str
    cpu: float
    active_calls: int
    step: int
    timestamp: str

class SSHCommand(BaseModel):
    command: str

class SystemInfo(BaseModel):
    test_type: str  # "asterisk" o "freeswitch"
    asterisk_version: str | None = None
    freeswitch_version: str | None = None
    core_cpu: str
    cpu_model: str
    total_ram: str
    timestamp: str

# ------------------------
# Página principal
# ------------------------

@app.get("/")
async def get_index():
    if index_html_path.exists():
        return HTMLResponse(content=index_html_path.read_text(), status_code=200)
    else:
        return JSONResponse(content={"error": "index.html not found"}, status_code=404)

# ------------------------
# WebSocket para métricas
# ------------------------

@app.websocket("/ws")
async def websocket_endpoint(ws: WebSocket):
    await ws.accept()
    await manager.connect(ws)
    try:
        while True:
            await ws.receive_text()
    except Exception:
        await manager.disconnect(ws)

# ------------------------
# API: Optiene informacion de Hardware y version de Asterisk/Freeswitch
# ------------------------

@app.post("/api/system_info")
async def system_info(data: SystemInfo):
    # Guardar info en el estado global
    test_state[data.test_type]["system_info"] = data.dict()

    # Limpiar versiones innecesarias para el otro sistema
    version = data.asterisk_version or data.freeswitch_version

    # Notificar a la interfaz web
    await manager.broadcast({
        "type": "system_info",
        "test_type": data.test_type,
        "version": version,
        "core_cpu": data.core_cpu,
        "cpu_model": data.cpu_model,
        "total_ram": data.total_ram,
        "timestamp": data.timestamp
    })

    return {"status": "ok"}

# ------------------------
# API: Progreso en tiempo real
# ------------------------

@app.post("/api/progress")
async def progress(data: ProgressData):
    global test_results

    # 🧹 Borrar resultados si este es el primer paso (step 0) de su tipo
    if data.step == 0:
        # ✅ Resetear estado global para nuevo análisis
        global exploded_services, analysis_sent, start_time
        exploded_services.clear()
        analysis_sent = False
        start_time = time.time()
        print("[DEBUG] Estado global reiniciado para nuevo test.")
        print(f"[DEBUG] Detected start of new test: {data.test_type}")
        test_results[data.test_type] = []
        test_state[data.test_type]["steps"].clear()

        # Si ambos están ahora vacíos (inicia ambos tests), borra el archivo
        if not test_results["asterisk"] and not test_results["freeswitch"]:
            if progress_file.exists():
                progress_file.unlink()
                print("[DEBUG] Limpieza inicial de results.json")

    # 💾 Guardar nuevo progreso
    test_state[data.test_type]["steps"].append(data.dict())
    test_results[data.test_type].append(data.dict())

    with open(progress_file, "w") as f:
        json.dump(test_results, f)

    await manager.broadcast({"type": "progress", "data": data.dict()})

# ------------------------
# API: Evento de explosión
# ------------------------

@app.post("/api/explosion")
async def explosion(data: ExplosionData):
    global analysis_sent
    test_state[data.test_type]["exploded"] = True
    test_state[data.test_type]["explosion_data"] = data.dict()
    await manager.broadcast({"type": "explosion", "data": data.dict()})

    exploded_services.add(data.test_type)

    if not analysis_sent and "asterisk" in exploded_services and "freeswitch" in exploded_services:
        analysis_sent = True
        asyncio.create_task(schedule_analysis())

# ------------------------
# Programar análisis 10s después del segundo explote
# ------------------------

async def schedule_analysis():
    await asyncio.sleep(2)
    await manager.broadcast({
        "type": "ai_waiting",
        "message": "Sending critical analysis request to the AI...\nHold tight. This could go *very* wrong. ☠️"
    })
    await send_analysis_to_clients()

# ------------------------
# Función: Enviar análisis a los clientes
# ------------------------

async def send_analysis_to_clients():
    global test_results
    try:
        print("[DEBUG] Preparing to send analysis to clients...")

        # 1. Mostrar el mensaje de espera ("dangerous demo") justo antes del request
        await manager.broadcast({
            "type": "ai_waiting",
            "message": "☠️ Dangerous Demo in progress...\nSending critical data to the AI overlord...\nHope this doesn’t break everything! 😱"
        })

        await asyncio.sleep(1)  # Dejá que el frontend muestre la animación

        with open(progress_file, "r") as f:
            result_data = json.load(f)

        a_data = result_data.get("asterisk", [])
        f_data = result_data.get("freeswitch", [])

        def get_max(data, key):
            return max(float(item.get(key, 0)) for item in data)

        def get_max_percent(data, key):
            return max(float(item[key].strip('%')) for item in data if key in item)

        def extract_last_bandwidth_per_call(data):
            last = data[-1]
            calls = int(last.get("active_calls", 0))
            bw_tx = float(last.get("bw_tx", 0))
            return round(bw_tx / calls, 2) if calls > 0 else 0.0

        summary_data = {
            "Max Calls": {
                "asterisk": max(item["calls"] for item in a_data),
                "freeswitch": max(item["calls"] for item in f_data)
            },
            "Max CPU %": {
                "asterisk": get_max(a_data, "cpu"),
                "freeswitch": get_max(f_data, "cpu")
            },
            "Max Memory %": {
                "asterisk": get_max_percent(a_data, "memory"),
                "freeswitch": get_max_percent(f_data, "memory")
            },
            "Avg BW/Call (kbps)": {
                "asterisk": extract_last_bandwidth_per_call(a_data),
                "freeswitch": extract_last_bandwidth_per_call(f_data)
            }
        }

        comparison = [
            {"metric": metric, "asterisk": value["asterisk"], "freeswitch": value["freeswitch"]}
            for metric, value in summary_data.items()
        ]

        winner = determine_winner()
        duration = round(time.time() - start_time)

        # 💬 Generate natural language summary with OpenAI
        ai_prompt = (
            "You are a VoIP benchmarking expert comparing two telephony systems: Asterisk and FreeSWITCH. "
            "Both systems were tested under identical hardware conditions. You are provided with key summary metrics:\n"
            "- Maximum simultaneous calls\n"
            "- Max CPU usage (%)\n"
            "- Max memory usage (%)\n"
            "- Average bandwidth per call (kbps)\n\n"

            "📌 The main performance goal is to determine which system handles more simultaneous calls **relative to its resource usage**. "
            "Higher CPU or memory usage is acceptable **if it results in handling more calls**. "
            "Please consider efficiency: how much CPU and memory are used **per call**.\n\n"

            "🔍 Your task is:\n"
            "1. 🔹 Write three concise technical bullet points (1 line each) comparing both systems, focusing on call-handling efficiency.\n"
            "2. 🏁 Conclude with a 1-line final judgment clearly stating the winner and why.\n\n"
            f"Input Summary JSON:\n{json.dumps(summary_data)}"
        )

        summary = "No summary available"
        if OPENAI_API_KEY:
            response = client.chat.completions.create(
                model=OPENAI_MODEL,
                messages=[
                    {"role": "system", "content": "You are an expert in performance benchmarking."},
                    {"role": "user", "content": ai_prompt}
                ],
                temperature=0.7,
                max_tokens=300
            )
            summary = response.choices[0].message.content.strip()

        # 2. Ahora que tenemos la respuesta, enviar el análisis completo
        await manager.broadcast({
            "type": "analysis",
            "winner": winner,
            "duration": duration,
            "comparison": comparison,
            "summary": summary,
            "confetti": True
        })

    except Exception as e:
        print(f"[ERROR] Failed to generate analysis: {e}")

# ------------------------
# Helpers para métricas
# ------------------------

def extract_max_percent(data, key):
    try:
        return max(float(item[key].strip('%')) for item in data if key in item)
    except:
        return "0%"

def extract_max_float(data, key):
    try:
        return max(float(item[key]) for item in data if key in item)
    except:
        return 0.0

def extract_max(data, key):
    try:
        return max(float(item[key]) for item in data if key in item)
    except:
        return 0.0

def average_bw_per_call(data):
    try:
        total_bw = sum(float(item['bw_tx']) + float(item['bw_rx']) for item in data if 'bw_tx' in item and 'bw_rx' in item)
        total_calls = max(int(item['calls']) for item in data if 'calls' in item)
        return round(total_bw / total_calls, 2) if total_calls else 0.0
    except:
        return 0.0

# ------------------------
# Determinar ganador según duración
# ------------------------

def determine_winner():
    len_ast = len(test_results["asterisk"])
    len_fs = len(test_results["freeswitch"])
    if len_ast > len_fs:
        return "Asterisk"
    elif len_fs > len_ast:
        return "FreeSWITCH"
    else:
        return "Tie"

# ------------------------
# WebSockets: SSH interactivo
# ------------------------

async def ssh_handler(websocket: WebSocket, ip: str):
    await websocket.accept()
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(ip, username=SSH_USER)
    channel = ssh.invoke_shell()
    channel.settimeout(0.0)

    async def read_from_ssh():
        while True:
            await asyncio.sleep(0.01)
            try:
                data = channel.recv(1024)
                if data:
                    await websocket.send_text(data.decode(errors="ignore"))
            except:
                pass

    asyncio.create_task(read_from_ssh())

    try:
        while True:
            data = await websocket.receive_text()
            channel.send(data)
    except:
        channel.close()
        ssh.close()

@app.websocket("/ws/terminal1")
async def ws_terminal1(websocket: WebSocket):
    await ssh_handler(websocket, TERMINAL1_IP)

@app.websocket("/ws/terminal2")
async def ws_terminal2(websocket: WebSocket):
    await ssh_handler(websocket, TERMINAL2_IP)
