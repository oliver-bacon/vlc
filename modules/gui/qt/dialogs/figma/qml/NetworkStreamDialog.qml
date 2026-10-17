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

import VLC.MainInterface
import VLC.Playlist
import VLC.Style

// "Open Network Stream" from the VLC Redesign Figma file: one or more URLs
// (one per line); with a name, they are also saved as a library playlist.
FigmaDialog {
    id: root

    title: qsTr("Open Network Stream")

    width: VLCStyle.dp(1048, VLCStyle.scale)
    height: VLCStyle.dp(631, VLCStyle.scale)

    saveEnabled: _urls().length > 0

    function _urls() {
        return urls.text.split(/\s+/).filter((u) => u !== "")
    }

    function reset() {
        urls.text = ""
        playlistName.text = ""
        urls.forceActiveFocus()
    }

    onAccepted: {
        const list = _urls()
        const name = playlistName.text.trim()
        if (name !== "" && MainCtx.mediaLibraryAvailable) {
            const model = Qt.createQmlObject("import VLC.MediaLibrary; MLPlaylistListModel { }", root)
            model.ml = MainCtx.mediaLibrary
            model.create(name, list)
        }
        MainPlaylistController.append(list, true)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: VLCStyle.dp(18, VLCStyle.scale)
        spacing: VLCStyle.dp(16, VLCStyle.scale)

        FigmaDialog.SectionHeader {
            title: qsTr("Network URL")
            description: qsTr("You can enter multiple links to load.")
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(192, VLCStyle.scale)
            radius: root.radius
            color: root.wellColor
            border.width: 1
            border.color: urls.activeFocus ? root.accentColor : root.panelColor

            Flickable {
                id: flick

                anchors.fill: parent
                anchors.margins: VLCStyle.dp(13, VLCStyle.scale)
                contentHeight: urls.implicitHeight
                clip: true

                T.TextArea {
                    id: urls

                    width: flick.width
                    wrapMode: TextEdit.WrapAnywhere
                    color: root.titleColor
                    selectionColor: root.accentSurface
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    placeholderText: qsTr("e.g., https://www.example.com/stream.avi")

                    Text {
                        visible: urls.text === ""
                        text: urls.placeholderText
                        color: root.placeholderColor
                        font: urls.font
                    }
                }
            }
        }

        FigmaDialog.Divider {
            Layout.fillWidth: true
            Layout.topMargin: VLCStyle.dp(4, VLCStyle.scale)
            visible: MainCtx.mediaLibraryAvailable
        }

        FigmaDialog.SectionHeader {
            visible: MainCtx.mediaLibraryAvailable
            title: qsTr("Playlist Name")
            suffix: qsTr("(optional)")
            description: qsTr("The playlist will be saved and displayed with this title.")
        }

        FigmaDialog.TextField {
            id: playlistName

            visible: MainCtx.mediaLibraryAvailable
            Layout.fillWidth: true
            placeholderText: qsTr("e.g., Favorite TV Channels")
        }

        Item { Layout.fillHeight: true }
    }
}
