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
apt-get install -y build-essential libcap-dev libssl-dev libpam0g-dev wget tar apache2 ufw net-tools nmap

# ==============================================================================
# 1. SETUP HTTP SERVICE (PORT 80)
# ==============================================================================
echo "[*] Configuring HTTP Service (Apache2)..."
systemctl enable apache2
systemctl start apache2

# Configure Apache Directory Listing (Indexes) on /var/www/html
cat << 'EOF' > /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options +Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Ensure autoindex module is enabled
a2enmod autoindex || true

# Rename or remove index.html so Apache shows the directory listing, or create a browsable /backup or /files folder
# We keep index.html for gateway, AND create exposed directories that show directory listing:
mkdir -p /var/www/html/backups
mkdir -p /var/www/html/secret_notes

cat << 'EOF' > /var/www/html/backups/db_backup.sql
-- Cybetary Internal Database Backup
-- Dump version 1.0.4
-- Note to admin: update vsftpd service credentials before deployment
CREATE DATABASE cybetary_staging;
EOF

cat << 'EOF' > /var/www/html/secret_notes/ftp_credentials.txt
[FTP Server Config Notes]
Service: vsftpd 2.3.4
Internal Port: 21
Notice: Server maintained by IT admin. Testing backdoor vulnerability lab.
EOF

# If you also want root / to show directory listing directly, we can remove index.html:
rm -f /var/www/html/index.html

systemctl restart apache2


# ==============================================================================
# 2. DOWNLOAD, COMPILE & INSTALL VSFTPD 2.3.4 (BACKDOORED)
# ==============================================================================
echo "[*] Downloading backdoored vsftpd-2.3.4 source..."
BUILD_DIR="/tmp/vsftpd_build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Download the authentic backdoored vsftpd-2.3.4 source code
git clone https://security.appspot.com/downloads/vsftpd-2.3.4.tar.gz "$BUILD_DIR/vsftpd-2.3.4"
cd "$BUILD_DIR/vsftpd-2.3.4"


echo "[*] Patching Makefile to link required crypto and cap libraries..."
# Ensure linking against crypt and cap libraries properly on modern Linux
sed -i 's/LIBS\t=\t`\.\/vsf_findlibs.sh`/LIBS\t=\t-lcrypt -lcap/g' Makefile
sed -i 's/-lcrypt -lcap/-lcrypt -lcap -lpam/' Makefile

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
