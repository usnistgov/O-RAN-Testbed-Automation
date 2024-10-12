#!/bin/bash
echo "# Script: $(realpath $0)..."

# Define the interface and addresses
INTERFACE="ogstun"
IPv4_ADDR="10.45.0.1/16"
IPv6_ADDR="2001:db8:cafe::1/48"
IPv4_SUBNET="10.45.0.0/16"

# Check if the tun interface already exists, if not, add it
if ! ip link show $INTERFACE > /dev/null 2>&1; then
    sudo ip tuntap add name $INTERFACE mode tun
fi

# Check if the IPv4 address is already assigned, if not, add it
if ! ip addr show $INTERFACE | grep -q $IPv4_ADDR; then
    sudo ip addr add $IPv4_ADDR dev $INTERFACE
fi

# Check if the IPv6 address is already assigned, if not, add it
if ! ip addr show $INTERFACE | grep -q $IPv6_ADDR; then
    sudo ip addr add $IPv6_ADDR dev $INTERFACE
fi

# Bring the interface up if it's not already up
if ! ip link show $INTERFACE | grep -q "state UP"; then
    sudo ip link set $INTERFACE up
fi

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1

# Check if the iptables MASQUERADE rule already exists, if not, add it
if ! sudo iptables -t nat -C POSTROUTING -s $IPv4_SUBNET ! -o $INTERFACE -j MASQUERADE 2> /dev/null; then
    sudo iptables -t nat -A POSTROUTING -s $IPv4_SUBNET ! -o $INTERFACE -j MASQUERADE
fi

# Check if the ip6tables MASQUERADE rule already exists, if not, add it
if ! sudo ip6tables -t nat -C POSTROUTING -s $IPv6_SUBNET -o $INTERFACE -j MASQUERADE 2> /dev/null; then
    sudo ip6tables -t nat -A POSTROUTING -s $IPv6_SUBNET -o $INTERFACE -j MASQUERADE 2> /dev/null
fi