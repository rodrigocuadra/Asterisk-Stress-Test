# 🚀 Asterisk Stress Test Toolkit

Welcome to the **Asterisk Stress Test Toolkit**, a practical utility designed to benchmark and evaluate Asterisk performance under simulated high call loads. This project provides everything needed to:

- 🎯 Install Asterisk from source
- 📊 Generate stress traffic to test server stability
- 📈 Monitor system resources (CPU, memory, bandwidth) during tests

---

## 📦 Repository Contents

| File                       | Description                                      |
|----------------------------|--------------------------------------------------|
| `install_asterisk.sh`      | Script to install Asterisk from source           |
| `stress_test.sh`           | Script to generate high call load                |

---

## ⚙️ Prerequisites

- Two Linux servers (Debian 12 recommended)
- Root SSH access
- Internet access from both servers
- Open ports for SIP communication (UDP 5060) and RTP (UDP 10000-20000)
- Minimum 2 GB RAM and 2 vCPUs per server for stress testing

---

## 🧱 Step 1: Install Asterisk on Both Servers

Run the following command **on both servers** to install Asterisk from source:

```bash
wget https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/install_asterisk.sh
chmod +x install_asterisk.sh
sudo ./install_asterisk.sh
```

> ☑️ This script installs Asterisk 22.4.1, configures PJSIP for SIP communication, and sets up the necessary environment for stress testing. It creates a dedicated `asterisk` user and configures basic firewall rules.

---

## 📞 Step 2: Run the Stress Test

Once both servers are up and running with Asterisk installed, log in to **one of the servers** (this will be your test controller), and run:

```bash
wget https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/stress-test.sh
chmod +x stress_test.sh
sudo ./stress_test.sh
```

During execution, the script will:

- Prompt for required network and performance parameters (e.g., local/remote IPs, codec, call duration)
- Automatically configure a PJSIP trunk to the remote server
- Upload the destination dialplan to the remote server (for audio playback)
- Start launching calls incrementally to stress the system
- Monitor CPU, memory, network usage, and active channels
- Log results into `data.csv`

---

## 📊 Results

After running the test, you'll get:

- **Live statistics** displayed step-by-step on screen
- A `data.csv` file containing all metrics for review
- A final summary of:
  - Max CPU usage
  - Max concurrent calls
  - Average bandwidth per call
  - Estimated calls per hour based on call duration

---

## 🧠 Notes

- Ensure the remote server allows unauthenticated SIP traffic (no registration required) for testing.
- This test uses audio files (`jonathan.wav` and `sarah.wav`) for playback, downloaded automatically.
- Supported codecs: PCMU (G.711), G.729, OPUS (G.729 and OPUS require respective modules).
- Modify the test script as needed to adjust call durations, codecs, or PJSIP settings.
- The script removes temporary configurations (`pjsip_stress_test.conf`, `extensions_stress_test.conf`) after testing.

---

## 👤 Author

**Rodrigo Cuadra**  
Adapted for Asterisk by Grok 3 (xAI)  
📧 For support, refer to Asterisk documentation or your system administrator

---

## 🛡️ Disclaimer

This stress test is designed for **controlled lab environments**.  
**Do not run it in production** unless you know what you're doing.

Use responsibly.

---
