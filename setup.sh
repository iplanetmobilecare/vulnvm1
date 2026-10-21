#!/usr/bin/env bash
# ==============================================================================
# Cybetary Academy - Lab 1: Vulnerable Machine Provisioning Script
# Target: vsftpd 2.3.4 Backdoor (Port 21 -> Port 6200 shell) + HTTP (Port 80)
# Compatible with: Ubuntu 20.04/22.04 LTS or Debian 11/12
# ==============================================================================

set -e

echo "[+] ==========================================================="
echo "[+] Starting Cybetary Academy Lab 1 Setup..."
echo "[+] ==========================================================="

# Check root privileges
if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run this script as root (e.g., sudo bash setup.sh)"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "[*] Updating package repositories..."
apt-get update -y

echo "[*] Installing dependencies & build tools..."
apt-get install -y build-essential libcap-dev libssl-dev libpam0g-dev wget tar apache2 ufw net-tools

# ==============================================================================
# 1. SETUP HTTP SERVICE (PORT 80)
# ==============================================================================
echo "[*] Configuring HTTP Service (Apache2)..."
systemctl enable apache2
systemctl start apache2

cat << 'EOF' > /var/www/html/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cybetary Academy - Internal Gateway</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: #0f172a;
            color: #e2e8f0;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
        }
        .card {
            background: #1e293b;
            padding: 2.5rem;
            border-radius: 12px;
            box-shadow: 0 10px 25px rgba(0,0,0,0.5);
            max-width: 540px;
            text-align: center;
            border: 1px solid #334155;
        }
        h1 {
            color: #38bdf8;
            margin-top: 0;
        }
        p {
            line-height: 1.6;
            color: #94a3b8;
        }
        .badge {
            display: inline-block;
            background: #0284c7;
            color: white;
            padding: 4px 12px;
            border-radius: 9999px;
            font-size: 0.85rem;
            margin-bottom: 1rem;
        }
        .footer {
            margin-top: 1.5rem;
            font-size: 0.8rem;
            color: #64748b;
        }
    </style>
</head>
<body>
    <div class="card">
        <span class="badge">Lab 1: Recon & Exploitation</span>
        <h1>Cybetary Academy Gateway</h1>
        <p>Welcome to the internal staging server. Authorized personnel only.</p>
        <p>All activities are monitored and logged.</p>
        <div class="footer">Server Status: Online | Port 80 / 21 Active</div>
    </div>
</body>
</html>
EOF

# ==============================================================================
# 2. DOWNLOAD, COMPILE & INSTALL VSFTPD 2.3.4 (BACKDOORED)
# ==============================================================================
echo "[*] Downloading backdoored vsftpd-2.3.4 source..."
BUILD_DIR="/tmp/vsftpd_build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Download the authentic backdoored source archive
wget -q --show-progress https://raw.githubusercontent.com/nikdubois/vsftpd-2.3.4/master/vsftpd-2.3.4.tar.gz -O vsftpd-2.3.4.tar.gz || \
wget -q --show-progress https://github.com/nikdubois/vsftpd-2.3.4/raw/master/vsftpd-2.3.4.tar.gz -O vsftpd-2.3.4.tar.gz

tar -xzf vsftpd-2.3.4.tar.gz
cd vsftpd-2.3.4

echo "[*] Patching Makefile to link required crypto and cap libraries..."
# Ensure linking against crypt and cap libraries properly on modern Linux
sed -i 's/LIBS\t=\t`\.\/vsf_findlibs.sh`/LIBS\t=\t-lcrypt -lcap/g' Makefile

echo "[*] Compiling vsftpd 2.3.4..."
make

echo "[*] Installing vsftpd binary and man pages..."
install -m 755 vsftpd /usr/local/sbin/vsftpd
install -m 644 vsftpd.8 /usr/local/man/man8/vsftpd.8 2>/dev/null || true
install -m 644 vsftpd.conf.5 /usr/local/man/man5/vsftpd.conf.5 2>/dev/null || true

# Prepare required system folders and users
mkdir -p /usr/share/empty
mkdir -p /var/ftp
if ! id "nobody" &>/dev/null; then
  useradd -s /bin/false nobody
fi
if ! id "ftp" &>/dev/null; then
  useradd -d /var/ftp -s /bin/false ftp
fi

# Configure vsftpd
cat << 'EOF' > /etc/vsftpd.conf
# Cybetary Academy Lab 1 vsftpd.conf
listen=YES
anonymous_enable=YES
local_enable=YES
write_enable=YES
anon_upload_enable=YES
anon_mkdir_write_enable=YES
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=NO
secure_chroot_dir=/usr/share/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=NO
EOF

# ==============================================================================
# 3. CREATE SYSTEMD SERVICE FOR VSFTPD
# ==============================================================================
echo "[*] Creating systemd service for vsftpd..."
cat << 'EOF' > /etc/systemd/system/vsftpd.service
[Unit]
Description=vsftpd 2.3.4 FTP Server (Cybetary Academy Lab 1)
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/vsftpd /etc/vsftpd.conf
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vsftpd
systemctl restart vsftpd

# ==============================================================================
# 4. FIREWALL CONFIGURATION
# ==============================================================================
echo "[*] Configuring firewall rules (Ports 21, 80, 6200)..."
if command -v ufw &> /dev/null; then
  ufw allow 21/tcp comment 'FTP'
  ufw allow 80/tcp comment 'HTTP'
  ufw allow 6200/tcp comment 'vsftpd backdoor trigger port'
fi

# ==============================================================================
# 5. VERIFICATION
# ==============================================================================
echo ""
echo "[+] ==========================================================="
echo "[+] Lab 1 Setup Complete!"
IP_ADDR=$(hostname -I | awk '{print $1}')
echo "[+] Machine Local IP: ${IP_ADDR}"
echo "[+] Apache status:"
systemctl is-active apache2
echo "[+] vsftpd status:"
systemctl is-active vsftpd
echo "[+] Listening ports (check 21 & 80):"
netstat -tulpn | grep -E ':(21|80)' || ss -tulpn | grep -E ':(21|80)'
echo "[+] ==========================================================="
echo "[*] Ready to be tested with nmap & msfconsole exploit/unix/ftp/vsftpd_234_backdoor"
