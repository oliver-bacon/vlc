/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
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
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets

// "Music" of the VLC Redesign (video 12:08, Figma "sidebar" frame): Add,
// Songs, Albums, Artists and Genres, in the main area of the full library.
Widgets.PageExt {
    id: root

    title: qsTr("Music")

    hasGridListMode: true

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    readonly property var _sections: [
        { "title": qsTr("Songs"),   "icon": VLCIcons.topbar_music,       "uri": ["music", "tracks"] },
        { "title": qsTr("Albums"),  "icon": VLCIcons.album_cover, "uri": ["music", "albums"] },
        { "title": qsTr("Artists"), "icon": VLCIcons.artist,      "uri": ["music", "artists"] },
        { "title": qsTr("Genres"),  "icon": VLCIcons.genre,       "uri": ["music", "genres"] }
    ]

    // "Add": add a folder to the library
    readonly property var _entries: [{ "title": qsTr("Add"), "icon": VLCIcons.add, "uri": null }].concat(root._sections)

    function _activate(modelData) {
        if (modelData.uri) {
            History.push(modelData.uri)
        } else {
            const folder = VLCConfig.browseFolder(qsTr("Add a Folder to the Library"))
            if (folder !== "") {
                // music folders stay out of Videos
                VLCConfig.setMusicFolder(folder, true)
                MainCtx.mediaLibrary.addFolder(folder)
            }
        }
    }

    Item {
        id: content

        anchors.fill: parent
        focus: true

        function setCurrentItemFocus(reason) {
            (MainCtx.gridView ? gridView : listView).forceActiveFocus(reason)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: VLCStyle.dynamicAppMargins(content.width) + VLCStyle.layout_left_margin
            anchors.rightMargin: VLCStyle.dynamicAppMargins(content.width) + VLCStyle.layout_right_margin
            spacing: VLCStyle.margin_xsmall

            Text {
                Layout.fillWidth: true
                text: qsTr("%1 items").arg(root._sections.length)
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_normal
            }

            GridView {
                id: gridView

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: MainCtx.gridView
                clip: true
                focus: MainCtx.gridView
                boundsBehavior: Flickable.StopAtBounds
                model: root._entries

                readonly property int _columns: Math.max(1, Math.floor(width / (VLCStyle.gridCover_video_width + VLCStyle.margin_normal)))
                cellWidth: Math.floor(width / _columns)
                cellHeight: VLCStyle.gridCover_video_height + VLCStyle.dp(56, VLCStyle.scale)

                delegate: Entry {
                    width: GridView.view.cellWidth
                    height: GridView.view.cellHeight
                    grid: true
                }
            }

            ListView {
                id: listView

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !MainCtx.gridView
                clip: true
                focus: !MainCtx.gridView
                boundsBehavior: Flickable.StopAtBounds
                model: root._entries

                delegate: Entry {
                    width: ListView.view.width
                    height: VLCStyle.dp(48, VLCStyle.scale)
                }
            }
        }
    }

    // a section: a row in the list, a tile in the grid (like Videos)
    component Entry: T.ItemDelegate {
        id: entry

        required property var modelData
        property bool grid: false

        padding: grid ? VLCStyle.margin_xxsmall : 0
        leftPadding: grid ? VLCStyle.margin_xxsmall : VLCStyle.margin_xsmall

        Accessible.name: modelData.title

        background: Rectangle {
            radius: VLCStyle.dp(4, VLCStyle.scale)
            color: entry.hovered || entry.activeFocus ? theme.bg.secondary : "transparent"
        }

        contentItem: GridLayout {
            columns: entry.grid ? 1 : 2
            columnSpacing: VLCStyle.margin_small
            rowSpacing: VLCStyle.margin_xxsmall

            Item {
                Layout.preferredWidth: entry.grid ? VLCStyle.gridCover_video_width : VLCStyle.icon_normal
                Layout.preferredHeight: entry.grid ? VLCStyle.gridCover_video_height : VLCStyle.icon_normal
                Layout.alignment: Qt.AlignHCenter

                Rectangle {
                    anchors.fill: parent
                    visible: entry.grid
                    radius: VLCStyle.dp(4, VLCStyle.scale)
                    color: theme.bg.secondary
                }
                Widgets.IconLabel {
                    anchors.centerIn: parent
                    text: entry.modelData.icon
                    color: theme.fg.secondary
                    font.pixelSize: entry.grid ? VLCStyle.icon_large : VLCStyle.icon_normal
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: entry.grid ? VLCStyle.gridCover_video_width : -1
                Layout.alignment: entry.grid ? Qt.AlignHCenter : Qt.AlignVCenter
                text: entry.modelData.title
                elide: Text.ElideRight
                maximumLineCount: 1
                color: theme.fg.primary
                font.pixelSize: VLCStyle.fontSize_normal
            }
        }

        onClicked: root._activate(modelData)
    }
}
