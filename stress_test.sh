#!/bin/bash

# ------------------------------------------------------------------------------
# Stress Test Script for Asterisk (Pure) with PJSIP
# ------------------------------------------------------------------------------
#
# Purpose:      Performs stress testing on Asterisk by generating SIP calls
#               between two servers, monitoring CPU, memory, and bandwidth usage,
#               and generating a performance report.
#
# Authors:      Rodrigo Cuadra (original author)
#
# Version:      1.1 for Asterisk 22.4.1
# Date:         June 28, 2025
#
# Compatibility: Asterisk 22.x with PJSIP module
# Requirements: 
#               - Two Asterisk servers with SSH access
#               - PJSIP configured with UDP transport
#               - Audio files (jonathan.wav, sarah.wav) for playback
#               - Supported codecs: PCMU, G.729, OPUS
#
# Usage:        sudo ./stress_test_asterisk.sh
#               Follow prompts to configure test parameters or use config.txt
#
# Output:       - Real-time performance metrics (CPU, calls, bandwidth)
#               - Summary report in data.csv
#
# Notes:        - Ensure ports 5060/UDP and 10000-20000/UDP are open
#               - G.729 and OPUS require respective codec modules
#               - Run as root or with sudo
#
# Support:      For issues, refer to Asterisk documentation (https://wiki.asterisk.org)
#               or contact your system administrator
#
# ------------------------------------------------------------------------------

set -e

# Clear the terminal for a clean start
clear

# Colors for output
CYAN='\033[1;36m'
NC='\033[0m' # No color

# Display welcome message
echo -e "\n${CYAN}"
echo -e "************************************************************"
echo -e "*          Welcome to the Asterisk Stress Test             *"
echo -e "*              All options are mandatory                   *"
echo -e "************************************************************"
echo -e "${NC}"

AUTO_MODE=false
WEB_NOTIFY=false
SKIP_CONFIG=false
for arg in "$@"
do
    case $arg in
        --auto|--no-confirm)
            AUTO_MODE=true
            echo "✅ Auto mode enabled: running with config.txt only, no prompts."
            ;;
        --notify)
            WEB_NOTIFY=true
            echo "📡 Web notify enabled: full reporting to server 5."
            ;;
        --skip-config)
            SKIP_CONFIG=true
            echo "📡 Skip configuration: Go straight to the test."
            ;;
        *)
            echo "⚠️ Unknown argument: $arg"
            ;;
    esac
done

# Read configuration from config.txt if it exists
filename="config.txt"
if [ -f "$filename" ]; then
    echo -e "Reading config file..."
    n=1
    while read line; do
        case $n in
            1) ip_local=$line ;;
            2) ip_remote=$line ;;
            3) ssh_remote_port=$line ;;
            4) interface_name=$line ;;
            5) codec=$line ;;
            6) recording=$line ;;
            7) maxcpuload=$line ;;
            8) call_step=$line ;;
            9) call_step_seconds=$line ;;
            10) call_duration=$line ;;
            11) web_notify_url_base=$line ;;
        esac
        n=$((n+1))
    done < "$filename"
    echo -e "IP Local.............................................. >  $ip_local"    
    echo -e "IP Remote............................................. >  $ip_remote"
    echo -e "SSH Remote Port (Default is 22)....................... >  $ssh_remote_port"
    echo -e "Network Interface name (e.g., eth0)................... >  $interface_name"
    echo -e "Codec (1.-PCMU, 2.-OPUS).............................. >  $codec"
    echo -e "Recording Calls (yes,no).............................. >  $recording"
    echo -e "Max CPU Load (Recommended 75%)........................ >  $maxcpuload"
    echo -e "Calls Step (Recommended 5-100)........................ >  $call_step"
    echo -e "Seconds between each step (Recommended 5-30).......... >  $call_step_seconds"
    echo -e "Estimated Call Duration Seconds (e.g., 180)........... >  $call_duration"
    if [ "$WEB_NOTIFY" = true ]; then
        echo -e "Web server URL base (e.g., http://192.168.5.5:8000)... >   $web_notify_url_base"
    fi
