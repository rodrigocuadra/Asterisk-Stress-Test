# Install Stress Test Monitor Server

```bash
apt install sudo -y
wget https://raw.githubusercontent.com/rodrigocuadra/Asterisk-Stress-Test/refs/heads/main/monitor/monitor_install.sh
chmod +x monitor_install.sh
sudo ./monitor_install.sh
```

# Create authorization key for the Access between Asterisk/Freeswitch Server to Monitor Server.

Go to **Monitor Server** and create the ssh for Asyterisk/Freeswitch server.
```
ssh-keygen -f /root/.ssh/id_rsa -t rsa -N '' >/dev/null
ssh-copy-id root@192.168.10.31
```
<pre>
Are you sure you want to continue connecting (yes/no/[fingerprint])? <strong>yes</strong>
root@192.168.10.62's password: <strong>(remote server root’s password)</strong>

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'root@192.168.10.30'"
and check to make sure that only the key(s) you wanted were added. 

root@vitalpbx-master:~#
</pre>

```
ssh-keygen -f /root/.ssh/id_rsa -t rsa -N '' >/dev/null
ssh-copy-id root@192.168.10.33
```
<pre>
Are you sure you want to continue connecting (yes/no/[fingerprint])? <strong>yes</strong>
root@192.168.10.62's password: <strong>(remote server root’s password)</strong>

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'root@192.168.10.30'"
and check to make sure that only the key(s) you wanted were added. 

root@vitalpbx-master:~#
</pre>

# Firewall
On certain virtual machines, such as those offered by Vurlt, it's necessary to create firewall rules. Here we describe the steps for each server.<br>

### Monitor Server

```
sudo apt install iptables-persistent
sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 8000 -j ACCEPT
sudo netfilter-persistent save
```

### Asterisk 01 Server
When installing iptables-persistent, preserve the current table by selecting **yes**. Then add the rules and save them so they're present on any system reboot.
```
sudo apt install iptables-persistent
sudo iptables -I INPUT -p tcp --dport 8000 -j ACCEPT
sudo netfilter-persistent save
```

### Freeswitch 01 Server
When installing iptables-persistent, preserve the current table by selecting **yes**. Then add the rules and save them so they're present on any system reboot.
```
sudo apt install iptables-persistent
sudo iptables -I INPUT -p tcp --dport 8000 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 5080 -j ACCEPT
sudo iptables -I INPUT -p udp --dport 5080 -j ACCEPT
sudo netfilter-persistent save
```
### Freeswitch 02 Server
When installing iptables-persistent, preserve the current table by selecting **yes**. Then add the rules and save them so they're present on any system reboot.
```
sudo apt install iptables-persistent
sudo iptables -I INPUT -p tcp --dport 5080 -j ACCEPT
sudo iptables -I INPUT -p udp --dport 5080 -j ACCEPT
sudo netfilter-persistent save
```
### Edit .env
Go to /opt/stresstest_monitor and edit the .env file to configure Terminal 1 of Asterisk_01 and Terminal 2 of Freeswict_01 and OpeanAI API Key
```
cd /opt/stresstest_monitor
nano .env
```
<pre>
TERMINAL1_IP=Asterisk_01 IP
TERMINAL2_IP=Freeswitch_01 IP
</pre>

Configure the OpenAI API Key
<pre>
OPENAI_API_KEY=
</pre>
