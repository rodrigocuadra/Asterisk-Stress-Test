from fastapi import FastAPI, WebSocket
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ValidationError
from ws_manager import manager
from state import test_state
import requests
import os
import json

app = FastAPI()

# Configurable threshold for active calls (default 500)
CALLS_THRESHOLD = int(os.getenv("CALLS_THRESHOLD", "500"))

# Placeholder for AI API endpoint (replace with actual xAI API)
AI_API_URL = os.getenv("AI_API_URL", "https://api.x.ai/analyze")  # Ejemplo, ajusta según la API real

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
    Accepts the WebSocket connection and manages it via the manager.
    """
    print("Attempting to accept WebSocket connection")
    await ws.accept()
    print("WebSocket connection accepted")
    await manager.connect(ws)
    try:
        while True:
            await ws.receive_text()  # Keep the connection alive
    except Exception as e:
        print(f"WebSocket error during connection: {e}")
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
    Handle explosion event when active_calls exceeds the threshold.
    Broadcasts explosion to WebSocket clients and sends data to AI.
    """
    print(f"Received /api/explosion raw data: {data}")
    try:
        # Validate and parse data
        validated_data = data.dict()
        test_type = validated_data["test_type"]
        active_calls = validated_data["active_calls"]
        print(f"Validated data: {validated_data}")

        # Check if test_state is initialized
        if test_type not in test_state:
            print(f"Error: test_state not initialized for {test_type}")
            return JSONResponse(status_code=500, content={"error": f"Test state not initialized for {test_type}"})

        # Trigger explosion if active_calls exceeds threshold
        if active_calls >= CALLS_THRESHOLD:
            test_state[test_type]["explosion_data"] = validated_data
            print(f"Attempting to broadcast explosion message for {test_type} due to {active_calls} active calls")
            try:
                await manager.broadcast({
                    "type": "explosion",
                    "data": validated_data
                })
                print(f"Explosion message broadcasted successfully for {test_type}")
            except Exception as e:
                print(f"Broadcast error: {e}")
                return JSONResponse(status_code=500, content={"error": "Failed to broadcast", "details": str(e)})

            # Send data to AI (placeholder)
            try:
                response = requests.post(AI_API_URL, json=validated_data)
                response.raise_for_status()
                print(f"Data sent to AI successfully: {response.text}")
            except Exception as e:
                print(f"Failed to send data to AI: {e}")

            return {"status": "explosion"}
        
        print(f"No explosion for {test_type}, active_calls {active_calls} below threshold {CALLS_THRESHOLD}")
        return {"status": "no_explosion"}

    except ValidationError as ve:
        print(f"Validation error: {ve}")
        return JSONResponse(status_code=422, content={"error": "Invalid data format", "details": str(ve)})
    except Exception as e:
        print(f"Internal server error: {e}")
        return JSONResponse(status_code=500, content={"error": "Internal server error", "details": str(e)})

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

# ------------------------
# API: Get Comparison (New Endpoint)
# ------------------------

@app.get("/api/comparison")
async def get_comparison():
    """
    Provide a comparison between Asterisk and FreeSWITCH based on collected data.
    """
    asterisk_data = test_state["asterisk"]["explosion_data"]
    freeswitch_data = test_state["freeswitch"]["explosion_data"]

    comparison = {
        "asterisk": asterisk_data or {"status": "No explosion data"},
        "freeswitch": freeswitch_data or {"status": "No explosion data"},
        "max_calls": {
            "asterisk": test_state["asterisk"]["maxCalls"],
            "freeswitch": test_state["freeswitch"]["maxCalls"]
        }
    }
    print(f"Comparison data: {comparison}")
    return comparison
