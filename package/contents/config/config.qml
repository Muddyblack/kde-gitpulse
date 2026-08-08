import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Account")
        icon: "user-identity"
        source: "configAccount.qml"
    }

    ConfigCategory {
        name: i18n("Sources")
        icon: "view-list-details"
        source: "configSources.qml"
    }

    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-color"
        source: "configAppearance.qml"
    }

    ConfigCategory {
        name: i18n("Behaviour")
        icon: "configure"
        source: "configBehavior.qml"
    }
}
