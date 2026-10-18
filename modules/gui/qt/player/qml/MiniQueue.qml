/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
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
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Playlist
import VLC.Style
import VLC.Widgets as Widgets

// Play queue part of the library miniplayer card (VLC Redesign video,
// 11:52): "Queue" title, item count and duration, sort / repeat / shuffle /
// remove / add, and plain rows (current item with a play mark, the others
// with a handle to drag them to another place).
Item {
    id: root

    // the card to move when the title is dragged
    property Item dragTarget: null
    property real dragXMin: 0
    property real dragXMax: 0
    property real dragYMin: 0
    property real dragYMax: 0

    signal addRequested()
    signal dragStarted()

    readonly property bool dark: VLCStyle.palette?.isDark ?? true
    readonly property color listColor: dark ? "#242424" : "#DEDEDE"
    readonly property color hoverColor: dark ? "#2E2E2E" : "#D2D2D2"
    readonly property color titleColor: dark ? "#C6C6C6" : "#161616"
    readonly property color textColor: dark ? "#8F8F8F" : "#2E2E2E"
    readonly property color dimColor: "#6B6B6B"
    readonly property color accentColor: VLCStyle.palette.orange500
    readonly property real dp1: VLCStyle.dp(1, VLCStyle.scale)

    property int selectedRow: -1

    readonly property PlaylistListModel queueModel: PlaylistListModel {
        playlist: MainPlaylistController.playlist
    }

    implicitHeight: 300 * dp1

    // keeps clicks on empty parts from reaching the card's tap handler
    // (which toggles play / pause)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: (wheel) => { wheel.accepted = true }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // title (drags the card)
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 44 * root.dp1

            Text {
                anchors.centerIn: parent
                text: qsTr("Queue")
                color: root.titleColor
                font.pixelSize: 14 * root.dp1
            }

            DragHandler {
                target: root.dragTarget
                enabled: !!root.dragTarget
                cursorShape: Qt.DragMoveCursor
                xAxis.minimum: root.dragXMin
                xAxis.maximum: root.dragXMax
                yAxis.minimum: root.dragYMin
                yAxis.maximum: root.dragYMax

                onActiveChanged: {
                    if (active)
                        root.dragStarted()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 10 * root.dp1
            color: root.listColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8 * root.dp1
                spacing: 4 * root.dp1

                // count, duration, actions
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 10 * root.dp1
                    spacing: 2 * root.dp1

                    Text {
                        Layout.fillWidth: true
                        text: (root.queueModel.count === 1 ? qsTr("1 item - %1")
                                                           : qsTr("%1 items - %2").arg(root.queueModel.count))
                              .arg(root.queueModel.duration.formatHMS())
                        color: root.dimColor
                        font.pixelSize: 12 * root.dp1
                        elide: Text.ElideRight
                    }

                    Widgets.SortControl {
                        font.pixelSize: VLCStyle.icon_normal
                        description: qsTr("Sort")
                        enabled: MainPlaylistController.count > 1
                        checked: MainPlaylistController.sortKey !== PlaylistController.SORT_KEY_NONE
                        popupAbove: false
                        model: MainPlaylistController.sortKeyTitleList

                        onSortSelected: (key) => {
                            MainPlaylistController.sortKey = key
                        }

                        onSortOrderSelected: (type) => {
                            if (type === Qt.AscendingOrder)
                                MainPlaylistController.sortOrder = PlaylistController.SORT_ORDER_ASC
                            else if (type === Qt.DescendingOrder)
                                MainPlaylistController.sortOrder = PlaylistController.SORT_ORDER_DESC

                            MainPlaylistController.sort()
                        }

                        sortOrder: MainPlaylistController.sortOrder === PlaylistController.SORT_ORDER_DESC
                                   ? Qt.DescendingOrder : Qt.AscendingOrder
                        sortKey: MainPlaylistController.sortKey
                    }

                    Widgets.IconToolButton {
                        font.pixelSize: VLCStyle.icon_normal
                        text: MainPlaylistController.repeatMode === PlaylistController.PLAYBACK_REPEAT_CURRENT
                              ? VLCIcons.repeat_one : VLCIcons.repeat_all
                        checked: MainPlaylistController.repeatMode !== PlaylistController.PLAYBACK_REPEAT_NONE
                        description: qsTr("Repeat")
                        onClicked: MainPlaylistController.toggleRepeatMode()
                    }

                    Widgets.IconToolButton {
                        font.pixelSize: VLCStyle.icon_normal
                        text: VLCIcons.shuffle
                        checked: MainPlaylistController.random
                        description: qsTr("Shuffle")
                        onClicked: MainPlaylistController.toggleRandom()
                    }

                    Widgets.IconToolButton {
                        font.pixelSize: VLCStyle.icon_normal
                        text: VLCIcons.remove
                        enabled: root.selectedRow >= 0 && root.selectedRow < root.queueModel.count
                        description: qsTr("Remove the selected item")
                        onClicked: {
                            root.queueModel.removeItems([root.selectedRow])
                            root.selectedRow = -1
                        }
                    }

                    Widgets.IconToolButton {
                        font.pixelSize: VLCStyle.icon_normal
                        text: VLCIcons.add
                        description: qsTr("Add files")
                        onClicked: root.addRequested()
                    }
                }

                ListView {
                    id: list

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    spacing: 2 * root.dp1
                    model: root.queueModel

                    // row the dragged item will be placed before (-1: none)
                    property int dropRow: -1

                    function rowAt(contentY) {
                        const step = 32 * root.dp1 + spacing
                        return Math.max(0, Math.min(count, Math.round(contentY / step)))
                    }

                    T.ScrollBar.vertical: Widgets.ScrollBarExt { }

                    // drop position while a row is dragged
                    Rectangle {
                        parent: list.contentItem
                        visible: list.dropRow >= 0
                        x: 8 * root.dp1
                        width: list.width - 16 * root.dp1
                        height: 2 * root.dp1
                        y: list.dropRow * (32 * root.dp1 + list.spacing) - list.spacing / 2 - height / 2
                        color: root.accentColor
                        z: 2
                    }

                    delegate: T.ItemDelegate {
                        id: row

                        required property var model
                        required property int index

                        width: ListView.view.width
                        implicitHeight: 32 * root.dp1
                        leftPadding: 10 * root.dp1
                        rightPadding: 10 * root.dp1

                        readonly property bool current: !!model.isCurrent

                        opacity: handleDrag.active ? 0.5 : 1

                        background: Rectangle {
                            radius: 6 * root.dp1
                            color: (row.hovered || root.selectedRow === row.index) ? root.hoverColor : "transparent"
                        }

                        contentItem: RowLayout {
                            spacing: 12 * root.dp1

                            // play mark of the current item, drag handle of the others
                            Item {
                                id: handle

                                Layout.preferredWidth: 14 * root.dp1
                                Layout.fillHeight: true

                                Text {
                                    anchors.centerIn: parent
                                    visible: row.current
                                    font.family: VLCIcons.fontFamily
                                    font.pixelSize: 14 * root.dp1
                                    text: VLCIcons.play
                                    color: root.accentColor
                                }

                                Column {
                                    anchors.centerIn: parent
                                    visible: !row.current
                                    spacing: 3 * root.dp1

                                    Repeater {
                                        model: 2
                                        Rectangle {
                                            width: 12 * root.dp1
                                            height: Math.max(1, 1.5 * root.dp1)
                                            radius: height / 2
                                            color: root.dimColor
                                        }
                                    }
                                }

                                // drag to another place (a MouseArea: it gets the
                                // press before the row button does)
                                MouseArea {
                                    id: handleDrag

                                    anchors.fill: parent
                                    anchors.margins: -4 * root.dp1
                                    cursorShape: Qt.SizeVerCursor
                                    preventStealing: true

                                    property real startY: 0
                                    property bool active: false

                                    onPressed: (mouse) => {
                                        startY = mouse.y
                                        active = false
                                    }

                                    onPositionChanged: (mouse) => {
                                        const dy = mouse.y - startY
                                        if (!active && Math.abs(dy) < 4 * root.dp1)
                                            return
                                        active = true
                                        list.dropRow = list.rowAt(row.y + row.height / 2 + dy)
                                    }

                                    onReleased: {
                                        const to = list.dropRow
                                        list.dropRow = -1
                                        // dropping just before or after itself does not move it
                                        if (active && to >= 0 && to !== row.index && to !== row.index + 1)
                                            root.queueModel.moveItemsPre([row.index], to)
                                        active = false
                                        root.selectedRow = -1
                                    }

                                    onCanceled: {
                                        list.dropRow = -1
                                        active = false
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: row.model.title ?? ""
                                color: row.current ? root.accentColor : root.titleColor
                                font.pixelSize: 13 * root.dp1
                                elide: Text.ElideRight
                            }

                            Text {
                                text: {
                                    const t = row.model.duration
                                    return (t && typeof t.formatHMS === "function") ? t.formatHMS() : ""
                                }
                                color: root.dimColor
                                font.pixelSize: 12 * root.dp1
                            }
                        }

                        onClicked: root.selectedRow = index
                        onDoubleClicked: MainPlaylistController.goTo(index, true)
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: list.count === 0
                        text: qsTr("The queue is empty")
                        color: root.dimColor
                        font.pixelSize: 12 * root.dp1
                    }
                }
            }
        }
    }
}
