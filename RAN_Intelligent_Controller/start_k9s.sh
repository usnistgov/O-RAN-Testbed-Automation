#!/bin/bash

if [ ! $(command -v k9s) ]; then
	echo "Installing k9s..."
	sudo ./install_scripts/install_k9s.sh
fi

echo "The Kubernetes cluster manager is starting up..."
sudo k9s -A