import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property string version: "1.0"
    readonly property string helper: "/usr/local/bin/claude-batteryconfig-helper"
    readonly property int endMin: 20          // safety floor for the stop threshold
    readonly property url iconUrl: Qt.resolvedUrl("../icons/claude-batteryconfig.svg")

    // ---- state reported by the helper ----
    property bool loaded: false
    property bool helperMissing: false
    property bool available: false
    property bool startSupported: false
    property string problem: ""
    property string batteryName: ""
    property string batteryState: ""
    property int capacity: 0
    property int curStart: 0
    property int curEnd: 100
    property bool persisted: false

    // ---- user edits ----
    property int pendingStart: 0
    property int pendingEnd: 100
    property bool persist: true
    property bool busy: false
    property string message: ""
    property bool messageIsError: false

    property bool startEmulated: false
    property bool daemonActive: true
    property string backend: "native"
    property int minEnd: 0
    // does this combination need the background service? then it must be saved
    readonly property bool needsLoop: backend === "end" ? pendingStart > 0
        : backend === "type" ? !(pendingEnd <= 80 || (pendingEnd >= 100 && pendingStart === 0))
        : false
    readonly property bool effectivePersist: persist || needsLoop

    readonly property bool dirty: available
        && (pendingEnd !== curEnd || (startSupported && pendingStart !== curStart))

    Plasmoid.icon: "claude-batteryconfig"
    toolTipMainText: "claude-batteryconfig v" + version
    toolTipSubText: !loaded ? "Reading battery…"
        : !available ? (helperMissing ? "Helper not installed" : problem)
        : (startSupported ? "Charge from " + curStart + "% to " + curEnd + "%"
                          : "Stop charging at " + curEnd + "%")
          + " · battery " + capacity + "% (" + batteryState + ")"

    preferredRepresentation: compactRepresentation

    // ---------------------------------------------------------------- commands
    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            disconnectSource(source)
            root.handleResult(source, data["stdout"] || "", data["stderr"] || "", data["exit code"])
        }
        function run(cmd) { connectSource(cmd) }
    }

    function refresh() {
        exec.run(helper + " status")
    }

    function apply() {
        if (busy || !dirty)
            return
        busy = true
        message = ""
        var s = startSupported ? pendingStart : curStart
        exec.run("pkexec " + helper + " set " + s + " " + pendingEnd + " " + (effectivePersist ? "persist" : "nopersist"))
    }

    function handleResult(source, out, err, code) {
        if (source.indexOf(" set ") >= 0) {
            busy = false
            if (code === 0) {
                message = "Applied: " + (startSupported ? pendingStart + "% → " : "stop at ") + pendingEnd + "%"
                messageIsError = false
                refresh()
            } else {
                var e = err.trim() || out.trim()
                if (code === 126 || code === 127)
                    e = e || "Authentication cancelled or not authorised."
                message = e || ("Failed (exit " + code + ")")
                messageIsError = true
            }
            return
        }
        parseStatus(out, code)
    }

    function parseStatus(out, code) {
        loaded = true
        if (code === 127 || code === 126 && out.trim() === "") {
            helperMissing = true
            available = false
            problem = "Helper not installed. Run install.sh."
            return
        }
        helperMissing = false
        var kv = {}
        out.split("\n").forEach(function (l) {
            var i = l.indexOf("=")
            if (i > 0) kv[l.substring(0, i)] = l.substring(i + 1).trim()
        })
        var wasDirty = dirty
        available = kv["available"] === "1"
        problem = kv["problem"] || ""
        if (!available)
            return
        batteryName = kv["battery"] || ""
        batteryState = kv["state"] || ""
        capacity = parseInt(kv["capacity"]) || 0
        startSupported = kv["start_supported"] === "1"
        curStart = startSupported ? (parseInt(kv["start"]) || 0) : 0
        curEnd = parseInt(kv["end"]) || 100
        persisted = kv["persisted"] === "1"
        startEmulated = kv["start_mode"] === "emulated"
        backend = kv["backend"] || "native"
        minEnd = parseInt(kv["min_end"]) || 0
        daemonActive = (kv["daemon"] || "active") === "active"
        if (!wasDirty) {
            pendingStart = curStart
            pendingEnd = curEnd
        }
    }

    function setPreset(s, e) {
        pendingEnd = Math.max(e, minEnd)
        pendingStart = Math.min(s, pendingEnd - 1)
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!root.busy) root.refresh()
    }

    // -------------------------------------------------------- compact (panel)
    compactRepresentation: MouseArea {
        id: compact
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: root.expanded = !root.expanded

        Kirigami.Icon {
            anchors.fill: parent
            source: root.iconUrl
            active: compact.containsMouse
        }
    }

    // ------------------------------------------------------------ popup
    fullRepresentation: Item {
        id: popup
        Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumHeight: Kirigami.Units.gridUnit * 18
        Layout.preferredHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            // header
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                Kirigami.Icon {
                    source: root.iconUrl
                    implicitWidth: Kirigami.Units.iconSizes.large
                    implicitHeight: Kirigami.Units.iconSizes.large
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Kirigami.Heading {
                        level: 3
                        text: "claude-batteryconfig"
                    }
                    PlasmaComponents.Label {
                        text: "v" + root.version + (root.batteryName ? " · " + root.batteryName : "")
                        opacity: 0.7
                        font: Kirigami.Theme.smallFont
                    }
                }
                PlasmaComponents.ToolButton {
                    icon.name: "view-refresh"
                    onClicked: root.refresh()
                    PlasmaComponents.ToolTip { text: "Refresh" }
                }
            }

            // unavailable
            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: root.loaded && !root.available
                type: Kirigami.MessageType.Warning
                text: root.problem
                    + (root.helperMissing ? "" : "\nDiagnostics: claude-batteryconfig-helper diag")
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: root.available && root.startEmulated && !root.daemonActive
                    && root.persisted && root.needsLoop
                type: Kirigami.MessageType.Warning
                text: "The background service is not running, so the start threshold is not enforced. "
                    + "Run: sudo systemctl enable --now claude-batteryconfig.service"
            }

            // battery bar with threshold window
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.available
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        text: "Battery " + root.capacity + "%"
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label {
                        text: root.batteryState
                        opacity: 0.7
                    }
                }

                Item {
                    id: bar
                    Layout.fillWidth: true
                    implicitHeight: Kirigami.Units.gridUnit * 1.4

                    Rectangle {
                        id: track
                        anchors.fill: parent
                        radius: height / 2
                        color: Kirigami.Theme.alternateBackgroundColor
                        border.color: Kirigami.Theme.disabledTextColor
                        border.width: 1
                        clip: true

                        // charge window (pending)
                        Rectangle {
                            x: track.width * root.pendingStart / 100
                            width: track.width * (root.pendingEnd - root.pendingStart) / 100
                            height: parent.height
                            color: Kirigami.Theme.highlightColor
                            opacity: 0.25
                        }
                        // current level
                        Rectangle {
                            width: track.width * root.capacity / 100
                            height: parent.height
                            radius: height / 2
                            color: root.batteryState === "Charging"
                                ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.highlightColor
                            opacity: 0.85
                        }
                    }
                    // markers
                    Repeater {
                        model: root.startSupported ? [root.pendingStart, root.pendingEnd] : [root.pendingEnd]
                        Rectangle {
                            required property int modelData
                            x: bar.width * modelData / 100 - width / 2
                            y: -2
                            width: 3
                            height: bar.height + 4
                            radius: 1
                            color: Kirigami.Theme.textColor
                        }
                    }
                }

                PlasmaComponents.Label {
                    text: root.startSupported
                        ? "Charging resumes below " + root.pendingStart + "% and stops at " + root.pendingEnd + "%"
                        : "Charging stops at " + root.pendingEnd + "%"
                    opacity: 0.7
                    font: Kirigami.Theme.smallFont
                }
            }

            // editors
            ThresholdRow {
                Layout.fillWidth: true
                visible: root.available
                enabled: root.startSupported && !root.busy
                title: "Start charging below"
                subtitle: root.backend === "type"
                    ? "Legion Go S: firmware can only hold charge above 80%, so values below 80 act as 80."
                    : root.startEmulated
                    ? "Emulated by a background service (this firmware only offers a stop limit)."
                    : "Charger stays idle until the battery drops under this level."
                from: 0
                to: Math.max(0, root.pendingEnd - 1)
                value: root.pendingStart
                onEdited: function (v) { root.pendingStart = Math.max(0, Math.min(v, root.pendingEnd - 1)) }
            }

            ThresholdRow {
                Layout.fillWidth: true
                visible: root.available
                enabled: !root.busy
                title: "Stop charging at"
                subtitle: "Charging halts when the battery reaches this level."
                from: Math.min(100, Math.max(root.endMin, root.minEnd, root.pendingStart + 1))
                to: 100
                value: root.pendingEnd
                onEdited: function (v) {
                    root.pendingEnd = Math.min(100, Math.max(v, root.pendingStart + 1, root.endMin, root.minEnd))
                }
            }

            // presets
            Flow {
                Layout.fillWidth: true
                visible: root.available && root.backend === "type"
                spacing: Kirigami.Units.smallSpacing
                PlasmaComponents.Button {
                    text: "Firmware cap 80"
                    enabled: !root.busy
                    onClicked: root.setPreset(0, 80)
                }
                PlasmaComponents.Button {
                    text: "Balanced 80–90"
                    enabled: !root.busy
                    onClicked: root.setPreset(80, 90)
                }
                PlasmaComponents.Button {
                    text: "Near full 90–95"
                    enabled: !root.busy
                    onClicked: root.setPreset(90, 95)
                }
                PlasmaComponents.Button {
                    text: "No limit"
                    enabled: !root.busy
                    onClicked: root.setPreset(0, 100)
                }
            }

            Flow {
                Layout.fillWidth: true
                visible: root.available && root.backend !== "type"
                spacing: Kirigami.Units.smallSpacing
                PlasmaComponents.Button {
                    text: "Longevity 40–60"
                    enabled: !root.busy
                    onClicked: root.setPreset(40, 60)
                }
                PlasmaComponents.Button {
                    text: "Balanced 70–80"
                    enabled: !root.busy
                    onClicked: root.setPreset(70, 80)
                }
                PlasmaComponents.Button {
                    text: "Travel 95–100"
                    enabled: !root.busy
                    onClicked: root.setPreset(95, 100)
                }
                PlasmaComponents.Button {
                    text: "No limit"
                    enabled: !root.busy
                    onClicked: root.setPreset(0, 100)
                }
            }

            QQC2.CheckBox {
                visible: root.available
                text: "Keep after reboot and resume"
                enabled: !root.needsLoop
                checked: root.effectivePersist
                onToggled: root.persist = checked
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: root.message !== ""
                type: root.messageIsError ? Kirigami.MessageType.Error : Kirigami.MessageType.Positive
                text: root.message
            }

            // actions
            RowLayout {
                Layout.fillWidth: true
                visible: root.available
                Item { Layout.fillWidth: true }
                PlasmaComponents.Button {
                    text: "Reset"
                    icon.name: "edit-undo"
                    enabled: root.dirty && !root.busy
                    onClicked: {
                        root.pendingStart = root.curStart
                        root.pendingEnd = root.curEnd
                    }
                }
                PlasmaComponents.Button {
                    text: root.busy ? "Applying…" : "Apply (admin)"
                    icon.name: "security-high"
                    highlighted: true
                    enabled: root.dirty && !root.busy
                    onClicked: root.apply()
                }
            }
        }
    }
}
