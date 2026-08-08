// Deferred-action toast.
//
// GitHub has no "mark unread" endpoint, so undo cannot be a compensating call.
// The only honest undo is one where the request has not been sent yet: the
// widget waits out this countdown before touching the API.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Rectangle {
    id: toast

    readonly property Tones tones: Tones {}

    property int windowSec: 6
    property string message: ""
    property int remaining: 0

    /** Fires when the window closes without an undo — now send the request. */
    signal committed
    signal undone

    function begin(text) {
        toast.message = text;
        toast.remaining = toast.windowSec;
        if (toast.windowSec <= 0) {
            toast.committed();
            return;
        }
        toast.visible = true;
        countdown.restart();
    }

    function cancel() {
        countdown.stop();
        toast.visible = false;
    }

    visible: false
    radius: Kirigami.Units.cornerRadius
    color: Kirigami.Theme.alternateBackgroundColor
    border.width: 1
    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
    implicitHeight: row.implicitHeight + Kirigami.Units.smallSpacing * 2

    Timer {
        id: countdown

        interval: 1000
        repeat: true
        onTriggered: {
            toast.remaining--;
            if (toast.remaining <= 0) {
                countdown.stop();
                toast.visible = false;
                toast.committed();
            }
        }
    }

    RowLayout {
        id: row

        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        anchors.leftMargin: Kirigami.Units.smallSpacing * 2
        spacing: Kirigami.Units.smallSpacing * 2

        // A shrinking ring reads as "time is running out" without needing a
        // number, and the number is there anyway for people who want it.
        Canvas {
            id: ring

            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            Layout.alignment: Qt.AlignVCenter

            readonly property real frac: toast.windowSec > 0 ? toast.remaining / toast.windowSec : 0
            readonly property color ink: toast.tones.accent

            onFracChanged: requestPaint()
            onInkChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                var r = Math.min(width, height) / 2 - 1.5;
                ctx.reset();
                ctx.lineWidth = 2;
                ctx.strokeStyle = Qt.rgba(ring.ink.r, ring.ink.g, ring.ink.b, 0.25);
                ctx.beginPath();
                ctx.arc(width / 2, height / 2, r, 0, Math.PI * 2);
                ctx.stroke();
                ctx.strokeStyle = ring.ink;
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * ring.frac);
                ctx.stroke();
            }
        }

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true

            PlasmaComponents.Label {
                text: toast.message
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                text: i18np("sending in %1 second", "sending in %1 seconds", toast.remaining)
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        PlasmaComponents.Button {
            text: i18n("Undo")
            icon.name: "edit-undo"
            flat: true
            onClicked: {
                countdown.stop();
                toast.visible = false;
                toast.undone();
            }
        }
    }
}
