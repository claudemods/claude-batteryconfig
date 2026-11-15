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
