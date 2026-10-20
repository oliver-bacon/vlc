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
import QtQuick.Templates as T

import VLC.Style

// Popup of a player bar button (playback settings, queue). In the player it
// is a card on the right side of the window (Player.sidePanelArea, VLC
// Redesign Figma); elsewhere (miniplayer) it sits above its button,
// right aligned, with defaultHeight.
T.Popup {
    id: root

    property real defaultHeight: VLCStyle.dp(420, VLCStyle.scale)

    // the Player.qml root around the button, found when opening
    property Item _player: null
    // the button in _player coordinates
    property point _buttonPos: Qt.point(0, 0)

    readonly property rect _area: _player ? _player.sidePanelArea : Qt.rect(0, 0, 0, 0)

    width: VLCStyle.dp(400, VLCStyle.scale)
    height: _player ? _area.height : defaultHeight

    x: _player ? _area.x + _area.width - width - _buttonPos.x
               : (parent?.width ?? 0) - width
    y: _player ? _area.y - _buttonPos.y
               : -height - VLCStyle.margin_small - VLCStyle.margin_large // gap above the player bar

    function _updatePosition() {
        if (_player && parent)
            _buttonPos = parent.mapToItem(_player, 0, 0)
    }

    onAboutToShow: {
        let p = parent
        while (p && p.sidePanelArea === undefined)
            p = p.parent
        _player = p
        _updatePosition()
    }

    // window resized or top bar changed
    on_AreaChanged: if (opened) Qt.callLater(_updatePosition)
}
