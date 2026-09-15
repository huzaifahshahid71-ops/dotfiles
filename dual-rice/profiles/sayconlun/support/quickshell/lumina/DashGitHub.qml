// Dashboard · GitHub: your repositories, local clones with pull/push, pull
// requests and issues - picked from a side menu like Productivity. Data and
// actions: GitHubService.qml.
import QtQuick
import QtQuick.Layouts
import Quickshell

RowLayout {
    id: page

    property var dash
    property string section: "repos"
    property string query: ""

    spacing: 16

    function openUrl(url) {
        Quickshell.execDetached(["xdg-open", url])
        dash.close()
    }

    component Row: Rectangle {
        id: row
        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property string meta: ""
        property bool highlight: false
        default property alias buttons: buttonRow.data
        signal clicked

        Layout.fillWidth: true
        implicitHeight: 62
        radius: 16
        color: rowArea.containsMouse ? Theme.alpha(Theme.on_surface, 0.06) : Theme.alpha(Theme.surface_container_high, 0.7)

        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 10
            spacing: 14

            LucideIcon {
                icon: row.icon
                size: 18
                color: row.highlight ? Theme.tertiary : Theme.primary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: row.title
                    elide: Text.ElideRight
                    color: Theme.on_surface
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: row.subtitle
                    elide: Text.ElideRight
                    color: Theme.on_surface_variant
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }

            Text {
                visible: text !== ""
                text: row.meta
                color: Theme.on_surface_variant
                font.family: Theme.font
                font.pixelSize: 12
            }

            RowLayout {
                id: buttonRow
                spacing: 2
            }
        }
    }

    component Label: Text {
        Layout.leftMargin: 4
        Layout.topMargin: 6
        color: Theme.on_surface_variant
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.Bold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1
    }

    // ---------------------------------------------------------- side menu --
    // Width pinned: its rows fill their width, and without min/max the
    // RowLayout handed this column almost everything and starved the content.
    ColumnLayout {
        Layout.fillWidth: false
        Layout.preferredWidth: 190
        Layout.minimumWidth: 190
        Layout.maximumWidth: 190
        Layout.alignment: Qt.AlignTop
        spacing: 6

        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 6
            implicitHeight: 52
            radius: 16
            color: Theme.alpha(Theme.surface_container_high, 0.85)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 6
                spacing: 10

                LucideIcon {
                    icon: "git-branch"
                    size: 18
                    color: GitHubService.authed ? Theme.primary : Theme.on_surface_variant
                }

                Text {
                    Layout.fillWidth: true
                    text: GitHubService.authed ? GitHubService.login : (GitHubService.checked ? "Not signed in" : "Checking…")
                    elide: Text.ElideRight
                    color: Theme.on_surface
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                DashButton {
                    icon: "refresh-cw"
                    size: 32
                    iconSize: 15
                    active: GitHubService.remoteLoading === 0 && !GitHubService.localLoading
                    onClicked: GitHubService.refresh()
                }
            }
        }

        Repeater {
            model: [
                { id: "repos", label: "Repositories", icon: "book-marked", count: GitHubService.repos.length },
                { id: "local", label: "Local", icon: "folder-open", count: GitHubService.local.length },
                { id: "prs", label: "Pull requests", icon: "git-pull-request", count: GitHubService.myPrs.length + GitHubService.reviewPrs.length },
                { id: "issues", label: "Issues", icon: "circle-dot", count: GitHubService.issues.length }
            ]

            Rectangle {
                required property var modelData
                readonly property bool selected: page.section === modelData.id

                Layout.fillWidth: true
                implicitHeight: 44
                radius: 15
                color: selected ? Theme.alpha(Theme.primary, 0.16)
                     : menuArea.containsMouse ? Theme.alpha(Theme.on_surface, 0.06) : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    LucideIcon {
                        icon: modelData.icon
                        size: 17
                        color: selected ? Theme.primary : Theme.on_surface
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.label
                        color: Theme.on_surface
                        font.family: Theme.font
                        font.pixelSize: 14
                        font.weight: selected ? Font.Bold : Font.Medium
                    }

                    Text {
                        visible: modelData.count > 0
                        text: modelData.count
                        color: Theme.on_surface_variant
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    id: menuArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.section = modelData.id
                }
            }
        }
    }

    Rectangle {
        Layout.fillHeight: true
        implicitWidth: 1
        color: Theme.alpha(Theme.on_surface, 0.1)
    }

    Loader {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        sourceComponent: page.section === "local" ? localView
                       : !GitHubService.authed ? signInView
                       : page.section === "prs" ? prsView
                       : page.section === "issues" ? issuesView
                       : reposView
    }

    // ------------------------------------------------------------ sign in --
    Component {
        id: signInView

        ColumnLayout {
            spacing: 14

            Item { Layout.preferredHeight: 30 }

            LucideIcon {
                Layout.alignment: Qt.AlignHCenter
                icon: "git-branch"
                size: 52
                color: Theme.primary
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: GitHubService.checked ? "Sign in to GitHub" : "Checking your GitHub sign-in…"
                color: Theme.on_surface
                font.family: Theme.font
                font.pixelSize: 20
                font.weight: Font.Bold
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 460
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                visible: GitHubService.checked
                text: "Repositories, pull requests and issues come from the GitHub CLI. Sign in once in a terminal, then press refresh. Local repos work without it."
                color: Theme.on_surface_variant
                font.family: Theme.font
                font.pixelSize: 14
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                visible: GitHubService.checked
                implicitWidth: signRow.implicitWidth + 36
                implicitHeight: 44
                radius: 22
                color: signArea.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary

                RowLayout {
                    id: signRow
                    anchors.centerIn: parent
                    spacing: 8

                    LucideIcon {
                        icon: "log-in"
                        size: 17
                        color: Theme.on_primary
                    }

                    Text {
                        text: "Sign in"
                        color: Theme.on_primary
                        font.family: Theme.font
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }
                }

                MouseArea {
                    id: signArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["kitty", "--title", "GitHub sign-in", "-e", "bash", "-c",
                            "gh auth login; echo; read -rp 'Done - press Enter to close. ' _"])
                        page.dash.close()
                    }
                }
            }

            Item { Layout.preferredHeight: 30 }
        }
    }

    // -------------------------------------------------------- repositories --
    Component {
        id: reposView

        ColumnLayout {
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 46
                radius: 15
                color: Theme.surface_container_lowest
                border.width: 1
                border.color: search.activeFocus ? Theme.primary : Theme.outline_variant

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10

                    LucideIcon {
                        icon: "search"
                        size: 16
                        color: Theme.on_surface_variant
                    }

                    TextInput {
                        id: search
                        Layout.fillWidth: true
                        text: page.query
                        onTextChanged: page.query = text
                        color: Theme.on_surface
                        font.family: Theme.font
                        font.pixelSize: 14
                        clip: true

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !search.text
                            text: GitHubService.remoteLoading > 0 ? "Loading repositories…" : "Search your repositories"
                            color: Theme.on_surface_variant
                            font: search.font
                        }
                    }
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(repoList.implicitHeight, 460)
                contentHeight: repoList.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: repoList
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: GitHubService.repos.filter(r => {
                            const q = page.query.toLowerCase()
                            return !q || r.name.toLowerCase().includes(q) || (r.description || "").toLowerCase().includes(q)
                        })

                        Row {
                            required property var modelData
                            readonly property var clone: GitHubService.localFor(modelData)

                            icon: modelData.visibility === "PRIVATE" ? "lock" : modelData.isFork ? "git-fork" : "globe"
                            title: modelData.name
                            subtitle: modelData.description || ""
                            meta: [modelData.primaryLanguage ? modelData.primaryLanguage.name : "",
                                   modelData.stargazerCount ? "★ " + modelData.stargazerCount : "",
                                   GitHubService.ago(modelData.pushedAt)].filter(x => x).join("  ·  ")
                            onClicked: page.openUrl(modelData.url)

                            DashButton {
                                icon: "external-link"
                                size: 34
                                iconSize: 15
                                onClicked: page.openUrl(modelData.url)
                            }

                            DashButton {
                                visible: clone === null
                                icon: "download"
                                size: 34
                                iconSize: 15
                                active: GitHubService.busy === ""
                                onClicked: GitHubService.clone(modelData)
                            }

                            DashButton {
                                visible: clone !== null
                                icon: "terminal"
                                size: 34
                                iconSize: 15
                                onClicked: {
                                    Quickshell.execDetached(["kitty", "--directory", clone.path])
                                    page.dash.close()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --------------------------------------------------------------- local --
    Component {
        id: localView

        ColumnLayout {
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                Label {
                    Layout.fillWidth: true
                    text: GitHubService.localLoading ? "Scanning your repos…" : GitHubService.local.length + " local repositories"
                }

                Rectangle {
                    implicitWidth: fetchRow.implicitWidth + 24
                    implicitHeight: 34
                    radius: 17
                    color: fetchArea.containsMouse ? Theme.alpha(Theme.primary, 0.18) : Theme.surface_container_high
                    opacity: GitHubService.busy === "" ? 1 : 0.5

                    RowLayout {
                        id: fetchRow
                        anchors.centerIn: parent
                        spacing: 6

                        LucideIcon {
                            icon: "refresh-cw"
                            size: 14
                            color: Theme.primary
                        }

                        Text {
                            text: GitHubService.busy === "*" ? "Fetching…" : "Fetch all"
                            color: Theme.on_surface
                            font.family: Theme.font
                            font.pixelSize: 13
                        }
                    }

                    MouseArea {
                        id: fetchArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: GitHubService.busy === ""
                        cursorShape: Qt.PointingHandCursor
                        onClicked: GitHubService.fetchAll()
                    }
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(localList.implicitHeight, 460)
                contentHeight: localList.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: localList
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: GitHubService.local

                        Row {
                            required property var modelData
                            readonly property bool working: GitHubService.busy === modelData.path

                            icon: "git-branch"
                            highlight: modelData.changes > 0
                            title: modelData.name
                            subtitle: modelData.path.replace(GitHubService.home, "~")
                                + (modelData.remote ? "" : "  ·  not on GitHub")
                            meta: [modelData.branch,
                                   modelData.ahead ? "↑" + modelData.ahead : "",
                                   modelData.behind ? "↓" + modelData.behind : "",
                                   modelData.changes ? modelData.changes + " changed" : "clean"].filter(x => x).join("  ·  ")
                            onClicked: {
                                Quickshell.execDetached(["thunar", modelData.path])
                                page.dash.close()
                            }

                            DashButton {
                                visible: modelData.upstream
                                icon: "arrow-down"
                                size: 34
                                iconSize: 15
                                active: GitHubService.busy === ""
                                onClicked: GitHubService.pull(modelData)
                            }

                            DashButton {
                                visible: modelData.upstream
                                icon: "arrow-up"
                                size: 34
                                iconSize: 15
                                accent: modelData.ahead > 0
                                active: GitHubService.busy === "" && modelData.ahead > 0
                                onClicked: GitHubService.push(modelData)
                            }

                            DashButton {
                                visible: !modelData.remote && GitHubService.authed
                                icon: "upload"
                                size: 34
                                iconSize: 15
                                active: GitHubService.busy === ""
                                onClicked: GitHubService.publish(modelData, "private")
                            }

                            DashButton {
                                icon: working ? "loader-circle" : "terminal"
                                size: 34
                                iconSize: 15
                                onClicked: {
                                    Quickshell.execDetached(["kitty", "--directory", modelData.path])
                                    page.dash.close()
                                }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.leftMargin: 4
                text: "↓ pull (fast-forward only)   ↑ push   ⇪ publish as a private GitHub repo   click a row for its folder"
                color: Theme.on_surface_variant
                opacity: 0.8
                font.family: Theme.font
                font.pixelSize: 11
            }
        }
    }

    // ------------------------------------------------------ pull requests --
    Component {
        id: prsView

        ColumnLayout {
            spacing: 6

            Label {
                text: "Yours · " + GitHubService.myPrs.length
            }

            Text {
                Layout.leftMargin: 4
                visible: GitHubService.myPrs.length === 0
                text: GitHubService.remoteLoading > 0 ? "Loading…" : "No open pull requests"
                color: Theme.on_surface_variant
                font.family: Theme.font
                font.pixelSize: 13
            }

            Repeater {
                model: GitHubService.myPrs

                Row {
                    required property var modelData
                    icon: "git-pull-request"
                    title: modelData.title
                    subtitle: `${modelData.repository.nameWithOwner} #${modelData.number}` + (modelData.isDraft ? "  ·  draft" : "")
                    meta: GitHubService.ago(modelData.updatedAt)
                    onClicked: page.openUrl(modelData.url)
                }
            }

            Label {
                text: "Waiting on your review · " + GitHubService.reviewPrs.length
            }

            Text {
                Layout.leftMargin: 4
                visible: GitHubService.reviewPrs.length === 0
                text: GitHubService.remoteLoading > 0 ? "Loading…" : "Nothing to review"
                color: Theme.on_surface_variant
                font.family: Theme.font
                font.pixelSize: 13
            }

            Repeater {
                model: GitHubService.reviewPrs

                Row {
                    required property var modelData
                    icon: "git-pull-request"
                    highlight: true
                    title: modelData.title
                    subtitle: `${modelData.repository.nameWithOwner} #${modelData.number}`
                    meta: GitHubService.ago(modelData.updatedAt)
                    onClicked: page.openUrl(modelData.url)
                }
            }
        }
    }

    // ------------------------------------------------------------- issues --
    Component {
        id: issuesView

        ColumnLayout {
            spacing: 6

            Label {
                text: "Assigned to you · " + GitHubService.issues.length
            }

            Text {
                Layout.leftMargin: 4
                visible: GitHubService.issues.length === 0
                text: GitHubService.remoteLoading > 0 ? "Loading…" : "No open issues assigned to you"
                color: Theme.on_surface_variant
                font.family: Theme.font
                font.pixelSize: 13
            }

            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(issueList.implicitHeight, 460)
                contentHeight: issueList.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: issueList
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: GitHubService.issues

                        Row {
                            required property var modelData
                            icon: "circle-dot"
                            title: modelData.title
                            subtitle: `${modelData.repository.nameWithOwner} #${modelData.number}`
                            meta: GitHubService.ago(modelData.updatedAt)
                            onClicked: page.openUrl(modelData.url)
                        }
                    }
                }
            }
        }
    }
}
