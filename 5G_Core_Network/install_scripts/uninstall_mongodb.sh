#!/bin/bash
#
# NIST-developed software is provided by NIST as a public service. You may use,
# copy, and distribute copies of the software in any medium, provided that you
# keep intact this entire notice. You may improve, modify, and create derivative
# works of the software or any portion of the software, and you may copy and
# distribute such modifications or works. Modified works should carry a notice
# stating that you changed the software and should note the date and nature of
# any such change. Please explicitly acknowledge the National Institute of
# Standards and Technology as the source of the software.
#
# NIST-developed software is expressly provided "AS IS." NIST MAKES NO WARRANTY
# OF ANY KIND, EXPRESS, IMPLIED, IN FACT, OR ARISING BY OPERATION OF LAW,
# INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTY OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, AND DATA ACCURACY. NIST
# NEITHER REPRESENTS NOR WARRANTS THAT THE OPERATION OF THE SOFTWARE WILL BE
# UNINTERRUPTED OR ERROR-FREE, OR THAT ANY DEFECTS WILL BE CORRECTED. NIST DOES
# NOT WARRANT OR MAKE ANY REPRESENTATIONS REGARDING THE USE OF THE SOFTWARE OR
# THE RESULTS THEREOF, INCLUDING BUT NOT LIMITED TO THE CORRECTNESS, ACCURACY,
# RELIABILITY, OR USEFULNESS OF THE SOFTWARE.
#
# You are solely responsible for determining the appropriateness of using and
# distributing the software and you assume all risks associated with its use,
# including but not limited to the risks and costs of program errors, compliance
# with applicable laws, damage to or loss of data, programs or equipment, and
# the unavailability or interruption of operation. This software is not intended
# to be used in any situation where a failure could cause risk of injury or
# damage to property. The software developed by NIST employees is not subject to
# copyright protection within the United States.

# Don't exit immediately if a command fails
set +e

echo "# Script: $(realpath $0)..."

# Stop and disable the MongoDB service
if systemctl is-active --quiet mongod; then
    sudo systemctl stop mongod
    sudo systemctl disable mongod
fi

# Uninstall the MongoDB packages
sudo apt-get purge -y mongodb-org mongodb-org-server mongodb-org-shell mongodb-org-mongos mongodb-org-tools mongosh

# Remove MongoDB and its user and group
sudo userdel mongodb
sudo groupdel mongodb

# Remove MongoDB data and log directories
sudo rm -rf /var/lib/mongodb
sudo rm -rf /var/log/mongodb

# Remove MongoDB configurations and system modifications
sudo rm -rf /etc/mongod
sudo rm /etc/apt/sources.list.d/mongodb-org-4.4.list
sudo rm /etc/apt/sources.list.d/mongodb-org-5.0.list
sudo rm /usr/share/keyrings/mongodb-archive-keyring.gpg

# Unpin MongoDB packages
echo "mongodb-org install" | sudo dpkg --set-selections
echo "mongodb-org-database install" | sudo dpkg --set-selections
echo "mongodb-org-server install" | sudo dpkg --set-selections
echo "mongodb-mongosh install" | sudo dpkg --set-selections
echo "mongodb-org-mongos install" | sudo dpkg --set-selections
echo "mongodb-org-tools install" | sudo dpkg --set-selections

sudo apt-get autoremove -y
sudo apt-get clean
