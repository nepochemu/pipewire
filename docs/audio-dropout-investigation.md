# Audio dropouts: investigation and outcome

Date: 2026-09-21
Sender: `nixos` (laptop, WiFi). Receiver: `pipe` (Raspberry Pi, HiFiBerry DAC+DSP).

## Summary

Two separate faults, found in sequence.

1. **The link was going over Tailscale instead of the LAN**, and Tailscale kept
   changing how it reached the receiver. Fixed.
2. **Dropouts on the LAN path**, caused by TCP stalls on the sender's WiFi
   outlasting the tunnel buffer. Mitigated by a larger buffer; the underlying
   transport is still the wrong one for low-latency use.

## Fault 1 — traffic routed over Tailscale

`pwlink`'s `find_endpoint` tried `resolve_tailscale_host()` *before* mDNS, so a
receiver on the same LAN was still reached through the tailnet. The receiver
compounded this: its `50-tcp.conf` bound pipewire-pulse only to the Tailscale
address, so no LAN path existed at all.

Tailscale was observed moving that peer between three states within one hour:

| path | address |
|---|---|
| direct LAN | `192.168.178.40:41641` |
| direct WAN | `89.245.197.51` |
| DERP relay | Frankfurt |

Every transition reset the connection, which is what produced
`mod.pulse-tunnel: connection failure: No data` and required a manual
`pwlink reset`.

Fixes:

- Receiver now binds both `tcp:192.168.178.40:4713` (LAN) and
  `tcp:100.121.123.17:4713` (Tailscale, for when the sender is away).
- `pwlink` prefers a reachable LAN path and falls back to Tailscale only when
  the host is not reachable locally (commit `f8471e3`).
- `.local` names resolve via `avahi-resolve`: nss-mdns is not wired into the
  sender's resolver, so `getent hosts pipe.local` fails and `module-tunnel-sink`
  cannot resolve it either.
- Added `pwlink watch` / `--watch`, since `module-tunnel-sink` never retries: a
  dead socket previously left audio gone until someone ran `reset` by hand.

## Fault 2 — dropouts on the LAN path

With the LAN path in place, playback still broke up every 2-5 minutes.

Ruled out by measurement:

| suspect | evidence |
|---|---|
| Receiver xruns | `pw-top` ERR = 0 on every receiver node |
| Weak signal | -44 dBm, 1170 Mbit/s, 5 GHz |
| WiFi power save | disabled on both ends (`uapsd_disable=3`, NM powersave off) |
| WPA rekeying | underflows occur with no `wpa_supplicant` events |
| Packet loss | 897/900 ICMP replies, max inter-reply gap 0.282 s |
| Stale mpv process | 0% CPU, audio node suspended |
| Network latency | LAN p50 1.6 ms, p99 5.3 ms once the receiver moved to Ethernet |

### Cause

Underflows correlate exactly with brief WiFi latency blips:

```
18:22:26.7   13.20 ms
18:22:27.0   30.30 ms   <- underflow logged 18:22:26
18:22:28.0   38.80 ms   <- underflow logged 18:22:28
```

A 39 ms blip cannot drain a 300 ms buffer, and that discrepancy is the whole
point: **ping and the audio stream do not experience the same stall.** ICMP
packets are independent, so a ping sent during the stall answers normally. The
tunnel is a TCP stream, and TCP guarantees in-order delivery — one lost segment
blocks every later segment until it is retransmitted, with exponential backoff
if the retransmit also fails. The audio stall is therefore much longer than any
ping reveals, while the DAC keeps draining the buffer at a fixed 192 KB/s.

This also explains why the receiver logged nothing: it never received data, so
it had nothing to complain about.

### Measured buffer behaviour

Each row is an 8-minute run, against a baseline of one dropout every 2-5 min.
Shorter windows are not trustworthy — two earlier "clean" 100-second runs were
contradicted within a minute.

| `latency_msec` | underflows in 8 min |
|---|---|
| 100 / 200 / 300 | dropouts every 2-5 min |
| 500 | **0** |
| 2000 | **0** |

Current setting: **500 ms**.

## Where this should go next

The requirement is low latency for video *and* music, with occasional inaudible
degradation acceptable. A large TCP buffer is the wrong shape of fix for that:

- seek and pause must flush and refill the whole reservoir, so scrubbing feels
  sluggish;
- buffer occupancy shifts as TCP recovers, so the effective delay wanders and a
  fixed `mpv --audio-delay` offset will not hold.

Consumer streamers (Roon/RAAT, UPnP, Spotify Connect, Snapcast at 1000 ms
default) all use TCP with large buffers, because they play files and do not care
about latency. Professional low-latency systems (Dante, AES67, Ravenna) use
RTP/UDP with PTP — but on wired, managed networks, because UDP without
retransmission needs a reliable medium.

Given the requirement, **unicast RTP** (`module-rtp-sink` / `module-rtp-source`)
targeting 50-100 ms is the architecture to prototype. Caveats:

- **Unicast only.** WiFi sends multicast at the lowest basic rate with no
  MAC-layer acknowledgement or retransmission; multicast RTP over WiFi would be
  worse than the current setup.
- Clock drift must be handled by resampling — TCP's flow control implicitly did
  this before.
- These modules are fussy about timing config: this system's journal already
  logs `mod.raop-sink: sess.latency.msec 250 should be an integer multiple of
  rtp.ptime 7.98` daily.
- Keep the TCP path working as a fallback rather than replacing it.

Unmeasured and worth doing first: **the WiFi packet loss rate**, which directly
predicts how often an RTP click would be audible.

## Notes

- The receiver moved from `wlan0` to `eth0` during this session, keeping
  `192.168.178.40`. Pi-hole, the audio listener, and `pwlink`'s LAN probe all
  depend on that address.
- `pwlink connect --latency-ms N` on an already-connected link saves N to the
  config but does not apply it — the module is only loaded when the sink is
  absent. Use `pwlink reset` after changing it. This should be fixed so the
  config cannot disagree with what is running.
