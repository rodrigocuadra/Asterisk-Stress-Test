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
from dotenv import load_dotenv

# ----------------------------------------------------------------------
# Load environment variables from a .env file located in the same folder
# ----------------------------------------------------------------------
load_dotenv()

# ----------------------------------------------------------------------
# Load environment-specific settings with fallback defaults
# These allow customization without changing the code directly
# ----------------------------------------------------------------------
progress_file = Path(os.getenv("PROGRESS_FILE", "/opt/stresstest_monitor/results.json"))
index_html_path = Path(os.getenv("INDEX_HTML_PATH", "/var/www/stresstest_monitor/index.html"))
CALLS_THRESHOLD = int(os.getenv("CALLS_THRESHOLD", "500"))
openai.api_key = os.getenv("OPENAI_API_KEY")
SSH_USER = os.getenv("SSH_USER", "root")
TERMINAL1_IP = os.getenv("TERMINAL1_IP", "192.168.10.31")
TERMINAL2_IP = os.getenv("TERMINAL2_IP", "192.168.10.33")

# Initialize data structure for storing results
test_results = {"asterisk": [], "freeswitch": []}

# Initialize FastAPI application
app = FastAPI()

# ----------------------------------------------------------------------
# Data models using Pydantic for validation of incoming JSON data
# ----------------------------------------------------------------------

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

# ----------------------------------------------------------------------
# Route: Serve main HTML dashboard page
# ----------------------------------------------------------------------

@app.get("/")
async def get_index():
    if index_html_path.exists():
        return HTMLResponse(content=index_html_path.read_text(), status_code=200)
    else:
        return JSONResponse(content={"error": "index.html not found"}, status_code=404)

# ----------------------------------------------------------------------
# WebSocket: Main dashboard metrics connection
# ----------------------------------------------------------------------

@app.websocket("/ws")
async def websocket_endpoint(ws: WebSocket):
    await ws.accept()
    await manager.connect(ws)
    try:
        while True:
            await ws.receive_text()  # Keeps the connection alive
    except Exception:
        await manager.disconnect(ws)

# ----------------------------------------------------------------------
# API: Receives real-time progress metrics during stress test
# Stores in memory and to disk, then broadcasts to dashboard clients
# ----------------------------------------------------------------------

@app.post("/api/progress")
async def progress(data: ProgressData):
    test_state[data.test_type]["steps"].append(data.dict())
    test_results[data.test_type].append(data.dict())
    with open(progress_file, "w") as f:
        json.dump(test_results, f)
    await manager.broadcast({"type": "progress", "data": data.dict()})

# ----------------------------------------------------------------------
# API: Receives "explosion" event (CPU overload alert)
# Broadcasts the event to frontend
# ----------------------------------------------------------------------

@app.post("/api/explosion")
async def explosion(data: ExplosionData):
    test_state[data.test_type]["exploded"] = True
    test_state[data.test_type]["explosion_data"] = data.dict()
    await manager.broadcast({"type": "explosion", "data": data.dict()})

# ----------------------------------------------------------------------
# WebSocket Handler: Interactive SSH Terminal using Paramiko
# Supports bidirectional command I/O between frontend and backend shell
# ----------------------------------------------------------------------

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

# ----------------------------------------------------------------------
# WebSocket Endpoints for two remote terminals
# Each connects to a separate IP as defined in environment variables
# ----------------------------------------------------------------------

@app.websocket("/ws/terminal1")
async def ws_terminal1(websocket: WebSocket):
    await ssh_handler(websocket, TERMINAL1_IP)

@app.websocket("/ws/terminal2")
async def ws_terminal2(websocket: WebSocket):
    await ssh_handler(websocket, TERMINAL2_IP)
