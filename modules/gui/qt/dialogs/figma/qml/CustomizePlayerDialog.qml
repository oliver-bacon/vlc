/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * Authors: Benjamin Arnaud <bunjee@omega.gg>
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

// "Customize Player" from the VLC Redesign Figma file: the items that can be
// put in the player bar, and the player bars of the current layout. Drag
// items into the bars to add them, out of the bars into the item box to
// remove them. Changes are kept with "Save", dropped with "Cancel".
FigmaDialog {
    id: root

    title: qsTr("Customize Player")

    width: VLCStyle.dp(980, VLCStyle.scale)
    height: VLCStyle.dp(720, VLCStyle.scale)

    function reset() {
        MainCtx.controlbarProfileModel.reload()
    }

    // the selected built-in profile (e.g. "Modern Style") back to its
    // current default layout; applied with "Save"
    extraText: qsTr("Restore Default")
    onExtraClicked: MainCtx.controlbarProfileModel.restoreSelectedDefault()

    onAccepted: MainCtx.controlbarProfileModel.save()
    onRejected: MainCtx.controlbarProfileModel.reload()

    ColumnLayout {
        anchors.fill: parent
        spacing: VLCStyle.dp(12, VLCStyle.scale)

        Text {
            Layout.fillWidth: true
            text: qsTr("Drag items around and out of the box below to re-order them. Drag items into the box to remove them from the player.")
            color: root.dimColor
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            wrapMode: Text.WordWrap
        }

        ToolbarEditor {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
