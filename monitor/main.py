from fastapi import FastAPI, WebSocket
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from ws_manager import manager
from state import test_state

import requests
import os

app = FastAPI()

# ------------------------
# Data models
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
    calls: int
    step: int
    timestamp: str

# ------------------------
# WebSocket endpoint
# ------------------------

@app.websocket("/ws")
async def websocket_endpoint(ws: WebSocket):
    await manager.connect(ws)
    try:
        while True:
            await ws.receive_text()  # This is not used, only output
    except:
        await manager.disconnect(ws)

# ------------------------
# API: Real-time progress
# ------------------------

@app.post("/api/progress")
async def progress(data: ProgressData):
    test_state[data.test_type]["steps"].append(data.dict())
    await manager.broadcast({
        "type": "progress",
        "data": data.dict()
    })
    return {"ok": True}

# ------------------------
# API: Explosion event
# ------------------------

@app.post("/api/explosion")
async def explosion(data: ExplosionData):
    """
    Handles an explosion event (when CPU usage exceeds the threshold).

    The first component (Asterisk or FreeSWITCH) that reaches the threshold
    will trigger an 'explosion' broadcast. The other one, if it also sends
    an explosion, will be considered the winner and broadcasted as such.
    """

    # Check if any system has already exploded
    for test_type, state in test_state.items():
        if state["exploded"]:
            if test_type != data.test_type:
                # The other system exploded first, so this one is the winner
                await manager.broadcast({
                    "type": "winner",
                    "data": data.dict()
                })
                return {"status": "winner"}
            else:
                # Duplicate explosion from the same system, ignore
                return {"status": "duplicate"}

    # No system exploded yet, this is the first one → EXPLOSION
    test_state[data.test_type]["exploded"] = True
    test_state[data.test_type]["explosion_data"] = data.dict()

    await manager.broadcast({
        "type": "explosion",
        "data": data.dict()
    })

    return {"status": "explosion"}

# ------------------------
# API: Start both tests
# ------------------------

@app.post("/api/start")
def start_tests():
    targets = {
        "asterisk": "http://192.168.10.31:8081",
        "freeswitch": "http://192.168.10.33:8081"
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
            "maxcpuload": lines[6],
            "call_step": lines[7],
            "call_step_seconds": lines[8],
            "call_duration": lines[9],
            "web_notify_url_base": lines[10]
        }

        try:
            r1 = requests.post(f"{base}/config", json=config_data)
            r1.raise_for_status()
            r2 = requests.post(f"{base}/start-test")
            r2.raise_for_status()
        except Exception as e:
            return JSONResponse(status_code=500, content={"error": f"Failed to start test for {tipo}: {str(e)}"})

    return {"started": True}
