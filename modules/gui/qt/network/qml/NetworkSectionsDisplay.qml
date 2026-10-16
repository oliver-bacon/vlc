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
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Dialogs
import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets

// First page of "Network" (VLC Redesign, Figma "sidebar" frame): Add Network
// Stream, Podcasts, Radio, and the saved streams (StreamsDisplay.qml).
Widgets.PageExt {
    id: root

    title: qsTr("Network")

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    // VLC's services discovery modules "podcast" and "radio"
    readonly property var _sections: [
        { "title": qsTr("Podcasts"), "icon": VLCIcons.stream, "uri": ["streams", "services", "source_root"], "source": "podcast" },
        { "title": qsTr("Radio"),    "icon": VLCIcons.stream, "uri": ["streams", "services", "source_root"], "source": "radio" },
        { "title": qsTr("Saved Streams"), "icon": VLCIcons.link, "uri": ["streams", "url"] }
    ]

    Item {
        id: content

        anchors.fill: parent
        focus: true

        function setCurrentItemFocus(reason) {
            listView.forceActiveFocus(reason)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: VLCStyle.dynamicAppMargins(content.width) + VLCStyle.layout_left_margin
            anchors.rightMargin: VLCStyle.dynamicAppMargins(content.width) + VLCStyle.layout_right_margin
            spacing: VLCStyle.margin_xsmall

            Text {
                Layout.fillWidth: true
                text: qsTr("%1 items").arg(root._sections.length)
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_normal
            }

            ListView {
                id: listView

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                focus: true
                boundsBehavior: Flickable.StopAtBounds

                // "Add Network Stream": VLC's network stream dialog
                model: [{ "title": qsTr("Add Network Stream"), "icon": VLCIcons.add, "uri": null }].concat(root._sections)

                delegate: T.ItemDelegate {
                    id: row

                    required property var modelData

                    width: ListView.view.width
                    height: VLCStyle.dp(48, VLCStyle.scale)
                    leftPadding: VLCStyle.margin_xsmall

                    Accessible.name: modelData.title

                    background: Rectangle {
                        radius: VLCStyle.dp(4, VLCStyle.scale)
                        color: row.hovered || row.activeFocus ? theme.bg.secondary : "transparent"
                    }

                    contentItem: RowLayout {
                        spacing: VLCStyle.margin_small

                        Widgets.IconLabel {
                            Layout.preferredWidth: VLCStyle.icon_normal
                            text: row.modelData.icon
                            color: theme.fg.secondary
                            font.pixelSize: VLCStyle.icon_normal
                        }
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.title
                            color: theme.fg.primary
                            font.pixelSize: VLCStyle.fontSize_normal
                        }
                    }

                    onClicked: {
                        if (!modelData.uri)
                            DialogsProvider.openNetDialog()
                        else if (modelData.source)
                            History.push(modelData.uri, { "source_name": modelData.source })
                        else
                            History.push(modelData.uri)
                    }
                }
            }
        }
    }
}
