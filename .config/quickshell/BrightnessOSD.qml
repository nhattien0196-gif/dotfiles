import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

Scope {
    id: brightnessOsd

    property bool osdVisible: false
    property real brightness: 0.0
    property real lastBrightness: -1.0

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

    readonly property color textColor:
        matugenColor("on_surface", "#ffffff")

    readonly property color outline:
        matugenColor("outline_variant", "#666666")
    Timer {
        id: hideTimer
        interval: 1100
        repeat: false
        onTriggered: brightnessOsd.osdVisible = false
    }

    Timer {
        id: pollTimer
        interval: 120
        repeat: true
        running: true

        onTriggered: readBrightness.running = true
    }

    Process {
        id: readBrightness

        command: [
            "sh",
            "-c",
            "brightnessctl -m 2>/dev/null | awk -F, 'NR==1 {gsub(/%/,\"\",$4); print $4}'"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                var value = parseFloat(text.trim())

                if (isNaN(value))
                    return

                var normalized = Math.max(0, Math.min(100, value))

                brightnessOsd.brightness = normalized / 100.0

                if (brightnessOsd.lastBrightness >= 0 &&
                    Math.abs(normalized - brightnessOsd.lastBrightness) > 0.01) {

                    brightnessOsd.osdVisible = true
                    hideTimer.restart()
                }

                brightnessOsd.lastBrightness = normalized
            }
        }
    }

    IpcHandler {
        target: "brightness-osd"

        function show(): void {
            brightnessOsd.osdVisible = true
            hideTimer.restart()
            readBrightness.running = true
        }

        function hide(): void {
            brightnessOsd.osdVisible = false
            hideTimer.stop()
        }

        function toggle(): void {
            brightnessOsd.osdVisible = !brightnessOsd.osdVisible

            if (brightnessOsd.osdVisible)
                hideTimer.restart()
            else
                hideTimer.stop()
        }
    }

    PanelWindow {
        id: root

        visible: brightnessOsd.osdVisible

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay

        WlrLayershell.keyboardFocus:
            WlrKeyboardFocus.None

        exclusionMode: ExclusionMode.Ignore

        Rectangle {
            id: osdCard

            width: 190
            height: 135

            anchors.centerIn: parent

            radius: 18

color: Qt.rgba(
    brightnessOsd.bg.r,
    brightnessOsd.bg.g,
    brightnessOsd.bg.b,
    0.78
)

            border.width: 1

border.color: Qt.rgba(
    brightnessOsd.outline.r,
    brightnessOsd.outline.g,
    brightnessOsd.outline.b,
    0.55
)
            opacity: brightnessOsd.osdVisible ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: 130
                    easing.type: Easing.OutCubic
                }
            }

            Column {
                anchors.centerIn: parent

                spacing: 10

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter

                    text: brightnessOsd.brightness <= 0.01
                          ? "☀"
                          : brightnessOsd.brightness < 0.35
                            ? "☼"
                            : "☀"

                    color: brightnessOsd.primary

                    font.pixelSize: 42
                    font.bold: true
                }

                Rectangle {
                    width: 154
                    height: 8

                    radius: 4

                    color: Qt.rgba(
                        1,
                        1,
                        1,
                        0.10
                    )

                    Rectangle {
                        width:
                            parent.width *
                            brightnessOsd.brightness

                        height: parent.height

                        radius: 4

                        color: brightnessOsd.primary

                        Behavior on width {
                            NumberAnimation {
                                duration: 100
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter

                    text:
                        Math.round(
                            brightnessOsd.brightness * 100
                        ) + "%"

                    color: brightnessOsd.textColor

                    font.pixelSize: 15
                    font.bold: true
                }
            }
        }
    }
}