fi

if [ "$AUTO_MODE" = false ]; then

    # Prompt for configuration if not set
    while [[ -z $ip_local ]]; do
        read -p "IP Local.............................................. > " ip_local 
    done 

    while [[ -z $ip_remote ]]; do
        read -p "IP Remote............................................. > " ip_remote 
    done

    while [[ -z $ssh_remote_port ]]; do
        read -p "SSH Remote Port (Default is 22)....................... > " ssh_remote_port 
    done

    while [[ -z $interface_name ]]; do
        read -p "Network Interface name (e.g., eth0)................... > " interface_name 
    done

    while [[ -z $codec ]]; do
        read -p "Codec (1.-PCMU, 2.-OPUS).............................. > " codec 
    done 

    while [[ -z $recording ]]; do
        read -p "Recording Calls (yes,no).............................. > " recording 
    done 

    while [[ -z $maxcpuload ]]; do
        read -p "Max CPU Load (Recommended 75%)........................ > " maxcpuload 
    done 

    while [[ -z $call_step ]]; do
        read -p "Calls Step (Recommended 5-100)........................ > " call_step 
    done 

    while [[ -z $call_step_seconds ]]; do
        read -p "Seconds between each step (Recommended 5-30).......... > " call_step_seconds
    done 

    while [[ -z $call_duration ]]; do
        read -p "Estimated Call Duration Seconds (e.g., 180)........... > " call_duration
    done 
    if [ "$WEB_NOTIFY" = true ]; then
        while [[ -z $web_notify_url_base ]]; do
            read -p "Web server URL base (e.g., http://192.168.5.5:8000)... > " web_notify_url_base
        done
    fi
    # Verify configuration
    echo -e "************************************************************"
    echo -e "*                   Check Information                      *"
    echo -e "*        Make sure that both servers have communication    *"
    echo -e "************************************************************"
    while [[ "$veryfy_info" != "yes" && "$veryfy_info" != "no" ]]; do
        read -p "Are you sure to continue with this settings? (yes,no) > " veryfy_info 
    done

    if [ "$veryfy_info" != "yes" ]; then
        # Re-prompt for all settings if user selects 'no'
        while [[ -z $ip_local ]]; do
            read -p "IP Local.............................................. > " ip_local 
        done 

        while [[ -z $ip_remote ]]; do
            read -p "IP Remote............................................. > " ip_remote 
        done

        while [[ -z $ssh_remote_port ]]; do
            read -p "SSH Remote Port (Default is 22)....................... > " ssh_remote_port 
        done

        while [[ -z $interface_name ]]; do
            read -p "Network Interface name (e.g., eth0)................... > " interface_name 
        done

        while [[ -z $codec ]]; do
            read -p "Codec (1.-PCMU, 2.-OPUS).............................. > " codec 
        done 

        while [[ -z $recording ]]; do
            read -p "Recording Calls (yes,no).............................. > " recording 
        done 

        while [[ -z $maxcpuload ]]; do
            read -p "Max CPU Load (Recommended 75%)........................ > " maxcpuload 
        done 

        while [[ -z $call_step ]]; do
            read -p "Calls Step (Recommended 5-100)........................ > " call_step 
        done 

        while [[ -z $call_step_seconds ]]; do
            read -p "Seconds between each step (Recommended 5-30).......... > " call_step_seconds
        done 

        while [[ -z $call_duration ]]; do
            read -p "Estimated Call Duration Seconds (e.g., 180)........... > " call_duration
        done 
        if [ "$WEB_NOTIFY" = true ]; then
            while [[ -z $web_notify_url_base ]]; do
                read -p "Web server URL base (e.g., http://192.168.5.5:8000)... > " web_notify_url_base
            done
        fi
    fi

else
    echo "🚀 Skipping confirmation. Proceeding with loaded config."
fi

