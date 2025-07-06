#!/bin/bash

apt update && apt install -y python3 python3-pip
pip3 install --break-system-packages fastapi uvicorn paramiko pydantic aiofiles python-multipart websockets requests
pip3 install openai --break-system-packages

mkdir -p /opt/stresstest_monitor
wget -O /opt/stresstest_monitor/main.py  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/main.py
wget -O /opt/stresstest_monitor/state.py  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/state.py
wget -O /opt/stresstest_monitor/ws_manager.py  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/ws_manager.py

mkdir -p /var/www/stresstest_monitor
mkdir -p /var/www/stresstest_monitor/static/js
mkdir -p /var/www/stresstest_monitor/static/css

# JS libraries
wget https://cdn.jsdelivr.net/npm/xterm@5.3.0/lib/xterm.min.js -O /var/www/stresstest_monitor/static/js/xterm.min.js
wget https://cdn.jsdelivr.net/npm/xterm-addon-fit@0.7.0/lib/xterm-addon-fit.min.js -O /var/www/stresstest_monitor/static/js/xterm-addon-fit.min.js
wget https://cdn.jsdelivr.net/npm/chart.js -O /var/www/stresstest_monitor/static/js/chart.umd.min.js
wget https://cdn.jsdelivr.net/npm/canvas-confetti@1.6.0/dist/confetti.browser.min.js -O /var/www/stresstest_monitor/static/js/confetti.min.js

# CSS
wget https://cdn.jsdelivr.net/npm/xterm@5.3.0/css/xterm.css -O /var/www/stresstest_monitor/static/css/xterm.css

wget -O /var/www/stresstest_monitor/explosion.mp3  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/explosion.mp3
wget -O /var/www/stresstest_monitor/winner.mp3  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/winner.mp3


wget -O /var/www/stresstest_monitor/index.html  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/index.html
wget -O /var/www/stresstest_monitor/favicon.ico  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/favicon.ico

wget -O /etc/nginx/sites-available/stresstest_monitor  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/stresstest_monitor
ln -s /etc/nginx/sites-available/stresstest_monitor /etc/nginx/sites-enabled/
nginx -t
rm /etc/nginx/sites-enabled/default
systemctl restart nginx

wget -O /etc/systemd/system/stresstest-api.service  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/stresstest-api.service

systemctl daemon-reload
systemctl enable stresstest-api
systemctl start stresstest-api
