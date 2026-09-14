# Shopee Blocker

Kill the whole Shopee / Sea ecosystem at the DNS + network level. No app. No link. No web. No redirect. No auto-download.

---

## Why this exists (#why)

It's not about hating Shopee. It's about **control**.

On modern Android, "default link handler" and app archive features are sneaky — they flip control to the vendor. You tap any link with a Shopee trace, and without your consent you get dragged into:

- Shopee redirect handlers,
- Shopee web pages that beg you to install the app,
- auto-tracking / auto-launch.

Result: data quota burned, attention funneled into a store you never asked for, and your device becomes a redirect landfill.

**Vision of this repo:** give that control back to the user. One way, firm, verified: every path to Shopee on-device gets shut down at the root.

**Mission:**

1. **Close the DNS path** — every Shopee/Sea domain never resolves to a real IP.
2. **Close the network path** — even already-cached IPs still get REJECTed.
3. **No extra apps** — a single systemless Magisk module, cleanly uninstallable.
4. **Zero collateral** — non-Shopee domains are completely untouched.
5. **Visible** — a monitor exists to watch how often Shopee connection attempts happen.

---

## The complaint: what Shopee does to your device (#complaint)

The root problem is not "the Shopee app is installed." The problem is the **shortcuts that exploit the platform**:

| Grievance | Why it's a problem |
|---|---|
| Redirect without consent | Tap any link → dragged to Shopee web even though you never opened Shopee |
| Web you didn't ask for | "Archive app" / "open default linked links" still call Shopee domains |
| Data hungry | Shopee page loaders = thousands of requests, minimum quota to burn |
| Install nagging | Shopee web always pushes you to install the app — pressure, not choice |
| Site family (SEA) | Blocking one domain isn't enough; Shopee can come through another branch |

This repo doesn't fix "why Shopee behaves that way" — that's their business problem. What's handled here: **your device is not their default target anymore.**

---

## How it works (#how-it-works)

### Layer 1 — DNS / hosts (systemless)

The module `mount --bind`s `system/etc/hosts` at boot/pre-mount. It maps ~100 Shopee + Sea domains to `0.0.0.0`:

- shopee.co.id, m./s./api./seller./live./mall./pay./help. — main subdomains
- all regional branches: shopee.com, .my, .sg, .vn, .th, .ph, .tw, .br, .mx, etc.
- short-links & tracking: shope.ee, shp.ee, shopee.io, shopeeads.com, shopeemobile.com
- the parent: sea.com, seagroup.com

Result: the resolver (netd) **returns 127.0.0.1/0.0.0.0 locally**, no query ever leaves the device. Normal browsing keeps working.

### Layer 2 — iptables REJECT

`service.sh` builds a `SHOPEE` chain with 10 REJECT rules targeting Shopee's officially-resolved IP ranges:

```
147.136.0.0/16      <- main Shopee SEA cloud
134.65.0.0/16       <- Shopee SEA
45.119.218.0/24     <- shopee.vn
103.115.76.0/24     <- live.shopee.vn
119.28.32.0/24      <- shopeeads.com
```

Then it's inserted at the very top of `OUTPUT`:

```
iptables -I OUTPUT 1 -j SHOPEE
```

TCP answers `tcp-reset`, UDP answers `icmp-port-unreachable`. This is the second wall: **even if an app has an IP cached, it still won't connect.** Every app is affected — Chrome, system browsers, any app, deeplinks, redirect handlers. Not per-app, but per-network.

### Anti-lapse monitor

netd often flushes custom rules when the network switches (wifi ↔ data). So there's a monitor loop checking every 30 seconds: if the `SHOPEE` jump disappears from OUTPUT, it gets re-applied. Idempotent — re-running never creates duplicate rules.

### Verified

- `ping shopee.co.id` → 127.0.0.1 (hosts active)
- `curl -v https://shopee.co.id` → Connection refused (iptables active)
- `curl https://www.google.com` → 200 OK (normal internet)

---

## How it differs from a plain Magisk hosts module (#vs-hosts-module)

Popular Magisk hosts modules (Energized, AdAway, etc.) are **single-layer**: domain blocking via hosts only.

| | Plain hosts module | This module |
|---|---|---|
| Structure | `<module>/system/etc/hosts` only | hosts + `service.sh` + `uninstall.sh` |
| Scope | ad/spam domain blocklist | Shopee/Sea ecosystem ONLY, all subdomains + regional |
| Layer(s) | DNS only | **DNS + iptables REJECT** |
| Cached IP | LEAKS — domain blocked but old IPs can still be called | still REJECTed |
| New IP inside Shopee range | LEAKS | still REJECTed (range-based) |
| Survives netd reset | n/a | auto re-applies every 30s |
| Collateral | can over-block | 0 — only Shopee ranges |

Bottom line: a plain hosts module **guesses names**, this one **closes addresses**. Name (DNS) + address (iptables) combined — if DNS fails to block, the IP range still gets REJECTed.

---

## Install

```sh
# Option A: install the release .zip directly via Magisk app (Modules → Install from storage)
# Option B: copy the module/ folder to /data/adb/modules/shopee_blocker/ and reboot,
#           or apply live from Termux:
su -c '
  cp -r module /data/adb/modules/shopee_blocker
  sh /data/adb/modules/shopee_blocker/service.sh
'
```

## Monitor

```sh
# watch connection attempts to Shopee in real time
su -c 'sh /data/adb/modules/shopee_blocker/shopee_monitor.sh'
```

## Uninstall

Remove the module folder or run `uninstall.sh`:

```sh
su -c 'sh /data/adb/modules/shopee_blocker/uninstall.sh'
```

Clean slate: the `SHOPEE` chain is removed, hosts back to normal.

---

## Structure

```
module/
  module.prop          <- Magisk metadata
  service.sh           <- install SHOPEE chain + monitor loop
  uninstall.sh         <- clean up iptables
  system/etc/hosts     <- Shopee/Sea domain blocklist
tools/
  shopee_monitor.sh    <- watch connection attempts via conntrack + iptables
```

## Legal-ish

This repo is about the user's control over their own device. Not an attack, not a dox, not ad material. What's blocked here are redirects/tracking **you never approved** when tapping a link — not transactions you consciously chose.