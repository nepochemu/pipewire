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
sudo apt install -y pipewire pipewire-audio-client-libraries pipewire-pulse avahi-daemon
```

### 2) Enable user services

```bash
systemctl --user enable --now pipewire pipewire-pulse wireplumber
```

### 3) Enable TCP on port 4713 (persistent)

```bash
mkdir -p ~/.config/pipewire/pipewire-pulse.conf.d
cat <<'CONF' > ~/.config/pipewire/pipewire-pulse.conf.d/tcp.conf
context.modules = [
  { name = libpipewire-module-protocol-pulse
    args = {
      server.address = [ "unix:native" "tcp:4713" ]
      auth.anonymous = true
    }
  }
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

