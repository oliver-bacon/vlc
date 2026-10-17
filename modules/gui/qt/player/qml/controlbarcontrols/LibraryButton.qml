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

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style

// "Library": shows or hides the library side panel of the player (VLC
// Redesign top bar); outside the player it opens the library
Widgets.IconToolButton {
    text: VLCIcons.panel_left
    description: qsTr("Library")
    enabled: !paintOnly

    readonly property bool _inPlayer: (typeof rootPlayer !== 'undefined') && rootPlayer !== null

    checked: _inPlayer && rootPlayer.libraryVisible
    onClicked: {
        if (_inPlayer)
            rootPlayer.libraryVisible = !rootPlayer.libraryVisible
        else
            MainCtx.playerView = false
    }
}
