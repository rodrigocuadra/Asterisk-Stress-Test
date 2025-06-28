#!/bin/bash

# ------------------------------------------------------------------------------
# StressTest API Installer Script
# ------------------------------------------------------------------------------
#
# Description:
#   This script installs and configures a FastAPI-based HTTP API to control
#   stress test scripts for Asterisk or FreeSWITCH.
#
# Requirements:
#   - Debian 12 or compatible system
#   - Root privileges
#
# Components Installed:
#   - Python 3 and pip
#   - FastAPI, Uvicorn, Pydantic (via pip with system override)
#   - API script (main.py)
#   - systemd service (stresstest-api.service)
#
# Author: Rodrigo Cuadra
# ------------------------------------------------------------------------------

set -e

echo "📦 Installing required system packages..."
apt update
apt install -y python3 python3-pip curl

echo "🐍 Installing Python libraries globally (bypassing PEP 668)..."
pip3 install --break-system-packages fastapi uvicorn pydantic

echo "📁 Creating API directory at /opt/stresstest_api..."
mkdir -p /opt/stresstest_api

echo "🧠 Writing main.py (FastAPI script)..."
cat > /opt/stresstest_api/main.py << 'EOF'
from fastapi import FastAPI
from pydantic import BaseModel
import subprocess

app = FastAPI()

class ConfigData(BaseModel):
    ip_local: str
    ip_remote: str
    ssh_remote_port: str
    interface_name: str
    codec: str
    recording: str
    maxcpuload: str
    call_step: str
    call_step_seconds: str
    call_duration: str
    web_notify_url_base: str

@app.post("/config")
def receive_config(data: ConfigData):
    with open("/opt/stress_test/config.txt", "w") as f:
        f.write("\n".join([
            data.ip_local,
            data.ip_remote,
            data.ssh_remote_port,
            data.interface_name,
            data.codec,
            data.recording,
            data.maxcpuload,
            data.call_step,
            data.call_step_seconds,
            data.call_duration,
            data.web_notify_url_base
        ]) + "\n")
    return {"status": "✔️ config.txt written"}

@app.post("/start-test")
def start_test():
    subprocess.Popen(["/bin/bash", "/opt/stress_test/stress_test.sh", "--auto"])
    return {"status": "🚀 test started"}
EOF

echo "🛠️ Creating systemd service: stresstest-api.service..."
cat > /etc/systemd/system/stresstest-api.service << EOF
[Unit]
Description=StressTest API for Asterisk/Freeswitch test control
After=network.target

[Service]
ExecStart=/usr/local/bin/uvicorn main:app --host 0.0.0.0 --port 8081
WorkingDirectory=/opt/stresstest_api
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

echo "🔄 Reloading systemd and starting the API service..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable stresstest-api.service
systemctl start stresstest-api.service

echo "✅ Installation complete."
echo "🌐 Access the API docs at: http://<your-server-ip>:8081/docs"
