/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * Authors: thespine1337 <thespine1337@gmail.com>
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

import VLC.MainInterface
import VLC.Style
import VLC.Dialogs

// "Properties & Metadata" of a library playlist (playlist context menu). The
// Figma file has no frame for it, so it follows the "New Playlist" dialog:
// name and picture can be changed, the rest is information from the media
// library.
FigmaDialog {
    id: root

    title: qsTr("Properties & Metadata")

    width: VLCStyle.dp(713, VLCStyle.scale)
    height: VLCStyle.dp(589, VLCStyle.scale)

    saveEnabled: playlistName.text.trim() !== "" && MainCtx.mediaLibraryAvailable

    property var playlistId
    property string _name: ""
    property string _thumbnail: ""
    property var _info: []

    function reset(args) {
        const a = args || {}
        playlistId = a.id
        _name = a.name || ""
        _thumbnail = a.thumbnail || ""
        playlistName.text = _name
        thumbnail.source = _thumbnail

        const count = Number(a.count || 0)
        const present = Number(a.present ?? count)
        const info = [
            [qsTr("Items"), String(count)],
            [qsTr("Videos"), String(a.video || 0)],
            [qsTr("Audio"), String(a.audio || 0)]
        ]
        if (Number(a.unknown || 0) > 0)
            info.push([qsTr("Other"), String(a.unknown)])
        if (present < count)
            info.push([qsTr("Missing Files"), String(count - present)])
        info.push([qsTr("Duration"), a.duration || "--"])
        const created = Number(a.created || 0)
        info.push([qsTr("Created"), created > 0
                   ? new Date(created * 1000).toLocaleString(Qt.locale(), Locale.ShortFormat)
                   : "--"])
        info.push([qsTr("Favorite"), a.favorite ? qsTr("Yes") : qsTr("No")])
        _info = info

        playlistName.forceActiveFocus()
    }

    onAccepted: {
        const ml = MainCtx.mediaLibrary
        if (!ml || !playlistId)
            return
        const name = playlistName.text.trim()
        if (name !== "" && name !== _name)
            ml.renamePlaylist(playlistId, name)
        if (thumbnail.source !== _thumbnail)
            ml.setPlaylistThumbnail(playlistId, thumbnail.source)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: VLCStyle.dp(18, VLCStyle.scale)
        spacing: VLCStyle.dp(16, VLCStyle.scale)

        RowLayout {
            Layout.fillWidth: true
            spacing: VLCStyle.dp(22, VLCStyle.scale)

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: VLCStyle.dp(16, VLCStyle.scale)

                FigmaDialog.SectionHeader {
                    title: qsTr("Playlist Details")
                    description: qsTr("The playlist is displayed with this title and thumbnail.")
                }

                FigmaDialog.TextField {
                    id: playlistName

                    Layout.fillWidth: true
                    Layout.topMargin: VLCStyle.dp(8, VLCStyle.scale)
                    placeholderText: qsTr("e.g., Favorite Videos")
                    onAccepted: if (root.saveEnabled) root.accept()
                }
            }

            PlaylistThumbnailBox {
                id: thumbnail

                Layout.alignment: Qt.AlignTop
                dialog: root
            }
        }

        FigmaDialog.Divider {
            Layout.fillWidth: true
            Layout.topMargin: VLCStyle.dp(6, VLCStyle.scale)
        }

        FigmaDialog.SectionHeader {
            title: qsTr("Information")
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: infoGrid.implicitHeight + VLCStyle.dp(32, VLCStyle.scale)
            radius: root.radius
            color: root.wellColor

            GridLayout {
                id: infoGrid

                anchors { left: parent.left; right: parent.right; top: parent.top; margins: VLCStyle.dp(16, VLCStyle.scale) }
                columns: 2
                rowSpacing: VLCStyle.dp(10, VLCStyle.scale)
                columnSpacing: VLCStyle.dp(24, VLCStyle.scale)

                Repeater {
                    model: root._info.length * 2

                    Text {
                        required property int index

                        Layout.alignment: Qt.AlignTop
                        Layout.fillWidth: index % 2 === 1
                        text: root._info[Math.floor(index / 2)][index % 2]
                        color: index % 2 === 0 ? root.dimColor : root.titleColor
                        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
