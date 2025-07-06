// app.js - Handles dashboard UI, charts, and interactive SSH terminals for Stress Test Monitor

// === Terminal Initialization ===
// Initialize two interactive SSH terminals (Asterisk & FreeSWITCH)
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

// === Dashboard Controls ===
// Play sounds and trigger confetti animation on test start
function startTests() {
    document.getElementById("explosion-sound").play().catch(() => {});
    document.getElementById("winner-sound").play().catch(() => {});
    document.getElementById("start-btn").style.display = "none";
    
    // Send command to both terminals to start stress test
    socket1.send("cd /opt/stress_test && ./stress_test.sh --notify --auto\n");
    socket2.send("cd /opt/stress_test && ./stress_test.sh --notify --auto\n");
}

// === WebSocket for Dashboard Metrics ===
const ws = new WebSocket("ws://" + location.hostname + ":8000/ws");

// Update the color of metric cards based on value (e.g., CPU usage)
function updateCardColor(card, value) {
    if (value >= 50) {
        card.style.background = '#f8d7da'; // red
    } else if (value >= 30) {
        card.style.background = '#fff3cd'; // yellow
    } else {
        card.style.background = '#d4edda'; // green
    }
}

// Update the line chart with new CPU value
function updateChart(chart, value) {
    chart.data.labels.push('');
    chart.data.datasets[0].data.push(value);
    if (chart.data.labels.length > 20) {
        chart.data.labels.shift();
        chart.data.datasets[0].data.shift();
    }
    chart.update();
}

// Trigger winner animation and message
function declareWinner(type) {
    const name = type === 'asterisk' ? 'Asterisk' : 'FreeSWITCH';
    document.getElementById("winner-box").innerText = "🏆 " + name + " is the Winner!";
    document.getElementById("winner-box").style.display = "block";
    confetti();
    document.getElementById("winner-sound").play();
}

// Trigger explosion overlay and sound
// Trigger explosion overlay and sound
function triggerExplosion(type) {
    const overlay = document.getElementById(type + "-overlay");
    overlay.style.display = "flex";
    document.getElementById("explosion-sound").play();
    setTimeout(() => {
        overlay.style.display = "none";
    }, 10000);
}

// === Chart Initialization ===
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

// === Handle incoming WebSocket messages for metrics ===
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

    if (msg.type === 'winner') {
        declareWinner(t);
    }
};
