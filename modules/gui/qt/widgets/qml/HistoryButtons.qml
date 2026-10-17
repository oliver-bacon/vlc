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

import VLC.MainInterface
import VLC.Style

// VLC Redesign: back / forward in front of the page title (they were in the
// top bar). Used by the page headers (PageExt.qml, BrowseTreeHeader.qml).
Row {
    id: root

    spacing: 0

    IconToolButton {
        anchors.verticalCenter: parent.verticalCenter

        font.pixelSize: VLCStyle.icon_normal
        text: VLCIcons.back
        description: qsTr("Back")
        enabled: !History.previousEmpty

        focusPolicy: Qt.NoFocus
        Navigation.navigable: false

        onClicked: History.previous()
    }

    IconToolButton {
        anchors.verticalCenter: parent.verticalCenter

        font.pixelSize: VLCStyle.icon_normal
        text: VLCIcons.arrow_right
        description: qsTr("Forward")
        enabled: !History.nextEmpty

        focusPolicy: Qt.NoFocus
        Navigation.navigable: false

        onClicked: History.next()
    }
}
