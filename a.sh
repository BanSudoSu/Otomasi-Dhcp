#!/usr/bin/expect -f

# Variabel konfigurasi
set HOST "192.168.234.132"      # Ganti dengan IP Mikrotik Anda
set PORT "30016"                # Port Telnet Mikrotik Anda
set USER "admin"                # Username Mikrotik
set NEW_PASS "123"              # Password baru yang akan diatur jika diminta

# Mulai sesi Telnet ke port yang ditentukan
spawn telnet $HOST $PORT

# Tunggu prompt login
expect "Login:"
send "$USER\r"

# Tunggu prompt password (kosong awalnya)
expect "Password:"
send "\r"

# Jika diminta mengganti password
expect {
    "New password:" {
        send "$NEW_PASS\r"
        expect "Retype new password:"
        send "$NEW_PASS\r"
    }
    ">" { }
}

# Tunggu prompt Mikrotik
send "/system console\r"

# Tunggu prompt Expert
expect "expert>"
send "/ip address add address=192.168.200.1/24 interface=ether2\r"  # Menggunakan ether2

# Tambahkan NAT Masquerade
expect "expert>"
send "/ip firewall nat add chain=srcnat out-interface=ether2 action=masquerade\r"  # Menggunakan ether2

# Tambahkan routing
expect "expert>"
send "/ip route add dst-address=192.168.20.10/32 gateway=192.168.200.1\r"

# Menunggu beberapa detik dan keluar
expect "expert>"
send "exit\r"

# Tutup sesi Telnet
expect eof
