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
import VLC.Menus
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Style

// "Chapters": list of the chapters of the current media, pick one to go there
Widgets.IconToolButton {
    id: root

    text: VLCIcons.chapters
    description: qsTr("Chapters")
    enabled: !paintOnly && Player.hasChapters

    onClicked: {
        const model = Player.chapters
        const items = []
        for (let i = 0; i < model.rowCount(); ++i) {
            const index = model.index(i, 0)
            items.push({ "text": model.data(index, Qt.DisplayRole), "checked": !!model.data(index, Qt.CheckStateRole) })
        }
        menu.popup(root.mapToGlobal(0, -VLCStyle.margin_small - items.length * VLCStyle.dp(48, VLCStyle.scale)), items)
    }

    StringListMenu {
        id: menu
        ctx: MainCtx
        onSelected: (index, _) => Player.chapters.selectChapter(index)
    }
}
