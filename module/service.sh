#!/system/bin/sh

# ===== SHOPEE BLOCKER service.sh =====
# Terapkan blokir IP Shopee via iptables pada setiap boot.
# Dipantau ulang tiap 30 detik agar tetap aktif meski netd flush aturan.

IPT=/system/bin/iptables

# IP range hasil resolusi DNS Shopee
# 147.136.0.0/16  = cloud utama Shopee SEA
# 134.65.0.0/16   = Shopee SEA
# 45.119.218.0/24 = shopee.vn
# 103.115.76.0/24 = live.shopee.vn
# 119.28.32.0/24  = shopeeads.com
SHOPEE_RANGES="147.136.0.0/16 134.65.0.0/16 45.119.218.0/24 103.115.76.0/24 119.28.32.0/24"

apply() {
    # buat chain baru
    $IPT -N SHOPEE 2>/dev/null
    # kosongkan aturan lama agar idempoten
    $IPT -F SHOPEE 2>/dev/null
    for r in $SHOPEE_RANGES; do
        $IPT -A SHOPEE -p tcp -d "$r" -j REJECT --reject-with tcp-reset
        $IPT -A SHOPEE -p udp -d "$r" -j REJECT
    done
    # sisipkan jump SHOPEE di urutan teratas OUTPUT
    $IPT -I OUTPUT 1 -j SHOPEE 2>/dev/null
}

apply

# monitor: netd bisa menghapus aturan custom saat jaringan berubah; re-apply bila hilang
(
    while true; do
        sleep 30
        $IPT -C OUTPUT -j SHOPEE 2>/dev/null || apply
    done
) &