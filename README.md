# Shopee Blocker

Kill the whole Shopee / Sea ecosystem at the DNS + network level. No app. No link. No web. No redirect. No auto-download.

---

## Wait, what is Shopee? (#what-is-shopee)

Shopee is a **Southeast Asian e-commerce platform** owned by Sea Group (Singapore), one of the biggest online marketplaces in the region. It's available in Indonesia, Malaysia, Singapore, Vietnam, Thailand, the Philippines, Taiwan, and a bunch more countries across SEA and LatAm — plus a mobile app, a website, seller tools, ShopeePay, ShopeeFood/Shopee mart meta-services, and Shopeemobile tracking infra.

That's exactly why this repo exists: Shopee isn't a single URL. It's a **family of sites, apps, and redirect services**. Blocking `shopee.co.id` alone is pointless if a short-link or a regional branch still gets through. So this module blocks the whole family across every region and subdomain.

---

## Why this exists (#why)

It's not about hating Shopee. It's about **control**.

On modern Android, "default link handler" and app archive features are sneaky — they flip control to the vendor. You tap any link with a Shopee trace, and without your consent you get dragged into:

- Shopee redirect handlers,
- Shopee web pages that beg you to install the app,
- auto-tracking / auto-launch.

And here's the thing: Shopee runs one of the **most aggressive ad / tracking machines** in the SEA app ecosystem. Their ads don't just sit in their app — they leak into *other* apps, browsers, share sheets, and system link handlers. Click a promo link someone pasted in a chat → you're on Shopee web. Try to just browse → some random Shopee ad deep-links into the app. The platform is built to **funnel you in** at every opportunity.

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
| Aggressive ads | Shopee ads deep-link into other apps, browsers & share sheets — everywhere |
| Site family (SEA) | Blocking one domain isn't enough; Shopee can come through another branch |

This repo doesn't fix "why Shopee behaves that way" — that's their business problem. What's handled here: **your device is not their default target anymore.**

---

## The ethical part: this is NOT stealing, harming, or threatening Shopee (#ethics)

Let's be very clear about what this module does and does NOT do — no drama, no grey area:

**This module does NOT:**
- ❌ steal, scrape, or exfiltrate any data — from Shopee or from you,
- ❌ attack, DDOS, throttle, or degrade Shopee's servers/services,
- ❌ block anyone *else* — it only blocks *your own device* from connecting to Shopee,
- ❌ touch transactions, accounts, money, or user data of any kind,
- ❌ promote piracy, hacking, or fraud.

**What it actually does:**
- ✅ makes **your own device** (a device you own, running software you control) refuse connections to a specific set of domains/IPs,
- ✅ equivalent to uninstalling an app or adding a hosts entry — nothing more,
- ✅ gives **you** the choice that Shopee's own platform architecture was designed to take away.

Shopee is a legitimate ad-driven business and is free to keep selling inside *their* app. This module never goes near their servers or their systems. It simply reclaims a user's right to decide what their own phone connects to. That's the whole trick — it's **one-way, local, and nobody else is affected**.

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

This repo is about the user's control over their own device — nothing more, nothing less.

- No data is stolen or leaked — nothing leaves the device except requests that only *fail*.
- No harm to Shopee's business infrastructure — their servers are never touched; we simply decline connections on our side.
- No threat, no attack, no reverse-engineering of their systems.
- Shopee keeps its ads and business models. This module only restores one thing: **your right to say no** to redirects/tracking you never approved when tapping a link — not transactions you consciously chose.