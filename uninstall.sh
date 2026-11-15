#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 claudemods
set -u
kpackagetool6 -t Plasma/Applet -r org.claudemods.batteryconfig 2>/dev/null
rm -f "$HOME/.local/share/icons/hicolor/scalable/apps/claude-batteryconfig.svg"

if [[ -d /run/systemd/system ]]; then
    sudo systemctl disable --now claude-batteryconfig.service 2>/dev/null
elif command -v rc-service >/dev/null 2>&1; then
    sudo rc-service claude-batteryconfig stop 2>/dev/null
    sudo rc-update del claude-batteryconfig default 2>/dev/null
fi

sudo rm -f /usr/local/bin/claude-batteryconfig-helper \
    /usr/share/polkit-1/actions/org.claudemods.batteryconfig.policy \
    /etc/systemd/system/claude-batteryconfig.service \
    /etc/init.d/claude-batteryconfig \
    /etc/polkit-1/rules.d/49-claude-batteryconfig.rules \
    /etc/claude-batteryconfig.conf \
    /var/lib/claude-batteryconfig/phase \
    /etc/modules-load.d/claude-batteryconfig.conf \
    /run/claude-batteryconfig.state
[[ -d /run/systemd/system ]] && sudo systemctl daemon-reload
echo "Removed. Thresholds already written to the firmware stay until reboot/reset."
echo "The acpi_call package and any line you added to /etc/modules are left in place."
