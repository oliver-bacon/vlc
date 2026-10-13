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
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Menus
import VLC.Style
import VLC.Dialogs

// "Keyboard Shortcuts" from the VLC Redesign Figma file: every VLC hotkey
// with its global hotkey, grouped, searchable. Click a key field and press
// the new key (Backspace removes it, Escape cancels). Nothing is written
// until "Save".
FigmaDialog {
    id: root

    title: qsTr("Keyboard Shortcuts")

    width: VLCStyle.dp(1048, VLCStyle.scale)
    height: VLCStyle.dp(800, VLCStyle.scale)

    saveEnabled: Object.keys(_pending).length > 0

    // name -> new value, until saved
    property var _pending: ({})
    property var _hotkeys: []
    property string _editing: ""
    property int _scope: 0 // 0: all fields, 1: action, 2: hotkey, 3: global hotkey

    readonly property var _scopes: [qsTr("All Fields"), qsTr("Action"), qsTr("Hotkey"), qsTr("Global Hotkey")]

    // groups of the design, the rest goes to "Other"
    // order of the "Basic" group of the design, then VLC's other basic keys
    readonly property var _basicKeys: ["key-toggle-fullscreen", "key-leave-fullscreen", "key-position",
                                       "key-intf-show", "key-intf-hide", "key-intf-popup-menu",
                                       "key-unzoom", "key-intf-boss", "key-quit"]

    function _group(name) {
        if (_basicKeys.includes(name))
            return qsTr("Basic")
        if (/bookmark/.test(name))
            return qsTr("Bookmarks")
        if (/jump/.test(name))
            return qsTr("Navigation")
        if (/vol-|audio|mute/.test(name))
            return qsTr("Audio")
        if (/subtitle|subdelay|subpos|subsync|sub-/.test(name))
            return qsTr("Subtitles")
        if (/aspect|crop|deinterlace|zoom|wallpaper|snapshot|viewpoint|video/.test(name))
            return qsTr("Video")
        if (/play|pause|stop|next|prev|faster|slower|rate|frame|record|loop|random|program|title|chapter|dvd|nav-/.test(name))
            return qsTr("Playback")
        return qsTr("Other")
    }

    readonly property var _groupOrder: [qsTr("Basic"), qsTr("Playback"), qsTr("Navigation"), qsTr("Audio"),
                                        qsTr("Video"), qsTr("Subtitles"), qsTr("Bookmarks"), qsTr("Other")]

    function reset() {
        _pending = {}
        _editing = ""
        search.text = ""
        const list = VLCConfig.hotkeys().map((h, i) => Object.assign(h, { group: _group(h.name), order: i }))
        const rank = (h) => _groupOrder.indexOf(h.group) * 10000
                            + (h.group === qsTr("Basic") ? _basicKeys.indexOf(h.name) : h.order)
        list.sort((a, b) => rank(a) - rank(b))
        _hotkeys = list
    }

    function _value(name) {
        if (!name)
            return ""
        return (name in _pending) ? _pending[name] : String(VLCConfig.value(name) ?? "")
    }

    function _set(name, value) {
        const pending = Object.assign({}, _pending)
        if (value === String(VLCConfig.value(name) ?? ""))
            delete pending[name]
        else
            pending[name] = value
        _pending = pending
    }

    function _matches(h) {
        const q = search.text.trim().toLowerCase()
        if (q === "")
            return true
        const fields = []
        if (_scope === 0 || _scope === 1) fields.push(h.text)
        if (_scope === 0 || _scope === 2) fields.push(VLCConfig.keyDisplayText(_value(h.name)))
        if (_scope === 0 || _scope === 3) fields.push(VLCConfig.keyDisplayText(_value(h.global)))
        return fields.join("\n").toLowerCase().includes(q)
    }

    function _refresh() {
        hotkeyModel.clear()
        for (const h of _hotkeys) {
            if (_matches(h))
                hotkeyModel.append({ "name": h.name, "text": h.text, "global": h.global, "group": h.group })
        }
    }

    on_HotkeysChanged: _refresh()
    on_ScopeChanged: _refresh()

    onAccepted: {
        for (const name in _pending)
            VLCConfig.setValue(name, _pending[name])
    }

    headerContent: RowLayout {
        width: parent.width
        spacing: VLCStyle.dp(10, VLCStyle.scale)

        FigmaDialog.TextField {
            id: search

            Layout.fillWidth: true
            implicitHeight: VLCStyle.dp(34, VLCStyle.scale)
            leftPadding: VLCStyle.dp(42, VLCStyle.scale)
            placeholderText: qsTr("Search Keyboard Shortcuts...")
            onTextChanged: root._refresh()
            background: Rectangle {
                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: root.dark ? "#151515" : "#DEDEDE"
            }

            Text {
                anchors { left: parent.left; leftMargin: VLCStyle.dp(12, VLCStyle.scale); verticalCenter: parent.verticalCenter }
                font.family: VLCIcons.fontFamily
                font.pixelSize: VLCStyle.icon_small
                text: VLCIcons.search
                color: root.textColor
            }
        }

        T.Button {
            id: scopeButton

            Layout.preferredWidth: VLCStyle.dp(200, VLCStyle.scale)
            implicitHeight: VLCStyle.dp(34, VLCStyle.scale)
            background: Rectangle {
                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: root.dark ? "#151515" : "#DEDEDE"
            }
            contentItem: RowLayout {
                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: VLCStyle.dp(12, VLCStyle.scale)
                    text: root._scopes[root._scope]
                    color: root.dark ? "#969696" : root.textColor
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                }
                Text {
                    Layout.rightMargin: VLCStyle.dp(12, VLCStyle.scale)
                    font.family: VLCIcons.fontFamily
                    font.pixelSize: VLCStyle.icon_small
                    text: VLCIcons.chevron_down
                    color: root.textColor
                }
            }
            onClicked: scopeMenu.popup(mapToGlobal(0, height + VLCStyle.dp(4, VLCStyle.scale)),
                                       root._scopes.map((t, i) => ({ "text": t, "checked": i === root._scope })))

            StringListMenu {
                id: scopeMenu
                ctx: MainCtx
                onSelected: (index, _) => { root._scope = index }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // column titles
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(40, VLCStyle.scale)

            Text { Layout.fillWidth: true; text: qsTr("Action"); color: root.dimColor; font.pixelSize: VLCStyle.dp(14, VLCStyle.scale) }
            Text { Layout.preferredWidth: list.fieldWidth; horizontalAlignment: Text.AlignHCenter; text: qsTr("Hotkey"); color: root.dimColor; font.pixelSize: VLCStyle.dp(14, VLCStyle.scale) }
            Item { Layout.preferredWidth: list.columnGap }
            Text { Layout.preferredWidth: list.fieldWidth; horizontalAlignment: Text.AlignHCenter; text: qsTr("Global Hotkey"); color: root.dimColor; font.pixelSize: VLCStyle.dp(14, VLCStyle.scale) }
        }

        ListView {
            id: list

            readonly property real fieldWidth: VLCStyle.dp(270, VLCStyle.scale)
            readonly property real columnGap: VLCStyle.dp(89, VLCStyle.scale)

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            model: ListModel { id: hotkeyModel }

            section.property: "group"
            section.delegate: Text {
                required property string section
                height: VLCStyle.dp(64, VLCStyle.scale)
                verticalAlignment: Text.AlignBottom
                bottomPadding: VLCStyle.dp(14, VLCStyle.scale)
                text: section
                color: root.dark ? "#969696" : root.textColor
                font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
            }

            delegate: RowLayout {
                required property var model
                readonly property var modelData: model

                width: ListView.view.width
                height: VLCStyle.dp(47, VLCStyle.scale)

                Text {
                    Layout.fillWidth: true
                    text: modelData.text
                    color: root.titleColor
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    elide: Text.ElideRight
                }

                KeyField { option: modelData.name }
                Item { Layout.preferredWidth: list.columnGap }
                KeyField { option: modelData.global }
            }
        }
    }

    // a key field: shows the key, click it then press the new key
    component KeyField: T.Control {
        id: field

        property string option

        readonly property bool editing: option !== "" && root._editing === option

        Layout.preferredWidth: list.fieldWidth
        implicitHeight: VLCStyle.dp(33, VLCStyle.scale)
        enabled: option !== ""
        focusPolicy: Qt.ClickFocus

        background: Rectangle {
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: root.wellColor
            border.width: field.editing ? 1 : 0
            border.color: root.accentColor
        }

        contentItem: Item {
            Text {
                anchors.centerIn: parent
                text: field.editing ? qsTr("Press a key...") : VLCConfig.keyDisplayText(root._value(field.option))
                color: field.editing ? root.accentColor : root.titleColor
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            }
            Text {
                anchors { right: parent.right; rightMargin: VLCStyle.dp(10, VLCStyle.scale); verticalCenter: parent.verticalCenter }
                visible: field.enabled
                font.family: VLCIcons.fontFamily
                font.pixelSize: VLCStyle.icon_small
                text: VLCIcons.edit
                color: root.textColor
            }
        }

        TapHandler {
            onTapped: {
                root._editing = field.option
                field.forceActiveFocus()
            }
        }

        onActiveFocusChanged: if (!activeFocus && editing) root._editing = ""

        Keys.onPressed: (event) => {
            if (!field.editing)
                return
            event.accepted = true
            if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
                root._editing = ""
                return
            }
            if (event.key === Qt.Key_Backspace && event.modifiers === Qt.NoModifier) {
                root._set(field.option, "")
                root._editing = ""
                return
            }
            const key = VLCConfig.keyFromEvent(event.key, event.modifiers, event.text)
            if (key === "")
                return
            root._set(field.option, key)
            root._editing = ""
        }
    }
}
