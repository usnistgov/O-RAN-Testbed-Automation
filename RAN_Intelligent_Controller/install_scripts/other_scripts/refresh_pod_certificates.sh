#!/bin/bash
echo "# Script: $(realpath $0)..."

sudo kubeadm init phase certs all --config=/root/config.yaml
sudo systemctl restart kubelet
