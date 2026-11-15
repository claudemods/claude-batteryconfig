#!/usr/bin/env bash
# claude-batteryconfig v1.0 installer (run as your normal user; sudo is used where needed)
#   ./install.sh                 install / upgrade
#   ./install.sh --passwordless  also let the 'wheel' group apply without a password prompt
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)

echo "==> Installing root helper, polkit policy and restore service"
sudo install -Dm755 "$here/helper/claude-batteryconfig-helper" /usr/local/bin/claude-batteryconfig-helper
sudo install -Dm644 "$here/helper/org.claudemods.batteryconfig.policy" /usr/share/polkit-1/actions/org.claudemods.batteryconfig.policy
sudo install -Dm644 "$here/helper/claude-batteryconfig.service" /etc/systemd/system/claude-batteryconfig.service
sudo systemctl daemon-reload
sudo systemctl enable claude-batteryconfig.service

if [[ ${1:-} == --passwordless ]]; then
    echo "==> Enabling passwordless apply for group 'wheel'"
    sudo tee /etc/polkit-1/rules.d/49-claude-batteryconfig.rules >/dev/null <<'EOF'
polkit.addRule(function(action, subject) {
    if (action.id == "org.claudemods.batteryconfig.set" && subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF
fi

echo "==> Checking Legion Go S firmware access"
if sudo claude-batteryconfig-helper diag 2>/dev/null | grep -q 'legion go s: yes' \
   && ! ls /sys/class/power_supply/*/charge_control_end_threshold >/dev/null 2>&1; then
    if [[ ! -e /proc/acpi/call ]]; then
        echo "Legion Go S has no kernel charge-limit interface; the widget needs the acpi_call module."
        if command -v pacman >/dev/null; then
            read -r -p "Install acpi_call-dkms with pacman now? [y/N] " ans
            if [[ ${ans,,} == y ]]; then
                sudo pacman -S --needed acpi_call-dkms || echo "pacman failed; install acpi_call manually."
            fi
        fi
        sudo modprobe acpi_call 2>/dev/null || echo "acpi_call not loadable yet (kernel headers may be missing, or reboot)."
    fi
    echo acpi_call | sudo tee /etc/modules-load.d/claude-batteryconfig.conf >/dev/null
fi

echo "==> Installing icon"
install -Dm644 "$here/plasmoid/contents/icons/claude-batteryconfig.svg" \
    "$HOME/.local/share/icons/hicolor/scalable/apps/claude-batteryconfig.svg"
gtk-update-icon-cache -q -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo "==> Installing Plasma widget"
kpackagetool6 -t Plasma/Applet -u "$here/plasmoid" 2>/dev/null \
    || kpackagetool6 -t Plasma/Applet -i "$here/plasmoid"

echo
echo "Done. Restart the shell once:  systemctl --user restart plasma-plasmashell"
echo "Then right-click the panel > Add Widgets > 'claude-batteryconfig'."
