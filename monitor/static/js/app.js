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

function startTests() {
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
    confetti();
    document.getElementById("winner-sound").play();
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
        const overlay = document.createElement("div");
        overlay.style.position = "fixed";
        overlay.style.top = "0";
        overlay.style.left = "0";
        overlay.style.width = "100%";
        overlay.style.height = "100%";
        overlay.style.backgroundColor = "rgba(0, 0, 0, 0.65)";
        overlay.style.zIndex = "9999";
        overlay.style.overflow = "auto";
        overlay.style.padding = "40px";
        overlay.style.color = "#fff";
        overlay.style.fontSize = "1.2em";

        const content = document.createElement("div");
        content.style.background = "#222";
        content.style.padding = "20px";
        content.style.borderRadius = "10px";
        content.style.maxWidth = "1000px";
        content.style.margin = "0 auto";
        content.style.whiteSpace = "pre-wrap";

        let table = `<h2 style='text-align:center'>🏆 ${msg.winner}</h2>`;
        table += `<p style='text-align:center'>⏱ Duration: ${msg.duration} seconds</p>`;
        table += `<table style='width:100%;border-collapse:collapse;margin-top:20px'>`;
        table += `<thead><tr><th style='border:1px solid #ccc;padding:8px'>Metric</th><th style='border:1px solid #ccc;padding:8px'>Asterisk</th><th style='border:1px solid #ccc;padding:8px'>FreeSWITCH</th></tr></thead><tbody>`;
        msg.comparison.forEach(row => {
            table += `<tr><td style='border:1px solid #ccc;padding:8px'>${row.metric}</td><td style='border:1px solid #ccc;padding:8px'>${row.asterisk}</td><td style='border:1px solid #ccc;padding:8px'>${row.freeswitch}</td></tr>`;
        });
        table += `</tbody></table>`;

        content.innerHTML = table;

        const closeBtn = document.createElement("button");
        closeBtn.innerText = "Close";
        closeBtn.style.marginTop = "20px";
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

        if (msg.confetti && window.confetti) {
            const duration = 10 * 1000;
            const end = Date.now() + duration;
            (function frame() {
                confetti({ particleCount: 5, angle: 60, spread: 55, origin: { x: 0 } });
                confetti({ particleCount: 5, angle: 120, spread: 55, origin: { x: 1 } });
                if (Date.now() < end) {
                    requestAnimationFrame(frame);
                }
            })();
        }
    }
};

let testStart = Date.now();
setInterval(() => {
    const elapsed = Math.floor((Date.now() - testStart) / 1000);
    document.getElementById("test-timer").textContent = `Elapsed: ${elapsed}s`;
}, 1000);
