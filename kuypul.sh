#!/bin/bash

# ASCII art untuk "Ban"
echo -e "\033[1;32m======================================="
echo "  ____              "
echo " |  _ \             "
echo " | |_) | __ _ _ __  "
echo " |  _ < / _\` | '_ \ "
echo " | |_) | (_| | | | |"
echo " |____/ \__,_|_| |_|"
echo "         Ban        "
echo "=======================================\033[0m"

# Variabel untuk progres
PROGRES=("Menambahkan Repository Ban" "Melakukan update paket" "Mengonfigurasi netplan" "Menginstal DHCP server" \
         "Mengonfigurasi DHCP server" "Mengaktifkan IP Forwarding" "Mengonfigurasi Masquerade" \
         "Menginstal iptables-persistent" "Menyimpan konfigurasi iptables" "Menginstal Expect" \
         "Menyiapkan rc.local untuk iptables NAT" "Konfigurasi Cisco")

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
sudo apt update -y

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
sudo netplan apply

# Instalasi ISC DHCP Server
echo -e "${GREEN}${PROGRES[3]}${NC}"
sudo apt install -y isc-dhcp-server

# Konfigurasi DHCP Server
echo -e "${GREEN}${PROGRES[4]}${NC}"
sudo bash -c 'cat > /etc/dhcp/dhcpd.conf' << EOF
subnet 192.168.20.0 netmask 255.255.255.0 {
  range 192.168.20.2 192.168.20.254;
  option domain-name-servers 8.8.8.8;
  option subnet-mask 255.255.255.0;
  option routers 192.168.20.1;
  option broadcast-address 192.168.20.255;
  default-lease-time 600;
  max-lease-time 7200;

  host Ban {
    hardware ethernet 00:11:22:33:44:55;  # Ganti dengan MAC address perangkat
    fixed-address 192.168.20.10;
  }
}
EOF
echo 'INTERFACESv4="eth1.10"' | sudo tee /etc/default/isc-dhcp-server > /dev/null
sudo systemctl restart isc-dhcp-server

# Aktifkan IP Forwarding
echo -e "${GREEN}${PROGRES[5]}${NC}"
sudo sed -i '/^#net.ipv4.ip_forward=1/s/^#//' /etc/sysctl.conf
sudo sysctl -p

# Konfigurasi Masquerade dengan iptables
echo -e "${GREEN}${PROGRES[6]}${NC}"
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Instalasi iptables-persistent dengan otomatisasi
echo -e "${GREEN}${PROGRES[7]}${NC}"
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean false | sudo debconf-set-selections
sudo apt install -y iptables-persistent

# Menyimpan Konfigurasi iptables
echo -e "${GREEN}${PROGRES[8]}${NC}"
sudo sh -c "iptables-save > /etc/iptables/rules.v4"
sudo sh -c "ip6tables-save > /etc/iptables/rules.v6"

# Membuat file rc.local untuk menjalankan iptables NAT secara otomatis
echo -e "${GREEN}${PROGRES[9]}${NC}"
sudo bash -c 'cat > /etc/rc.local' << 'RCLOCAL'
#!/bin/bash
# Aktifkan aturan iptables NAT
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
exit 0
RCLOCAL

# Memberikan izin eksekusi pada rc.local
sudo chmod +x /etc/rc.local

# Pastikan rc.local service aktif
if ! systemctl is-active --quiet rc-local; then
    sudo bash -c 'cat > /etc/systemd/system/rc-local.service' << 'SERVICE'
[Unit]
Description=/etc/rc.local Compatibility
ConditionPathExists=/etc/rc.local

[Service]
Type=forking
ExecStart=/etc/rc.local
TimeoutSec=0
StandardInput=tty
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE

    sudo systemctl enable rc-local
    sudo systemctl start rc-local
fi

# Instalasi Expect
echo -e "${GREEN}${PROGRES[10]}${NC}"
sudo apt install -y expect

# Konfigurasi Cisco
echo -e "${GREEN}${PROGRES[11]}${NC}"
CISCO_IP="192.168.234.132"
CISCO_PORT="30013"

# Pastikan `expect` terinstal
command -v expect > /dev/null || error_message "Expect tidak terpasang. Instal dengan: sudo apt install expect"

expect <<EOF
spawn telnet $CISCO_IP $CISCO_PORT
set timeout 20
# Masuk ke perangkat dan mode konfigurasi
expect ">" { send "enable\r" }
expect "#" { send "configure terminal\r" }

# Konfigurasi interface e0/0: mode access dan VLAN 10
expect "(config)#" { send "interface e0/0\r" }
expect "(config-if)#" { send "switchport mode access\r" }
expect "(config-if)#" { send "switchport access vlan 10\r" }
expect "(config-if)#" { send "no shutdown\r" }
expect "(config-if)#" { send "exit\r" }

# Konfigurasi interface e0/1: mode trunk
expect "(config)#" { send "interface e0/1\r" }
expect "(config-if)#" { send "switchport mode trunk\r" }
expect "(config-if)#" { send "switchport trunk encapsulation dot1q\r" }
expect "(config-if)#" { send "no shutdown\r" }
expect "(config-if)#" { send "exit\r" }

# Keluar dari mode konfigurasi
expect "(config)#" { send "exit\r" }
expect "#" { send "exit\r" }
expect eof
EOF

# Selesai
echo -e "${GREEN}Otomasi selesai!${NC}"
