#!/bin/bash

sudo kubeadm init phase certs all --config=/root/config.yaml
sudo systemctl restart kubelet
