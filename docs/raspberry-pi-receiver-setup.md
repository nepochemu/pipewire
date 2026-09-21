# Raspberry Pi PipeWire Audio Receiver – Stable Deployment Guide

This document summarizes the **final, working, low-risk setup** for deploying a Raspberry Pi as a **network audio receiver** using **PipeWire**, **HiFiBerry**, and **Tailscale**, while avoiding the problems encountered during experimentation.

The goal is:
- predictable behavior
- minimal moving parts
- no protocol switching mid‑setup
- no lock‑out risk

---

## 1. Design decisions (important context)

Before any commands, these rules matter:

- **Do not mix protocols** casually
  - Either use *native PipeWire* **or** *Pulse (pipewire‑pulse)*
  - This setup uses **Pulse over PipeWire** because it is stable and well-supported

- **Do not bind by interface name** (`tailscale0`)
  - PipeWire on Raspberry Pi OS is unreliable with interface-name binding
  - Always bind by IP or `0.0.0.0`

- **Tailscale provides isolation**
  - We rely on Tailscale for security
  - We do NOT rely on clever PipeWire binding tricks

- **SSH safety first**
  - Always confirm Tailscale SSH works *before* disabling classic SSH

---

## 2. Base OS preparation (Pi)

- Raspberry Pi OS Lite (64‑bit recommended)
- Enable SSH at imaging time (temporary)
- User created: `airflower`

After first boot:

```bash
sudo apt update
sudo apt install -y pipewire pipewire-pulse wireplumber
```

Verify:
```bash
systemctl --user status pipewire
systemctl --user status pipewire-pulse
```

Both must be **active (running)**.

---

## 3. HiFiBerry DAC verification

Ensure the DAC is detected:

```bash
aplay -l
```

You must see:
- **HiFiBerry DAC+ DSP** (or your exact model)

PipeWire check:

```bash
wpctl status
```

You must see the HiFiBerry listed as a **Sink**.

---

## 4. Enable Pulse TCP listener (receiver side)

Create configuration directory:

```bash
mkdir -p ~/.config/pipewire/pipewire-pulse.conf.d
```

Create file:

```bash
nvim ~/.config/pipewire/pipewire-pulse.conf.d/50-tcp.conf
```

**Use exactly this**:

```ini
pulse.properties = {
  server.address = [
    "unix:native"
    "tcp:0.0.0.0:4713"
  ]
}
```

Restart Pulse layer:

```bash
systemctl --user restart pipewire-pulse
```

Verify listener:

```bash
ss -ltnp | grep 4713
```

Expected:
```
LISTEN ... 0.0.0.0:4713 ... pipewire-pulse
```

If this is not present, **stop and fix before proceeding**.

---

## 5. Install and enable Tailscale (Pi)

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh
```

Verify:

```bash
tailscale status
tailscale ip -4
```

You should see the device named **pipe** and a `100.x.y.z` IP.

---

## 6. Verify Tailscale SSH (critical safety step)

From another device:

```bash
tailscale ssh airflower@pipe
```

Do **not** proceed until this works.

---

## 7. Disable classic SSH (only after Step 6 works)

```bash
sudo systemctl disable --now ssh
```

Verify:

```bash
ss -ltn | grep :22
```

Expected: **no output**.

---

## 8. Client-side requirements (audio sender)

On the client machine:

- PipeWire running
- **pipewire-pulse installed**
- `pactl` available

Verify:

```bash
pactl info
```

---

## 9. Create audio tunnel (client side)

On the **client machine** (not the Pi):

```bash
pactl load-module module-tunnel-sink \
  server=tcp:pipe:4713 \
  sink_name=pipe_audio
```

Verify:

```bash
pactl list short sinks
```

Set as default (optional):

```bash
pactl set-default-sink pipe_audio
```

Audio should now play through the HiFiBerry.

---

## 10. Recovery rules (important)

If audio stops working:

1. **Check listener on Pi**
   ```bash
   ss -ltnp | grep 4713
   ```

2. **Check pipewire-pulse is running**
   ```bash
   systemctl --user status pipewire-pulse
   ```

3. **Recreate tunnel on client**
   ```bash
   pactl unload-module module-tunnel-sink
   pactl load-module module-tunnel-sink server=tcp:pipe:4713 sink_name=pipe_audio
   ```

Never change protocols while troubleshooting.

---

## 11. Explicit things NOT to do

- ❌ Do not bind PipeWire to `tailscale0`
- ❌ Do not mix native PipeWire and PulseAudio tunnels
- ❌ Do not edit multiple audio configs at once
- ❌ Do not disable SSH before Tailscale SSH works

---

## 12. Final state checklist

- SSH only via Tailscale
- No LAN-exposed SSH
- One audio protocol (Pulse)
- One TCP port (4713)
- Stable, boring, reproducible

---

**This setup is intentionally conservative.**
It favors reliability over cleverness and should survive reboots, updates, and redeployments without surprises.

