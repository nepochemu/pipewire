

# Raspberry Pi “pipe” Audio Appliance Bootstrapper

Goal: provide a **single `curl | bash` installer** that bootstraps a headless Raspberry Pi OS Lite system into a stable audio receiver using a HiFiBerry HAT + PipeWire, and exposes a **listening port** (PipeWire native TCP). The installer must also optionally install and bring up **Tailscale**, and must support **interactive HAT selection**.

This is meant to be **portable + reproducible**: run the installer on a fresh system and it configures everything needed, then reboots. After reboot the Pi should have audio working and the listener up.

---

## Target environment

- OS: **Raspberry Pi OS Lite** (Debian-based)
- Hardware: Raspberry Pi 4 (but don’t hardcode Pi model)
- Audio: HiFiBerry HAT (selected interactively)
- User: assume a normal non-root user exists (default: `airflower`, but script should detect and/or prompt)
- Services: `pipewire`, `wireplumber`, (optionally `pipewire-pulse` installed for compatibility)
- Networking: DHCP; Wi-Fi/ethernet already configured by the user / Raspberry Pi Imager
- Headless: no GUI, no monitor

---

## Why we’re doing this

We built a working system manually:
- HiFiBerry DAC+ DSP detected as ALSA card `hw:2` (example)
- PipeWire running as user service (linger enabled)
- Listening port for audio set up
- Power issues fixed (undervoltage was a cause of glitches)
- Volume low due to PipeWire sink volume set to 0.40; fixed by setting to 1.0

We want to codify it into a repeatable installer.

---

## Deliverables

