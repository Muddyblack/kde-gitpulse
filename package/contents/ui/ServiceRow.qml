// One GitHub service, its indicator dot, and optionally its 90-day strip.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../code/Format.js" as Fmt

ColumnLayout {
    id: service

    property string name: ""
    property string status: "operational"
    property string tone: "positive"
    /** Output of Contract.incidentStrip(); empty hides the strip. */
    property var strip: []

    readonly property Tones tones: Tones {}

    spacing: Math.round(Kirigami.Units.smallSpacing / 2)

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing * 2
        Layout.rightMargin: Kirigami.Units.smallSpacing * 2
        spacing: Kirigami.Units.smallSpacing * 1.5

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Math.round(Kirigami.Units.smallSpacing * 2)
            implicitHeight: implicitWidth
            radius: width / 2
            color: service.tones.of(service.tone)
        }

        PlasmaComponents.Label {
            text: service.name
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Pill {
            text: Fmt.humanise(service.status)
            tone: service.tone
        }
    }

    UptimeStrip {
        strip: service.strip
        visible: service.strip.length > 0
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing * 2 + Math.round(Kirigami.Units.smallSpacing * 2) + Kirigami.Units.smallSpacing * 1.5
        Layout.rightMargin: Kirigami.Units.smallSpacing * 2
        Layout.bottomMargin: Kirigami.Units.smallSpacing
    }
}
