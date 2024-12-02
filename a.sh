#!/bin/bash  

# Warna untuk output  
GREEN='\033[1;32m'  
NC='\033[0m'  

# Informasi koneksi Mikrotik  
MIKROTIK_IP="192.168.234.132"  
MIKROTIK_PORT="30016"  
MIKROTIK_USER="admin"  
DEFAULT_PASS=""  
NEW_PASS="123"  

# Header  
echo -e "${GREEN}Konfigurasi Mikrotik Dimulai...${NC}"  

expect <<EOF  
spawn telnet $MIKROTIK_IP $MIKROTIK_PORT  
set timeout 5  

# Login  
expect {  
    "Login:" { send "$MIKROTIK_USER\r"; exp_continue }  
    "Password:" { send "$DEFAULT_PASS\r" }  
    "New Password:" { send "$NEW_PASS\r"; exp_continue }  
    "Re-enter Password:" { send "$NEW_PASS\r" }  
}  

# Tambahkan VLAN 10  
expect ">" { send "/interface vlan add name=vlan10 vlan-id=10 interface=ether2\r" }  

# Tambahkan IP Address untuk VLAN 10  
expect ">" { send "/ip address add address=192.168.200.1/24 interface=vlan10\r" }  

# Tambahkan IP Route ke Ubuntu Server  
expect ">" { send "/ip route add dst-address=192.168.20.10/24 gateway=192.168.200.1\r" }  

# Keluar  
expect ">" { send "quit\r" }  
expect eof  
EOF  

# Output selesai  
echo -e "${GREEN}Konfigurasi Mikrotik selesai.${NC}"  
