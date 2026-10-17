/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * Authors: Oliver Bacon <oliverbacon@tutamail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.Dialogs
import VLC.MainInterface
import VLC.Player
import VLC.Playlist
import VLC.Style
import VLC.Widgets as Widgets

// Queue / Bookmarks / Chapters popover of the VLC Redesign Figma file
// (play queue button of the player bar, queue button of the miniplayer).
T.Popup {
    id: root

    property int currentTab: 0
    // the miniplayer shows the queue only
    property bool queueOnly: false

    width: VLCStyle.dp(400, VLCStyle.scale)
    height: VLCStyle.dp(queueOnly ? 300 : 420, VLCStyle.scale)
    padding: 0
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutsideParent

    readonly property bool dark: VLCStyle.palette?.isDark ?? true
    readonly property color panelColor: dark ? "#191919" : "#E7E7E7"
    readonly property color tabsColor: dark ? "#151515" : "#DEDEDE"
    readonly property color titleColor: dark ? "#C6C6C6" : "#161616"
    readonly property color textColor: dark ? "#8F8F8F" : "#2E2E2E"
    readonly property color dimColor: "#6B6B6B"
    readonly property color accentColor: "#D37918"
    readonly property real dp1: VLCStyle.dp(1, VLCStyle.scale)

    property int selectedRow: -1

    readonly property PlaylistListModel queueModel: PlaylistListModel {
        playlist: MainPlaylistController.playlist
    }

    // created only with a media library (the module may be missing)
    property var bookmarkModel: null

    Component.onCompleted: {
        if (MainCtx.mediaLibraryAvailable) {
            bookmarkModel = Qt.createQmlObject("import VLC.MediaLibrary; MLBookmarkModel { }", root)
            bookmarkModel.player = Player
            bookmarkModel.ml = MainCtx.mediaLibrary
        }
    }

    onCurrentTabChanged: selectedRow = -1

    background: Rectangle {
        radius: 10 * root.dp1
        color: root.panelColor
    }

    contentItem: ColumnLayout {
        spacing: 0

        // tabs, or the "Queue" title
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50 * root.dp1
            color: root.tabsColor
            radius: 10 * root.dp1

            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: parent.radius
                color: parent.color
            }

            Text {
                anchors.centerIn: parent
                visible: root.queueOnly
                text: qsTr("Queue")
                color: root.titleColor
                font.pixelSize: 14 * root.dp1
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10 * root.dp1
                anchors.rightMargin: 10 * root.dp1
                visible: !root.queueOnly
                spacing: 0

                Repeater {
                    model: [
                        { "text": qsTr("Queue"), "glyph": VLCIcons.enqueue },
                        { "text": qsTr("Bookmarks"), "glyph": VLCIcons.bookmarks },
                        { "text": qsTr("Chapters"), "glyph": VLCIcons.chapters }
                    ]

                    delegate: T.TabButton {
                        id: tab

                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        checked: root.currentTab === index
                        onClicked: root.currentTab = index

                        background: Item {
                            Rectangle {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 8 * root.dp1; rightMargin: 8 * root.dp1 }
                                height: 2 * root.dp1
                                visible: tab.checked
                                color: root.accentColor
                            }
                        }
                        contentItem: Row {
                            spacing: 6 * root.dp1
                            leftPadding: Math.max(0, (tab.width - implicitWidth) / 2)
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                font.family: VLCIcons.fontFamily
                                font.pixelSize: 15 * root.dp1
                                text: tab.modelData.glyph
                                color: tab.checked ? root.accentColor : root.dimColor
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tab.modelData.text
                                font.pixelSize: 13 * root.dp1
                                color: tab.checked ? root.titleColor : root.dimColor
                            }
                        }
                    }
                }
            }
        }

        // header: count, actions
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 26 * root.dp1
            Layout.rightMargin: 18 * root.dp1
            Layout.topMargin: 12 * root.dp1
            visible: root.currentTab !== 2

            Text {
                Layout.fillWidth: true
                text: root.currentTab === 0
                      ? (root.queueModel.count === 1 ? qsTr("1 item - %1").arg(root.queueModel.duration.formatHMS())
                                                     : qsTr("%1 items - %2").arg(root.queueModel.count).arg(root.queueModel.duration.formatHMS()))
                      : (list.count === 1 ? qsTr("1 Bookmark") : qsTr("%1 Bookmarks").arg(list.count))
                color: root.dimColor
                font.pixelSize: 12 * root.dp1
            }
            // Queue: sort, repeat, shuffle, -, + (video 2:10)
            Widgets.SortControl {
                visible: root.currentTab === 0
                implicitWidth: 28 * root.dp1
                implicitHeight: 28 * root.dp1
                font.pixelSize: 15 * root.dp1
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
            HeaderButton {
                visible: root.currentTab === 0
                glyph: MainPlaylistController.repeatMode === PlaylistController.PLAYBACK_REPEAT_CURRENT
                       ? VLCIcons.repeat_one : VLCIcons.repeat_all
                active: MainPlaylistController.repeatMode !== PlaylistController.PLAYBACK_REPEAT_NONE
                tip: qsTr("Repeat")
                onClicked: MainPlaylistController.toggleRepeatMode()
            }
            HeaderButton {
                visible: root.currentTab === 0
                glyph: VLCIcons.shuffle
                active: MainPlaylistController.random
                tip: qsTr("Shuffle")
                onClicked: MainPlaylistController.toggleRandom()
            }
            HeaderButton {
                glyph: VLCIcons.remove
                tip: qsTr("Remove the selected item")
                enabled: root.selectedRow >= 0
                onClicked: {
                    if (root.currentTab === 0)
                        root.queueModel.removeItems([root.selectedRow])
                    else if (root.bookmarkModel)
                        root.bookmarkModel.remove([root.bookmarkModel.index(root.selectedRow, 0)])
                    root.selectedRow = -1
                }
            }
            HeaderButton {
                glyph: VLCIcons.add
                tip: root.currentTab === 0 ? qsTr("Add files") : qsTr("Add a bookmark here")
                enabled: root.currentTab === 0 || !!root.bookmarkModel
                onClicked: {
                    if (root.currentTab === 0)
                        DialogsProvider.PLAppendDialog()
                    else
                        root.bookmarkModel.add()
                }
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 10 * root.dp1
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: 2 * root.dp1

            model: root.currentTab === 0 ? root.queueModel
                 : root.currentTab === 1 ? root.bookmarkModel
                 : Player.chapters

            delegate: T.ItemDelegate {
                id: row

                required property var model
                required property int index

                width: ListView.view.width
                implicitHeight: 32 * root.dp1
                leftPadding: 8 * root.dp1
                rightPadding: 8 * root.dp1

                readonly property bool current: root.currentTab === 0 ? !!model.isCurrent
                                              : root.currentTab === 2 ? !!model.checked : false

                background: Rectangle {
                    radius: 4 * root.dp1
                    color: (row.hovered || root.selectedRow === row.index) ? root.tabsColor : "transparent"
                }
                contentItem: RowLayout {
                    spacing: 12 * root.dp1
                    Text {
                        visible: root.currentTab === 0
                        font.family: VLCIcons.fontFamily
                        font.pixelSize: 14 * root.dp1
                        text: VLCIcons.ic_fluent_arrow_move
                        color: root.dimColor
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.currentTab === 0 ? (row.model.title ?? "")
                            : root.currentTab === 1 ? (row.model.name ?? "")
                            : (row.model.display ?? "")
                        color: row.current ? root.accentColor : root.titleColor
                        font.pixelSize: 13 * root.dp1
                        elide: Text.ElideRight
                    }
                    Text {
                        text: {
                            // bookmarks: a formatted string; queue and chapters: a time value
                            const t = root.currentTab === 0 ? row.model.duration : row.model.time
                            if (typeof t === "string")
                                return t
                            return (t && typeof t.formatHMS === "function") ? t.formatHMS() : ""
                        }
                        color: root.dimColor
                        font.pixelSize: 12 * root.dp1
                    }
                }

                onClicked: root.selectedRow = index
                onDoubleClicked: {
                    if (root.currentTab === 0)
                        MainPlaylistController.goTo(index, true)
                    else if (root.currentTab === 1)
                        root.bookmarkModel.select(root.bookmarkModel.index(index, 0))
                    else
                        Player.chapters.selectChapter(index)
                }
            }

            Text {
                parent: list
                anchors.centerIn: parent
                visible: list.count === 0
                text: root.currentTab === 0 ? qsTr("The queue is empty")
                    : root.currentTab === 1 ? qsTr("No bookmarks yet")
                    : qsTr("This media has no chapters")
                color: root.dimColor
                font.pixelSize: 13 * root.dp1
            }
        }
    }

    component HeaderButton: T.Button {
        id: hb
        property string glyph
        property string tip
        // on/off state (repeat, shuffle)
        property bool active: false
        implicitWidth: 28 * root.dp1
        implicitHeight: 28 * root.dp1
        background: Rectangle {
            radius: 4 * root.dp1
            color: hb.hovered ? root.tabsColor : "transparent"
        }
        contentItem: Text {
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: VLCIcons.fontFamily
            font.pixelSize: 15 * root.dp1
            text: hb.glyph
            color: !hb.enabled ? root.dimColor : (hb.active ? root.accentColor : root.textColor)
        }
        Accessible.name: tip
    }
}
