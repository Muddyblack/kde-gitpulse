// The Hyprland side of shared/Pill.qml's icon injection: draws the glyph set
// from Icon.qml/Icons.js. See package/contents/ui/shared/Pill.qml for why
// this is injected rather than baked into the shared component.
import QtQuick

QtObject {
    readonly property Component delegate: Component {
        Icon {
            property string iconName: ""

            name: iconName
        }
    }
}
