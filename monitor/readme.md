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
