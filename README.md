# claude-batteryconfig v1.0

KDE Plasma 6 panel widget for **CachyOS on the Lenovo Legion Go S** that sets when
the battery **starts charging** and when it **stops charging**.

- Sliders and editable number boxes for both thresholds
- Live battery bar showing the charge window
- Presets shown as "resume below → stop at": Lifespan 30→80, Daily 20→90, Full 20→100, No limit
- Optional "keep after reboot and resume"
- Admin rights are requested only when you press **Apply** (polkit prompt)

<p align="center">
  <img src="docs/screenshot.svg" alt="claude-batteryconfig popup showing the battery bar, start and stop sliders, presets and Apply button" width="360">
</p>

## Requirements

- KDE Plasma 6 (default on CachyOS KDE), `kpackagetool6`, `polkit`, `systemd`
- A kernel with battery charge control (`charge_control_end_threshold`), or the
  `acpi_call` fallback (see "Legion Go S support")

## Install

```bash
chmod +x install.sh uninstall.sh
./install.sh
systemctl --user restart plasma-plasmashell
```

Then right-click the panel, choose **Add Widgets**, and add **claude-batteryconfig**.

Optional: `./install.sh --passwordless` lets members of the `wheel` group apply
without a password prompt (installs a polkit rule).

Uninstall with `./uninstall.sh`.

## Usage

1. Click the panel icon.
2. Set **Start charging below** and **Stop charging at** with the sliders or by typing a value.
   Start is always lower than stop: moving one slider past the other drags it along.
   The stop limit has a 20% floor.
3. Optionally tick **Keep after reboot and resume**.
4. Press **Apply (admin)** and authenticate.

Hover the icon for a summary of the current limits and battery state.

## Legion Go S support (CachyOS)

Recent CachyOS kernels expose the Go S charge limit through the standard battery
interface, `/sys/class/power_supply/BAT0/charge_control_end_threshold`. This is the
main method and the one seen working on a real Go S (kernel `7.3.4-1-cachyos`, a
10% → 80% limit applied successfully):

- **Stop limit:** written straight to `charge_control_end_threshold`.
- **Start threshold:** the kernel offers no start file, so `claude-batteryconfig.service`
  emulates it (checks every 15 s). While idle it holds the stop limit at your start
  value; when the battery falls below start it raises the limit to your stop value.
- Because the service enforces the start threshold, those settings are always saved
  (the "Keep after reboot" checkbox is locked on). Start 0 is a plain stop limit with
  no background service.
- If the service stops, the widget warns that the start threshold is not enforced.

The helper detects the method automatically and falls back if needed:

| Method | Detected when | Notes |
|---|---|---|
| **kernel stop limit** (main) | `charge_control_end_threshold` exists | start emulated by the service |
| kernel start + stop | `charge_control_start_threshold` also exists | both written directly, no service |
| firmware switch | a writable `charge_type(s)` file exists, or `acpi_call` is loaded on a Go S | only Standard / Long Life (80% cap): stop limit 80-100%, start below 80 acts as 80 |

### Fallback: acpi_call

Only needed if your kernel has none of the interfaces above. The helper then calls the
Lenovo firmware method (`\_SB.GZFD.WMAE`, feature `0x03010001`) through the `acpi_call`
module, the same method Handheld Daemon uses. `install.sh` offers to install it:

```bash
sudo pacman -S --needed acpi_call-dkms   # plus headers for your kernel, e.g. linux-cachyos-headers
sudo modprobe acpi_call
```

It is loaded at boot through `/etc/modules-load.d/claude-batteryconfig.conf`.

Do not run this together with Handheld Daemon's charge-limit setting: they will fight.
If the firmware rejects a value, the helper reports an error and keeps the previous setting.
The firmware-switch fallback has not been tested on hardware.

## Troubleshooting

```bash
claude-batteryconfig-helper diag      # kernel, product, power_supply, lenovo modules
claude-batteryconfig-helper status    # what the widget reads
ls /sys/class/power_supply/*/charge_control_*
systemctl status claude-batteryconfig.service
```

Include the `diag` output when reporting a problem.

## What gets installed

| Path | Purpose |
|---|---|
| `~/.local/share/plasma/plasmoids/org.claudemods.batteryconfig/` | the widget |
| `~/.local/share/icons/hicolor/scalable/apps/claude-batteryconfig.svg` | icon |
| `/usr/local/bin/claude-batteryconfig-helper` | root helper (`status`, `set`, `daemon`, `diag`) |
| `/usr/share/polkit-1/actions/org.claudemods.batteryconfig.policy` | polkit action for the helper |
| `/etc/systemd/system/claude-batteryconfig.service` | restores limits at boot and after resume; runs the emulation loop |
| `/etc/claude-batteryconfig.conf` | saved `START` / `END` |
| `/etc/modules-load.d/claude-batteryconfig.conf` | loads `acpi_call` (fallback only) |
| `/etc/polkit-1/rules.d/49-claude-batteryconfig.rules` | only with `--passwordless` |

## Security

Only the helper runs as root. It accepts just `set START END [persist|nopersist]`,
validates `0 <= START < END <= 100`, parses the config file instead of sourcing it,
and writes only to the battery's charge-control files (`charge_control_*`,
`charge_type`) or, in the fallback, calls the one Lenovo ACPI method.

## Project layout

```
plasmoid/      widget (metadata.json, contents/ui, contents/icons)
helper/        root helper, polkit policy, systemd unit
docs/          screenshot
install.sh  uninstall.sh
```

## License

claude-batteryconfig is free software, licensed under the
[GNU General Public License v3.0 or later](LICENSE) (`GPL-3.0-or-later`).
It comes with ABSOLUTELY NO WARRANTY. It writes to battery firmware controls, so use it at your own risk.
