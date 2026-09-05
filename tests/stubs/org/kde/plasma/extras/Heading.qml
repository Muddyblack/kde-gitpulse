import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

QQC2.Label {
    property int level: 2
    color: Kirigami.Theme.textColor
    font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * (level <= 1 ? 1.8 : level === 2 ? 1.5 : level === 3 ? 1.25 : 1.1))
    font.weight: Font.DemiBold
}
