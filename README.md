# claude-batteryconfig v1.0

KDE Plasma 6 panel widget for **CachyOS on the Lenovo Legion Go S** that sets when
the battery **starts charging** and when it **stops charging**.

- Sliders and editable number boxes for both thresholds
- Live battery bar showing the charge window
- Presets: Longevity 40-60, Balanced 70-80, Travel 95-100, No limit
- Optional "keep after reboot and resume"
- Admin rights are requested only when you press **Apply** (polkit prompt)

## Requirements

- KDE Plasma 6 (default on CachyOS KDE), `kpackagetool6`, `polkit`, `systemd`
- A kernel that exposes battery charge control in sysfs (see "Legion Go S support")

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
   Start is always lower than stop; the stop limit has a 20% floor.
3. Optionally tick **Keep after reboot and resume**.
4. Press **Apply (admin)** and authenticate.

Hover the icon for a summary of the current limits and battery state.

## Legion Go S support

Charge limiting for the Go S on mainline Linux comes from the `lenovo-wmi-other`
"WMI battery charge limiting" patch series. It exposes a **stop** limit
(`charge_control_end_threshold`) and, to my knowledge, no start threshold. The
helper picks a backend automatically:

| Backend | When | How it works |
|---|---|---|
| native | kernel has both `charge_control_start_threshold` and `charge_control_end_threshold` | values written directly |
| emulated start | kernel has only `charge_control_end_threshold` | `claude-batteryconfig.service` checks every 20 s, holds the stop limit at START while idle and raises it to END when the battery falls below START |

Notes on the emulated backend:
- Settings are always saved when START > 0, because the service needs them.
- Set START to 0 for a plain stop limit with no background loop.
- If the service is stopped, the widget warns that the start threshold is not enforced.

If neither file exists, the widget reports that your kernel lacks charge limiting
and nothing can be written. Try a newer `linux-cachyos` kernel.

**Not verified on real Legion Go S hardware.** The firmware may reject some values;
the helper then reports an error and leaves the previous setting.

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
| `/etc/polkit-1/rules.d/49-claude-batteryconfig.rules` | only with `--passwordless` |

## Security

Only the helper runs as root. It accepts just `set START END [persist|nopersist]`,
validates `0 <= START < END <= 100`, parses the config file instead of sourcing it,
and writes only to the battery's `charge_control_*` files.

## Project layout

```
plasmoid/      widget (metadata.json, contents/ui, contents/icons)
helper/        root helper, polkit policy, systemd unit
install.sh  uninstall.sh
```
