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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick

import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Menus
import VLC.Style
import VLC.Util

// "Frequently Visited Folders" of the VLC Redesign home page.
// The media library does not count folder visits, so the folders are
// ranked by the play counts of the recently played local media they
// contain. A click opens the folder in the browser; right-click pins it to
// the side navigation.
FocusScope {
    id: root

    property int maximumCount: 6
    property real leftPadding: 0
    property real rightPadding: 0

    // read by Widgets.ViewHeader to align the title
    readonly property real contentLeftMargin: leftPadding
    readonly property real contentRightMargin: rightPadding

    readonly property int count: _folders.length

    property var _folders: []

    implicitHeight: flow.implicitHeight + VLCStyle.margin_normal

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Item
    }

    MLRecentMediaModel {
        id: recentModel
        ml: MediaLib
        limit: 200
    }

    // reads mrl and play count of every row; the rows load asynchronously,
    // so the list is rebuilt (with a short delay) whenever one changes
    Item {
        visible: false

        Repeater {
            id: rows
            model: recentModel

            Item {
                required property var mrl
                required property var playcount

                onMrlChanged: rebuild.restart()
                onPlaycountChanged: rebuild.restart()
                Component.onCompleted: rebuild.restart()
                Component.onDestruction: rebuild.restart()
            }
        }
    }

    Timer {
        id: rebuild
        interval: 100
        onTriggered: root._rebuild()
    }

    function _rebuild() {
        const scores = {}
        for (let i = 0; i < rows.count; ++i) {
            const row = rows.itemAt(i)
            if (!row)
                continue
            const mrl = String(row.mrl ?? "")
            if (!mrl.startsWith("file://"))
                continue
            const folder = mrl.substring(0, mrl.lastIndexOf("/"))
            if (folder.length <= "file://".length)
                continue
            scores[folder] = (scores[folder] ?? 0) + Math.max(1, Number(row.playcount) || 0)
        }
        _folders = Object.keys(scores)
            .sort((a, b) => scores[b] - scores[a] || a.localeCompare(b))
            .slice(0, maximumCount)
            .map((url) => {
                const parts = decodeURIComponent(url).split("/")
                return {
                    url: url,
                    name: parts[parts.length - 1],
                    parent: parts.length > 1 ? parts[parts.length - 2] : ""
                }
            })
    }

    function _open(folder) {
        History.push(["network", "browse"], { "tree": VLCConfig.browseNode(folder.url) })
    }

    function _pin(folder) {
        let list = []
        try {
            list = JSON.parse(VLCConfig.uiValue("Library/Pins", "[]"))
            if (!Array.isArray(list))
                list = []
        } catch (e) {
            list = []
        }
        list = list.filter((p) => !(p.type === "folder" && p.url === folder.url))
        list.push({ type: "folder", url: folder.url, name: folder.name })
        VLCConfig.setUiValue("Library/Pins", JSON.stringify(list))
    }

    StringListMenu {
        id: menu

        ctx: MainCtx

        property var folder: null

        onSelected: (index, text) => {
            if (!folder)
                return
            if (index === 0)
                root._open(folder)
            else
                root._pin(folder)
        }
    }

    Flow {
        id: flow

        x: root.leftPadding
        width: root.width - root.leftPadding - root.rightPadding
        topPadding: VLCStyle.margin_xsmall
        spacing: VLCStyle.margin_normal

        Repeater {
            model: root._folders

            Rectangle {
                id: card

                required property var modelData
                required property int index

                width: VLCStyle.colWidth(2)
                height: VLCStyle.dp(56, VLCStyle.scale)
                radius: VLCStyle.dp(8, VLCStyle.scale)
                color: mouse.containsMouse || activeFocus ? theme.bg.highlight : theme.bg.secondary

                focus: index === 0
                activeFocusOnTab: true

                Accessible.role: Accessible.Button
                Accessible.name: modelData.name

                Keys.onReturnPressed: root._open(modelData)
                Keys.onEnterPressed: root._open(modelData)

                Text {
                    id: glyph

                    anchors.left: parent.left
                    anchors.leftMargin: VLCStyle.margin_normal
                    anchors.verticalCenter: parent.verticalCenter

                    font.family: VLCIcons.fontFamily
                    font.pixelSize: VLCStyle.icon_normal
                    text: VLCIcons.topbar_network
                    color: theme.accent
                }

                Column {
                    anchors.left: glyph.right
                    anchors.leftMargin: VLCStyle.margin_small
                    anchors.right: parent.right
                    anchors.rightMargin: VLCStyle.margin_normal
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        width: parent.width
                        text: card.modelData.name
                        elide: Text.ElideRight
                        color: theme.fg.primary
                        font.pixelSize: VLCStyle.fontSize_normal
                        font.weight: Font.DemiBold
                    }

                    Text {
                        width: parent.width
                        text: card.modelData.parent
                        visible: text !== ""
                        elide: Text.ElideRight
                        color: theme.fg.secondary
                        font.pixelSize: VLCStyle.fontSize_small
                    }
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor

                    onClicked: (mouseEvent) => {
                        if (mouseEvent.button === Qt.RightButton) {
                            menu.folder = card.modelData
                            menu.popup(card.mapToGlobal(mouseEvent.x, mouseEvent.y),
                                       [{ "text": qsTr("Open") }, { "text": qsTr("Pin to Sidebar") }])
                        } else {
                            root._open(card.modelData)
                        }
                    }
                }
            }
        }
    }
}
