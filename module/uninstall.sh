#!/system/bin/sh

# ===== SHOPEE BLOCKER uninstall.sh =====
# Bersihkan aturan iptables saat module dihapus

IPT=/system/bin/iptables

$IPT -D OUTPUT -j SHOPEE 2>/dev/null
$IPT -F SHOPEE 2>/dev/null
$IPT -X SHOPEE 2>/dev/null

exit 0