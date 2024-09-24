#!/bin/bash

set -e

# Menambahkan repository lokal Kartolo
cat <<EOF | sudo tee /etc/apt/sources.list
deb http://kartolo.sby.datautama.net.id/ubuntu/ focal main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ focal-updates main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ focal-security main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ focal-backports main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ focal-proposed main restricted universe multiverse
EOF

# Memperbarui daftar paket
sudo apt update

# Menginstal ISC DHCP Server, IPTables, dan iptables-persistent
sudo apt install -y isc-dhcp-server iptables iptables-persistent

# Mengonfigurasi DHCP server
cat <<EOF | sudo tee /etc/dhcp/dhcpd.conf
subnet 192.168.20.0 netmask 255.255.255.0 {
    range 192.168.20.2 192.168.20.200;
    option routers 192.168.20.1;
    option domain-name-servers 8.8.8.8, 8.8.4.4;
}
EOF

# Mengonfigurasi interface DHCP server
sudo sed -i 's/^INTERFACESv4=.*/INTERFACESv4="enp0s8"/' /etc/default/isc-dhcp-server

# Mengonfigurasi IP statis untuk internal network
cat <<EOF | sudo tee /etc/netplan/00-installer-yaml
network:
  version: 2
  ethernets:
    enp0s3:
     dhcp4: true
    enp0s8:
      addresses:
        - 192.168.20.1/24
      dhcp4: no
EOF

# Menerapkan konfigurasi netplan
sudo netplan apply

# Merestart DHCP server menggunakan /etc/init.d
sudo /etc/init.d/isc-dhcp-server restart 

# Mengaktifkan IP forwarding dan mengonfigurasi IPTables
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE

# Menyimpan aturan IPTables
sudo netfilter-persistent save
