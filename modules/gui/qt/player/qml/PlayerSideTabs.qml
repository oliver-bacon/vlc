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
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.Style

// Queue / Bookmarks / Chapters tabs of the player side panel (VLC Redesign
// video, 15:12): above the play queue, which is the first tab.
Item {
    id: root

    property int currentTab: 0

    signal tabClicked(int index)

    readonly property bool dark: VLCStyle.palette?.isDark ?? true
    readonly property color titleColor: dark ? "#C6C6C6" : "#161616"
    readonly property color dimColor: "#6B6B6B"
    readonly property color accentColor: VLCStyle.palette.orange500
    // tab icons: grey part and accent details (Figma Dark/FG/A2, Dark/Accent/Dim)
    readonly property color iconColor: dark ? "#8F8F8F" : "#2E2E2E"
    readonly property color accentDimColor: VLCStyle.palette.accentDim
    readonly property real dp1: VLCStyle.dp(1, VLCStyle.scale)

    implicitHeight: 44 * dp1

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: VLCStyle.margin_small
        anchors.rightMargin: VLCStyle.margin_small
        spacing: 0

        Repeater {
            model: [
                { "text": qsTr("Queue"), "glyph": VLCIcons.enqueue, "sel": VLCIcons.enqueue_sel, "selAccent": VLCIcons.enqueue_sel_accent },
                { "text": qsTr("Bookmarks"), "glyph": VLCIcons.bookmarks, "sel": VLCIcons.bookmarks_sel, "selAccent": VLCIcons.bookmarks_sel_accent },
                { "text": qsTr("Chapters"), "glyph": VLCIcons.chapters, "sel": VLCIcons.chapters_sel, "selAccent": VLCIcons.chapters_sel_accent }
            ]

            delegate: T.TabButton {
                id: tab

                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.fillHeight: true
                checked: root.currentTab === index
                onClicked: root.tabClicked(index)

                Accessible.name: modelData.text

                background: Item {
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 8 * root.dp1; rightMargin: 8 * root.dp1 }
                        height: 2 * root.dp1
                        visible: tab.checked
                        color: root.accentColor
                    }
                }
                contentItem: Row {
                    spacing: 6 * root.dp1
                    leftPadding: Math.max(0, (tab.width - implicitWidth) / 2)
                    // Figma: the selected tab icon is two-tone, grey with its details in the dim accent
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: tabIcon.implicitWidth
                        implicitHeight: tabIcon.implicitHeight
                        width: implicitWidth
                        height: implicitHeight
                        Text {
                            id: tabIcon
                            font.family: VLCIcons.fontFamily
                            font.pixelSize: 15 * root.dp1
                            text: tab.checked ? tab.modelData.sel : tab.modelData.glyph
                            color: tab.checked ? root.iconColor : root.dimColor
                        }
                        Text {
                            visible: tab.checked
                            font.family: VLCIcons.fontFamily
                            font.pixelSize: 15 * root.dp1
                            text: tab.modelData.selAccent
                            color: root.accentDimColor
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.modelData.text
                        font.pixelSize: 13 * root.dp1
                        color: tab.checked ? root.titleColor : root.dimColor
                    }
                }
            }
        }
    }
}
