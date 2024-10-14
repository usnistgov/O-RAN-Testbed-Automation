#!/bin/bash
echo "# Script: $(realpath $0)..."

echo "Installing KubeArmor..."
helm repo add kubearmor https://kubearmor.github.io/charts
helm repo update
helm upgrade --install kubearmor-operator kubearmor/kubearmor-operator -n kubearmor --create-namespace
kubectl apply -f https://raw.githubusercontent.com/kubearmor/KubeArmor/main/pkg/KubeArmorOperator/config/samples/sample-config.yml

echo "KubeArmor Successfully Installed."
echo "Please give several minutes for KubeArmor to initialize, then terminate and initialize all other pods."
echo "Check the status with: kubectl get pods -A"
