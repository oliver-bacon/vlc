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

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style

// "Right Sidebar": shows or hides the play queue panel
Widgets.IconToolButton {
    text: VLCIcons.sidebar_right
    description: qsTr("Right Sidebar")
    enabled: !paintOnly
    // in the player, through its panel state machine (with video, the
    // panel can be hidden while playqueuePanel.visible is still true)
    readonly property bool _inPlayer: (typeof rootPlayer !== 'undefined') && rootPlayer !== null
    checked: _inPlayer ? rootPlayer.sidePanelVisible : MainCtx.playqueuePanel.visible
    onClicked: {
        if (_inPlayer)
            rootPlayer.toggleSidePanel()
        else
            MainCtx.playqueuePanel.visible = !MainCtx.playqueuePanel.visible
    }
}
