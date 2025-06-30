from fastapi import FastAPI, WebSocket
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from ws_manager import manager
from state import test_state

import requests
import os

app = FastAPI()

# ------------------------
# Data Models
# ------------------------

class ProgressData(BaseModel):
    test_type: str  # 'asterisk' or 'freeswitch'
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

# ------------------------
# WebSocket Endpoint
# ------------------------

@app.websocket("/ws")
async def websocket_endpoint(ws: WebSocket):
    """
    WebSocket endpoint for real-time updates.
    """
    await manager.connect(ws)
    try:
        while True:
            await ws.receive_text()  # Not used, only for output
    except Exception as e:
        print(f"WebSocket error: {e}")
        await manager.disconnect(ws)

# ------------------------
# API: Real-time Progress
# ------------------------

@app.post("/api/progress")
async def progress(data: ProgressData):
    """
    Handle progress updates from Asterisk/FreeSWITCH and broadcast to WebSocket clients.
    """
    test_state[data.test_type]["steps"].append(data.dict())
    print(f"Received /api/progress: {data.dict()}")
    await manager.broadcast({
        "type": "progress",
        "data": data.dict()
    })
    return {"ok": True}

# ------------------------
# API: Explosion Event
# ------------------------

@app.post("/api/explosion")
async def explosion(data: ExplosionData):
    """
    Handle explosion event when CPU exceeds threshold.
    Broadcasts explosion to WebSocket clients unless already exploded (unless forced).
    """
    print(f"Received /api/explosion: {data.dict()}")
    test_type = data.test_type
    
    # Allow explosion for manual testing (e.g., curl) or if not exploded
    if os.getenv("FORCE_EXPLOSION", "false").lower() == "true" or not test_state[test_type]["exploded"]:
        test_state[test_type]["exploded"] = True
        test_state[test_type]["explosion_data"] = data.dict()
        print(f"Sending WebSocket message: type=explosion, data={data.dict()}")
        await manager.broadcast({
            "type": "explosion",
            "data": data.dict()
        })
        return {"status": "explosion"}
    
    print(f"Duplicate explosion for {test_type}, ignoring")
    return {"status": "duplicate"}

# ------------------------
# API: Reset State
# ------------------------

@app.post("/api/reset")
def reset_state():
    """
    Reset test state for both systems to allow new tests.
    """
    for test_type in ["asterisk", "freeswitch"]:
        test_state[test_type] = {
            "maxcpuload": test_state[test_type].get("maxcpuload", 75.0),
            "exploded": False,
            "steps": [],
            "explosion_data": {}
        }
    print(f"State reset: {test_state}")
    return {"status": "reset"}

# ------------------------
# API: Start Both Tests
# ------------------------

@app.post("/api/start")
def start_tests():
    """
    Start stress tests for Asterisk and FreeSWITCH by sending config to their servers.
    Resets test state before starting.
    """
    targets = {
        "asterisk": "http://192.168.10.31:8081",
        "freeswitch": "http://192.168.10.33:8081"
    }

    # Reset state before starting tests
    for test_type in ["asterisk", "freeswitch"]:
        test_state[test_type] = {
            "maxcpuload": test_state[test_type].get("maxcpuload", 75.0),
            "exploded": False,
            "steps": [],
            "explosion_data": {}
        }

    for tipo, base in targets.items():
        config_path = f"/opt/stresstest_monitor/configs/{tipo}_config.txt"
        
        if not os.path.exists(config_path):
            return JSONResponse(status_code=400, content={"error": f"Missing config for {tipo}"})

        with open(config_path, "r") as f:
            lines = [line.strip() for line in f.readlines()]

        if len(lines) < 11:
            return JSONResponse(status_code=400, content={"error": f"Incomplete config for {tipo}"})

        config_data = {
            "ip_local": lines[0],
            "ip_remote": lines[1],
            "ssh_remote_port": lines[2],
            "interface_name": lines[3],
            "codec": lines[4],
            "recording": lines[5],
            "maxcpuload": float(lines[6]),
            "call_step": lines[7],
            "call_step_seconds": lines[8],
            "call_duration": lines[9],
            "web_notify_url_base": lines[10]
        }

        test_state[tipo]["maxcpuload"] = config_data["maxcpuload"]

        try:
            r1 = requests.post(f"{base}/config", json=config_data)
            r1.raise_for_status()
            r2 = requests.post(f"{base}/start-test")
            r2.raise_for_status()
        except Exception as e:
            return JSONResponse(status_code=500, content={"error": f"Failed to start test for {tipo}: {str(e)}"})

    print(f"Tests started, state: {test_state}")
    return {"started": True}
