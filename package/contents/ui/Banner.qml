// One inline message, at the top, explaining the whole popup's condition.
//
// It exists so individual rows never have to lie: during a GitHub Actions
// outage every red run is explained once here instead of implying your code
// broke seven times.
import QtQuick
import org.kde.kirigami as Kirigami

import "../code/Format.js" as Fmt
import "../code/GitHub.js" as GH

Kirigami.InlineMessage {
    id: banner

    required property var engine
    signal configure

    readonly property int outages: {
        var n = 0;
        for (var i = 0; i < banner.engine.statusComponents.length; i++) {
            if (banner.engine.statusComponents[i].tone !== "positive")
                n++;
        }
        return n;
    }

    /** Bumped once a second so the countdown below re-evaluates. */
    property int tick: 0
    readonly property int resetInSec: banner.tick >= 0 && banner.engine.rateResetMs > 0 ? Math.max(0, Math.round((banner.engine.rateResetMs - Date.now()) / 1000)) : 0

    visible: banner.text !== ""
    position: Kirigami.InlineMessage.Position.Header

    type: {
        switch (banner.engine.primaryError) {
        case GH.ERR.AUTH:
        case GH.ERR.RATE_LIMIT:
            return Kirigami.MessageType.Error;
        case GH.ERR.OFFLINE:
        case GH.ERR.NO_TOKEN:
            return Kirigami.MessageType.Warning;
        default:
            return banner.outages > 0 ? Kirigami.MessageType.Warning : Kirigami.MessageType.Information;
        }
    }

    text: {
        switch (banner.engine.primaryError) {
        case GH.ERR.NO_TOKEN:
            return i18n("Add a GitHub token to start syncing.");
        case GH.ERR.AUTH:
            return i18n("GitHub rejected the token. It may have expired or been revoked.");
        case GH.ERR.RATE_LIMIT:
            return banner.resetInSec > 0 ? i18n("Rate limit reached. Polling resumes in %1.", Fmt.until(banner.resetInSec)) : i18n("Rate limit reached. Polling is paused.");
        case GH.ERR.OFFLINE:
            return i18n("Offline — showing the last data received.");
        }
        if (banner.outages > 0)
            return i18np("GitHub is reporting a problem with %1 service.", "GitHub is reporting problems with %1 services.", banner.outages);
        return "";
    }

    actions: [
        Kirigami.Action {
            text: i18n("Configure…")
            icon.name: "configure"
            visible: banner.engine.primaryError === GH.ERR.NO_TOKEN || banner.engine.primaryError === GH.ERR.AUTH
            onTriggered: banner.configure()
        },
        Kirigami.Action {
            text: i18n("Retry")
            icon.name: "view-refresh"
            visible: banner.engine.primaryError === GH.ERR.OFFLINE
            onTriggered: banner.engine.refreshAll(false)
        }
    ]

    // Keeps the countdown honest while the popup stays open.
    Timer {
        interval: 1000
        repeat: true
        running: banner.visible && banner.engine.primaryError === GH.ERR.RATE_LIMIT
        onTriggered: banner.tick++
    }
}
