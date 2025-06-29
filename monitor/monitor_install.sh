#!/bin/bash

apt update && apt install -y python3 python3-pip
pip3 install --break-system-packages fastapi uvicorn pydantic aiofiles python-multipart websockets requests

mkdir /opt/stresstest_monitor

wget -O /opt/stresstest_monitor/main.py  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/main.py
wget -O /opt/stresstest_monitor/state.py  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/state.py
wget -O /opt/stresstest_monitor/ws_manager.py  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/ws_manager.py

wget -O /opt/stresstest_monitor/explosion.mp3  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/explosion.mp3
wget -O /opt/stresstest_monitor/winner.mp3  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/winner.mp3

mkdir /var/www/stresstest_monitor
wget -O /var/www/stresstest_monitor/index.html  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/index.html

wget -O /etc/nginx/sites-available/stresstest_monitor  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/stresstest_monitor
ln -s /etc/nginx/sites-available/stresstest_monitor /etc/nginx/sites-enabled/
nginx -t
rm /etc/nginx/sites-enabled/default
systemctl restart nginx

wget -O /etc/systemd/system/stresstest-api.service  https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/stresstest-api.service

systemctl daemon-reload
systemctl enable stresstest-api
systemctl start stresstest-api
