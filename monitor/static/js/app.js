// app.js - Handles dashboard UI, charts, and interactive SSH terminals for Stress Test Monitor

// === Terminal Initialization ===
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

let testStart;
const timerEl = document.createElement("div");
timerEl.id = "test-timer";
timerEl.style.position = "fixed";
timerEl.style.top = "20px";
timerEl.style.right = "20px";
timerEl.style.background = "rgba(0, 0, 0, 0.85)";
timerEl.style.color = "white";
timerEl.style.padding = "10px 20px";
timerEl.style.borderRadius = "10px";
timerEl.style.fontSize = "1.5em";
timerEl.style.fontWeight = "bold";
timerEl.style.zIndex = "1000";
timerEl.style.boxShadow = "0 0 10px rgba(0,0,0,0.5)";
timerEl.textContent = "Elapsed: 0s";
document.body.appendChild(timerEl);

let timerInterval;

function startTests() {
    testStart = Date.now();
    clearInterval(timerInterval);
    timerInterval = setInterval(() => {
        const elapsed = Math.floor((Date.now() - testStart) / 1000);
        timerEl.textContent = `Elapsed: ${elapsed}s`;
    }, 1000);

    document.getElementById("explosion-sound").play().catch(() => {});
    document.getElementById("winner-sound").play().catch(() => {});
    document.getElementById("start-btn").style.display = "none";
    socket1.send("cd /opt/stress_test && ./stress_test.sh --notify --auto\n");
    socket2.send("cd /opt/stress_test && ./stress_test.sh --notify --auto\n");
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
    document.getElementById("winner-sound").play();

    // Trigger confetti on the custom canvas
    if (window.confetti) {
        const canvas = document.getElementById("confetti-canvas");
        const myConfetti = confetti.create(canvas, { resize: true, useWorker: true });
        const duration = 10 * 1000;
        const end = Date.now() + duration;

        (function frame() {
            myConfetti({ particleCount: 5, angle: 60, spread: 55, origin: { x: 0 } });
            myConfetti({ particleCount: 5, angle: 120, spread: 55, origin: { x: 1 } });
            if (Date.now() < end) {
                requestAnimationFrame(frame);
            }
        })();
    }
}

function triggerExplosion(type) {
    const overlay = document.getElementById(`${type}-overlay`);
    const sound = document.getElementById("explosion-sound");
    overlay.classList.remove("show", "persistent");
    void overlay.offsetWidth;
    overlay.classList.add("show");
    sound.currentTime = 0;
    sound.play().catch(() => {});
    setTimeout(() => {
        overlay.classList.remove("show");
        overlay.classList.add("persistent");
    }, 10000);
}

const charts = {
    asterisk: new Chart(document.getElementById("asterisk-chart"), {
        type: 'line',
        data: {
            labels: [],
            datasets: [{ label: 'CPU %', data: [], borderColor: '#007BFF' }]
        },
        options: {
            animation: false,
            responsive: true,
            scales: { y: { beginAtZero: true, max: 100 } }
        }
    }),
    freeswitch: new Chart(document.getElementById("freeswitch-chart"), {
        type: 'line',
        data: {
            labels: [],
            datasets: [{ label: 'CPU %', data: [], borderColor: '#28A745' }]
        },
        options: {
            animation: false,
            responsive: true,
            scales: { y: { beginAtZero: true, max: 100 } }
        }
    })
};