# Save configuration to config.txt
echo -e "$ip_local"          > config.txt
echo -e "$ip_remote"         >> config.txt
echo -e "$ssh_remote_port"   >> config.txt
echo -e "$interface_name"    >> config.txt
echo -e "$codec"             >> config.txt
echo -e "$recording"         >> config.txt
echo -e "$maxcpuload"        >> config.txt
echo -e "$call_step"         >> config.txt
echo -e "$call_step_seconds" >> config.txt
echo -e "$call_duration"     >> config.txt
if [ "$WEB_NOTIFY" = true ]; then
    echo -e "$web_notify_url_base"    >> config.txt
else
    echo -e "None"                    >> config.txt
fi

test_type="asterisk"
progress_url="${web_notify_url_base}/api/progress"
explosion_url="${web_notify_url_base}/api/explosion"

if [ "$codec" = "1" ]; then
    codec_name="PCMU"
elif [ "$codec" = "2" ]; then
    codec_name="OPUS"
fi

if [ "$AUTO_MODE" = false ]; then
# Set up SSH key for passwordless communication
echo -e "************************************************************"
echo -e "*          Copy Authorization key to remote server         *"
echo -e "************************************************************"
sshKeyFile="/root/.ssh/id_rsa"

if [ ! -f "$sshKeyFile" ]; then
    echo -e "Generating SSH key..."
    ssh-keygen -f "$sshKeyFile" -t rsa -N '' >/dev/null
fi

echo -e "Copying public key to $ip_remote..."
ssh-copy-id -i "${sshKeyFile}.pub" -p "$ssh_remote_port" root@$ip_remote

if [ $? -eq 0 ]; then
    echo -e "${GREEN}*** SSH key installed successfully. ***${NC}"
else
    echo -e "${RED}❌ Failed to copy SSH key. Check connectivity or credentials.${NC}"
    exit 1
fi

# Create Asterisk configuration files
echo -e "************************************************************"
echo -e "*            Creating Asterisk config files                *"
echo -e "************************************************************"

# Download audio files for testing
wget -O /var/lib/asterisk/sounds/en/jonathan.wav https://github.com/rodrigocuadra/Asterisk-Stress-Test/raw/refs/heads/main/jonathan.wav || echo -e "${RED}Warning: Failed to download jonathan.wav${NC}"

# Server A: extensions.conf
rm -rf /etc/asterisk/pjsip_stress_test.conf /etc/asterisk/extensions_stress_test.conf
cat > /etc/asterisk/extensions_stress_test.conf << EOF
[stress_test]
exten => 200,1,NoOp(Outgoing Call)
 same => n,Answer()
EOF
if [ "$recording" = "yes" ]; then
    echo " same => n,MixMonitor(/tmp/\${UNIQUEID}.wav,ab)" >> /etc/asterisk/extensions_stress_test.conf
fi
cat >> /etc/asterisk/extensions_stress_test.conf << EOF
 same => n,Dial(PJSIP/100@trunk_to_server_b,\${CALL_DURATION})
 same => n,Hangup()
EOF

# Server A: pjsip.conf
cat > /etc/asterisk/pjsip_stress_test.conf << EOF
[global]
type=global
max_initial_qualify_time=5

