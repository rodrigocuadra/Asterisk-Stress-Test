from fastapi import FastAPI, WebSocket
from fastapi.responses import JSONResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from ws_manager import manager
from state import test_state

import requests
import os
import json
from pathlib import Path
import openai
import subprocess
import asyncio
import paramiko

progress_file = Path("/opt/stresstest_monitor/results.json")
test_results = {"asterisk": [], "freeswitch": []}

app = FastAPI()

CALLS_THRESHOLD = int(os.getenv("CALLS_THRESHOLD", "500"))
openai.api_key = os.getenv("sk-proj-*****")

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
    html_path = Path("/var/www/stresstest_monitor/index.html")
    if html_path.exists():
        return HTMLResponse(content=html_path.read_text(), status_code=200)
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
    return {"ok": True}

# ------------------------
# API: Evento de explosión
# ------------------------

@app.post("/api/explosion")
async def explosion(data: ExplosionData):
    test_state[data.test_type]["exploded"] = True
    test_state[data.test_type]["explosion_data"] = data.dict()
    await manager.broadcast({"type": "explosion", "data": data.dict()})
    return {"status": "explosion"}

# ------------------------
# API: Reset del estado
# ------------------------

@app.post("/api/reset")
def reset_state():
    for test_type in ["asterisk", "freeswitch"]:
        test_state[test_type] = {
            "maxcpuload": test_state[test_type].get("maxcpuload", 75.0),
            "exploded": False,
            "steps": [],
            "explosion_data": {}
        }
    return {"status": "reset"}

# ------------------------
# API: Iniciar stress tests remotos
# ------------------------

@app.post("/api/start")
def start_tests():
    hosts = {
        "asterisk": "192.168.10.31",
        "freeswitch": "192.168.10.33"
    }

    for test_type in hosts:
        test_state[test_type] = {
            "maxcpuload": test_state[test_type].get("maxcpuload", 75.0),
            "exploded": False,
            "steps": [],
            "explosion_data": {}
        }

    for tipo, ip in hosts.items():
        try:
            subprocess.run(
                ["ssh", f"root@{ip}", "bash -lc '/opt/stress_test/stress_test.sh --notify --auto'"],
                check=True
            )
        except subprocess.CalledProcessError as e:
            return JSONResponse(status_code=500, content={"error": f"Failed to start {tipo} test: {str(e)}"})

    return {"started": True}

# ------------------------
# WebSockets: SSH interactivo
# ------------------------

async def ssh_handler(websocket: WebSocket, ip: str):
    await websocket.accept()
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(ip, username="root")
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
    await ssh_handler(websocket, "192.168.10.31")

@app.websocket("/ws/terminal2")
async def ws_terminal2(websocket: WebSocket):
    await ssh_handler(websocket, "192.168.10.33")