ws.onmessage = (event) => {
    const msg = JSON.parse(event.data);
    const t = msg.data?.test_type;

    if (msg.type === 'system_info') {
        // Actualizar el título con la versión
        const versionSpan = document.getElementById(`${msg.test_type}-version`);
        versionSpan.textContent = `(${msg.version})`;

        // Insertar el hardware info en una sola línea
        const infoDiv = document.getElementById(`${msg.test_type}-info`);
        infoDiv.innerText = `${msg.core_cpu} cores • ${msg.cpu_model} • RAM ${msg.total_ram}`;
    }
    
    if (msg.type === 'progress') {
        document.getElementById(t + "-cpu").innerText = "CPU: " + msg.data.cpu + "%";
        document.getElementById(t + "-mem").innerText = "Memory: " + msg.data.memory;
        document.getElementById(t + "-calls").innerText = "Active Calls: " + msg.data.active_calls;
        document.getElementById(t + "-bw").innerText = "BW TX: " + msg.data.bw_tx + " kb/s";

        updateCardColor(document.getElementById(t + "-cpu"), msg.data.cpu);
        updateChart(charts[t], msg.data.cpu);

        const mbox = document.getElementById(t + "-message");
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

    if (msg.type === 'analysis') {
        clearInterval(timerInterval);

        const overlay = document.createElement("div");
        overlay.style.position = "fixed";
        overlay.style.top = "0";
        overlay.style.left = "0";
        overlay.style.width = "100vw";
        overlay.style.height = "100vh";
        overlay.style.backgroundColor = "rgba(0, 0, 0, 0.92)";
        overlay.style.zIndex = "9999";
        overlay.style.display = "flex";
        overlay.style.justifyContent = "center";
        overlay.style.alignItems = "center";
        overlay.style.padding = "0";  // sin márgenes internos
        overlay.style.margin = "0";  // sin márgenes externos

        const content = document.createElement("div");
        const summaryText = (msg.summary || "No summary available.")
            .replace(/\*\*/g, '') // quitar negritas markdown
            .replace(/^\s*\d+\.\s+/gm, match => match.trim()) // limpiar numeración si es Markdown
            .trim();
        content.style.width = "100vw";               // usa el 100% del ancho visible
        content.style.maxWidth = "100vw";            // sin restricción de ancho máximo
        content.style.maxHeight = "90vh";            // previene desborde vertical
        content.style.overflowY = "auto";            // scroll solo vertical si necesario
        content.style.background = "#222";
        content.style.padding = "40px";
        content.style.borderRadius = "0";            // sin bordes redondeados
        content.style.boxSizing = "border-box";
        content.style.color = "#fff";
        content.style.fontSize = "1.2em";
        content.style.textAlign = "left";

        let table = `
            <div id="winner-summary" style="position: relative; padding-top: 30px;">

                <div class="test-duration" style="
                    position: absolute;
                    top: 0;
                    right: 20px;
                    font-size: 1em;
                    color: #ccc;">
                    ⏱ Duration: ${msg.duration} seconds
                </div>

                <h2 style="
                    font-size: 3em;
                    text-align: center;
                    color: #ffd700;
                    margin-bottom: 10px;">
                    🏆 ${msg.winner}
                </h2>

                <h3 style="text-align: center; font-size: 1.5em; margin-bottom: 15px;">📋 Summary</h3>
                <div style="
                    padding: 20px;
                    background: #2c2c2c;
                    border-radius: 10px;
                    color: #f0f0f0;
                    font-size: 1.2em;
                    line-height: 1.8;
                    text-align: justify;
                    margin-bottom: 30px;">
                    ${
                        summaryText
                            .replace(/\*\*(.*?)\*\*/g, "<strong>$1</strong>")
                            .replace(/\s*\d+\.\s/g, '\n$&')
                            .replace(/🏁/g, '\n🏁')
                            .split('\n')
                            .filter(line => line.trim())
                            .map(line => `<p>${line.trim()}</p>`)
                            .join('\n')
                    }
                </div>

                <table style="
                    width: 50%;
                    max-width: 50%;
                    margin: 0 auto 20px auto;
                    border-collapse: collapse;
                    font-size: 1em;
                    color: #fff;">
                    <thead>
                        <tr>
                            <th style="border:1px solid #ccc;padding:8px">Metric</th>
                            <th style="border:1px solid #ccc;padding:8px">Asterisk</th>
                            <th style="border:1px solid #ccc;padding:8px">FreeSWITCH</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${msg.comparison.map(row => `
                            <tr>
                                <td style="border:1px solid #ccc;padding:8px">${row.metric}</td>
                                <td style="border:1px solid #ccc;padding:8px">${row.asterisk}</td>
                                <td style="border:1px solid #ccc;padding:8px">${row.freeswitch}</td>
                            </tr>`).join('\n')}
                    </tbody>
                </table>
            </div>
        `;

        content.innerHTML = table;

        const closeBtn = document.createElement("button");
        closeBtn.innerText = "Close";
        closeBtn.style.marginTop = "20px";
        closeBtn.style.display = "block";
        closeBtn.style.marginLeft = "auto";
        closeBtn.style.marginRight = "auto";
        closeBtn.style.padding = "10px 20px";
        closeBtn.style.fontSize = "1em";
        closeBtn.style.background = "#007BFF";
        closeBtn.style.border = "none";
        closeBtn.style.borderRadius = "5px";
        closeBtn.style.cursor = "pointer";
        closeBtn.onclick = () => overlay.remove();

        content.appendChild(closeBtn);
        overlay.appendChild(content);
        document.body.appendChild(overlay);

        document.getElementById("winner-sound").play().catch(() => {});
        declareWinner(msg.winner.toLowerCase());
    }
};
