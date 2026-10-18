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
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets

// Bookmarks or chapters of the current media, for the player side panel
// (VLC Redesign video, 15:12–15:16). Double-click jumps there.
ColumnLayout {
    id: root

    // 1: bookmarks, 2: chapters (indexes of the side panel tabs)
    property int mode: 1

    readonly property bool dark: VLCStyle.palette?.isDark ?? true
    readonly property color hoverColor: dark ? "#222222" : "#D5D5D5"
    readonly property color titleColor: dark ? "#C6C6C6" : "#161616"
    readonly property color textColor: dark ? "#8F8F8F" : "#2E2E2E"
    readonly property color dimColor: "#6B6B6B"
    readonly property color accentColor: VLCStyle.palette.orange500
    readonly property real dp1: VLCStyle.dp(1, VLCStyle.scale)

    property int selectedRow: -1

    // created only with a media library (the module may be missing)
    property var bookmarkModel: null

    Component.onCompleted: {
        if (MainCtx.mediaLibraryAvailable) {
            bookmarkModel = Qt.createQmlObject("import VLC.MediaLibrary; MLBookmarkModel { }", root)
            bookmarkModel.player = Player
            bookmarkModel.ml = MainCtx.mediaLibrary
        }
    }

    onModeChanged: selectedRow = -1

    spacing: 0

    // header: count, remove, add (bookmarks only)
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: VLCStyle.margin_normal
        Layout.rightMargin: VLCStyle.margin_small
        Layout.topMargin: VLCStyle.margin_xsmall
        visible: root.mode === 1

        Text {
            Layout.fillWidth: true
            text: list.count === 1 ? qsTr("1 Bookmark") : qsTr("%1 Bookmarks").arg(list.count)
            color: root.dimColor
            font.pixelSize: VLCStyle.fontSize_small
        }
        Widgets.IconToolButton {
            font.pixelSize: VLCStyle.icon_normal
            text: VLCIcons.remove
            description: qsTr("Remove the selected bookmark")
            enabled: root.selectedRow >= 0 && !!root.bookmarkModel
            onClicked: {
                root.bookmarkModel.remove([root.bookmarkModel.index(root.selectedRow, 0)])
                root.selectedRow = -1
            }
        }
        Widgets.IconToolButton {
            font.pixelSize: VLCStyle.icon_normal
            text: VLCIcons.add
            description: qsTr("Add a bookmark here")
            enabled: !!root.bookmarkModel
            onClicked: root.bookmarkModel.add()
        }
    }

    ListView {
        id: list

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: VLCStyle.margin_xsmall
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: 2 * root.dp1

        model: root.mode === 1 ? root.bookmarkModel : Player.chapters

        delegate: T.ItemDelegate {
            id: row

            required property var model
            required property int index

            width: ListView.view.width
            implicitHeight: 36 * root.dp1
            leftPadding: VLCStyle.margin_small
            rightPadding: VLCStyle.margin_small

            readonly property bool current: root.mode === 2 && !!model.checked

            background: Rectangle {
                radius: 4 * root.dp1
                color: (row.hovered || root.selectedRow === row.index) ? root.hoverColor : "transparent"
            }
            contentItem: RowLayout {
                spacing: 12 * root.dp1
                // chapter number
                Text {
                    visible: root.mode === 2
                    text: row.index + 1
                    color: root.accentColor
                    font.pixelSize: 13 * root.dp1
                }
                Text {
                    Layout.fillWidth: true
                    text: root.mode === 1 ? (row.model.name ?? "") : (row.model.display ?? "")
                    color: row.current ? root.accentColor : root.titleColor
                    font.pixelSize: 13 * root.dp1
                    elide: Text.ElideRight
                }
                Text {
                    text: {
                        // bookmarks: a formatted string; chapters: a time value
                        const t = row.model.time
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
                if (root.mode === 1)
                    root.bookmarkModel.select(root.bookmarkModel.index(index, 0))
                else
                    Player.chapters.selectChapter(index)
            }
        }

        Text {
            parent: list
            anchors.centerIn: parent
            visible: list.count === 0
            text: root.mode === 1 ? qsTr("No bookmarks yet") : qsTr("This media has no chapters")
            color: root.dimColor
            font.pixelSize: VLCStyle.fontSize_normal
        }
    }
}
