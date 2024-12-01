#!/bin/bash

# ASCII art untuk "Ban"
echo -e "\033[1;32m======================================="
echo "  ____              "
echo " |  _ \             "
echo " | |_) | __ _ _ __  "
echo " |  _ < / _\` | '_ \ "
echo " | |_) | (_| | | | |"
echo " |____/ \__,_|_| |_|"
echo "                    "
echo "=======================================\033[0m"

# Variabel untuk progres
PROGRES=("Menambahkan Repository Ban" "Melakukan update paket" "Mengonfigurasi netplan" "Menginstal DHCP server" \
         "Mengonfigurasi DHCP server" "Mengaktifkan IP Forwarding" "Mengonfigurasi Masquerade" \
         "Menginstal iptables-persistent" "Menyimpan konfigurasi iptables"  \
         "Membuat iptables NAT Service" "Menginstal Expect" "Konfigurasi Cisco")

# Warna untuk output
GREEN='\033[1;32m'
NC='\033[0m'

# Fungsi untuk pesan sukses dan gagal
success_message() { echo -e "${GREEN}$1 berhasil!${NC}"; }
error_message() { echo -e "\033[1;31m$1 gagal!${NC}"; exit 1; }

# Otomasi Dimulai
echo "Otomasi Dimulai"

# Menambahkan Repository Ban
echo -e "${GREEN}${PROGRES[0]}${NC}"
REPO="http://kartolo.sby.datautama.net.id/ubuntu/"
if ! grep -q "$REPO" /etc/apt/sources.list; then
    cat <<EOF | sudo tee /etc/apt/sources.list > /dev/null
deb ${REPO} focal main restricted universe multiverse
deb ${REPO} focal-updates main restricted universe multiverse
deb ${REPO} focal-security main restricted universe multiverse
deb ${REPO} focal-backports main restricted universe multiverse
deb ${REPO} focal-proposed main restricted universe multiverse
EOF
fi

# Update Paket
echo -e "${GREEN}${PROGRES[1]}${NC}"
sudo apt update -y > /dev/null 2>&1

# Konfigurasi Netplan
echo -e "${GREEN}${PROGRES[2]}${NC}"
cat <<EOT | sudo tee /etc/netplan/01-netcfg.yaml > /dev/null
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: yes
    eth1:
      dhcp4: no
  vlans:
    eth1.10:
      id: 10
      link: eth1
      addresses:
        - 192.168.20.1/24
EOT
sudo netplan apply > /dev/null 2>&1

# Instalasi ISC DHCP Server
echo -e "${GREEN}${PROGRES[3]}${NC}"
sudo apt install -y isc-dhcp-server > /dev/null 2>&1

# Konfigurasi DHCP Server
echo -e "${GREEN}${PROGRES[4]}${NC}"
sudo bash -c 'cat > /etc/dhcp/dhcpd.conf' << EOF > /dev/null
subnet 192.168.20.0 netmask 255.255.255.0 {
  range 192.168.20.2 192.168.20.254;
  option domain-name-servers 8.8.8.8;
  option subnet-mask 255.255.255.0;
  option routers 192.168.20.1;
  option broadcast-address 192.168.20.255;
  default-lease-time 600;
  max-lease-time 7200;

  host Ban {
    hardware ethernet 00:50:79:66:68:0f;  
    fixed-address 192.168.20.10;
  }
}
EOF
echo 'INTERFACESv4="eth1.10"' | sudo tee /etc/default/isc-dhcp-server > /dev/null
sudo systemctl restart isc-dhcp-server > /dev/null 2>&1

# Aktifkan IP Forwarding
echo -e "${GREEN}${PROGRES[5]}${NC}"
sudo sed -i '/^#net.ipv4.ip_forward=1/s/^#//' /etc/sysctl.conf
sudo sysctl -p > /dev/null 2>&1

# Konfigurasi Masquerade dengan iptables
echo -e "${GREEN}${PROGRES[6]}${NC}"
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE > /dev/null 2>&1

# Instalasi iptables-persistent dengan otomatisasi
echo -e "${GREEN}${PROGRES[7]}${NC}"
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections > /dev/null 2>&1
echo iptables-persistent iptables-persistent/autosave_v6 boolean false | sudo debconf-set-selections > /dev/null 2>&1
sudo apt install -y iptables-persistent > /dev/null 2>&1

# Menyimpan Konfigurasi iptables
echo -e "${GREEN}${PROGRES[8]}${NC}"
sudo sh -c "iptables-save > /etc/iptables/rules.v4" > /dev/null 2>&1
sudo sh -c "ip6tables-save > /etc/iptables/rules.v6" > /dev/null 2>&1

# Membuat iptables NAT Service
echo -e "${GREEN}${PROGRES[9]}${NC}"
sudo bash -c 'cat > /etc/systemd/system/iptables-nat.service' << 'EOF'
[Unit]
Description=Setup iptables NAT
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable iptables-nat
sudo systemctl start iptables-nat

# Instalasi Expect
echo -e "${GREEN}${PROGRES[10]}${NC}"
if ! command -v expect > /dev/null; then
    sudo apt install -y expect > /dev/null 2>&1
    [ $? -eq 0 ] && success_message "Instalasi Expect" || error_message "Instalasi Expect"
else
    success_message "Expect sudah terinstal"
fi

# Konfigurasi Cisco
echo -e "${GREEN}${PROGRES[11]}${NC}"
CISCO_IP="192.168.234.132"
CISCO_PORT="30013"
expect <<EOF > /dev/null 2>&1
spawn telnet $CISCO_IP $CISCO_PORT
set timeout 20
expect ">" { send "enable\r" }
expect "#" { send "configure terminal\r" }
expect "(config)#" { send "interface e0/0\r" }
expect "(config-if)#" { send "switchport mode access\r" }
expect "(config-if)#" { send "switchport access vlan 10\r" }
expect "(config-if)#" { send "no shutdown\r" }
expect "(config-if)#" { send "exit\r" }
expect "(config)#" { send "interface e0/1\r" }
expect "(config-if)#" { send "switchport mode trunk\r" }
expect "(config-if)#" { send "switchport trunk encapsulation dot1q\r" }
expect "(config-if)#" { send "no shutdown\r" }
expect "(config-if)#" { send "exit\r" }
expect "(config)#" { send "exit\r" }
expect "#" { send "exit\r" }
expect eof
EOF

# Selesai
echo -e "${GREEN}Otomasi selesai!${NC}"