[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
external_media_address=$ip_local
external_signaling_address=$ip_local
local_net=$ip_local/24

[trunk_to_server_b]
type=endpoint
context=stress_test
dtmf_mode=rfc4733
EOF
if [ "$codec" = "1" ]; then
    codec_name="PCMU"
    echo "disallow=all" >> /etc/asterisk/pjsip_stress_test.conf
    echo "allow=ulaw,alaw" >> /etc/asterisk/pjsip_stress_test.conf
elif [ "$codec" = "2" ]; then
    codec_name="OPUS"
    echo "disallow=all" >> /etc/asterisk/pjsip_stress_test.conf
    echo "allow=opus" >> /etc/asterisk/pjsip_stress_test.conf
fi
cat >> /etc/asterisk/pjsip_stress_test.conf << EOF
language=en
aors=trunk_to_server_b
trust_id_inbound=no
trust_id_outbound=no

[trunk_to_server_b]
type=aor
max_contacts=2
contact=sip:trunk_to_server_b@$ip_remote:5060
qualify_frequency=30
qualify_timeout=3

[trunk_to_server_b]
type=identify
endpoint=trunk_to_server_b
match=$ip_remote
EOF

# Server A: Include stress test configs in main config files
# Remove existing includes to avoid duplicates
sed -i '/#include extensions_stress_test.conf/d' /etc/asterisk/extensions.conf
sed -i '/#include pjsip_stress_test.conf/d' /etc/asterisk/pjsip.conf
# Add new includes
echo "#include extensions_stress_test.conf" >> /etc/asterisk/extensions.conf
echo "#include pjsip_stress_test.conf" >> /etc/asterisk/pjsip.conf

# Change from 1024 to 50,000 open files. Increases the simultaneous call capacity in Asterisk.
# Remove existing includes to avoid duplicates
sed -i '/maxfiles = 50000/d' /etc/asterisk/asterisk.conf
sed -i '/transmit_silence = yes/d' /etc/asterisk/asterisk.conf
sed -i '/hide_messaging_ami_events = yes/d' /etc/asterisk/asterisk.conf
# Add new settings
echo "maxfiles = 50000" >> /etc/asterisk/asterisk.conf
echo "transmit_silence = yes" >> /etc/asterisk/asterisk.conf
echo "hide_messaging_ami_events = yes" >> /etc/asterisk/asterisk.conf

# Server B: Download audio file
ssh -p $ssh_remote_port root@$ip_remote "wget -O /var/lib/asterisk/sounds/en/sarah.wav https://github.com/rodrigocuadra/Asterisk-Stress-Test/raw/refs/heads/main/sarah.wav" || echo -e "${RED}Warning: Failed to download sarah.wav on remote server${NC}"

# Server B: extensions.conf
ssh -p $ssh_remote_port root@$ip_remote "rm -rf /etc/asterisk/pjsip_stress_test.conf /etc/asterisk/extensions_stress_test.conf"
ssh -p $ssh_remote_port root@$ip_remote "cat > /etc/asterisk/extensions_stress_test.conf << EOF
[stress_test]
exten => 100,1,Answer()
 same => n,Wait(1)
 same => n,Playback(sarah&sarah&sarah)
 same => n,Hangup()
EOF"

# Server B: pjsip.conf
ssh -p $ssh_remote_port root@$ip_remote "cat > /etc/asterisk/pjsip_stress_test.conf << EOF
[global]
type=global
max_initial_qualify_time=5

[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
external_media_address=$ip_remote
external_signaling_address=$ip_remote
local_net=$ip_remote/24

[trunk_from_server_a]
type=endpoint
context=stress_test
dtmf_mode=rfc4733
EOF"
if [ "$codec" = "1" ]; then
    ssh -p $ssh_remote_port root@$ip_remote "echo 'disallow=all' >> /etc/asterisk/pjsip_stress_test.conf"
    ssh -p $ssh_remote_port root@$ip_remote "echo 'allow=ulaw,alaw' >> /etc/asterisk/pjsip_stress_test.conf"
elif [ "$codec" = "2" ]; then
    ssh -p $ssh_remote_port root@$ip_remote "echo 'disallow=all' >> /etc/asterisk/pjsip_stress_test.conf"
    ssh -p $ssh_remote_port root@$ip_remote "echo 'allow=opus' >> /etc/asterisk/pjsip_stress_test.conf"
fi
ssh -p $ssh_remote_port root@$ip_remote "cat >> /etc/asterisk/pjsip_stress_test.conf << EOF
language=en
aors=trunk_from_server_a
trust_id_inbound=no
trust_id_outbound=no

[trunk_from_server_a]
type=aor
max_contacts=2
contact=sip:trunk_from_server_a@$ip_local:5060
qualify_frequency=30
qualify_timeout=3

[trunk_from_server_a]
type=identify
endpoint=trunk_from_server_a
match=$ip_local
EOF"

# Server B: Include stress test configs in main config files
# Remove existing includes to avoid duplicates
ssh -p $ssh_remote_port root@$ip_remote "sed -i '/#include extensions_stress_test.conf/d' /etc/asterisk/extensions.conf"
ssh -p $ssh_remote_port root@$ip_remote "sed -i '/#include pjsip_stress_test.conf/d' /etc/asterisk/pjsip.conf"
# Add new includes
ssh -p $ssh_remote_port root@$ip_remote "echo '#include extensions_stress_test.conf' >> /etc/asterisk/extensions.conf"
ssh -p $ssh_remote_port root@$ip_remote "echo '#include pjsip_stress_test.conf' >> /etc/asterisk/pjsip.conf"

# Set permissions for configuration files
chown asterisk:asterisk /etc/asterisk/extensions_stress_test.conf /etc/asterisk/pjsip_stress_test.conf
chmod 640 /etc/asterisk/extensions_stress_test.conf /etc/asterisk/pjsip_stress_test.conf
ssh -p $ssh_remote_port root@$ip_remote "chown asterisk:asterisk /etc/asterisk/extensions_stress_test.conf /etc/asterisk/pjsip_stress_test.conf"
ssh -p $ssh_remote_port root@$ip_remote "chmod 640 /etc/asterisk/extensions_stress_test.conf /etc/asterisk/pjsip_stress_test.conf"

# Change from 1024 to 50,000 open files. Increases the simultaneous call capacity in Asterisk.
# Remove existing includes to avoid duplicates
ssh -p $ssh_remote_port root@$ip_remote "sed -i '/maxfiles = 50000/d' /etc/asterisk/asterisk.conf"
ssh -p $ssh_remote_port root@$ip_remote "sed -i '/transmit_silence = yes/d' /etc/asterisk/asterisk.conf"
ssh -p $ssh_remote_port root@$ip_remote "sed -i '/hide_messaging_ami_events = yes/d' /etc/asterisk/asterisk.conf"
# Add new settings
ssh -p $ssh_remote_port root@$ip_remote "echo 'maxfiles = 50000' >> /etc/asterisk/asterisk.conf"
ssh -p $ssh_remote_port root@$ip_remote "echo 'transmit_silence = yes' >> /etc/asterisk/asterisk.conf"
ssh -p $ssh_remote_port root@$ip_remote "echo 'hide_messaging_ami_events = yes' >> /etc/asterisk/asterisk.conf"
fi

# Restart Asterisk on both servers
systemctl restart asterisk
ssh -p $ssh_remote_port root@$ip_remote "systemctl restart asterisk"
echo -e "${GREEN}*** Done ***${NC}"
echo -e "*****************************************************************************************"
echo -e "*                        Restarting Asterisk in both servers                            *"
echo -e "*****************************************************************************************"
sleep 10

echo -e "*****************************************************************************************"
echo -e "*                                  Start stress test                                    *"
echo -e "*****************************************************************************************"
numcores=$(nproc --all)
exitcalls=false
i=0
step=0
total_elapsed=0
clear
asterisk_version=$(asterisk -V)
echo -e "***************************************************************************************************"
echo -e "                           Asterisk Version: ${asterisk_version}                                   "
echo -e "     Actual Test State (Step: ${call_step_seconds}s, Core: ${numcores}, Protocol: SIP(PJSIP), Codec: ${codec_name}, Recording: ${recording})     "
echo -e "***************************************************************************************************"
echo -e "---------------------------------------------------------------------------------------------------"
printf "%2s %7s %10s %19s %10s %10s %10s %12s %12s\n" "|" " Step |" "Calls |" "Asterisk Channels |" "CPU Load |" "Load |" "Memory |" "BW TX kb/s |" "BW RX kb/s |"
R1=$(cat /sys/class/net/"$interface_name"/statistics/rx_bytes)
T1=$(cat /sys/class/net/"$interface_name"/statistics/tx_bytes)
date1=$(date +"%s")
# slepcall=$(printf %.2f "$((1000000000 * call_step_seconds / call_step))e-9")
# Convert call_step_seconds to milliseconds
target_ms=$((call_step_seconds * 1000))
sleep 4
echo -e "step, calls, active calls, cpu load (%), memory (%), bwtx (kb/s), bwrx (kb/s), delay (ms)" > data.csv

while [ "$exitcalls" = "false" ]; do
    R2=$(cat /sys/class/net/"$interface_name"/statistics/rx_bytes)
    T2=$(cat /sys/class/net/"$interface_name"/statistics/tx_bytes)
    date2=$(date +"%s")
    diff=$((date2 - date1))
    seconds=$((diff % 60))
    T2=$((T2 + 128))
    R2=$((R2 + 128))
    TBPS=$((T2 - T1))
    RBPS=$((R2 - R1))
    TKBPS=$((TBPS / 128))
    RKBPS=$((RBPS / 128))
    bwtx=$((TKBPS / seconds))
    bwrx=$((RKBPS / seconds))
    activecalls=$(asterisk -rx "core show calls" | grep "active" | cut -d' ' -f1)
    load=$(cat /proc/loadavg | awk '{print $1}')
    cpu=`top -n 1 | awk 'FNR > 7 {s+=$10} END {print s}'`
    cpuint=${cpu%.*}
    cpu="$((cpuint/numcores))"
    memory=$(free | awk '/Mem:/ {used=$3; total=$2} END {if (total>0) printf("%.2f%%", used/total*100); else print "N/A"}')
    
    # Color-code output based on CPU load
    if [ "$cpu" -le 34 ]; then
        echo -e "\e[92m---------------------------------------------------------------------------------------------------"
    elif [ "$cpu" -ge 35 ] && [ "$cpu" -lt 65 ]; then
        echo -e "\e[93m---------------------------------------------------------------------------------------------------"
    else
        echo -e "\e[91m---------------------------------------------------------------------------------------------------"
    fi
    printf "%2s %7s %10s %19s %10s %10s %10s %12s %12s\n" "|" " $step |" "$i |" "$activecalls |" "$cpu% |" "$load |" "$memory |" "$bwtx |" "$bwrx |"
    echo -e "$i, $activecalls, $cpu, $load, $memory, $bwtx, $bwrx, $total_elapsed" >> data.csv

    if [ "$web_notify_url_base" != "" ] && [ "$WEB_NOTIFY" = true ]; then
        curl --silent --output /dev/null --write-out '' -X POST "$progress_url" \
            -H "Content-Type: application/json" \
            -d "{
                \"test_type\": \"$test_type\",
                \"ip\": \"$ip_local\",
                \"step\": $step,
                \"calls\": $i,
                \"active_calls\": $activecalls,
                \"cpu\": $cpu,
                \"load\": \"$load\",
                \"memory\": \"$memory\",
           		\"avg_elapsed\": \"$avg_elapsed\",
                \"bw_tx\": $bwtx,
                \"bw_rx\": $bwrx,
                \"timestamp\": \"$(date --iso-8601=seconds)\"
            }" &
    fi
    
    exitstep=false
    x=1
    total_elapsed=0
    while [ "$exitstep" = "false" ]; do
        x=$((x + 1))
        if [ "$call_step" -lt "$x" ]; then
            exitstep=true
        fi
        call_start=$(date +%s%3N)
        asterisk -rx "channel originate Local/200@stress_test application Playback jonathan&jonathan&jonathan"
        call_end=$(date +%s%3N)
        call_elapsed=$((call_end - call_start))
        total_elapsed=$((total_elapsed + call_elapsed))
    done

    # Calculate how much sleep you need if necessary
    if [ "$total_elapsed" -lt "$target_ms" ]; then
        sleep_ms=$((target_ms - batch_elapsed_ms))
        sleep_sec=$(awk "BEGIN { printf(\"%.3f\", $sleep_ms / 1000) }")
        sleep "$sleep_sec"
    fi
   
    step=$((step + 1))
    i=$((i + call_step))
    if [ "$cpu" -gt "$maxcpuload" ]; then
        exitcalls=true
            if [ "$web_notify_url_base" != "" ] && [ "$WEB_NOTIFY" = true ]; then
                # echo "🔥 Threshold reached ($cpu%). Notifying control server..."
                curl --silent --output /dev/null --write-out '' -X POST "$explosion_url" \
                    -H "Content-Type: application/json" \
                    -d "{
                    \"test_type\": \"$test_type\",
                    \"ip\": \"$ip_local\",
                    \"cpu\": $cpu,
                    \"active_calls\": $activecalls,
                    \"step\": $step,
                    \"timestamp\": \"$(date --iso-8601=seconds)\"
                    }" &
                    # echo "📤 Explosion request sent for $test_type (CPU: $cpu%, Active Calls: $activecalls)"
            fi
    fi
    R1=$(cat /sys/class/net/"$interface_name"/statistics/rx_bytes)
    T1=$(cat /sys/class/net/"$interface_name"/statistics/tx_bytes)
    date1=$(date +"%s")
    sleep 1
