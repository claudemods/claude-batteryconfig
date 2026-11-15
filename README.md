<p align="center">
<img src="https://i.postimg.cc/JhMRf2RZ/claudemods-03-17-2025.gif">

<div align="center">

  <a href="https://www.linux.org" target="_blank"><img src="https://img.shields.io/badge/OS-Linux-e06c75?style=for-the-badge&logo=linux" /></a>
  <a href="https://www.qt.io" target="_blank"><img src="https://img.shields.io/badge/GUI-Qt6-41CD52?style=for-the-badge&logo=qt&logoColor=white" /></a>
  <a href="https://kde.org/plasma-desktop/" target="_blank"><img src="https://img.shields.io/badge/DESKTOP-KDE_Plasma-1d99f3?style=for-the-badge&logo=kde&logoColor=white" /></a>

  <a href="https://archlinux.org" target="_blank"><img src="https://img.shields.io/badge/DISTRO-Arch-56b6c2?style=for-the-badge&logo=arch-linux" /></a>
  <a href="https://ubuntu.com/" target="_blank"><img src="https://img.shields.io/badge/DISTRO-Ubuntu-E95420?style=for-the-badge&logo=Ubuntu" /></a>
  <a href="https://www.debian.org" target="_blank"><img src="https://img.shields.io/badge/DISTRO-Debian-CE0058?style=for-the-badge&logo=Debian" /></a>
  <a href="https://getfedora.org" target="_blank"><img src="https://img.shields.io/badge/DISTRO-Fedora-51A2DA?style=for-the-badge&logo=fedora" /></a>
  <a href="https://www.opensuse.org" target="_blank"><img src="https://img.shields.io/badge/DISTRO-openSUSE-73BA25?style=for-the-badge&logo=opensuse" /></a>
  <a href="https://linuxmint.com" target="_blank"><img src="https://img.shields.io/badge/DISTRO-Linux_Mint-87CF3E?style=for-the-badge&logo=linuxmint&logoColor=white" /></a>
  <a href="https://alpinelinux.org" target="_blank"><img src="https://img.shields.io/badge/DISTRO-Alpine-0D597F?style=for-the-badge&logo=alpine-linux" /></a>
  <a href="https://www.gentoo.org" target="_blank"><img src="https://img.shields.io/badge/DISTRO-Gentoo-54487A?style=for-the-badge&logo=gentoo" /></a>

  <a href="https://claude.com/claude-code" target="_blank">
    <img src="https://img.shields.io/badge/Built_Using-Claude_Code-D97757?style=for-the-badge&logo=claude&logoColor=white" alt="Built Using Claude Code">
  </a>

  ## [ Guide ](#guide)

  ## [ Support Me ](https://www.paypal.com/paypalme/claudemods?country.x=GB&locale)

</div>

