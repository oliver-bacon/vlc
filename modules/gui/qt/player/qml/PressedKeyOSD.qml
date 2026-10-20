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

import VLC.MainInterface

// "Pressed C" under VLC's on-screen message (video 15:28): the key that was
// just pressed, drawn with the keycaps of the redesign's shortcuts page
// (Figma "Onboarding" shortcuts: 42px high, radius 12, #1B1B1B, 3px #373737
// outline, #EAEAEA light text). Fill the video surface with it.
//
// VLC draws its message itself, at the top right of the video area: 4% of
// the area away from the edges, font height 6.25% of the area height (times
// the subtitle text scale). This line sits right below it, same size.
Item {
    id: root

    enabled: false

    readonly property real _area: Math.min(width, height)
    // VLC's on-screen text size
    readonly property real _fontSize: _area * 0.0625 * (Number(VLCConfig.value("sub-text-scale")) || 100) / 100
    // keycaps as high as a line of that text, in the Figma proportions
    readonly property real _s: _fontSize * 1.25 / 42

    property var _keys: []

    Connections {
        target: MainCtx
        function onHotkeyPressed(keys) {
            root._keys = keys
            line.opacity = 1
            fade.restart()
        }
    }

    // VLC shows its message for 1 s and fades it out in the last quarter
    SequentialAnimation {
        id: fade
        PauseAnimation { duration: 750 }
        NumberAnimation { target: line; property: "opacity"; to: 0; duration: 250 }
    }

    Row {
        id: line

        visible: opacity > 0
        opacity: 0

        anchors.right: parent.right
        anchors.rightMargin: root.width * 0.04
        y: root.height * 0.04 + root._fontSize * 1.2
        spacing: root._fontSize * 0.3

        // like VLC's on-screen text: white with a black outline
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Pressed")
            color: "white"
            style: Text.Outline
            styleColor: "black"
            font.pixelSize: Math.max(1, root._fontSize)
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4 * root._s

            Repeater {
                model: root._keys

                delegate: Rectangle {
                    required property string modelData

                    // letters and words have 23px at each side, symbols 15px
                    readonly property real _padding: (/^[\p{L}\p{N}]/u.test(modelData) ? 23 : 15) * root._s

                    width: keyText.implicitWidth + 2 * _padding
                    height: 42 * root._s
                    radius: 12 * root._s
                    color: "#1B1B1B"
                    border.width: 3 * root._s
                    border.color: "#373737"

                    Text {
                        id: keyText
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: "#EAEAEA"
                        font.pixelSize: Math.max(1, 16 * root._s)
                        font.weight: Font.Light
                    }
                }
            }
        }
    }
}
