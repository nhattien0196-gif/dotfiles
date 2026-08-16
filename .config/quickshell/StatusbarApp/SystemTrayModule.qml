import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

// System tray (StatusNotifierItem / AppIndicator hosts).
RowLayout {
    id: tray

    spacing: 10

    // Hide the module when there are no tray items.
    readonly property bool collapsed:
        SystemTray.items.values.length === 0

    // Keep the bar expanded while a tray menu is open.
    property int openMenuCount: 0

    readonly property bool menuOpen:
        openMenuCount > 0


    // ============================================================
    // CUSTOM WIFI APP
    // ============================================================


    // ============================================================
    // SYSTEM TRAY ITEMS
    // ============================================================

    Repeater {
        model: SystemTray.items

        delegate: MouseArea {
            id: trayItem

            required property var modelData

            implicitWidth: 20
            implicitHeight: 20

            Layout.alignment:
                Qt.AlignVCenter

            hoverEnabled: true

            cursorShape:
                Qt.PointingHandCursor

            acceptedButtons:
                Qt.LeftButton | Qt.RightButton


            // ====================================================
            // TRAY ICON
            // ====================================================

            Image {
                anchors.centerIn: parent

                source:
                    trayItem.modelData.icon

                width: 18
                height: 18

                sourceSize.width: 18
                sourceSize.height: 18

                fillMode:
                    Image.PreserveAspectFit
            }


            // ====================================================
            // CLICK HANDLER
            // ====================================================

            onClicked: (mouse) => {
console.log(
        "TRAY:",
        "id=", modelData.id,
        "title=", modelData.title,
        "tooltip=", modelData.tooltip,
        "button=", mouse.button
    )
                // ------------------------------------------------
                // NETWORKMANAGER / NM-APPLET
                //
                // This is the EXACT ID confirmed through D-Bus:
                //
                // org.freedesktop.network-manager-applet
                // /org/ayatana/NotificationItem/nm_applet
                // Id = nm-applet
                // ------------------------------------------------

                if (
                    mouse.button === Qt.LeftButton
                    &&
                    String(modelData.id) === "nm-applet"
                ) {

                    console.log(
                        "NetworkManager clicked -> opening WifiApp"
                    )

Quickshell.execDetached([
    "qs",
    "ipc",
    "call",
    "wifi",
    "toggle"
])
                    return
                }


                // ------------------------------------------------
                // ALL OTHER TRAY APPLICATIONS
                //
                // Keep the original ML4W behavior unchanged.
                // ------------------------------------------------

                if (
                    mouse.button === Qt.LeftButton
                    &&
                    !modelData.onlyMenu
                ) {

                    modelData.activate()

                } else if (
                    modelData.hasMenu
                ) {

                    trayMenu.open()
                }
            }


            // ====================================================
            // TRAY CONTEXT MENU
            // ====================================================

            QsMenuAnchor {
                id: trayMenu

                menu:
                    trayItem.modelData.menu

                anchor.item:
                    trayItem

                anchor.edges:
                    Edges.Bottom

                anchor.gravity:
                    Edges.Bottom


                // Keep the statusbar expanded while the menu exists.
                onOpened:
                    tray.openMenuCount++

                onClosed:
                    tray.openMenuCount--
            }
        }
    }
}
