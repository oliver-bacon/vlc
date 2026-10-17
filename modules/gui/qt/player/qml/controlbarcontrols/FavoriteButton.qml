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
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Style

// Adds the current media to the media library favorites, or removes it.
// Disabled for media that are not part of the media library.
Widgets.IconToolButton {
    id: root

    property bool _known: false
    property bool _favorite: false

    text: VLCIcons.favorite
    description: _favorite ? qsTr("Remove from favorites") : qsTr("Add to favorites")
    checked: _favorite

    // disabled (dimmed) for media that are not part of the media library
    enabled: !paintOnly && MainCtx.mediaLibraryAvailable && _known

    onClicked: MainCtx.mediaLibrary.setMediaFavorite(Player.url, !_favorite)

    function _refresh() {
        _known = false
        _favorite = false
        if (!paintOnly && MainCtx.mediaLibraryAvailable)
            MainCtx.mediaLibrary.queryMediaFavorite(Player.url)
    }

    Component.onCompleted: _refresh()

    Connections {
        target: Player
        function onInputChanged() { root._refresh() }
    }

    Connections {
        target: MainCtx.mediaLibrary
        function onMediaFavoriteState(mrl, known, favorite) {
            if (mrl !== Player.url)
                return
            root._known = known
            root._favorite = favorite
        }
    }
}
