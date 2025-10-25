#!/bin/bash

# Step 1: Set root password to VPN@01920280000
echo "Setting root password..."
echo "root:VPN@01920280000" | sudo chpasswd
if [ $? -eq 0 ]; then
    echo -e "\e[32m✔ Root password set successfully\e[0m"
else
    echo -e "\e[31m✘ Failed to set root password\e[0m"
    exit 1
fi

# Step 2: Update and upgrade system
echo "Updating system..."
sudo apt update && sudo apt upgrade -y
if [ $? -eq 0 ]; then
    echo -e "\e[34m✔ System updated successfully\e[0m"
else
    echo -e "\e[31m✘ System update failed\e[0m"
    exit 1
fi

# Step 3: Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com | sh
if [ $? -eq 0 ]; then
    echo -e "\e[36m✔ Docker installed successfully\e[0m"
else
    echo -e "\e[31m✘ Docker installation failed\e[0m"
    exit 1
fi
