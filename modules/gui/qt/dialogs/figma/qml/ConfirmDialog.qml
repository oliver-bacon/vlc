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

import VLC.MainInterface
import VLC.Style
import VLC.Dialogs

// Yes/no question (delete a file, delete playlists...) in the frame of the
// redesign's dialogs. DialogsProvider::questionDialog() opens it and waits
// for DialogsProvider.answerQuestion().
FigmaDialog {
    id: root

    property bool _waiting: false

    title: qsTr("VLC media player")
    saveText: qsTr("Yes")
    cancelText: qsTr("No")

    width: VLCStyle.dp(440, VLCStyle.scale)
    // header + margins + text + buttons
    height: VLCStyle.dp(50 + 20 + 20 + 32 + 20, VLCStyle.scale) + message.implicitHeight

    function reset(args) {
        message.text = args?.text ?? ""
        root.title = args?.title || qsTr("VLC media player")
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

        Text {
            id: message

            width: parent.width
            wrapMode: Text.Wrap
            color: root.titleColor
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            lineHeight: 1.2
        }
    }
}
