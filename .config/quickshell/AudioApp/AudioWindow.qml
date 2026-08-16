import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Widgets

Scope {
    id: audioApp

    // ============================================================
    // MATUGEN
    // ============================================================

    FileView {
        id: colorsFile

        path: "/home/tiendn/.config/waybar/colors.css"
        preload: true
        blockLoading: true
        printErrors: false
        watchChanges: true

        onFileChanged: reload()
    }

function matugenColor(name, fallback) {
    var css = colorsFile.text()

    if (!css || css.length === 0)
        return fallback

    // Matugen / Waybar:
    // @define-color background #xxxxxx;
    var re1 = new RegExp(
        "@define-color\\s+" + name + "\\s+([^;]+);"
    )

    var match1 = css.match(re1)

    if (match1 && match1.length > 1)
        return match1[1].trim()

    // CSS variable:
    // --background: #xxxxxx;
    var re2 = new RegExp(
        "--" + name + "\\s*:\\s*([^;]+);"
    )

    var match2 = css.match(re2)

    if (match2 && match2.length > 1)
        return match2[1].trim()

    return fallback
}
readonly property color bg:
    matugenColor("surface_container", "#202020")

readonly property color surface:
    matugenColor("surface_container_high", "#303030")

readonly property color primary:
    matugenColor("primary", "#ffffff")

readonly property color text:
    matugenColor("on_surface", "#ffffff")

readonly property color outline:
    matugenColor("outline_variant", "#666666")
    // ============================================================
    // PIPEWIRE
    // ============================================================

    readonly property PwNode sink:
        Pipewire.defaultAudioSink

    readonly property PwNode source:
        Pipewire.defaultAudioSource

    readonly property bool audioReady:
        sink !== null &&
        sink.ready &&
        sink.audio !== null

    readonly property real volume:
        audioReady
            ? sink.audio.volume
            : 0

    readonly property bool muted:
        audioReady
            ? sink.audio.muted
            : false

    readonly property int percent:
        Math.round(volume * 100)

    PwObjectTracker {
        objects: sink !== null
            ? [sink]
            : []
    }

    function setVolume(value) {
        if (!audioReady)
            return

        sink.audio.muted = false

        sink.audio.volume =
            Math.max(
                0,
                Math.min(1, value)
            )
    }

    function toggleMute() {
        if (!audioReady)
            return

        sink.audio.muted =
            !sink.audio.muted
    }

    function nodeName(node) {
        if (!node)
            return "Không có thiết bị"

        return node.description ||
               node.nickname ||
               node.name ||
               "Unknown"
    }

    function appName(node) {
        if (!node)
            return "Unknown"

        var props = node.properties

        if (props) {
            return props["application.name"] ||
                   props["media.name"] ||
                   node.description ||
                   node.name ||
                   "Unknown"
        }

        return node.description ||
               node.name ||
               "Unknown"
    }

    function appIcon(node) {
        if (!node)
            return Quickshell.iconPath("audio-x-generic", false)

        var props = node.properties
        var candidates = []

        if (props) {
            if (props["application.id"])
                candidates.push(props["application.id"])

            if (props["application.desktop"])
                candidates.push(props["application.desktop"])

            if (props["application.name"])
                candidates.push(props["application.name"])
        }

        for (var i = 0; i < candidates.length; i++) {
            var candidate = candidates[i]

            if (!candidate)
                continue

            var entry = DesktopEntries.heuristicLookup(candidate)

            if (entry && entry.icon)
                return Quickshell.iconPath(entry.icon, "audio-x-generic")
        }

        return Quickshell.iconPath("audio-x-generic", false)
    }


    // ============================================================
    // MPRIS / NOW PLAYING
    // ============================================================

    property var mediaPlayer: null

    function refreshMediaPlayer() {
        var players = Mpris.players.values
        var selected = null

        // Prefer the player that is actively playing.
        for (var i = 0; i < players.length; i++) {
            if (players[i] && players[i].isPlaying) {
                selected = players[i]
                break
            }
        }

        // If nothing is playing, keep a player with track metadata so
        // paused media can still be shown and controlled.
        if (!selected) {
            for (var j = 0; j < players.length; j++) {
                if (players[j] &&
                    players[j].trackTitle) {
                    selected = players[j]
                    break
                }
            }
        }

        mediaPlayer = selected
    }

    function mediaTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            seconds = 0

        var total = Math.floor(seconds)
        var minutes = Math.floor(total / 60)
        var secs = total % 60

        return minutes + ":" +
               (secs < 10 ? "0" : "") +
               secs
    }

    Timer {
        id: mediaRefreshTimer

        interval: 500
        repeat: true
        running: true

        onTriggered: {
            audioApp.refreshMediaPlayer()

            if (audioApp.mediaPlayer &&
                audioApp.mediaPlayer.isPlaying) {
                audioApp.mediaPlayer.positionChanged()
            }
        }
    }


    // ============================================================
    // DEVICE DROPDOWN STATE
    // ============================================================

    property bool outputExpanded: false
    property bool inputExpanded: false

    function selectOutput(node) {
        if (!node)
            return

        Pipewire.preferredDefaultAudioSink = node
        outputExpanded = false
    }

    function selectInput(node) {
        if (!node)
            return

        Pipewire.preferredDefaultAudioSource = node
        inputExpanded = false
    }


    // ============================================================
    // IPC
    // ============================================================

    IpcHandler {
        target: "audio"

        function toggle(): void {
            root.visible = !root.visible
        }

        function show(): void {
            root.visible = true
        }

        function hide(): void {
            root.visible = false
        }
    }

    // ============================================================
    // POPUP
    // ============================================================

    PanelWindow {
        id: root

        visible: false

        anchors {
            top: true
            right: true
        }

        margins {
            top: 15
            right: 400
        }

        implicitWidth: 380
        implicitHeight: 700

        color: "transparent"

        WlrLayershell.layer:
            WlrLayer.Overlay

        focusable: true

        WlrLayershell.keyboardFocus:
            WlrKeyboardFocus.OnDemand

        // ========================================================
        // CLICK OUTSIDE
        // ========================================================

        HyprlandFocusGrab {
            windows: [root]
            active: root.visible

            onCleared: {
                if (root.visible)
                    root.visible = false
            }
        }

        // ========================================================
        // MAIN CARD
        // ========================================================

        Rectangle {
            anchors.fill: parent

            radius: 18

            color: audioApp.bg

            border.width: 1
            border.color: audioApp.outline

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18

                spacing: 14

                // =================================================
                // HEADER
                // =================================================

                RowLayout {
                    Layout.fillWidth: true

                    spacing: 10

                    Text {
                        text:
                            audioApp.muted
                            ? "󰝟"
                            : "󰕾"

                        color: audioApp.primary

                        font.pixelSize: 25
                    }

                    ColumnLayout {
                        Layout.fillWidth: true

                        spacing: 1

                        Text {
                            text: "Âm thanh"

                            color: audioApp.text

                            font.pixelSize: 15
                            font.bold: true
                        }

                        Text {
                            text:
                                audioApp.muted
                                ? "Đang tắt tiếng"
                                : "Âm lượng hệ thống"

                            color: audioApp.text

                            opacity: 0.55

                            font.pixelSize: 11
                        }
                    }

                    Text {
                        text:
                            audioApp.percent + "%"

                        color: audioApp.primary

                        font.pixelSize: 14
                        font.bold: true
                    }

                    Rectangle {
                        width: 36
                        height: 36

                        radius: 10

                        color:
                            audioApp.muted
                            ? audioApp.primary
                            : audioApp.surface

                        border.width: 1
                        border.color:
                            audioApp.primary

                        Text {
                            anchors.centerIn: parent

                            text:
                                audioApp.muted
                                ? "󰕾"
                                : "󰝟"

                            color:
                                audioApp.muted
                                ? audioApp.bg
                                : audioApp.primary

                            font.pixelSize: 18
                        }

                        MouseArea {
                            anchors.fill: parent

                            cursorShape:
                                Qt.PointingHandCursor

                            onClicked:
                                audioApp.toggleMute()
                        }
                    }
                }

                // =================================================
                // VOLUME SLIDER
                // =================================================

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30

                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter:
                                parent.verticalCenter
                        }

                        height: 7
                        radius: 4

                        color: audioApp.surface

                        Rectangle {
                            width:
                                parent.width *
                                audioApp.volume

                            height: parent.height

                            radius: 4

                            color: audioApp.primary
                        }
                    }

                    Rectangle {
                        width: 18
                        height: 18

                        radius: 9

                        x:
                            parent.width *
                            audioApp.volume -
                            width / 2

                        y:
                            parent.height / 2 -
                            height / 2

                        color: audioApp.primary

                        border.width: 2
                        border.color: audioApp.bg
                    }

                    MouseArea {
                        anchors.fill: parent

                        cursorShape:
                            Qt.PointingHandCursor

                        onPressed: mouse => {
                            audioApp.setVolume(
                                mouse.x / width
                            )
                        }

                        onPositionChanged: mouse => {
                            if (pressed) {
                                audioApp.setVolume(
                                    mouse.x / width
                                )
                            }
                        }

                        onWheel: wheel => {
                            audioApp.setVolume(
                                audioApp.volume +
                                (
                                    wheel.angleDelta.y > 0
                                    ? 0.05
                                    : -0.05
                                )
                            )
                        }
                    }
                }

                // =================================================
                // OUTPUT
                // =================================================

                Rectangle {
                    id: outputCard

                    Layout.fillWidth: true
                    Layout.preferredHeight: 55

                    radius: 12
                    color: audioApp.surface

                    border.width: 1
                    border.color: audioApp.outline

                    z: audioApp.outputExpanded ? 100 : 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 11
                        spacing: 10

                        Text {
                            text: "󰓃"
                            color: audioApp.primary
                            font.pixelSize: 21
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: "Output"
                                color: audioApp.text
                                opacity: 0.55
                                font.pixelSize: 10
                            }

                            Text {
                                Layout.fillWidth: true
                                text: audioApp.nodeName(audioApp.sink)
                                color: audioApp.text
                                font.pixelSize: 12
                                font.bold: true
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            text: audioApp.outputExpanded ? "󰅃" : "󰅀"
                            color: audioApp.primary
                            font.pixelSize: 17
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            audioApp.inputExpanded = false
                            audioApp.outputExpanded =
                                !audioApp.outputExpanded
                        }
                    }

                    Rectangle {
                        id: outputMenu

                        visible: audioApp.outputExpanded

                        anchors {
                            top: parent.bottom
                            left: parent.left
                            right: parent.right
                        }

                        anchors.topMargin: 6

                        height: Math.min(
                            250,
                            Math.max(50, outputColumn.implicitHeight + 16)
                        )

                        radius: 12
                        color: audioApp.bg

                        border.width: 1
                        border.color: audioApp.outline

                        z: 200
                        clip: true

                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 8
                            clip: true

                            ColumnLayout {
                                id: outputColumn

                                width: parent.width
                                spacing: 5

                                Repeater {
                                    model: Pipewire.nodes

                                    delegate: Rectangle {
                                        required property var modelData

                                        readonly property bool valid:
                                            modelData !== null &&
                                            modelData.ready &&
                                            !modelData.isStream &&
                                            modelData.isSink &&
                                            modelData.audio !== null

                                        visible: valid

                                        Layout.fillWidth: true
                                        Layout.preferredHeight:
                                            visible ? 44 : 0

                                        radius: 9

                                        color:
                                            modelData === audioApp.sink
                                            ? audioApp.primary
                                            : audioApp.surface

                                        border.width:
                                            modelData === audioApp.sink
                                            ? 0
                                            : 1

                                        border.color: audioApp.outline

                                        PwObjectTracker {
                                            objects:
                                                modelData
                                                ? [modelData]
                                                : []
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 9

                                            Text {
                                                text:
                                                    modelData === audioApp.sink
                                                    ? "󰄬"
                                                    : "󰋼"

                                                color:
                                                    modelData === audioApp.sink
                                                    ? audioApp.bg
                                                    : audioApp.primary

                                                font.pixelSize: 15
                                            }

                                            Text {
                                                Layout.fillWidth: true

                                                text:
                                                    audioApp.nodeName(modelData)

                                                color:
                                                    modelData === audioApp.sink
                                                    ? audioApp.bg
                                                    : audioApp.text

                                                font.pixelSize: 11
                                                font.bold:
                                                    modelData === audioApp.sink

                                                elide: Text.ElideRight
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape:
                                                Qt.PointingHandCursor

                                            onClicked:
                                                audioApp.selectOutput(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // =================================================
                // INPUT
                // =================================================

                Rectangle {
                    id: inputCard

                    Layout.fillWidth: true
                    Layout.preferredHeight: 55

                    radius: 12
                    color: audioApp.surface

                    border.width: 1
                    border.color: audioApp.outline

                    z: audioApp.inputExpanded ? 100 : 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 11
                        spacing: 10

                        Text {
                            text: "󰍬"
                            color: audioApp.primary
                            font.pixelSize: 21
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: "Input"
                                color: audioApp.text
                                opacity: 0.55
                                font.pixelSize: 10
                            }

                            Text {
                                Layout.fillWidth: true
                                text: audioApp.nodeName(audioApp.source)
                                color: audioApp.text
                                font.pixelSize: 12
                                font.bold: true
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            text: audioApp.inputExpanded ? "󰅃" : "󰅀"
                            color: audioApp.primary
                            font.pixelSize: 17
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            audioApp.outputExpanded = false
                            audioApp.inputExpanded =
                                !audioApp.inputExpanded
                        }
                    }

                    Rectangle {
                        id: inputMenu

                        visible: audioApp.inputExpanded

                        anchors {
                            top: parent.bottom
                            left: parent.left
                            right: parent.right
                        }

                        anchors.topMargin: 6

                        height: Math.min(
                            250,
                            Math.max(50, inputColumn.implicitHeight + 16)
                        )

                        radius: 12
                        color: audioApp.bg

                        border.width: 1
                        border.color: audioApp.outline

                        z: 200
                        clip: true

                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 8
                            clip: true

                            ColumnLayout {
                                id: inputColumn

                                width: parent.width
                                spacing: 5

                                Repeater {
                                    model: Pipewire.nodes

                                    delegate: Rectangle {
                                        required property var modelData

                                        readonly property bool valid:
                                            modelData !== null &&
                                            modelData.ready &&
                                            !modelData.isStream &&
                                            !modelData.isSink &&
                                            modelData.audio !== null

                                        visible: valid

                                        Layout.fillWidth: true
                                        Layout.preferredHeight:
                                            visible ? 44 : 0

                                        radius: 9

                                        color:
                                            modelData === audioApp.source
                                            ? audioApp.primary
                                            : audioApp.surface

                                        border.width:
                                            modelData === audioApp.source
                                            ? 0
                                            : 1

                                        border.color: audioApp.outline

                                        PwObjectTracker {
                                            objects:
                                                modelData
                                                ? [modelData]
                                                : []
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 9

                                            Text {
                                                text:
                                                    modelData === audioApp.source
                                                    ? "󰄬"
                                                    : "󰍬"

                                                color:
                                                    modelData === audioApp.source
                                                    ? audioApp.bg
                                                    : audioApp.primary

                                                font.pixelSize: 15
                                            }

                                            Text {
                                                Layout.fillWidth: true

                                                text:
                                                    audioApp.nodeName(modelData)

                                                color:
                                                    modelData === audioApp.source
                                                    ? audioApp.bg
                                                    : audioApp.text

                                                font.pixelSize: 11
                                                font.bold:
                                                    modelData === audioApp.source

                                                elide: Text.ElideRight
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape:
                                                Qt.PointingHandCursor

                                            onClicked:
                                                audioApp.selectInput(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // =================================================
                // APPLICATIONS
                // =================================================

                Text {
                    text: "Ứng dụng đang phát"

                    color: audioApp.text

                    font.pixelSize: 13
                    font.bold: true
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    clip: true

                    ColumnLayout {
                        width: parent.width

                        spacing: 8

Repeater {
    model: Pipewire.nodes

    delegate: Rectangle {
        required property var modelData
        required property int index

readonly property bool valid:
    modelData !== null &&
    modelData.ready &&
    modelData.isStream &&
    modelData.audio !== null &&
    modelData.properties &&
    modelData.properties["media.class"] === "Stream/Output/Audio" &&
    modelData.properties["media.name"] !== "Quickshell Networking API"

        readonly property string applicationName:
            modelData &&
            modelData.properties &&
            modelData.properties["application.name"]
                ? modelData.properties["application.name"]
                : (
                    modelData
                    ? (
                        modelData.description ||
                        modelData.name ||
                        "Unknown"
                    )
                    : "Unknown"
                )

        // Chỉ lấy stream đầu tiên của mỗi ứng dụng

visible: valid

        Layout.fillWidth: true

        Layout.preferredHeight:
            visible ? 54 : 0

        color: "transparent"

        PwObjectTracker {
            objects:
                modelData
                ? [modelData]
                : []
        }

        IconImage {
            id: applicationIcon

            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }

            implicitSize: 22

            source:
                audioApp.appIcon(
                    modelData
                )
        }

        Text {
            anchors {
                left: applicationIcon.right
                leftMargin: 8
                right: parent.right
                top: parent.top
            }

            height: 20

            text: applicationName

            color: audioApp.text

            font.pixelSize: 11
            font.bold: true

            elide: Text.ElideRight
        }

        Text {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }

            text:
                modelData.audio
                ? Math.round(
                    modelData.audio.volume * 100
                ) + "%"
                : "0%"

            color: audioApp.primary

            font.pixelSize: 10
        }

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            height: 6

            radius: 3

            color: audioApp.surface

            Rectangle {
                width:
                    modelData.audio
                    ? parent.width *
                      modelData.audio.volume
                    : 0

                height: parent.height

                radius: 3

                color:
                    modelData.audio &&
                    modelData.audio.muted
                    ? audioApp.outline
                    : audioApp.primary
            }

            MouseArea {
                anchors.fill: parent

                cursorShape:
                    Qt.PointingHandCursor

                onPressed: mouse => {
                    if (!modelData.audio)
                        return

                    modelData.audio.muted = false

                    modelData.audio.volume =
                        Math.max(
                            0,
                            Math.min(
                                1,
                                mouse.x / width
                            )
                        )
                }

                onPositionChanged: mouse => {
                    if (pressed &&
                        modelData.audio) {

                        modelData.audio.muted = false

                        modelData.audio.volume =
                            Math.max(
                                0,
                                Math.min(
                                    1,
                                    mouse.x / width
                                )
                            )
                    }
                }
            }
        }
    }
}

                    }
                }

                // =================================================
                // NOW PLAYING / MEDIA
                // =================================================

                Rectangle {
                    id: nowPlayingCard

                    visible: audioApp.mediaPlayer !== null

                    Layout.fillWidth: true
                    Layout.preferredHeight: 158

                    radius: 14

                    color: audioApp.surface

                    border.width: 1
                    border.color: audioApp.outline

                    clip: true

                    RowLayout {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                        }

                        anchors.margins: 12

                        height: 78

                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 72
                            Layout.preferredHeight: 72

                            radius: 10

                            color: audioApp.bg

                            clip: true

                            Image {
                                anchors.fill: parent

                                source:
                                    audioApp.mediaPlayer &&
                                    audioApp.mediaPlayer.trackArtUrl
                                    ? audioApp.mediaPlayer.trackArtUrl
                                    : ""

                                fillMode: Image.PreserveAspectCrop

                                asynchronous: true

                                smooth: true
                            }

                            Text {
                                anchors.centerIn: parent

                                visible:
                                    !(
                                        audioApp.mediaPlayer &&
                                        audioApp.mediaPlayer.trackArtUrl
                                    )

                                text: "󰎆"

                                color: audioApp.primary

                                font.pixelSize: 28
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter

                            spacing: 3

                            Text {
                                Layout.fillWidth: true

                                text:
                                    audioApp.mediaPlayer
                                    ? (
                                        audioApp.mediaPlayer.trackTitle ||
                                        "Unknown Title"
                                    )
                                    : ""

                                color: audioApp.text

                                font.pixelSize: 13
                                font.bold: true

                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true

                                text:
                                    audioApp.mediaPlayer
                                    ? (
                                        audioApp.mediaPlayer.trackArtist ||
                                        audioApp.mediaPlayer.trackAlbumArtist ||
                                        audioApp.mediaPlayer.identity ||
                                        "Unknown Artist"
                                    )
                                    : ""

                                color: audioApp.text

                                opacity: 0.62

                                font.pixelSize: 11

                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true

                                text:
                                    audioApp.mediaPlayer
                                    ? audioApp.mediaPlayer.identity
                                    : ""

                                color: audioApp.primary

                                opacity: 0.8

                                font.pixelSize: 9

                                elide: Text.ElideRight
                            }
                        }
                    }

                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            topMargin: 91
                        }

                        height: 5

                        radius: 3

                        color: audioApp.bg

                        Rectangle {
                            width:
                                audioApp.mediaPlayer &&
                                audioApp.mediaPlayer.length > 0
                                ? parent.width *
                                  Math.min(
                                      1,
                                      Math.max(
                                          0,
                                          audioApp.mediaPlayer.position /
                                          audioApp.mediaPlayer.length
                                      )
                                  )
                                : 0

                            height: parent.height

                            radius: 3

                            color: audioApp.primary
                        }

                        MouseArea {
                            anchors.fill: parent

                            enabled:
                                audioApp.mediaPlayer !== null &&
                                audioApp.mediaPlayer.canSeek &&
                                audioApp.mediaPlayer.positionSupported &&
                                audioApp.mediaPlayer.lengthSupported

                            cursorShape:
                                enabled
                                ? Qt.PointingHandCursor
                                : Qt.ArrowCursor

                            onClicked: mouse => {
                                if (!audioApp.mediaPlayer ||
                                    !enabled)
                                    return

                                var ratio =
                                    Math.max(
                                        0,
                                        Math.min(
                                            1,
                                            mouse.x / width
                                        )
                                    )

                                audioApp.mediaPlayer.position =
                                    ratio *
                                    audioApp.mediaPlayer.length
                            }
                        }
                    }

                    RowLayout {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            topMargin: 101
                            bottom: parent.bottom
                        }

                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.bottomMargin: 8

                        spacing: 8

                        Text {
                            text:
                                audioApp.mediaPlayer
                                ? audioApp.mediaTime(
                                    audioApp.mediaPlayer.position
                                )
                                : "0:00"

                            color: audioApp.text

                            opacity: 0.65

                            font.pixelSize: 10
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text:
                                audioApp.mediaPlayer
                                ? audioApp.mediaTime(
                                    audioApp.mediaPlayer.length
                                )
                                : "0:00"

                            color: audioApp.text

                            opacity: 0.65

                            font.pixelSize: 10
                        }

                        Item {
                            Layout.preferredWidth: 4
                        }

                        Text {
                            text: "󰒮"

                            visible:
                                audioApp.mediaPlayer &&
                                audioApp.mediaPlayer.canGoPrevious

                            color: audioApp.primary

                            font.pixelSize: 18

                            MouseArea {
                                anchors.fill: parent

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked:
                                    audioApp.mediaPlayer.previous()
                            }
                        }

                        Text {
                            text:
                                audioApp.mediaPlayer &&
                                audioApp.mediaPlayer.isPlaying
                                ? "󰏤"
                                : "󰐊"

                            visible:
                                audioApp.mediaPlayer &&
                                audioApp.mediaPlayer.canTogglePlaying

                            color: audioApp.primary

                            font.pixelSize: 20

                            MouseArea {
                                anchors.fill: parent

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked:
                                    audioApp.mediaPlayer.togglePlaying()
                            }
                        }

                        Text {
                            text: "󰒭"

                            visible:
                                audioApp.mediaPlayer &&
                                audioApp.mediaPlayer.canGoNext

                            color: audioApp.primary

                            font.pixelSize: 18

                            MouseArea {
                                anchors.fill: parent

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked:
                                    audioApp.mediaPlayer.next()
                            }
                        }
                    }
                }

            }
        }
    }
}

