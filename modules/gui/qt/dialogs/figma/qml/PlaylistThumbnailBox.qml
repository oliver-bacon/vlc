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
import QtQuick.Templates as T

import VLC.Style

// Square playlist picture of the "New Playlist" design: a "+" when empty,
// otherwise the picture with a button to remove it. Clicking picks a file.
Rectangle {
    id: box

    required property var dialog
    // URL of the picture, "" when there is none
    property string source: ""

    implicitWidth: VLCStyle.dp(104, VLCStyle.scale)
    implicitHeight: implicitWidth
    radius: dialog.radius
    color: dialog.wellColor
    border.width: 1
    border.color: mouse.containsMouse ? dialog.dividerColor : dialog.panelColor
    clip: true

    function pick() {
        const files = VLCConfig.browseFiles(qsTr("Select a Picture"),
                                            qsTr("Images") + " (*.png *.jpg *.jpeg *.bmp *.gif *.webp)")
        if (files.length > 0)
            box.source = String(files[0])
    }

    Image {
        anchors.fill: parent
        anchors.margins: 1
        visible: box.source !== ""
        source: box.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: width * 2
        sourceSize.height: height * 2
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: box.pick()
    }

    FigmaDialog.PlusButton {
        anchors.centerIn: parent
        visible: box.source === ""
        onClicked: box.pick()
    }

    // remove the picture
    T.Button {
        id: remove

        anchors { top: parent.top; right: parent.right; margins: VLCStyle.dp(4, VLCStyle.scale) }
        visible: box.source !== "" && (mouse.containsMouse || hovered)
        implicitWidth: VLCStyle.dp(22, VLCStyle.scale)
        implicitHeight: implicitWidth
        background: Rectangle {
            radius: width / 2
            color: "#CC090909"
        }
        contentItem: Text {
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: VLCIcons.fontFamily
            font.pixelSize: VLCStyle.dp(12, VLCStyle.scale)
            text: VLCIcons.close
            color: "#C6C6C6"
        }
        onClicked: box.source = ""
    }
}
