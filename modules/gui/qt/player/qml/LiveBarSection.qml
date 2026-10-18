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
import VLC.Dialogs
import VLC.Player

// One part (left, center or right) of a player bar while the player is
// customized in place (VLC Redesign "Player - customize"): the controls in
// dashed boxes, dragged within and between the bars, from the Customize
// Player panel into a bar, or out of a bar onto the panel.
//
// Drag sources (here and in CustomizePlayerPanel.qml) carry:
//   barControlId  the control (ControlListModel.ControlType)
//   barModel      the ControlListModel it comes from, null from the panel
//   barIndex      its index in barModel
Item {
    id: section

    // ControlListModel
    property var model: null

    // the controls at the right end (right part of a bar)
    property bool alignRight: false

    readonly property bool _hasSeekBar: {
        void repeater.count
        return !!model && model.getControls().includes(ControlListModel.SEEK_BAR)
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    readonly property real _pad: VLCStyle.dp(3, VLCStyle.scale)

    implicitWidth: Math.max(row.implicitWidth + 2 * _pad, VLCStyle.dp(40, VLCStyle.scale))
    implicitHeight: row.implicitHeight + 2 * _pad

    // moves, adds or takes over the dragged control so that it is at `index`
    // whether the dragged control can be dropped here: the seek bar
    // (ControlListModel.SEEK_BAR) is not moved, and nothing goes next to it
    function accepts(src) {
        if (!src || src.barControlId === undefined || !section.model)
            return false
        return src.barControlId !== ControlListModel.SEEK_BAR && !section._hasSeekBar
    }

    function dropAt(drop, index) {
        const src = drop.source
        if (!section.accepts(src))
            return
        const target = section.model
        const from = src.barModel
        const fromIndex = src.barIndex
        const id = src.barControlId
        drop.accept(Qt.MoveAction)
        // later: the dragged control may be deleted by the change, and it
        // is still in its mouse handler
        Qt.callLater(() => {
            if (from === target) {
                const dest = (fromIndex < index) ? index - 1 : index
                if (dest !== fromIndex)
                    target.move(fromIndex, dest)
            } else {
                target.insert(index, { "id": id })
                if (from)
                    from.remove(fromIndex)
            }
        })
    }

    DashedBorder {
        anchors.fill: parent
        radius: VLCStyle.dp(4, VLCStyle.scale)
        dash: 4
        gap: 3
        color: Qt.alpha(theme.fg.secondary, 0.6)
    }

    // dropped after the last control
    DropArea {
        id: endDrop

        anchors.fill: parent
        onEntered: (drag) => { drag.accepted = section.accepts(drag.source) }
        onDropped: (drop) => section.dropAt(drop, repeater.count)
    }

    Rectangle {
        visible: endDrop.containsDrag && !row.childDrop && !section._hasSeekBar
        x: row.x + row.width
        anchors.verticalCenter: parent.verticalCenter
        width: VLCStyle.dp(2, VLCStyle.scale)
        height: VLCStyle.icon_medium
        color: theme.accent
    }

    Row {
        id: row

        // a control of this row shows its own drop marker
        property bool childDrop: false

        x: section.alignRight ? section.width - section._pad - width : section._pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: VLCStyle.dp(4, VLCStyle.scale)

        Repeater {
            id: repeater

            model: section.model

            delegate: Item {
                id: entry

                required property int index
                required property var model

                // drag protocol (see the top of the file)
                readonly property int barControlId: model.id
                readonly property var barModel: section.model
                readonly property int barIndex: index

                readonly property bool _seekBar: barControlId === ControlListModel.SEEK_BAR
                readonly property var _control: _seekBar ? { "label": "", "source": "" }
                                                         : PlayerControlbarControls.control(barControlId)

                implicitWidth: _seekBar ? VLCStyle.dp(160, VLCStyle.scale)
                                        : Math.max(loader.implicitWidth, VLCStyle.dp(20, VLCStyle.scale)) + 2 * section._pad
                implicitHeight: Math.max(loader.implicitHeight, VLCStyle.icon_toolbar) + 2 * section._pad
                // the seek bar takes the whole part (it is alone there)
                width: _seekBar ? Math.max(implicitWidth, section.width - 2 * section._pad) : implicitWidth
                height: implicitHeight

                // the seek bar: times and track as in the bar
                Item {
                    anchors.fill: parent
                    anchors.margins: VLCStyle.margin_xsmall
                    visible: entry._seekBar

                    Text {
                        id: seekTime
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: Player.time.formatHMS(0)
                        color: theme.fg.secondary
                        font.pixelSize: VLCStyle.fontSize_normal
                    }
                    Text {
                        id: seekLength
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Player.length.formatHMS(0)
                        color: theme.fg.secondary
                        font.pixelSize: VLCStyle.fontSize_normal
                    }
                    Rectangle {
                        id: seekTrack
                        anchors.left: seekTime.right
                        anchors.right: seekLength.left
                        anchors.margins: VLCStyle.margin_xsmall
                        anchors.verticalCenter: parent.verticalCenter
                        height: VLCStyle.dp(24, VLCStyle.scale)
                        radius: VLCStyle.dp(4, VLCStyle.scale)
                        color: Qt.alpha(theme.fg.primary, 0.08)

                        Rectangle {
                            width: Math.max(height, parent.width * Math.max(0, Math.min(1, Player.position)))
                            height: parent.height
                            radius: parent.radius
                            color: Qt.alpha(theme.accent, 0.35)
                        }
                    }
                }

                opacity: mouse.drag.active ? 0.3 : 1.0

                Loader {
                    id: loader

                    anchors.centerIn: parent
                    active: !entry._seekBar
                    source: entry._control.source
                    onLoaded: {
                        item.paintOnly = true
                        item.enabled = false
                    }
                }

                DashedBorder {
                    anchors.fill: parent
                    radius: VLCStyle.dp(3, VLCStyle.scale)
                    dash: 3
                    gap: 2
                    color: Qt.alpha(theme.fg.secondary, mouse.containsMouse ? 0.9 : 0.5)
                }

                // dropped before this control
                DropArea {
                    id: drop

                    anchors.fill: parent
                    onEntered: (drag) => { drag.accepted = section.accepts(drag.source) }
                    onContainsDragChanged: row.childDrop = containsDrag
                    onDropped: (drop) => section.dropAt(drop, entry.index)
                }

                Rectangle {
                    visible: drop.containsDrag && drop.drag.source !== entry
                    x: -VLCStyle.dp(3, VLCStyle.scale)
                    anchors.verticalCenter: parent.verticalCenter
                    width: VLCStyle.dp(2, VLCStyle.scale)
                    height: VLCStyle.icon_medium
                    color: theme.accent
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    enabled: !entry._seekBar // the seek bar stays where it is
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

                // what follows the mouse, above everything in the window
                Rectangle {
                    id: ghost

                    parent: T.Overlay.overlay
                    visible: mouse.drag.active
                    width: VLCStyle.dp(40, VLCStyle.scale)
                    height: VLCStyle.dp(40, VLCStyle.scale)
                    radius: VLCStyle.dp(6, VLCStyle.scale)
                    color: Qt.alpha(theme.bg.primary, 0.9)
                    border.color: theme.accent
                    border.width: VLCStyle.dp(1, VLCStyle.scale)

                    Drag.active: mouse.drag.active
                    Drag.source: entry
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    Text {
                        anchors.centerIn: parent
                        text: entry._control.label ?? ""
                        font.family: VLCIcons.fontFamily
                        font.pixelSize: VLCStyle.icon_normal
                        color: theme.fg.primary
                    }
                }
            }
        }
    }
}
