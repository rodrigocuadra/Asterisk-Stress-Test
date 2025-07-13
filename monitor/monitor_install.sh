#!/bin/bash

# -----------------------------
# Update & Install Dependencies
# -----------------------------
# Update the package list and install Python 3 and pip nginx
apt update && apt install -y python3 python3-pip nginx

# Install required Python packages for the FastAPI application
# --break-system-packages ensures compatibility on newer systems like Ubuntu 23+
pip3 install --break-system-packages fastapi uvicorn paramiko pydantic aiofiles python-multipart websockets requests python-dotenv
pip3 install openai --break-system-packages

# -----------------------------
# Create Project Directory
# -----------------------------
mkdir -p /opt/stresstest_monitor

# -----------------------------
# Download Backend Python Scripts
# -----------------------------
wget -O /opt/stresstest_monitor/main.py  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/main.py
wget -O /opt/stresstest_monitor/state.py  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/state.py
wget -O /opt/stresstest_monitor/ws_manager.py  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/ws_manager.py

# -----------------------------
# Prepare Web Frontend Structure
# -----------------------------
mkdir -p /var/www/stresstest_monitor
mkdir -p /var/www/stresstest_monitor/static/js
mkdir -p /var/www/stresstest_monitor/static/css
mkdir -p /var/www/stresstest_monitor/static/audios

# -----------------------------
# Download JavaScript Libraries
# -----------------------------
wget https://cdn.jsdelivr.net/npm/xterm@5.3.0/lib/xterm.min.js -O /var/www/stresstest_monitor/static/js/xterm.min.js
wget https://cdn.jsdelivr.net/npm/xterm-addon-fit@0.7.0/lib/xterm-addon-fit.min.js -O /var/www/stresstest_monitor/static/js/xterm-addon-fit.min.js
wget https://cdn.jsdelivr.net/npm/chart.js -O /var/www/stresstest_monitor/static/js/chart.umd.min.js
wget https://cdn.jsdelivr.net/npm/canvas-confetti@1.5.1/dist/confetti.browser.min.js -O /var/www/stresstest_monitor/static/js/confetti.browser.min.js
wget https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/static/js/app.js -O /var/www/stresstest_monitor/static/js/app.js

# -----------------------------
# Download CSS Stylesheets
# -----------------------------
wget https://cdn.jsdelivr.net/npm/xterm@5.3.0/css/xterm.css -O /var/www/stresstest_monitor/static/css/xterm.css
wget https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/static/css/styles.css -O /var/www/stresstest_monitor/static/css/styles.css

# -----------------------------
# Download Audio Effects
# -----------------------------
wget -O /var/www/stresstest_monitor/static/audios/explosion.mp3  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/static/audios/explosion.mp3
wget -O /var/www/stresstest_monitor/static/audios/winner.mp3  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/static/audios/winner.mp3

# -----------------------------
# Download Web Entry Point and Favicon
# -----------------------------
wget -O /var/www/stresstest_monitor/index.html  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/index.html
wget -O /var/www/stresstest_monitor/favicon.ico  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/favicon.ico

# -----------------------------
# Configure Nginx
# -----------------------------
wget -O /etc/nginx/sites-available/stresstest_monitor  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/stresstest_monitor
ln -s /etc/nginx/sites-available/stresstest_monitor /etc/nginx/sites-enabled/
nginx -t
rm /etc/nginx/sites-enabled/default
systemctl restart nginx

# -----------------------------
# Install systemd Service for FastAPI App
# -----------------------------
wget -O /etc/systemd/system/stresstest-api.service  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/stresstest-api.service
systemctl daemon-reload
systemctl enable stresstest-api
systemctl start stresstest-api

# Create environment file
cat <<EOF > /opt/stresstest_monitor/.env
CALLS_THRESHOLD=500
OPENAI_API_KEY=sk-proj-************************
INDEX_HTML_PATH=/var/www/stresstest_monitor/index.html
PROGRESS_FILE=/opt/stresstest_monitor/results.json
SSH_USER=root
TERMINAL1_IP=xxx.xxx.xxx.xxx
TERMINAL2_IP=xxx.xxx.xxx.xxx
EOF
