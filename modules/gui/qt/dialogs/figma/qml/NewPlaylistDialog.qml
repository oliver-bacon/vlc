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

// "New Playlist" from the VLC Redesign Figma file: a name, a picture and the
// files to put in the playlist (drop them on the box or pick them). The
// picture is kept by VLC next to the media library (see
// MediaLib::setPlaylistThumbnail).
FigmaDialog {
    id: root

    title: qsTr("New Playlist")

    width: VLCStyle.dp(713, VLCStyle.scale)
    height: VLCStyle.dp(589, VLCStyle.scale)

    saveEnabled: playlistName.text.trim() !== "" && MainCtx.mediaLibraryAvailable

    property var files: []

    function reset(args) {
        playlistName.text = ""
        thumbnail.source = ""
        files = Array.isArray(args) ? args.slice() : []
        playlistName.forceActiveFocus()
    }

    function _addFiles(urls) {
        const list = root.files.slice()
        for (let i = 0; i < urls.length; ++i) {
            const url = String(urls[i])
            if (!list.includes(url))
                list.push(url)
        }
        root.files = list
    }

    function _fileName(url) {
        const path = decodeURIComponent(String(url))
        return path.substring(path.lastIndexOf("/") + 1)
    }

    onAccepted: {
        const model = Qt.createQmlObject("import VLC.MediaLibrary; MLPlaylistListModel { }", root)
        model.ml = MainCtx.mediaLibrary
        model.create(playlistName.text.trim(), root.files, thumbnail.source)
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
                    description: qsTr("The playlist will be saved and displayed with this title and thumbnail.")
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
            title: qsTr("Select Files")
            description: qsTr("These files will be added to the playlist.")
        }

        // drop zone: dashed border, click or drop to add files
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: root.radius
            color: dropArea.containsDrag ? Qt.lighter(root.wellColor, 1.6) : root.wellColor

            DashedBorder {
                anchors.fill: parent
                radius: root.radius
                dash: 4
                gap: 3
                color: root.dark ? "#2D2D2D" : "#9B9B9B"
            }

            DropArea {
                id: dropArea

                anchors.fill: parent
                onDropped: (drop) => {
                    if (drop.hasUrls)
                        root._addFiles(drop.urls)
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root._addFiles(VLCConfig.browseFiles(qsTr("Select Files")))
            }

            Column {
                anchors.centerIn: parent
                visible: root.files.length === 0
                spacing: VLCStyle.dp(16, VLCStyle.scale)

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Drag files into the box or click here to select files.")
                    color: root.placeholderColor
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                }

                FigmaDialog.PlusButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitWidth: VLCStyle.dp(84, VLCStyle.scale)
                    onClicked: root._addFiles(VLCConfig.browseFiles(qsTr("Select Files")))
                }
            }

            // added files
            ListView {
                anchors.fill: parent
                anchors.margins: VLCStyle.dp(13, VLCStyle.scale)
                visible: root.files.length > 0
                clip: true
                model: root.files
                spacing: VLCStyle.dp(6, VLCStyle.scale)

                delegate: Item {
                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: VLCStyle.dp(24, VLCStyle.scale)

                    Text {
                        anchors { left: parent.left; right: remove.left; verticalCenter: parent.verticalCenter }
                        text: root._fileName(modelData)
                        color: root.textColor
                        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                        elide: Text.ElideMiddle
                    }

                    FigmaDialog.CloseButton {
                        id: remove

                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        implicitWidth: VLCStyle.dp(24, VLCStyle.scale)
                        implicitHeight: VLCStyle.dp(24, VLCStyle.scale)
                        onClicked: {
                            const list = root.files.slice()
                            list.splice(index, 1)
                            root.files = list
                        }
                    }
                }
            }
        }
    }
}
