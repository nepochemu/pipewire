# pwlink Notes

## What Was Built
- New project in `~/dev/pipewire` based on PipeWire-Pulse over TCP.
- CLI name: `pwlink`.
- Discovery: mDNS `_pulse._tcp` / `_pulse-native._tcp` with cached endpoints; manual host:port supported.
- Fallback: `pwlink connect <name>` tries `<name>.local:4713` automatically.
- Saved default endpoint in `~/.config/pwlink/config.json`.
- Uses `pactl module-tunnel-sink` to create a remote sink.

## Sender Commands (Local Machine)
- `pwlink list` — list discovered endpoints
- `pwlink connect <name|host:port>` — connect to remote
- `pwlink connect` — reconnect saved default
- `pwlink status` — show current default sink
- `pwlink disconnect` — unload tunnel and return to local sink
- `pwlink selftest` — check required tools

## Receiver Assumptions (Raspberry Pi OS)
- PipeWire + pipewire-pulse installed and running.
- TCP server listening on port 4713 (IPv4/IPv6).
- Avahi is running for mDNS (optional but recommended).

## Key Behavior
- `Connection refused` means TCP 4713 is not listening on receiver.
- If mDNS is empty, manual `host:port` works.
- After receiver restarts, run `pwlink connect` again on sender.

