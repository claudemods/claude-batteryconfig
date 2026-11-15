#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 claudemods
set -u
kpackagetool6 -t Plasma/Applet -r org.claudemods.batteryconfig 2>/dev/null
rm -f "$HOME/.local/share/icons/hicolor/scalable/apps/claude-batteryconfig.svg"
sudo systemctl disable claude-batteryconfig.service 2>/dev/null
sudo rm -f /usr/local/bin/claude-batteryconfig-helper \
    /usr/share/polkit-1/actions/org.claudemods.batteryconfig.policy \
    /etc/systemd/system/claude-batteryconfig.service \
    /etc/polkit-1/rules.d/49-claude-batteryconfig.rules \
    /etc/claude-batteryconfig.conf /etc/modules-load.d/claude-batteryconfig.conf
sudo systemctl daemon-reload
echo "Removed. Thresholds already written to the firmware stay until reboot/reset."
