#!/bin/bash

echo
echo "Registering CHART_REPO_URL=http://0.0.0.0:8090 for user \"$USER\"..."
ENV_VAR="export CHART_REPO_URL=http://0.0.0.0:8090"

# Add to /etc/profile for login shells
if ! grep -q "CHART_REPO_URL=http://0.0.0.0:8090" /etc/profile; then
    echo "$ENV_VAR" | sudo tee -a /etc/profile > /dev/null
    echo "Added CHART_REPO_URL to /etc/profile"
fi

# Add to ~/.bashrc for non-login shells
if ! grep -q "CHART_REPO_URL=http://0.0.0.0:8090" ~/.bashrc; then
    echo "$ENV_VAR" >> ~/.bashrc
    echo "Added CHART_REPO_URL to ~/.bashrc"
fi

# Apply the environment variable for the current session
export CHART_REPO_URL=http://0.0.0.0:8090
echo "CHART_REPO_URL set to $CHART_REPO_URL for current and future sessions for user \"$USER\"."

# Source the updated profiles to ensure the variable is available immediately
source /etc/profile
source ~/.bashrc