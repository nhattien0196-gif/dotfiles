import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Scope {
    id: volumeOsd

    // ============================================================
    // MATUGEN COLORS
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

        var re1 = new RegExp(
            "@define-color\\s+" + name + "\\s+([^;]+);"
        )

        var match1 = css.match(re1)
        if (match1 && match1.length > 1)
            return match1[1].trim()

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

    readonly property bool audioReady:
        sink !== null &&
        sink.ready &&
        sink.audio !== null

    readonly property real volume:
        audioReady ? sink.audio.volume : 0

    readonly property bool muted:
        audioReady ? sink.audio.muted : false

    readonly property int percent:
        Math.round(volume * 100)

    PwObjectTracker {
        objects: sink !== null ? [sink] : []
    }

    // ============================================================
    // AUTO HIDE
    // ============================================================

    Timer {
        id: hideTimer
        interval: 1100
        repeat: false

        onTriggered: volumeOsd.hideOsd()
    }

    Timer {
        id: finishHideTimer
        interval: 180
        repeat: false

        onTriggered: root.visible = false
    }

    function showOsd() {
        if (!audioReady)
            return

        finishHideTimer.stop()
        root.visible = true
        osdCard.opacity = 1
        osdCard.scale = 1
        hideTimer.restart()
    }

    function hideOsd() {
        hideTimer.stop()
        osdCard.opacity = 0
        osdCard.scale = 0.96
        finishHideTimer.restart()
    }

    // ============================================================
    // WATCH REAL VOLUME CHANGES
    // ============================================================

    Connections {
        target: volumeOsd.sink && volumeOsd.sink.audio
                 ? volumeOsd.sink.audio
                 : null

        function onVolumeChanged() {
            volumeOsd.showOsd()
        }

        function onMutedChanged() {
            volumeOsd.showOsd()
        }
    }

    // ============================================================
    // OPTIONAL IPC
    // ============================================================

    IpcHandler {
        target: "volume-osd"

        function show(): void {
            volumeOsd.showOsd()
        }

        function hide(): void {
            volumeOsd.hideOsd()
        }

        function toggle(): void {
            if (root.visible)
                volumeOsd.hideOsd()
            else
                volumeOsd.showOsd()
        }
    }

    // ============================================================
    // OSD WINDOW
    // ============================================================

    PanelWindow {
        id: root

        visible: false

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Do not reserve screen space.
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        Rectangle {
            id: osdCard

            anchors.centerIn: parent

            width: 190
            height: 135

            radius: 20

color: Qt.rgba(
    volumeOsd.bg.r,
    volumeOsd.bg.g,
    volumeOsd.bg.b,
    0.9
)
            border.width: 1
            border.color: volumeOsd.outline

            opacity: 0
            scale: 0.96

            Behavior on opacity {
                NumberAnimation {
                    duration: 130
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 130
                    easing.type: Easing.OutCubic
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18

                spacing: 9

                Text {
                    Layout.alignment: Qt.AlignHCenter

                    text:
                        volumeOsd.muted || volumeOsd.percent <= 0
                        ? "󰝟"
                        : volumeOsd.percent < 35
                          ? "󰕿"
                          : volumeOsd.percent < 70
                            ? "󰖀"
                            : "󰕾"

                    color: volumeOsd.primary
                    font.pixelSize: 34
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8

                    radius: 4
                    color: volumeOsd.surface

                    Rectangle {
                        width:
                            parent.width *
                            Math.max(0, Math.min(1, volumeOsd.volume))

                        height: parent.height
                        radius: 4

                        color: volumeOsd.primary
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter

                    text:
                        volumeOsd.muted
                        ? "Đã tắt tiếng"
                        : volumeOsd.percent + "%"

                    color: volumeOsd.text
                    font.pixelSize: 14
                    font.bold: true
                }
            }
        }
    }
}
