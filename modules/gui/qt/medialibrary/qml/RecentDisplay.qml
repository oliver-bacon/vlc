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

import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets

// "Recent" of the VLC Redesign side navigation: the media played last,
// newest first. Double-click plays, "+" adds to the play queue.
Widgets.PageExt {
    id: root

    title: qsTr("Recent")

    isSearchable: true

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    MLRecentMediaModel {
        id: recentModel
        ml: MediaLib
        searchPattern: root.search.pattern
    }

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

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: recentModel.count === 1 ? qsTr("1 item") : qsTr("%1 items").arg(recentModel.count)
                    color: theme.fg.secondary
                    font.pixelSize: VLCStyle.fontSize_normal
                }

                Widgets.ButtonExt {
                    text: qsTr("Clear History")
                    enabled: recentModel.count > 0
                    onClicked: recentModel.clearHistory()
                }
            }

            ListView {
                id: listView

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                focus: true
                boundsBehavior: Flickable.StopAtBounds
                model: recentModel

                T.ScrollBar.vertical: Widgets.ScrollBarExt { }

                delegate: T.ItemDelegate {
                    id: row

                    required property var model
                    required property int index

                    width: ListView.view.width
                    height: VLCStyle.dp(48, VLCStyle.scale)
                    leftPadding: VLCStyle.margin_xsmall
                    rightPadding: VLCStyle.margin_xsmall

                    Accessible.name: model.title ?? ""

                    background: Rectangle {
                        radius: VLCStyle.dp(4, VLCStyle.scale)
                        color: row.hovered ? theme.bg.secondary : "transparent"
                    }

                    contentItem: RowLayout {
                        spacing: VLCStyle.margin_small

                        Rectangle {
                            Layout.preferredWidth: VLCStyle.dp(64, VLCStyle.scale)
                            Layout.preferredHeight: VLCStyle.dp(36, VLCStyle.scale)
                            radius: VLCStyle.dp(3, VLCStyle.scale)
                            color: theme.bg.secondary
                            clip: true

                            Image {
                                id: cover
                                anchors.fill: parent
                                source: row.model.small_cover ?? ""
                                sourceSize: Qt.size(width * 2, height * 2)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                            Widgets.IconLabel {
                                anchors.centerIn: parent
                                visible: !cover.visible
                                text: row.model.isVideo ? VLCIcons.topbar_video : VLCIcons.topbar_music
                                color: theme.fg.secondary
                                font.pixelSize: VLCStyle.icon_normal
                            }
                            // watched part
                            Rectangle {
                                anchors { left: parent.left; bottom: parent.bottom }
                                height: VLCStyle.dp(2, VLCStyle.scale)
                                width: parent.width * Math.max(0, Math.min(1, row.model.progress ?? 0))
                                color: theme.accent
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: row.model.title ?? ""
                                elide: Text.ElideRight
                                color: theme.fg.primary
                                font.pixelSize: VLCStyle.fontSize_normal
                            }
                            Text {
                                Layout.fillWidth: true
                                text: {
                                    const parts = decodeURIComponent(String(row.model.mrl ?? "")).split("/")
                                    return parts.length > 1 ? parts[parts.length - 2] : ""
                                }
                                elide: Text.ElideMiddle
                                color: theme.fg.secondary
                                font.pixelSize: VLCStyle.fontSize_small
                            }
                        }

                        Text {
                            text: row.model.last_played_date ?? ""
                            color: theme.fg.secondary
                            font.pixelSize: VLCStyle.fontSize_small
                        }

                        Widgets.IconToolButton {
                            visible: row.hovered
                            text: VLCIcons.add
                            description: qsTr("Add to the Play Queue")
                            onClicked: MediaLib.addToPlaylist(row.model.id)
                        }
                    }

                    onDoubleClicked: MediaLib.addAndPlay(row.model.id)
                }

                Text {
                    parent: listView
                    anchors.centerIn: parent
                    visible: listView.count === 0
                    text: qsTr("Nothing played yet")
                    color: theme.fg.secondary
                    font.pixelSize: VLCStyle.fontSize_large
                }
            }
        }
    }
}
