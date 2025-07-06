        function startTests() {
            document.getElementById("explosion-sound").play().catch(() => { });
            document.getElementById("winner-sound").play().catch(() => { });

            const cmd = "cd /opt/stress_test && ./stress_test.sh --notify --auto\n";
            if (socket1 && socket1.readyState === WebSocket.OPEN) socket1.send(cmd);
            if (socket2 && socket2.readyState === WebSocket.OPEN) socket2.send(cmd);
        }

        const ws = new WebSocket("ws://" + location.hostname + ":8000/ws");

        function updateCardColor(card, value) {
            if (value >= 50) {
                card.style.background = '#f8d7da';
            } else if (value >= 30) {
                card.style.background = '#fff3cd';
            } else {
                card.style.background = '#d4edda';
            }
        }

        function updateChart(chart, value) {
            chart.data.labels.push('');
            chart.data.datasets[0].data.push(value);
            if (chart.data.labels.length > 20) {
                chart.data.labels.shift();
                chart.data.datasets[0].data.shift();
            }
            chart.update();
        }

        function declareWinner(type) {
            const name = type === 'asterisk' ? 'Asterisk' : 'FreeSWITCH';
            document.getElementById("winner-box").innerText = "🏆 " + name + " is the Winner!";
            document.getElementById("winner-box").style.display = "block";
            confetti();
            document.getElementById("winner-sound").play();
        }

        function triggerExplosion(type) {
            const overlay = document.getElementById(type + "-overlay");
            overlay.style.display = "flex";
            document.getElementById("explosion-sound").play();
            setTimeout(() => {
                overlay.style.display = "none";
            }, 10000);
        }
        const charts = {
            asterisk: new Chart(document.getElementById("asterisk-chart"), {
                type: 'line',
                data: { labels: [], datasets: [{ label: 'CPU %', data: [], borderColor: '#007BFF' }] },
                options: { animation: false, responsive: true, scales: { y: { beginAtZero: true, max: 100 } } }
            }),
            freeswitch: new Chart(document.getElementById("freeswitch-chart"), {
                type: 'line',
                data: { labels: [], datasets: [{ label: 'CPU %', data: [], borderColor: '#28A745' }] },
                options: { animation: false, responsive: true, scales: { y: { beginAtZero: true, max: 100 } } }
            })
        };

        ws.onmessage = (event) => {
            const msg = JSON.parse(event.data);
            const t = msg.data.test_type;

            if (msg.type === 'progress') {
                document.getElementById(t + "-cpu").innerText = "CPU: " + msg.data.cpu + "%";
                document.getElementById(t + "-mem").innerText = "Memory: " + msg.data.memory;
                document.getElementById(t + "-calls").innerText = "Active Calls: " + msg.data.active_calls;
                document.getElementById(t + "-bw").innerText = "BW TX: " + msg.data.bw_tx + " kb/s";

                updateCardColor(document.getElementById(t + "-cpu"), msg.data.cpu);
                updateChart(charts[t], msg.data.cpu);

                let mbox = document.getElementById(t + "-message");
                if (msg.data.cpu < 35) {
                    mbox.innerText = "💪 More calls! I can handle more load!";
                } else if (msg.data.cpu < 60) {
                    mbox.innerText = "😅 Take it easy, I'm getting tired...";
                } else {
                    mbox.innerText = "🥵 Please stop! I'm overloaded!";
                }
            }

            if (msg.type === 'explosion') {
                triggerExplosion(t);
            }

            if (msg.type === 'winner') {
                declareWinner(t);
            }
        };

        const term1 = new Terminal({ cursorBlink: true, fontSize: 14 });
        const fitAddon1 = new FitAddon.FitAddon();
        term1.loadAddon(fitAddon1);
        term1.open(document.getElementById("terminal1"));
        fitAddon1.fit();

        const socket1 = new WebSocket(`ws://${location.host}/ws/terminal1`);
        socket1.onmessage = e => term1.write(e.data);
        term1.onData(data => socket1.send(data));

        const term2 = new Terminal({ cursorBlink: true, fontSize: 14 });
        const fitAddon2 = new FitAddon.FitAddon();
        term2.loadAddon(fitAddon2);
        term2.open(document.getElementById("terminal2"));
        fitAddon2.fit();

        const socket2 = new WebSocket(`ws://${location.host}/ws/terminal2`);
        socket2.onmessage = e => term2.write(e.data);
        term2.onData(data => socket2.send(data));
