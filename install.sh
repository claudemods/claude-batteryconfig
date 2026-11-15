#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 claudemods
# claude-batteryconfig v1.0 installer. Run as your normal user; sudo is used where needed.
#
#   ./install.sh                 install / upgrade
#   ./install.sh --passwordless  let groups wheel/sudo apply without a password prompt
#   ./install.sh --yes           do not ask before installing packages
#   ./install.sh --acpi-call     force the acpi_call setup (normally only done on a Legion Go S
#                                whose kernel has no charge-control interface)
#
# Supports Arch/CachyOS, Debian/Ubuntu/Mint, Fedora, openSUSE, Gentoo and Alpine,
# on systemd or OpenRC. Anything else: acpi_call is built from source.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)

PASSWORDLESS=0; ASSUME_YES=0; FORCE_ACPI=0
for a in "$@"; do
    case $a in
        --passwordless) PASSWORDLESS=1 ;;
        --yes|-y)       ASSUME_YES=1 ;;
        --acpi-call)    FORCE_ACPI=1 ;;
        -h|--help)      sed -n 5,13p "$0"; exit 0 ;;
        *) echo "Unknown option: $a" >&2; exit 2 ;;
    esac
done

# ------------------------------------------------------------ environment
pm=""
for c in pacman apt-get dnf zypper emerge apk; do
    command -v "$c" >/dev/null 2>&1 && { pm=$c; break; }
done
if [[ -d /run/systemd/system ]]; then init=systemd
elif command -v rc-service >/dev/null 2>&1; then init=openrc
else init=none; fi
# shellcheck disable=SC1091
. /etc/os-release 2>/dev/null || true
echo "==> ${PRETTY_NAME:-Linux}: package manager=${pm:-unknown}, init=$init, kernel=$(uname -r)"

command -v kpackagetool6 >/dev/null 2>&1 \
    || { echo "kpackagetool6 not found. This widget needs KDE Plasma 6." >&2; exit 1; }
command -v pkexec >/dev/null 2>&1 \
    || { echo "pkexec not found. Install polkit first." >&2; exit 1; }

confirm() { # prompt
    (( ASSUME_YES )) && return 0
    local ans; read -r -p "$1 [y/N] " ans
    [[ ${ans,,} == y ]]
}

pm_install() {
    case $pm in
        pacman) sudo pacman -S --needed --noconfirm "$@" ;;
        apt-get) sudo apt-get install -y "$@" ;;
        dnf)    sudo dnf install -y "$@" ;;
        zypper) sudo zypper --non-interactive install "$@" ;;
        emerge) sudo emerge --noreplace "$@" ;;
        apk)    sudo apk add "$@" ;;
        *)      return 1 ;;
    esac
}

# ------------------------------------------------------------ acpi_call
build_acpi_call_from_source() {
    echo "Building acpi_call from source (needs git, make, gcc and the kernel headers)."
    for c in git make gcc; do
        command -v "$c" >/dev/null 2>&1 || { echo "Missing $c; install it and re-run." >&2; return 1; }
    done
    [[ -d /lib/modules/$(uname -r)/build ]] \
        || { echo "Kernel headers for $(uname -r) not found; install them and re-run." >&2; return 1; }
    local tmp; tmp=$(mktemp -d)
    git clone --depth 1 https://github.com/nix-community/acpi_call "$tmp/acpi_call"
    make -C "$tmp/acpi_call"
    sudo install -Dm644 "$tmp/acpi_call/acpi_call.ko" "/lib/modules/$(uname -r)/extra/acpi_call.ko"
    sudo depmod -a
    rm -rf "$tmp"
    echo "NOTE: a source build is not rebuilt on kernel updates; re-run ./install.sh --acpi-call after one."
}

# ask, install packages, and fall back to a source build if the package install fails
install_or_build() { # prompt pkgs...
    local prompt=$1 rc=0; shift
    confirm "$prompt" || { echo "Skipped. Install acpi_call yourself (see README)."; return 1; }
    pm_install "$@" || rc=$?
    (( rc == 0 )) || build_acpi_call_from_source
}

