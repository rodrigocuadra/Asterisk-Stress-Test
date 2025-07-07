from fastapi import FastAPI, WebSocket
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

# Initialize OpenAI client
client = OpenAI(api_key=OPENAI_API_KEY)

# Runtime result buffer
test_results = {"asterisk": [], "freeswitch": []}
exploded_services = set()
analysis_sent = False
start_time = time.time()

app = FastAPI()

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
# API: Progreso en tiempo real
# ------------------------

@app.post("/api/progress")
async def progress(data: ProgressData):
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
    await asyncio.sleep(10)
    await send_analysis_to_clients()

# ------------------------
# Función: Enviar análisis a los clientes
# ------------------------

async def send_analysis_to_clients():
    global test_results
    try:
        print("[DEBUG] Preparing to send analysis to clients...")
        with open(progress_file, "r") as f:
            result_data = json.load(f)

        a_data = result_data.get("asterisk", [])
        f_data = result_data.get("freeswitch", [])

        comparison = [
            {"metric": "Max Calls", "asterisk": len(a_data) * 100, "freeswitch": len(f_data) * 100},
            {"metric": "Max CPU %", "asterisk": f"{extract_max(a_data, 'cpu')}%", "freeswitch": f"{extract_max(f_data, 'cpu')}%"},
            {"metric": "Max Memory %", "asterisk": extract_max_percent(a_data, 'memory'), "freeswitch": extract_max_percent(f_data, 'memory')},
            {"metric": "Max Load", "asterisk": extract_max_float(a_data, 'load'), "freeswitch": extract_max_float(f_data, 'load')},
            {"metric": "Max BW TX (kbps)", "asterisk": extract_max_float(a_data, 'bw_tx'), "freeswitch": extract_max_float(f_data, 'bw_tx')}
        ]

        winner = determine_winner()
        duration = round(time.time() - start_time)

        # 💬 Generate natural language summary with OpenAI
        ai_prompt = (
            "You are a performance analyst. I will give you a JSON object with two sections: 'asterisk' and 'freeswitch', "
            "each containing multiple step results with metrics like cpu, memory, bw_tx, bw_rx, etc.\n"
            "Analyze it and provide:\n"
            "- A short summary of the most relevant technical differences\n"
            "- An engaging and energetic one-sentence declaration of the winner\n\n"
            f"Input JSON:\n{json.dumps(result_data)}"
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
