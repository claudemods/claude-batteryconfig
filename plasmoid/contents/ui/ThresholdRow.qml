import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// One labelled threshold editor: slider + editable spin box.
ColumnLayout {
    id: row

    property string title
    property string subtitle
    property int value: 0
    property int from: 0
    property int to: 100
    signal edited(int newValue)

    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        Layout.fillWidth: true

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            PlasmaComponents.Label {
                text: row.title
                font.bold: true
            }
            PlasmaComponents.Label {
                text: row.subtitle
                opacity: 0.7
                font: Kirigami.Theme.smallFont
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        QQC2.SpinBox {
            id: spin
            editable: true
            enabled: row.enabled
            from: row.from
            to: row.to
            value: row.value
            onValueModified: {
                row.edited(value)
                // re-sync in case the parent clamped the value
                spin.value = Qt.binding(function () { return row.value })
            }
        }
        PlasmaComponents.Label {
            text: "%"
        }
    }

    QQC2.Slider {
        id: slider
        Layout.fillWidth: true
        enabled: row.enabled
        from: row.from
        to: row.to
        stepSize: 1
        snapMode: QQC2.Slider.SnapAlways
        value: row.value
        onMoved: {
            row.edited(Math.round(value))
            slider.value = Qt.binding(function () { return row.value })
        }
    }
}
