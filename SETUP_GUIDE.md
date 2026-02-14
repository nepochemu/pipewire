# pwlink Deployment Guide

This guide is for a fresh machine and a Codex agent.

## Sender (Your Main Linux Machine)

### 1) Install dependencies
Ensure PipeWire-Pulse and Avahi tools are available.

```bash
# NixOS/Home Manager example:
# add `pulseaudio` and `avahi` packages
```

### 2) Install pwlink

```bash
cd ~/dev/pipewire
nix profile install .#pwlink
```

### 3) Verify

```bash
pwlink selftest
pwlink list
```

## Receiver (Raspberry Pi OS)

### 1) Install packages

```bash
sudo apt update
sudo apt install -y pipewire pipewire-audio-client-libraries pipewire-pulse wireplumber avahi-daemon pulseaudio-utils
```

### 2) Enable user services

```bash
systemctl --user enable --now pipewire pipewire-pulse wireplumber
```

### 3) Enable TCP on port 4713 (persistent)

```bash
mkdir -p ~/.config/pipewire/pipewire-pulse.conf.d
cat <<'CONF' > ~/.config/pipewire/pipewire-pulse.conf.d/tcp.conf
pulse.cmd = [
  { cmd = "load-module" args = "module-native-protocol-tcp listen=0.0.0.0 port=4713 auth-anonymous=1" }
]
CONF

systemctl --user restart pipewire pipewire-pulse wireplumber
```

### 4) Enable mDNS (optional)

```bash
sudo systemctl enable --now avahi-daemon
```

### 5) Verify receiver is listening

```bash
ss -lntp | rg 4713
```

### 6) HiFiBerry DAC+DSP (if installed on receiver)

```bash
# Enable HiFiBerry overlay and disable onboard audio
sudo cp /boot/firmware/config.txt /boot/firmware/config.txt.bak.$(date +%Y%m%d%H%M%S)
sudo sed -i 's/^[[:space:]]*dtparam=audio=on/dtparam=audio=off/' /boot/firmware/config.txt
rg -q '^[[:space:]]*dtoverlay=hifiberry-dacplusdsp' /boot/firmware/config.txt || \
  echo 'dtoverlay=hifiberry-dacplusdsp' | sudo tee -a /boot/firmware/config.txt >/dev/null
sudo reboot
```

After reboot (headless setup), ensure user services persist and output is unmuted:

```bash
sudo loginctl enable-linger "$USER"
sudo systemctl start "user@$(id -u).service"

systemctl --user enable --now pipewire pipewire-pulse wireplumber
PULSE_SERVER=tcp:127.0.0.1:4713 pactl list short sinks
PULSE_SERVER=tcp:127.0.0.1:4713 pactl set-sink-volume @DEFAULT_SINK@ 100%
```

If playback is still quiet while sink is 100%, raise per-stream volume:

```bash
PULSE_SERVER=tcp:127.0.0.1:4713 pactl list short sink-inputs | awk '{print $1}' | \
  xargs -r -I{} pactl set-sink-input-volume {} 100%
```

## Connect From Sender

```bash
# If mDNS works
pwlink connect pipe

# Or manual IP
pwlink connect 192.168.x.x:4713
```

## Troubleshooting

- `pwlink list` is empty: mDNS not visible; connect by IP.
- `Connection refused`: receiver not listening on 4713.
- After receiver restart: re-run `pwlink connect`.
