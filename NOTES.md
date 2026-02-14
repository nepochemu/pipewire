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
- For HiFiBerry DAC+DSP boards: `dtparam=audio=off` and `dtoverlay=hifiberry-dacplusdsp` in `/boot/firmware/config.txt`, then reboot.
- For headless receivers: enable linger so user PipeWire services survive logout (`sudo loginctl enable-linger <user>`).

## Key Behavior
- `Connection refused` means TCP 4713 is not listening on receiver.
- If mDNS is empty, manual `host:port` works.
- After receiver restarts, run `pwlink connect` again on sender.
- Quiet playback can be stream attenuation: check `pactl list sink-inputs` on receiver and set sink-input volume to `100%`.

## Next Troubleshooting Steps (Sender, Low-Risk)
1) Increase latency:
   - `pwlink reset`
   - `pwlink connect pipe --latency-ms 300` (try `500` if needed)
2) Disable suspend-on-idle for pipewire-pulse (NixOS):
   - Set `module-suspend-on-idle = false` in `services.pipewire.pulse.extraConfig`
3) Increase PipeWire buffers (NixOS):
   - Set `default.clock.quantum`, `min-quantum`, `max-quantum` in `services.pipewire.extraConfig`
4) Disable Wi-Fi power saving (if on Wi‑Fi):
   - `sudo iw dev <iface> set power_save off`
