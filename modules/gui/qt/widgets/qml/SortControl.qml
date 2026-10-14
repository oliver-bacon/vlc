/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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
import VLC.Style
import VLC.Menus
import VLC.Widgets as Widgets

Widgets.IconToolButton {
    id: root

    // Properties

    property var model: []

    property bool popupAbove: false

    property real listWidth: VLCStyle.widthSortBox

    // NOTE: This allows us provide a custom menu and override sortMenu.
    property SortMenu menu

    // properties that should be handled by parent
    // if they are not updated, tick mark and order mark will not be shown
    property var sortKey: undefined
    property var sortOrder: undefined

    // Private

    property SortMenu _menu: (menu) ? menu
                                    : sortMenu

    // Signals

    // sortSelected is triggered with new sorting key when a different sorting key is selected
    // sortOrderSelected is triggered with Qt.AscendingOrder when different sorting key is selected
    // sortOrderSelected is triggered with Qt.AscendingOrder or Qt.DescendingOrder when the same sorting key is selected
    signal sortSelected(var key)
    signal sortOrderSelected(int type)


    font.pixelSize: VLCStyle.icon_normal

    focus: true

    description: qsTr("Sort")

    text: VLCIcons.topbar_sort

    checked: _menu && _menu.shown

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)


    // Events

    onClicked: root.show()
    onVisibleChanged: if (!visible) _menu.close()
    onEnabledChanged: if (!enabled) _menu.close()

    // Connections

    Connections {
        target: (_menu) ? _menu : null

        function onSelected(index: int) {
            const entry = root._entries[index]
            if (!entry)
                return

            if (root.sortKey !== entry.criteria)
                root.sortSelected(entry.criteria)
            root.sortOrderSelected(entry.order)
        }
    }

    // Functions

    // Entries of the menu, laid out like the "Sorting Options" of the
    // VLC Redesign Figma file: one entry per sort key and direction
    property var _entries: []

    readonly property var _dateKeys: ["release_year", "last_played_date", "fileModified", "insertion"]
    readonly property var _numericKeys: ["duration", "track_number", "disc_number", "nb_tracks", "nb_videos",
                                         "count", "fileSizeRaw64", "mrl", "url"]

    function show() {
        const dateCount = root.model.filter((m) => _dateKeys.includes(m.criteria)).length
        const entries = []

        for (let i = 0; i < root.model.length; ++i) {
            const modelData = root.model[i]
            const key = modelData.criteria
            if (key === "playcount") {
                // Figma "Sorting Options": Unwatched First / Watched First
                entries.push({ criteria: key, order: Qt.AscendingOrder, text: qsTr("Unwatched First") })
                entries.push({ criteria: key, order: Qt.DescendingOrder, text: qsTr("Watched First") })
            } else if (_dateKeys.includes(key)) {
                const prefix = (dateCount > 1) ? modelData.text + ": " : ""
                entries.push({ criteria: key, order: Qt.DescendingOrder, text: prefix + qsTr("Newest First") })
                entries.push({ criteria: key, order: Qt.AscendingOrder, text: prefix + qsTr("Oldest First") })
            } else if (_numericKeys.includes(key)) {
                entries.push({ criteria: key, order: Qt.AscendingOrder, text: qsTr("%1 Ascending").arg(modelData.text) })
                entries.push({ criteria: key, order: Qt.DescendingOrder, text: qsTr("%1 Descending").arg(modelData.text) })
            } else {
                entries.push({ criteria: key, order: Qt.AscendingOrder, text: qsTr("%1 A-Z").arg(modelData.text) })
                entries.push({ criteria: key, order: Qt.DescendingOrder, text: qsTr("%1 Z-A").arg(modelData.text) })
            }
        }
        root._entries = entries

        const model = entries.map((entry) => ({
            "text": entry.text,
            "checked": entry.criteria === root.sortKey && entry.order === root.sortOrder
        }))

        let point

        if (root.popupAbove)
            point = root.mapToGlobal(0, - VLCStyle.margin_xxsmall)
        else
            point = root.mapToGlobal(0, root.height + VLCStyle.margin_xxsmall)

        root._menu.popup(point, root.popupAbove, model)
    }

    // Children

    SortMenu {
        id: sortMenu

        ctx: MainCtx
    }
}

