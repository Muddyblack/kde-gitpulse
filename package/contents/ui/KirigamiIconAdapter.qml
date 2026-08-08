// The KDE side of shared/Pill.qml's icon injection: resolves a named icon
// through the system icon theme via Kirigami.Icon. See shared/Pill.qml for
// why this is injected rather than baked into the shared component.
import QtQuick
import org.kde.kirigami as Kirigami

QtObject {
    readonly property Component delegate: Component {
        Kirigami.Icon {
            property string iconName: ""
            property bool spinning: false

            source: iconName
            isMask: true

            RotationAnimator on rotation {
                running: spinning
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: Kirigami.Units.veryLongDuration * 3
            }
        }
    }
}
