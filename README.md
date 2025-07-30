# 🚀 Asterisk Stress Test Toolkit

Welcome to the **Asterisk Stress Test Toolkit**, a complete and reproducible testing framework to evaluate **Asterisk's** performance under high-load SIP call scenarios.

This toolkit is ideal for:

* 🎯 Installing Asterisk from source
* 🔁 Generating simulated SIP traffic
* 📈 Monitoring system performance (CPU, bandwidth, RAM, concurrency)
* 📊 Analyzing call capacity with automatic CSV reporting

---

## 📎 Related Projects

* [FreeSWITCH Stress Test Toolkit](https://github.com/rodrigocuadra/Freeswitch-Stress-Test)

---

## 📦 Repository Contents

| File                  | Description                                     |
| --------------------- | ----------------------------------------------- |
| `install_asterisk.sh` | Installs Asterisk 22.4.1 from source with PJSIP |
| `stress_test.sh`      | Launches simulated SIP calls for benchmarking   |

---

## ⚙️ Requirements

* Two Debian 12 servers (VMs or bare-metal)
* Root access to both servers
* Outbound internet access (to fetch audio/codecs)
* Open ports: **5060/UDP** (SIP), **10000–20000/UDP** (RTP)
* Recommended: ≥2 vCPU, ≥2 GB RAM

---

## 🛠️ Step 1: Install Asterisk

Run the following **on both servers**:

```bash
apt install sudo -y
wget https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/install_asterisk.sh
chmod +x install_asterisk.sh
sudo ./install_asterisk.sh
```

☑️ This will:

* Compile Asterisk 22.4.1 with PJSIP support
* Configure SIP ports and RTP range
* Set up a working SIP profile
* Create the `asterisk` user and apply firewall rules

---

## 📞 Step 2: Run the Stress Test

On the first of the two Asterisk servers run:

**Stress Test**
```
mkdir /opt/stress_test
cd /opt/stress_test
wget https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/stress_test.sh
chmod +x stress_test.sh
sudo ./stress_test.sh
```

You’ll be prompted to:

* Enter local/remote IP addresses
* Choose codec and call duration
* Specify call ramp-up settings

```
************************************************************
*          Welcome to the Asterisk Stress Test             *
*              All options are mandatory                   *
************************************************************

Reading config file...
IP Local.............................................. >  192.168.10.31
IP Remote............................................. >  192.168.10.32
SSH Remote Port (Default is 22)....................... >  22
Network Interface name (e.g., eth0)................... >  eth0
Codec (1.-PCMU, 2.-OPUS).............................. >  1
Recording Calls (yes,no).............................. >  no
Max CPU Load (Recommended 75%)........................ >  75
Calls Step (Recommended 5-100)........................ >  100
Seconds between each step (Recommended 5-30).......... >  4
Estimated Call Duration Seconds (e.g., 180)........... >  180
Monitor server URL (None or http://192.168.5.5:8000).. > http://192.168.10.30:8000
************************************************************
*                   Check Information                      *
*        Make sure that both servers have communication    *
************************************************************
Are you sure to continue with this settings? (yes,no) >
```


🧪 The script will automatically:

* Configure trunks and dialplans
* Upload destination dialplan to the remote server
* Simulate two-way SIP calls
* Monitor CPU, RAM, bandwidth, and concurrency
* Save results into `data.csv`

---

## 📊 Example Results

After a full test cycle, you’ll get a final statistical summary like this:

* Max concurrent calls: **900**
* Max CPU usage: **86.00%**
* Load average: **11.06**
* Avg bandwidth per call: **75.87 kb/s**
* Est. throughput: **18,000 calls/hour**

### 📷 Benchmark Snapshot:

![Asterisk Stress Test Result](https://github.com/rodrigocuadra/Asterisk-Stress-Test/blob/main/Asterisk_2Core.png)

---

## 🔍 Interpretation

* These values were obtained using **Hyper-V** virtual machines on 2-core systems.
* **CPU usage above 45%** is not recommended for long periods in production.
* The test simulates a real-world call with **bi-directional media playback** (using `jonathan.wav` and `sarah.wav`).
* **Bandwidth consumption remains constant** across the test due to static media size.

---

## ✍️ Customization Notes

* All configs are temporary: `pjsip_stress_test.conf` and `extensions_stress_test.conf` are removed after the test
* You can modify codecs, step sizes, and durations directly in `stress_test.sh`
* The test assumes **unauthenticated SIP traffic** (no registration) for simplicity

---

## 📤 CSV Output Sample

The script generates a `data.csv` file with fields:

```
Step,Concurrent_Calls,CPU_Usage,Load_Avg,TX_kbps,RX_kbps
```

Perfect for plotting time-series graphs or analyzing call behavior step-by-step.

---

## 👤 Author

**Rodrigo Cuadra**
🔗 GitHub: [@rodrigocuadra](https://github.com/rodrigocuadra)

---

## 🛡️ Disclaimer

This toolkit is meant for **controlled testing environments**.
Running this in production without safeguards could disrupt your VoIP services.
Use responsibly.

---