<div align="center">

  [![Ko-Fi](https://img.shields.io/badge/Ko--fi-F16061?style=for-the-badge&label=claudemods&color=3399FF&Linux&logo=ko-fi&logoColor=white)](https://ko-fi.com/claudemods)
  [![GitHub Sponsors](https://img.shields.io/badge/sponsor-30363D?style=for-the-badge&label=claudemods&color=A836FF&logo=GitHub-Sponsors&logoColor=#white)](https://github.com/sponsors/claudemods)

</div>

# claude-batteryconfig v1.0

KDE Plasma 6 panel widget for the **Lenovo Legion Go S** that sets when the battery
**starts charging** and when it **stops charging**.

**Tested and working** on a Legion Go S running **CachyOS** with KDE Plasma 6
(kernel `7.3.4-1-cachyos`): limits apply from the widget and the battery obeys them.

- Sliders and editable number boxes for both thresholds
- Live battery bar showing the charge window
- Presets shown as "resume below → stop at": Lifespan 30→80, Daily 20→90, Full 20→100, No limit
- Optional "keep after reboot and resume"
- Admin rights are requested only when you press **Apply** (polkit prompt)

<p align="center">
  <img src="docs/screenshot.svg" alt="claude-batteryconfig popup showing the battery bar, start and stop sliders, presets and Apply button" width="360">
</p>

<a id="guide"></a>

## Requirements

- KDE Plasma 6, `kpackagetool6`, `polkit`, `systemd`
- A kernel with battery charge control (`charge_control_end_threshold`), or the
  `acpi_call` fallback (see "Other distributions and kernels")

## Install

```bash
chmod +x install.sh uninstall.sh
./install.sh
systemctl --user restart plasma-plasmashell
```

Then right-click the panel, choose **Add Widgets**, and add **claude-batteryconfig**.

Optional: `./install.sh --passwordless` lets members of the `wheel` or `sudo` group apply
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
main method and the one tested on a real Go S:

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

## Other distributions and kernels (acpi_call)

If your kernel has no charge-control interface, the helper talks to the Lenovo firmware
directly through the **`acpi_call`** kernel module (method `\_SB.GZFD.WMAE`, feature
`0x03010001`, the same one Handheld Daemon uses). It should therefore work on any
distribution and kernel where that module is available, provided KDE Plasma 6 is
installed. **Only CachyOS has been tested.**

`install.sh` detects your package manager and init system, and on a Legion Go S without
kernel charge control it sets `acpi_call` up for you (asking before installing packages;
`--yes` skips the questions). If a package install fails it builds the module from source.

| Distribution | What `install.sh` does | Package listing checked |
|---|---|---|
| **Arch / CachyOS** (tested) | `pacman -S dkms <running-kernel>-headers acpi_call-dkms` | yes, `extra` repository |
| Debian | `apt install dkms linux-headers-$(uname -r) acpi-call-dkms` | yes, Debian package tracker |
| Ubuntu | same as Debian (`universe`) | yes, packages.ubuntu.com |
| Linux Mint | same as Ubuntu (uses Ubuntu's repositories) | inherited from Ubuntu |
| Gentoo | `emerge sys-power/acpi_call` | yes, packages.gentoo.org |
| Alpine | `apk add akms linux-<flavor>-dev acpi_call-src` (`community` repository) | yes, pkgs.alpinelinux.org |
| Fedora | no official package: offers the unofficial COPR `cr7pt0gr4ph7/acpi_call`, else builds from source | COPR only, unofficial |
| openSUSE | no official package confirmed: installs `kernel-<flavor>-devel` and builds from source | not verified |
| anything else | builds from <https://github.com/nix-community/acpi_call> | n/a |

Notes:
- **Init systems:** systemd and OpenRC (Alpine, Gentoo with OpenRC) are supported. On
  OpenRC the service is installed with `rc-update`; limits are not re-applied after
  suspend there, only at boot. With neither, the widget still works but nothing is
  restored at boot and the start threshold cannot be enforced.
- **Source builds** are not rebuilt on kernel updates; re-run `./install.sh --acpi-call`
  after one. Package installs (DKMS/AKMS) rebuild automatically.
- **Boot loading:** `acpi_call` is loaded at boot through `/etc/modules-load.d/` (or
  `/etc/modules` on Alpine).
- **Passwordless apply** (`--passwordless`) covers the `wheel` and `sudo` groups.
- Do not run this together with Handheld Daemon's charge-limit setting: they will fight.
- If the firmware rejects a value, the helper reports an error and keeps the previous setting.
- The firmware-switch fallback and the non-Arch install paths have not been tested on hardware.
The firmware-switch fallback has not been tested on hardware.

## Troubleshooting

```bash
claude-batteryconfig-helper diag      # kernel, product, power_supply, lenovo modules
claude-batteryconfig-helper status    # what the widget reads
ls /sys/class/power_supply/*/charge_control_*
systemctl status claude-batteryconfig.service   # OpenRC: rc-service claude-batteryconfig status
```

Include the `diag` output when reporting a problem.

## What gets installed

| Path | Purpose |
|---|---|
| `~/.local/share/plasma/plasmoids/org.claudemods.batteryconfig/` | the widget |
| `~/.local/share/icons/hicolor/scalable/apps/claude-batteryconfig.svg` | icon |
| `/usr/local/bin/claude-batteryconfig-helper` | root helper (`status`, `set`, `daemon`, `diag`) |
| `/usr/share/polkit-1/actions/org.claudemods.batteryconfig.policy` | polkit action for the helper |
| `/etc/systemd/system/claude-batteryconfig.service` (or `/etc/init.d/claude-batteryconfig` on OpenRC) | restores limits at boot and after resume; runs the emulation loop |
| `/etc/claude-batteryconfig.conf` | saved `START` / `END` |
| `/var/lib/claude-batteryconfig/phase` | whether the service is currently charging or letting the battery discharge |
| `/var/lib/claude-batteryconfig/phase` | whether the service is currently charging or letting the battery discharge |
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
