/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * Authors: Oliver Bacon <oliverbacon@tutamail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.PlayerControls
import VLC.Widgets as Widgets
import VLC.Dialogs

// "Customize Player" of the VLC Redesign (Figma "Player - customize"),
// inside the player window while its bars are edited in place
// (MainCtx.playerCustomizing, LiveBarSection.qml): the controls that are
// in none of the bars, to drag into them; a control dragged onto the panel
// leaves its bar. "Save" keeps the bars, "Cancel" brings back the saved
// ones.
Item {
    id: root

    // the edited bars (PlayerControlbarModel), e.g. top bar and control bar
    property var barModels: []

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    readonly property real dp1: VLCStyle.dp(1, VLCStyle.scale)

    // controls that can be in a bar more than once
    readonly property var _repeatable: [ControlListModel.WIDGET_SPACER,
                                        ControlListModel.WIDGET_SPACER_EXTEND,
                                        ControlListModel.DIVIDER]

    // incremented when a bar changes
    property int _revision: 0

    readonly property var _lists: {
        const lists = []
        for (const m of barModels) {
            if (!m)
                continue
            lists.push(m.left, m.center, m.right)
        }
        return lists.filter((l) => !!l)
    }

    readonly property var available: {
        void _revision
        const present = new Set()
        for (const l of _lists)
            for (const id of l.getControls())
                present.add(id)
        return PlayerControlbarControls.controlList.filter((c) => _repeatable.includes(c.id) || !present.has(c.id))
    }

    function close(save) {
        if (save)
            MainCtx.controlbarProfileModel.save()
        else
            MainCtx.controlbarProfileModel.reload()
        MainCtx.playerCustomizing = false
    }

    Shortcut {
        sequence: StandardKey.Cancel
        onActivated: root.close(false)
    }

    // leaving the player cancels the changes
    Connections {
        target: MainCtx
        function onMainInterfaceModesChanged() {
            if (!MainCtx.playerView && MainCtx.playerCustomizing)
                root.close(false)
        }
    }

    Repeater {
        model: root._lists
        delegate: Item {
            required property var modelData
            Connections {
                target: modelData
                function onCountChanged() { root._revision++ }
            }
        }
    }

    Rectangle {
        id: panel

        anchors.centerIn: parent
        width: Math.min(1048 * root.dp1, root.width - 40 * root.dp1)
        height: Math.min(655 * root.dp1, root.height - 20 * root.dp1)
        radius: 14 * root.dp1
        color: Qt.alpha("#0E0E0E", 0.95)
        clip: true

        // clicks on the panel do not reach the video
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: (wheel) => wheel.accepted = true
        }

        // a control dragged here leaves its bar
        DropArea {
            id: removeDrop

            anchors.fill: parent
            onDropped: (drop) => {
                const src = drop.source
                if (!src || !src.barModel)
                    return
                const from = src.barModel
                const index = src.barIndex
                drop.accept(Qt.MoveAction)
                Qt.callLater(() => from.remove(index))
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: removeDrop.containsDrag && !!removeDrop.drag.source?.barModel
            color: "transparent"
            border.color: theme.accent
            border.width: 2 * root.dp1
        }

        // header
        Text {
            x: 19 * root.dp1
            y: 16 * root.dp1
            text: qsTr("Customize Player")
            color: "#8F8F8F"
            font.pixelSize: 14 * root.dp1
        }

        Widgets.IconToolButton {
            anchors.right: parent.right
            anchors.rightMargin: 10 * root.dp1
            y: 6 * root.dp1
            text: VLCIcons.close
            description: qsTr("Cancel")
            onClicked: root.close(false)
        }

        Text {
            id: hint

            x: 19 * root.dp1
            y: 60 * root.dp1
            width: parent.width - 38 * root.dp1
            text: qsTr("Drag items around and out of the box below to re-order them. Drag items into the box to remove them from the player.")
            wrapMode: Text.WordWrap
            color: "#6B6B6B"
            font.pixelSize: 14 * root.dp1
        }

        GridView {
            id: grid

            anchors.top: hint.bottom
            anchors.topMargin: 20 * root.dp1
            anchors.bottom: buttons.top
            anchors.bottomMargin: 10 * root.dp1
            anchors.left: parent.left
            anchors.leftMargin: 20 * root.dp1
            anchors.right: parent.right
            anchors.rightMargin: 20 * root.dp1
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            cellWidth: 110 * root.dp1
            cellHeight: 98 * root.dp1

            T.ScrollBar.vertical: Widgets.ScrollBarExt { }

            model: root.available

            delegate: Item {
                id: cell

                required property var modelData

                // drag protocol (LiveBarSection.qml): from the panel
                readonly property int barControlId: modelData.id
                readonly property var barModel: null
                readonly property int barIndex: -1

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4 * root.dp1
                    radius: 6 * root.dp1
                    color: cellMouse.containsMouse && !cellMouse.drag.active ? Qt.alpha(theme.fg.primary, 0.05)
                                                                            : "transparent"
                }

                Item {
                    id: iconBox

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 18 * root.dp1
                    width: 24 * root.dp1
                    height: 24 * root.dp1

                    DashedBorder {
                        anchors.fill: parent
                        anchors.margins: -4 * root.dp1
                        radius: 4
                        dash: 2
                        gap: 2
                        color: "#8F8F8F"
                        opacity: 0.6
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.label ?? ""
                        font.family: VLCIcons.fontFamily
                        font.pixelSize: 18 * root.dp1
                        color: "#8F8F8F"
                    }
                }

                Text {
                    anchors.top: iconBox.bottom
                    anchors.topMargin: 12 * root.dp1
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 4 * root.dp1
                    anchors.rightMargin: 4 * root.dp1
                    text: cell.modelData.text
                    color: "#8F8F8F"
                    font.pixelSize: 13 * root.dp1
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: cellMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    preventStealing: true

                    drag.target: ghost
                    drag.smoothed: false

                    onPressed: (mouse) => {
                        const p = mapToItem(ghost.parent, mouse.x, mouse.y)
                        ghost.x = p.x - ghost.width / 2
                        ghost.y = p.y - ghost.height / 2
                    }
                    onReleased: ghost.Drag.drop()
                }

                Rectangle {
                    id: ghost

                    parent: T.Overlay.overlay
                    visible: cellMouse.drag.active
                    width: 40 * root.dp1
                    height: 40 * root.dp1
                    radius: 6 * root.dp1
                    color: Qt.alpha(theme.bg.primary, 0.9)
                    border.color: theme.accent
                    border.width: root.dp1

                    Drag.active: cellMouse.drag.active
                    Drag.source: cell
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.label ?? ""
                        font.family: VLCIcons.fontFamily
                        font.pixelSize: VLCStyle.icon_normal
                        color: theme.fg.primary
                    }
                }
            }
        }

        // Cancel / Restore Default ... Save (Figma: 100 x 32)
        Item {
            id: buttons

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 20 * root.dp1
            height: 32 * root.dp1

            component PanelButton: T.Button {
                id: btn
                property color fill: "#1B1B1B"
                property color textColor: "#8F8F8F"
                implicitWidth: Math.max(100 * root.dp1, label.implicitWidth + 24 * root.dp1)
                implicitHeight: 32 * root.dp1
                background: Rectangle {
                    radius: 6 * root.dp1
                    color: btn.hovered ? Qt.lighter(btn.fill, 1.3) : btn.fill
                }
                contentItem: Text {
                    id: label
                    text: btn.text
                    color: btn.textColor
                    font.pixelSize: 13 * root.dp1
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Row {
                spacing: 10 * root.dp1
                PanelButton {
                    text: qsTr("Cancel")
                    onClicked: root.close(false)
                }
                PanelButton {
                    text: qsTr("Restore Default")
                    onClicked: MainCtx.controlbarProfileModel.restoreSelectedDefault()
                }
            }

            PanelButton {
                anchors.right: parent.right
                text: qsTr("Save")
                fill: "#371F06"
                textColor: "#D37918"
                onClicked: root.close(true)
            }
        }
    }
}
