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
import QtQuick.Layouts

import VLC.Style

// The seek bar control (ControlListModel.SEEK_BAR, VLC Redesign): the place
// of the seek bar and its times in a bar. It takes the free width of its
// row. The items themselves belong to the control bar around it
// (ControlBar.qml, `seekBarItems`), which shows them here.
FocusScope {
    id: root

    property bool paintOnly: false

    // the control bar that shows its seek bar here
    property Item host: null

    // ControlRepeater / ControlLayout: may grow beyond implicitWidth
    readonly property bool expands: true

    implicitWidth: VLCStyle.dp(240, VLCStyle.scale)
    implicitHeight: row.implicitHeight > 0 ? row.implicitHeight : VLCStyle.icon_toolbar

    Layout.minimumWidth: VLCStyle.dp(160, VLCStyle.scale)

    Component.onCompleted: {
        let p = parent
        while (p && p.isSeekBarHost !== true)
            p = p.parent
        if (!p)
            return
        host = p
        host.seekSlot = root
    }

    Component.onDestruction: {
        if (host && host.seekSlot === root)
            host.seekSlot = null
    }

    RowLayout {
        id: row

        anchors.fill: parent
        spacing: VLCStyle.margin_xsmall

        children: (root.host && root.host.seekSlot === root) ? root.host.seekBarItems : []
    }
}
