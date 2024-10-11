#!/bin/bash
echo "# Script: $(realpath $0)..."

sudo apt-get install -y ca-certificates curl gnupg
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

NODE_MAJOR=20

echo "deb [arch=amd64,arm64 signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list

sudo apt update

sudo apt install nodejs -y

curl -fsSL https://open5gs.org/open5gs/assets/webui/install | sudo -E bash -
