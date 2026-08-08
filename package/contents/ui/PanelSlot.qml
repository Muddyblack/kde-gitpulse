// Compact representation: what Gitpulse looks like in the panel or tray.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid

Item {
    id: slot

    required property var engine
    required property var host // the PlasmoidItem, for expanded/actions

    readonly property bool onDesktop: Plasmoid.formFactor !== PlasmaCore.Types.Horizontal && Plasmoid.formFactor !== PlasmaCore.Types.Vertical
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property int count: slot.engine.badge.needsYou
    // Red when failing pipelines are the reason the badge is lit at all.
    readonly property bool urgent: slot.engine.badge.failing > 0 && slot.engine.badge.failing >= slot.count

    // In a panel the widget is square and sized by the panel's thickness; on
    // the desktop it gets room for a label as well.
    readonly property int iconSize: slot.onDesktop ? Math.min(width, height) * 0.55 : Math.min(width, height)

    implicitWidth: slot.onDesktop ? Kirigami.Units.gridUnit * 6 : slot.vertical ? width : height
    implicitHeight: slot.onDesktop ? Kirigami.Units.gridUnit * 6 : slot.vertical ? width : height

    Layout.minimumWidth: slot.vertical ? 0 : slot.implicitWidth
    Layout.minimumHeight: slot.vertical ? slot.implicitHeight : 0

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: slot.iconSize
            Layout.preferredHeight: slot.iconSize

            Avatar {
                id: face

                anchors.fill: parent
                login: slot.engine.viewerLogin
                source: slot.engine.avatarSource || slot.engine.avatarUrl
                // Stale data should look stale rather than quietly lie.
                opacity: slot.engine.stale ? 0.5 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                    }
                }
            }

            CountBadge {
                count: slot.count
                urgent: slot.urgent
                anchors.right: face.right
                anchors.top: face.top
                anchors.rightMargin: -Math.round(width / 4)
                anchors.topMargin: -Math.round(height / 4)
            }

            // A single dot beats a second badge for "something is wrong with
            // the widget itself" — no token, bad token, no network.
            Rectangle {
                visible: slot.engine.primaryError !== ""
                width: Math.max(6, Math.round(slot.iconSize * 0.26))
                height: width
                radius: width / 2
                color: Kirigami.Theme.neutralTextColor
                border.width: 1
                border.color: Kirigami.Theme.backgroundColor
                anchors.right: face.right
                anchors.bottom: face.bottom
            }
        }

        PlasmaComponents.Label {
            visible: slot.onDesktop
            Layout.alignment: Qt.AlignHCenter
            text: slot.count > 0 ? i18np("%1 needs you", "%1 need you", slot.count) : slot.engine.viewerLogin !== "" ? slot.engine.viewerLogin : i18n("Not signed in")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            elide: Text.ElideRight
            Layout.maximumWidth: slot.width - Kirigami.Units.gridUnit
            horizontalAlignment: Text.AlignHCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        // Right-click is deliberately not accepted: it must reach Plasma so the
        // applet's own context menu (plus our contextualActions) opens.
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        hoverEnabled: true

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton)
                slot.engine.refreshAll(false);
            else
                slot.host.expanded = !slot.host.expanded;
        }

        // Scrolling a tray icon to cycle its views is a habit panels already
        // teach; free affordance, no chrome.
        onWheel: wheel => {
            if (!slot.host.expanded)
                slot.host.expanded = true;
            slot.host.cycleTab(wheel.angleDelta.y < 0 ? 1 : -1);
        }
    }
}