install_acpi_call() {
    [[ -e /proc/acpi/call ]] && return 0
    sudo modprobe acpi_call 2>/dev/null && return 0

    local flavor=${1:-}   # kernel flavour suffix, e.g. lts / default
    echo "==> Installing the acpi_call kernel module"
    case $pm in
        pacman)
            # headers for the *running* kernel (works for linux, linux-zen, linux-cachyos, ...)
            local base; base=$(cat "/usr/lib/modules/$(uname -r)/pkgbase" 2>/dev/null || echo linux)
            install_or_build "Install dkms, ${base}-headers and acpi_call-dkms with pacman?" \
                dkms "${base}-headers" acpi_call-dkms || return 1 ;;
        apt-get)
            sudo apt-get update || true
            install_or_build "Install dkms, linux-headers-$(uname -r) and acpi-call-dkms with apt?" \
                dkms "linux-headers-$(uname -r)" acpi-call-dkms || return 1 ;;
        dnf)
            echo "Fedora has no official acpi_call package; options are the community COPR or a source build."
            if confirm "Use the unofficial COPR cr7pt0gr4ph7/acpi_call (builds via akmods)?"; then
                pm_install dnf-plugins-core "kernel-devel-$(uname -r)" \
                    && sudo dnf copr enable -y cr7pt0gr4ph7/acpi_call \
                    && pm_install akmod-acpi_call \
                    && { sudo akmods --force >/dev/null 2>&1 || true; } \
                    || { echo "COPR route failed, trying a source build."; pm_install "kernel-devel-$(uname -r)" gcc make git || true; build_acpi_call_from_source; }
            else
                pm_install "kernel-devel-$(uname -r)" gcc make git || true
                build_acpi_call_from_source
            fi ;;
        zypper)
            echo "openSUSE: no confirmed official package, building from source."
            confirm "Install kernel-${flavor:-default}-devel, gcc, make and git with zypper?" \
                || { echo "Skipped. Install acpi_call yourself (see README)."; return 1; }
            pm_install "kernel-${flavor:-default}-devel" gcc make git || true
            build_acpi_call_from_source ;;
        emerge)
            install_or_build "Install sys-power/acpi_call with emerge?" sys-power/acpi_call || return 1 ;;
        apk)
            install_or_build "Install akms, linux-${flavor:-lts}-dev and acpi_call-src with apk?" \
                akms "linux-${flavor:-lts}-dev" acpi_call-src || return 1 ;;
        *)  build_acpi_call_from_source ;;
    esac
    sudo modprobe acpi_call 2>/dev/null \
        || echo "acpi_call is installed but not loadable yet (a reboot or matching kernel headers may be needed)."
}

load_acpi_call_at_boot() {
    case $init in
        systemd) echo acpi_call | sudo tee /etc/modules-load.d/claude-batteryconfig.conf >/dev/null ;;
        *)
            if [[ -f /etc/modules ]]; then      # Alpine
                grep -qx acpi_call /etc/modules || echo acpi_call | sudo tee -a /etc/modules >/dev/null
            else                                # Gentoo OpenRC
                echo acpi_call | sudo tee /etc/modules-load.d/claude-batteryconfig.conf >/dev/null
            fi ;;
    esac
}

# ------------------------------------------------------------ helper + policy + service
echo "==> Installing root helper and polkit policy"
sudo install -Dm755 "$here/helper/claude-batteryconfig-helper" /usr/local/bin/claude-batteryconfig-helper
sudo install -Dm644 "$here/helper/org.claudemods.batteryconfig.policy" \
    /usr/share/polkit-1/actions/org.claudemods.batteryconfig.policy

echo "==> Installing the restore/enforcement service ($init)"
case $init in
    systemd)
        sudo install -Dm644 "$here/helper/claude-batteryconfig.service" /etc/systemd/system/claude-batteryconfig.service
        sudo systemctl daemon-reload
        sudo systemctl enable claude-batteryconfig.service ;;
    openrc)
        sudo install -Dm755 "$here/helper/claude-batteryconfig.openrc" /etc/init.d/claude-batteryconfig
        sudo rc-update add claude-batteryconfig default ;;
    *)
        echo "WARNING: no systemd or OpenRC found. The widget works, but limits are not restored"
        echo "         at boot and the start threshold cannot be enforced." ;;
esac

if (( PASSWORDLESS )); then
    echo "==> Enabling passwordless apply for groups wheel and sudo"
    sudo tee /etc/polkit-1/rules.d/49-claude-batteryconfig.rules >/dev/null <<'EOF'
polkit.addRule(function(action, subject) {
    if (action.id == "org.claudemods.batteryconfig.set" &&
        (subject.isInGroup("wheel") || subject.isInGroup("sudo"))) {
        return polkit.Result.YES;
    }
});
EOF
fi

# ------------------------------------------------------------ Legion Go S firmware access
echo "==> Checking charge-control access"
helper=/usr/local/bin/claude-batteryconfig-helper
if (( ! FORCE_ACPI )) && "$helper" status 2>/dev/null | grep -q '^available=1'; then
    echo "Charge control is available; no extra setup needed."
    [[ -e /proc/acpi/call ]] && load_acpi_call_at_boot
elif (( FORCE_ACPI )) || "$helper" diag 2>/dev/null | grep -q 'legion go s: yes'; then
    flavor=$(uname -r | sed -n 's/.*-\([a-z][a-z]*\)$/\1/p')
    if install_acpi_call "$flavor"; then load_acpi_call_at_boot; else echo "acpi_call setup incomplete; see README."; fi
else
    echo "No kernel charge control and this is not a detected Legion Go S; nothing to set up."
    echo "Run claude-batteryconfig-helper diag if the widget reports no charge control."
fi

# ------------------------------------------------------------ icon + widget
echo "==> Installing icon"
install -Dm644 "$here/plasmoid/contents/icons/claude-batteryconfig.svg" \
    "$HOME/.local/share/icons/hicolor/scalable/apps/claude-batteryconfig.svg"
gtk-update-icon-cache -q -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo "==> Installing Plasma widget"
kpackagetool6 -t Plasma/Applet -u "$here/plasmoid" 2>/dev/null \
    || kpackagetool6 -t Plasma/Applet -i "$here/plasmoid"

echo
echo "Done. Restart the shell once:"
echo "  systemd:     systemctl --user restart plasma-plasmashell"
echo "  otherwise:   kquitapp6 plasmashell; kstart plasmashell"
echo "Then right-click the panel > Add Widgets > 'claude-batteryconfig'."
