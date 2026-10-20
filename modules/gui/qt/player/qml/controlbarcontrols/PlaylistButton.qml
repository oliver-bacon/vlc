/*****************************************************************************
 * Copyright (C) 2021 VLC authors and VideoLAN
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
import VLC.Util
import VLC.Player


Widgets.IconToolButton {
    id: playlistBtn

    text: VLCIcons.playlist
    signal requestLockUnlockAutoHide(bool lock)

    // Queue / Bookmarks / Chapters card on the right side of the player, like
    // the playback settings; the docked side panel stays available through
    // the "Right Sidebar" item
    onClicked: popover.opened ? popover.close() : popover.open()
    checked: popover.opened

    QueuePopover {
        id: popover

        onOpened: playlistBtn.requestLockUnlockAutoHide(true)
        onClosed: playlistBtn.requestLockUnlockAutoHide(false)
    }

    description: qsTr("Play Queue")

    AccessibleCompat.id: "playqueueButton"
}