done

echo -e "\e[39m---------------------------------------------------------------------------------------------------"
echo -e "***************************************************************************************************"
echo -e "*                                     Restarting Asterisk                                         *"
echo -e "***************************************************************************************************"
systemctl restart asterisk
ssh -p $ssh_remote_port root@$ip_remote "systemctl restart asterisk"
rm -rf /tmp/*.wav

echo -e "\n\033[1;32m✅ Test complete. Results saved to data.csv\033[0m"
echo -e "***************************************************************************************************"
echo -e "*                                     Summary Report                                              *"
echo -e "***************************************************************************************************"
echo -e "\n${BLUE}Generating summary from data.csv...${NC}"

if [ -f data.csv ]; then
    tail -n +2 data.csv | awk -F',' -v dur="$call_duration" '
    BEGIN {
        max_cpu=0; sum_cpu=0; count=0;
        max_calls=0; sum_calls=0;
        sum_bw_per_call=0;
        total_batch_delay = 0;
        total_calls = 0;
    }
    {
        cpu = $3 + 0;
        calls = $2 + 0;
        tx = $6 + 0;
        rx = $7 + 0;
        elapsed = $8 + 0;

        # Bandwidth per call (includes both legs: TX + RX)
        bw_per_call = (calls > 0) ? (tx + rx) / calls : 0;

        if(cpu > max_cpu) max_cpu = cpu;
        if(calls > max_calls) max_calls = calls;

        sum_cpu += cpu;
        sum_calls += calls;
        sum_bw_per_call += bw_per_call;
        total_batch_delay = total_batch_delay + elapsed;
        count++;
    }
    END {
        avg_cpu = (count > 0) ? sum_cpu / count-1 : 0;
        avg_bw = (count > 0) ? sum_bw_per_call / count-1 : 0;
        est_calls_per_hour = (dur > 0) ? max_calls * (3600 / dur) : 0;
        avg_delay_per_call = (total_batch_delay > 0) ? total_batch_delay / max_calls : 0;

        printf("\n📊 Summary:\n");
        printf("• Max CPU Usage..................: %.2f%%\n", max_cpu);
        printf("• Average CPU Usage..............: %.2f%%\n", avg_cpu);
        printf("• Max Concurrent Calls...........: %d\n", max_calls);
        printf("• Average Bandwidth/Call.........: %.2f kb/s (TX + RX)\n", avg_bw);
        printf("• ⏱️ Total Originate Delay........: %.0f ms\n", total_batch_delay);
        printf("• ⌛ Avg Delay per Call..........: %.2f ms\n", avg_delay_per_call);
        printf("• ➕ Estimated Calls/Hour (~%ds): %.0f\n", dur, est_calls_per_hour);
    }'

    # ✅ Append system info
    echo -e "\n🧠 CPU Info:"
    lscpu | grep -E 'Model name|^CPU\(s\)|CPU MHz' | grep -v NUMA

    echo -e "\n💾 RAM Info:"
    free -h | awk '/^Mem:/ {print "Total Memory: " $2}'

else
    echo "❌ data.csv not found."
fi

echo -e "***************************************************************************************************"
echo -e "*                                       Test Complete                                             *"
echo -e "*                                  Result in data.csv file                                        *"
echo -e "***************************************************************************************************"
echo -e "${NC}"
