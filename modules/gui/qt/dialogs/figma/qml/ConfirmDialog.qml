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
 *****************************************************************************/
import QtQuick
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Dialogs

// Yes/no question (delete a file, delete playlists...): the question with
// Yes and No under it, left aligned, in a square outlined frame without a
// title bar (Oliver's choice). DialogsProvider::questionDialog() opens it
// and waits for DialogsProvider.answerQuestion().
FigmaDialog {
    id: root

    property bool _waiting: false

    title: qsTr("VLC Gold")

    // square with a thin outline like the settings window
    frameRadius: 0
    outlined: true
    showHeader: false
    showButtons: false

    width: VLCStyle.dp(440, VLCStyle.scale)
    // margins + text + gap + buttons
    height: contentMargins * 2 + content.implicitHeight

    function reset(args) {
        message.text = args?.text ?? ""
        root.title = args?.title || qsTr("VLC Gold")
        root._waiting = true
        keys.forceActiveFocus()
    }

    function _answer(yes) {
        if (!root._waiting)
            return
        root._waiting = false
        DialogsProvider.answerQuestion(yes)
    }

    onAccepted: _answer(true)
    onRejected: _answer(false)
    // closed another way (window manager...)
    onVisibleChanged: if (!visible) _answer(false)
    Component.onDestruction: _answer(false)

    Item {
        id: keys

        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.reject()

        ColumnLayout {
            id: content

            width: parent.width
            spacing: VLCStyle.dp(20, VLCStyle.scale)

            Text {
                id: message

                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: root.titleColor
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                lineHeight: 1.2
            }

            Row {
                spacing: VLCStyle.dp(10, VLCStyle.scale)

                FigmaDialog.Button {
                    text: qsTr("Yes")
                    primary: true
                    onClicked: root.accept()
                }

                FigmaDialog.Button {
                    text: qsTr("No")
                    onClicked: root.reject()
                }
            }
        }
    }
}
