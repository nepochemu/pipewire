# pwlink

Simple CLI to route local audio to a remote PipeWire-Pulse server over TCP. Uses mDNS discovery with a fallback to cached endpoints or manual host:port.

## Requirements

- `pactl` (PipeWire-Pulse)
- `avahi-browse` (mDNS discovery)

## Usage

```bash
./pwlink list                     # List discovered endpoints
./pwlink connect "Living Room"    # Connect by name
./pwlink connect 192.168.1.10:4713 # Connect by host:port
./pwlink connect pipe             # Try pipe.local:4713
./pwlink connect                  # Connect saved default
./pwlink status                   # Show current default sink
./pwlink disconnect               # Disconnect and return to local sink
./pwlink selftest                 # Check required tools
```

## Receiver (Raspberry Pi OS)

On the receiver, enable PipeWire-Pulse TCP server and mDNS. Example commands:

```bash
# Enable TCP protocol (allow from LAN only)
pactl load-module module-native-protocol-tcp auth-anonymous=1

# Ensure avahi is running so the service is discoverable
systemctl --user status pipewire-pulse
systemctl status avahi-daemon
```

If you want this permanent on the receiver, configure PipeWire-Pulse to load `module-native-protocol-tcp` on startup.