### 1) Single “curl | bash” installer
- Provide an install entrypoint script (e.g. `install.sh`) designed to be executed like:

  ```bash
  curl -fsSL https://raw.githubusercontent.com/<user>/<repo>/main/install.sh | bash


Must be non-interactive by default (sane defaults), but also support interactive mode.

2) Interactive HAT selection

Installer should prompt user to select a HiFiBerry overlay from a list.

Must support at least:

hifiberry-dacplusdsp (DAC+ DSP)

hifiberry-dacplus

hifiberry-dac

hifiberry-digi (if applicable)

After selection, update /boot/config.txt:

ensure dtoverlay=<selected>

remove dtparam=audio=on if present

optional: add any known-required params for chosen HAT (document)

Must be idempotent: re-running shouldn’t append duplicates.

3) Tailscale auto-install (optional)

Installer should offer:

Install Tailscale? (Y/n)

If yes:

install tailscale using official method (package repo/script)

enable and start tailscaled

optionally run tailscale up in a safe mode:

don’t force --ssh unless explicitly chosen

prompt if user wants Tailscale SSH and warn it requires ACL policy

Output the device’s tailscale IP(s) after successful connection.

4) PipeWire listening (receiver) setup

We want PipeWire native TCP (preferred) on a chosen port.

On the Pi, add config:

~/.config/pipewire/pipewire.conf.d/50-native-tcp.conf

Example content:

context.modules += [
  { name = libpipewire-module-protocol-native
    args = {
      listen = [
        { address = "tcp:4714" }
      ]
    }
  }
]


Ensure user services start at boot:

sudo loginctl enable-linger <user>

enable user units: pipewire, wireplumber

Provide an optional watchdog timer to restart PipeWire if listener port isn’t up (nice-to-have).

Provide a check command post-install:

ss -ltnp | grep 4714 should show listening.

5) Optional: pipewire-pulse TCP (legacy)

We previously used a Pulse port listener at 4713 (pipewire-pulse).
This is optional; native PipeWire is preferred.

If implemented, config file path:

~/.config/pipewire/pipewire-pulse.conf.d/50-tcp.conf

Example:

pulse.properties = {
  server.address = [
    "unix:native"
    "tcp:4713"
  ]
}

6) Safety and sanity checks

Run vcgencmd get_throttled (if available) and warn if undervoltage flags are non-zero.

Ensure locales aren’t broken (fresh minimal images sometimes miss en_US.UTF-8):

either configure locale or show clear guidance; avoid noisy login warnings.

Ensure volume on Pi isn’t attenuated:

set default sink to 1.0 using wpctl set-volume @DEFAULT_SINK@ 1.0 after PipeWire starts.

7) Documentation

Add clear usage examples:

default run

fully non-interactive (env vars)

interactive HAT selection

with/without tailscale

Add a troubleshooting section:

port not listening after reboot

check linger

restart pipewire

check undervoltage

check ALSA device busy, how to stop PipeWire to run speaker-test

Installer requirements / constraints

Must run on Raspberry Pi OS Lite with apt.

Must not require GUI tools.

Must be idempotent:

safe to re-run

avoid duplicate lines in /boot/config.txt

Must not assume rg exists; use grep.

Must prefer systemctl --user for PipeWire stack.

Must not break existing SSH access.

Must print a final summary showing:

chosen HAT overlay

listening port (4714 and/or 4713)

local IPs (hostname -I)

tailscale IP if enabled (tailscale ip -4)

commands to verify: ss -ltnp | grep <port>

Suggested repo layout
.
├── install.sh
├── README.md
└── lib/
    ├── common.sh          # helpers: log, prompt, detect user, idempotent edits
    ├── hats.sh            # list overlays + selection logic
    ├── tailscale.sh       # install + optional up
    ├── pipewire.sh        # config drop-ins + systemd user setup
    └── bootcfg.sh         # /boot/config.txt editing utilities

Acceptance tests (must pass)

After running:

curl -fsSL <raw install.sh> | bash
sudo reboot


On next boot, via SSH:

HiFiBerry ALSA device present:

aplay -l | grep -i hifiberry


PipeWire user services active:

systemctl --user status pipewire --no-pager
systemctl --user status wireplumber --no-pager


Listener port is up (native):

ss -ltnp | grep 4714


Linger is enabled:

loginctl show-user <user> -p Linger --no-pager


No undervoltage:

vcgencmd get_throttled
# expect throttled=0x0


Volume leading to low output is avoided:

wpctl status shows sink volume ~1.00 or can be set.

Notes / Context for agent

We observed micro-gaps when using PulseAudio tunneling (module-tunnel-sink) from client.

Pi audio path was clean; issues were client-side Pulse tunneling underruns.

For the receiver, focus on stable listening endpoints; client transport choice is out-of-scope here.

Listening port:

Primary: PipeWire native TCP on 4714

Optional/legacy: pipewire-pulse TCP on 4713

Non-interactive mode (proposed)

Allow environment variables:

PI_AUDIO_USER (default auto-detect)

PI_AUDIO_HAT (e.g. hifiberry-dacplusdsp)

PI_AUDIO_ENABLE_TAILSCALE=1|0

PI_AUDIO_TAILSCALE_UP=1|0

PI_AUDIO_LISTEN_PORT=4714

PI_AUDIO_ENABLE_PULSE_TCP=1|0

PI_AUDIO_PULSE_PORT=4713

If env vars are set, do not prompt.

Implementation tips

Editing /boot/config.txt safely:

remove existing matching dtoverlay=hifiberry-*

append only once

Ensure correct ownership of ~/.config files.

When enabling user services from a script, use:

sudo -u "$USER" systemctl --user ...

but note user systemd may need lingering; enable linger first.

If systemctl --user fails due to no session, consider:

sudo loginctl enable-linger "$USER"

and run user commands via machinectl shell or runuser carefully.

simplest: create files and enable units; they will start at boot due to linger.

Out of scope (explicitly)

Building client-side network sender

DSP/EQ configuration

Measuring/room correction

Setting up Wi-Fi itself (assumed done by user)


If you want, I can also add a short “Codex task list” section at the top (checkboxes) to make it even more agent-friendly.
::contentReference[oaicite:0]{index=0}
