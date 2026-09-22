import QtQuick
import QtQuick.Layouts
import "../package/contents/code/ProjectInfo.js" as Project

ColumnLayout {
    id: info

    required property var theme
    property var shell: null
    readonly property string iconDir: (shell && shell.iconDir) ? shell.iconDir : Qt.resolvedUrl("../package/contents/icons/")
    property var counts: ({})
    property var contributorList: []
    property var requests: []
    property bool requested: false
    readonly property string currentVersion: Project.currentVersion
    property string latestVersion: ""
    property string releaseCheckState: "Not checked"
    readonly property string versionStatus: latestVersion ? Project.releaseStatus(currentVersion, latestVersion) : releaseCheckState
    readonly property bool onlineEnabled: true
    readonly property var accent: theme.accent

    spacing: info.theme.spacing * 1.5

    function checkRelease() {
        if (!onlineEnabled || releaseCheckState === "Checking…")
            return;
        latestVersion = "";
        releaseCheckState = "Checking…";
        const request = new XMLHttpRequest();
        requests.push(request);
        request.open("GET", Project.latestReleaseUrl);
        request.onreadystatechange = function () {
            if (request.readyState !== XMLHttpRequest.DONE)
                return;
            info.latestVersion = request.status === 200 ? Project.releaseVersion(request.responseText) : "";
            info.releaseCheckState = info.latestVersion ? "Checked" : "Could not check for updates";
        };
        request.send();
        timeout.restart();
    }

    function loadCounts() {
        if (!onlineEnabled || requested)
            return;
        requested = true;
        checkRelease();
        Project.statistics.forEach(function (stat) {
            const request = new XMLHttpRequest();
            info.requests.push(request);
            request.open("GET", stat.url);
            request.onreadystatechange = function () {
                if (request.readyState !== XMLHttpRequest.DONE || request.status !== 200)
                    return;
                const value = Project.count(request.responseText);
                if (value) {
                    const next = Object.assign({}, info.counts);
                    next[stat.id] = value;
                    info.counts = next;
                }
            };
            request.send();
        });
        const contributorsRequest = new XMLHttpRequest();
        requests.push(contributorsRequest);
        contributorsRequest.open("GET", Project.contributorsUrl);
        contributorsRequest.onreadystatechange = function () {
            if (contributorsRequest.readyState === XMLHttpRequest.DONE && contributorsRequest.status === 200)
                info.contributorList = Project.contributors(contributorsRequest.responseText);
        };
        contributorsRequest.send();
        timeout.restart();
    }

    function cancelRequests() {
        requests.forEach(function (request) {
            request.onreadystatechange = null;
            request.abort();
        });
        requests = [];
        if (releaseCheckState === "Checking…")
            releaseCheckState = "Could not check for updates";
    }

    onVisibleChanged: {
        if (visible && !requested)
            loadCounts();
    }
    Component.onCompleted: loadCounts()
    Component.onDestruction: cancelRequests()

    Timer {
        id: timeout
        interval: 8000
        onTriggered: info.cancelRequests()
    }

    // ── Header (Icon, Title, Author) ─────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 14

        Image {
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            source: Qt.resolvedUrl("../package/icon.png")
            sourceSize.width: 112
            sourceSize.height: 112
            fillMode: Image.PreserveAspectFit
            Accessible.name: "Gitpulse project icon"
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                Layout.fillWidth: true
                text: Project.name
                wrapMode: Text.WordWrap
                color: info.theme.text
                font.pixelSize: 16
                font.bold: true
            }

            RowLayout {
                spacing: 8

                RoundAvatar {
                    theme: info.theme
                    login: Project.author
                    source: info.onlineEnabled ? Project.avatar : ""
                    implicitWidth: 24
                    implicitHeight: 24
                }

                ActionButton {
                    theme: info.theme
                    text: "By " + Project.author + " ↗"
                    onClicked: Qt.openUrlExternally(Project.profile)
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: qsTr("The pulse of your repos — GitHub, GitLab and Codeberg notifications, CI runs, pull requests, issues, profile and service health in your panel. Explore the project, get updates, or help improve it.")
        wrapMode: Text.WordWrap
        color: info.theme.textDim
        font.pixelSize: 11
        lineHeight: 1.25
    }

    // ── Version Card ─────────────────────────────────────────────────────────
    Rectangle {
        objectName: "projectVersion"
        Layout.fillWidth: true
        implicitHeight: versionContent.implicitHeight + 20
        radius: info.theme.radiusSmall
        color: info.theme.surfaceAlt
        border.color: info.theme.line
        border.width: 1

        ColumnLayout {
            id: versionContent
            anchors.fill: parent
            anchors.margins: 10
            spacing: 4

            Text {
                text: qsTr("Installed version · %1").arg(info.currentVersion)
                color: info.theme.text
                font.pixelSize: 11
                font.bold: true
            }

            Text {
                objectName: "latestVersionLabel"
                text: qsTr("Latest stable release · %1").arg(info.latestVersion || "—")
                color: info.theme.textDim
                font.pixelSize: 10
            }

            Text {
                objectName: "versionStatusLabel"
                Layout.fillWidth: true
                text: info.versionStatus
                wrapMode: Text.WordWrap
                color: text === "Update available" ? info.accent : info.theme.textDim
                opacity: text === "Update available" ? 1.0 : 0.8
                font.pixelSize: 10
            }

            RowLayout {
                spacing: 8

                ActionButton {
                    theme: info.theme
                    primary: info.versionStatus === "Update available"
                    text: info.versionStatus === "Update available" ? qsTr("Get update ↗") : qsTr("View latest release ↗")
                    onClicked: Qt.openUrlExternally(Project.releasesPage)
                }

                ActionButton {
                    theme: info.theme
                    text: qsTr("Check again")
                    enabled: info.onlineEnabled && info.releaseCheckState !== "Checking…"
                    onClicked: info.checkRelease()
                }
            }
        }
    }

    // ── Statistics Cards ─────────────────────────────────────────────────────
    Flow {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: Project.statistics

            Rectangle {
                id: statBox
                required property var modelData
                objectName: "stat_" + modelData.id
                width: info.width >= 570 ? (info.width - 16) / 3 : info.width >= 360 ? (info.width - 8) / 2 : info.width
                height: 68
                radius: info.theme.radiusSmall
                color: statArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : info.theme.surfaceAlt
                border.width: 1
                border.color: statArea.containsMouse ? info.accent : info.theme.line

                Image {
                    objectName: "statIcon_" + statBox.modelData.id
                    x: 10
                    y: 10
                    width: 20
                    height: 20
                    source: info.iconDir + statBox.modelData.icon
                    sourceSize: Qt.size(40, 40)
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    x: 38
                    y: 8
                    text: info.counts[statBox.modelData.id] || "—"
                    color: info.theme.text
                    font.pixelSize: 17
                    font.bold: true
                }

                Text {
                    x: 10
                    y: 38
                    width: parent.width - 20
                    text: statBox.modelData.label + " ↗"
                    color: info.theme.textDim
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: statArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.name: statBox.modelData.label + ", open " + statBox.modelData.href
                    onClicked: Qt.openUrlExternally(statBox.modelData.href)
                }
            }
        }
    }

    // ── License Card ─────────────────────────────────────────────────────────
    Rectangle {
        objectName: "projectLicense"
        Layout.fillWidth: true
        height: 52
        radius: info.theme.radiusSmall
        color: info.theme.surfaceAlt
        border.color: info.theme.line
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 2

            Text {
                text: qsTr("License · %1").arg(Project.license)
                color: info.theme.text
                font.pixelSize: 11
                font.bold: true
            }

            Text {
                text: Project.licenseId + " · " + qsTr("From the bundled LICENSE file")
                color: info.theme.textFaint
                font.pixelSize: 9
            }
        }
    }

    // ── Contributors Section ─────────────────────────────────────────────────
    ColumnLayout {
        objectName: "contributorsSection"
        Layout.fillWidth: true
        visible: info.contributorList.length > 0
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: qsTr("Contributors")
                color: info.theme.text
                font.pixelSize: 13
                font.bold: true
            }

            Item {
                Layout.fillWidth: true
            }

            ActionButton {
                theme: info.theme
                text: qsTr("See all on GitHub ↗")
                onClicked: Qt.openUrlExternally(Project.contributorsPage)
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: info.contributorList

                Rectangle {
                    id: contributorCard
                    required property var modelData
                    objectName: "contributor_" + modelData.login
                    width: info.width >= 570 ? (info.width - 16) / 3 : info.width >= 360 ? (info.width - 8) / 2 : info.width
                    height: 50
                    radius: info.theme.radiusSmall
                    color: contributorArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : info.theme.surfaceAlt
                    border.color: contributorArea.containsMouse ? info.accent : info.theme.line
                    border.width: 1

                    RoundAvatar {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        theme: info.theme
                        login: contributorCard.modelData.login
                        source: info.onlineEnabled ? contributorCard.modelData.avatar : ""
                        implicitWidth: 30
                        implicitHeight: 30
                    }

                    ColumnLayout {
                        x: 46
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 54
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: contributorCard.modelData.login
                            elide: Text.ElideRight
                            color: info.theme.text
                            font.pixelSize: 10
                            font.bold: true
                        }

                        Text {
                            text: contributorCard.modelData.commits + (contributorCard.modelData.commits === 1 ? " commit" : " commits")
                            color: info.theme.textFaint
                            font.pixelSize: 9
                        }
                    }

                    MouseArea {
                        id: contributorArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.name: "Open " + contributorCard.modelData.login + " on GitHub"
                        onClicked: Qt.openUrlExternally(contributorCard.modelData.profile)
                    }
                }
            }
        }
    }

    // ── Support the project ──────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
            text: qsTr("Support the project")
            color: info.theme.text
            font.pixelSize: 13
            font.bold: true
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: Project.funding

                Rectangle {
                    id: fundingCard
                    required property var modelData
                    objectName: "funding_" + modelData.id
                    width: info.width >= 570 ? (info.width - 16) / 3 : info.width >= 360 ? (info.width - 8) / 2 : info.width
                    height: 52
                    radius: info.theme.radiusSmall
                    color: linkArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : info.theme.surfaceAlt
                    border.width: 1
                    border.color: linkArea.containsMouse ? info.accent : info.theme.line

                    Image {
                        objectName: "fundingIcon_" + fundingCard.modelData.id
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        height: 22
                        source: info.iconDir + fundingCard.modelData.icon
                        fillMode: Image.PreserveAspectFit
                        sourceSize: Qt.size(44, 44)
                    }

                    Text {
                        x: 36
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 44
                        text: fundingCard.modelData.label
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        color: info.theme.text
                        font.pixelSize: 10
                        font.bold: true
                    }

                    MouseArea {
                        id: linkArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.name: "Support on " + fundingCard.modelData.label
                        onClicked: Qt.openUrlExternally(fundingCard.modelData.url)
                    }
                }
            }
        }
    }

    // ── Footer Actions ───────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ActionButton {
            theme: info.theme
            text: qsTr("View source on GitHub ↗")
            onClicked: Qt.openUrlExternally(Project.repository)
        }

        ActionButton {
            theme: info.theme
            text: qsTr("Report an issue ↗")
            onClicked: Qt.openUrlExternally(Project.repository + "/issues")
        }

        Item {
            Layout.fillWidth: true
        }
    }
}
