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


import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player
import VLC.Util

Widgets.IconToolButton {
    id: root

    // Proprerties

    // tab of the track popover to open (0 video, 1 audio, 2 subtitles);
    // -1 keeps the last one
    property int tab: -1

    readonly property var _parentItem: {
        if ((typeof rootPlayer !== 'undefined') && (rootPlayer !== null))
            return rootPlayer
        else
            return g_mainDisplay
    }

    // Signals

    signal requestLockUnlockAutoHide(bool lock)
    signal menuOpened(var menu)

    // Settings

    text: checked ? VLCIcons.audiosub_active : VLCIcons.audiosub

    enabled: menuLoader.status === Loader.Ready

    // highlighted while its popover is open (on its own tab)
    checked: menuLoader.status === Loader.Ready && menuLoader.item.opened
             && (root.tab < 0 || menuLoader.item.currentTab === root.tab)

    description: qsTr("Languages and tracks")

    AccessibleCompat.id: "langButton"

    // Events

    onClicked: {
        if (menuLoader.item.opened) {
            menuLoader.item.close()
            return
        }
        if (root.tab >= 0)
            menuLoader.item.currentTab = root.tab
        menuLoader.item.open()
    }

    // Children

    Loader {
        id: menuLoader

        // Figma track popover, above the button, right aligned, with a gap
        // above the player bar (margin_small alone reaches the bar's top)
        sourceComponent: TracksPopover {
            id: menu

            x: root.width - width
            y: -height - VLCStyle.margin_small - VLCStyle.margin_large

            onOpened: {
                root.requestLockUnlockAutoHide(true)
                root.menuOpened(menu)
            }
            onClosed: {
                root.requestLockUnlockAutoHide(false)
                root.forceActiveFocus()
            }
        }
    }
}
