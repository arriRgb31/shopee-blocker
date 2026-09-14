# Shopee Blocker

Block seluruh ekosistem Shopee / Sea Group di level DNS + network. No app. No link. No web. No redirect. No auto-download.

---

## Kenapa ada repo ini (#visi)

Bukan benci Shopee. Ini soal **kontrol**.

Di Android modern, "setting default link tertaut" dan fitur arsip aplikasi itu belatuk — mereka membalik kontrol ke vendor. Lo klik link apapun yang mengandung jejak Shopee, dan tanpa lo sepakat, lo dibawa ke:

- redirect handler Shopee,
- halaman web Shopee yang minta install app,
- auto-tracking / auto-launch.

Hasilnya: kuota data habis, perhatian diarahkan ke toko yang nggak lo minta, dan device lo jadi "pengumpul sampah redirect".

**Visi repo ini:** kembalikan kontrol itu ke tangan user. Satu cara, tegas, terverifikasi: semua jalur menuju Shopee di device ditutup dari akar.

**Misi:**

1. Tutup jalur **DNS** — semua domain Shopee/Sea nggak akan pernah resolve ke IP aslinya.
2. Tutup jalur **network** — bahkan kalau ada IP yang sudah di-cache, tetap kena REJECT.
3. **Tanpa app tambahan** — satu Magisk module, systemless, bisa di-uninstall bersih.
4. **Anti-gangguan** — domain di luar Shopee nggak disentuh sama sekali.
5. **Terlihat** — ada monitor untuk ngecek seberapa sering koneksi ke Shopee dicoba.

---

## Keluhan: apa yang Shopee lakukan ke device (#keluhan)

Akar masalahnya bukan "app Shopee di-install". Masalahnya adalah **jalan pintas yang mengeksploitasi platform**:

| Keluhan | Kenapa ini masalah |
|---|---|
| Redirect tanpa izin | Klik link apapun → dibawa ke Shopee web walau user nggak klik Shopee |
| Web yang nggak diminta | "Arsipkan aplikasi" / "buka default link tertaut" tetap memanggil domain Shopee |
| Haus data | Loader/page content Shopee = ribuan per request, kuota minimal |
| Auto-nudge install | Shopee web selalu nyuruh install app → pressure, bukan pilihan |
| Family-situs (SEA) | Blokir satu domain aja nggak cukup; Shopee bisa lewat cabang lain |

Repo ini nggak nyelesaiin "kenapa Shopee begitu" — itu urusan bisnis mereka. Yang diurus di sini: **device lo bukan korban default mereka lagi.**

---

## Cara kerja module (#cara-kerja)

### Lapisan 1 — DNS / hosts (systemless)

Module nge-`mount --bind` filesystem `system/etc/hosts` selama boot/before-mount. Isinya memetakan ~100 domain Shopee + Sea Group ke `0.0.0.0`:

- shopee.co.id, m./s./api./seller./live./mall./pay./help. — subdomain utama
- semua cabang regional: shopee.com, .my, .sg, .vn, .th, .ph, .tw, .br, .mx, dst
- short-link & tracking: shope.ee, shp.ee, shopee.io, shopeeads.com, shopeemobile.com
- induk: sea.com, seagroup.com

Hasilnya: resolver (netd) **ngereturn 127.0.0.1/0.0.0.0 lokal**, query nggak pernah keluar device. Browsing normal tetap jalan.

### Lapisan 2 — iptables REJECT

`service.sh` bikin chain `SHOPEE` berisi 10 rule REJECT ke IP range hasil resolusi resmi Shopee:

```
147.136.0.0/16      <- cloud utama Shopee SEA
134.65.0.0/16       <- Shopee SEA
45.119.218.0/24     <- shopee.vn
103.115.76.0/24     <- live.shopee.vn
119.28.32.0/24      <- shopeeads.com
```

Lalu di-insert di posisi paling atas chain `OUTPUT`:

```
iptables -I OUTPUT 1 -j SHOPEE
```

TCP dijawab `tcp-reset`, UDP dijawab `icmp-port-unreachable`. Ini benteng kedua: **kalau IP yang dipanggil sudah ter-cache di suatu app, tetap nggak akan konek.** Semua app jadi terkena blokir — Chrome, browser system, app apa pun, deeplink, redirect handler. Bukan per-app, tapi per-network.

### Anti-lupa (monitor)

netd sering mereset aturan custom saat jaringan ganti (wifi ↔ data). Karena itu ada loop monitor yang ngecek tiap 30 detik: kalau jump `SHOPEE` hilang dari OUTPUT, diapasang lagi. Idempoten — jalan jalan ulang nggak bikin duplikat rule.

### Verified

- `ping shopee.co.id` → 127.0.0.1 (hosts aktif)
- `curl -v https://shopee.co.id` → Connection refused (iptables aktif)
- `curl https://www.google.com` → 200 OK (internet normal)

---

## Bedanya sama Magisk "hosts module" biasa (#beda-vs-hosts-module)

Magisk host modules populer (Energized, AdAway, dll) itu cuma **satu lapis**: domain block via hosts.

| | Hosts module biasa | Module ini |
|---|---|---|
| Struktur | `<module>/system/etc/hosts` | sama + `service.sh` + `uninstall.sh` |
| Skope | blokir domain iklan/spam | khusus ekosistem Shopee/Sea, SEMUA subdomain + regional |
| Lapisan | DNS doang | **DNS + iptables REJECT** |
| Kalau IP di-cache | LOLOS — domain-nya ke block tapi IP lama bisa tetap dipanggil app | tetap kena REJECT |
| Kalau dapat IP baru di range Shopee | LOLOS | tetap kena REJECT (range-based) |
| Persist when netd reset | n/a (animasi) | auto re-apply tiap 30 detik |
| Impact ke traffic lain | bisa overblocking | 0 — hanya range Shopee |

Intinya: hosts module biasa **menebak nama**, andre ini **menutup alamat**. Kombinasi nama (DNS) + alamat (iptables) — kalau DNS gagal ke-block, range IP-nya masih di-REJECT.

---

## Install

```sh
# Salin folder module/ ke /data/adb/modules/shopee_blocker/
# lalu reboot, atau langsung dari Termux:
su -c '
  cp -r module /data/adb/modules/shopee_blocker
  sh /data/adb/modules/shopee_blocker/service.sh
'
```

## Monitor

```sh
# pantau percobaan koneksi ke Shopee
su -c 'sh /data/adb/modules/shopee_blocker/shopee_monitor.sh'
```

## Uninstall

Hapus folder module atau jalankan `uninstall.sh`:

```sh
su -c 'sh /data/adb/modules/shopee_blocker/uninstall.sh'
```

Semua bersih: chain `SHOPEE` dihapus, hosts kembali normal.

---

## Struktur

```
module/
  module.prop          <- metadata Magisk
  service.sh           <- pasang chain SHOPEE + monitor loop
  uninstall.sh         <- bersihkan iptables
  system/etc/hosts     <- block list domain Shopee/Sea
tools/
  shopee_monitor.sh    <- pantau percobaan koneksi via conntrack + iptables
```

## Legal-ish

Repository ini untuk kontrol user atas device sendiri. Tidak dimaksudkan sebagai penyerang, bukan dox, dan bukan bahan iklan. Fitur yang diblokir di sini adalah redirect/tracking yang **tidak disetujui** saat user klik link — bukan transaksi yang dipilih user secara sadar.