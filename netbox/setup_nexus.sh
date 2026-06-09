#!/bin/bash
# setup_nexus.sh - Install Docker and run Sonatype Nexus 3
set -e

echo "Updating system..."
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg-agent

echo "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

echo "Starting Nexus 3 container..."
# Create a persistent volume for Nexus data
sudo mkdir -p /opt/nexus-data
sudo chown -R 200:200 /opt/nexus-data

sudo docker run -d \
  --name nexus \
  -p 8081:8081 \
  -v /opt/nexus-data:/nexus-data \
  --restart always \
  sonatype/nexus3

echo "===================================================="
echo "Nexus is starting up. It may take 2-3 minutes."
echo "Access URL: http://$(curl -s ifconfig.me):8081"
echo "To get the initial admin password, run:"
echo "sudo cat /opt/nexus-data/admin.password"
echo "===================================================="
