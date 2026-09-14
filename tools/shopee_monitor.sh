#!/system/bin/sh
# shopee_monitor.sh — Pantau percobaan koneksi ke Shopee secara real-time.
# Usage: su -c 'sh /data/adb/modules/shopee_blocker/shopee_monitor.sh'

IPT=/system/bin/iptables
INTERVAL=3

echo "=========================================="
echo "   SHOPEE CONNECTION ATTEMPT MONITOR"
echo "   Ctrl+C untuk stop"
echo "=========================================="
echo ""

while true; do
    echo "========== $(date '+%H:%M:%S') =========="

    echo ""
    echo "[iptables SHOPEE chain - blocked packets]"
    TOTAL=$($IPT -L SHOPEE -vn 2>/dev/null | awk 'NR>2{sum+=$1}END{print sum+0}')
    echo "  Total REJECTED packets: $TOTAL"
    if [ "$TOTAL" -gt 0 ]; then
        echo "  Per-range breakdown:"
        $IPT -L SHOPEE -vn 2>/dev/null | awk 'NR>2 && $1>0 {printf "    %-20s -> %d pkts (%d bytes)\n", $6, $1, $2}'
    fi

    echo ""
    echo "[conntrack - live shopee connections]"
    FOUND=$(cat /proc/net/nf_conntrack 2>/dev/null | grep -cE "147\.136\.|134\.65\.|45\.119\.218\.|103\.115\.76\.|119\.28\.32\.")
    echo "  Active shopee-related connections: $FOUND"
    if [ "$FOUND" -gt 0 ]; then
        cat /proc/net/nf_conntrack 2>/dev/null | grep -E "147\.136\.|134\.65\.|45\.119\.218\.|103\.115\.76\.|119\.28\.32\." | while read line; do
            echo "  -> $line"
        done
    fi

    echo ""
    echo "[DNS status - shopee.co.id resolves to]"
    DNS_ANS=$(ping -c1 -W2 shopee.co.id 2>/dev/null | sed -n 's/.*(\([^)]*\)).*/\1/p' | head -1)
    if [ -n "$DNS_ANS" ]; then
        if echo "$DNS_ANS" | grep -q "127\|localhost\|0.0.0.0"; then
            echo "  OK: $DNS_ANS (hosts block ACTIVE)"
        else
            echo "  WARN: $DNS_ANS (real IP - shopee reachable!)"
        fi
    else
        echo "  Unknown host (DNS blocked or no network)"
    fi

    echo ""
    sleep $INTERVAL
done