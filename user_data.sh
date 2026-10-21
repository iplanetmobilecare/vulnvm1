#!/bin/bash
# AWS EC2 User Data script
# Auto-runs as root on first boot of your Ubuntu EC2 instance
apt-get update -y
apt-get install -y git
git clone https://github.com/iplanetmobilecare/vulnvm1.git /opt/vulnvm1
chmod +x /opt/vulnvm1/setup.sh
/opt/vulnvm1/setup.sh