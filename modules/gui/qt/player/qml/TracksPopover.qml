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

import VLC.Dialogs
import VLC.MainInterface
import VLC.Player
import VLC.Playlist
import VLC.Style

// Track popover of the VLC Redesign Figma file (subtitle button of the
// player bar): Video / Audio / Subtitles tabs listing the embedded tracks,
// the audio output devices, and "Show Preferences".
T.Popup {
    id: root

    property int currentTab: 1

    width: VLCStyle.dp(400, VLCStyle.scale)
    height: VLCStyle.dp(520, VLCStyle.scale)
    padding: 0
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutsideParent

    readonly property bool dark: VLCStyle.palette?.isDark ?? true
    readonly property color panelColor: dark ? "#191919" : "#E7E7E7"
    readonly property color tabsColor: dark ? "#151515" : "#DEDEDE"
    readonly property color dividerColor: dark ? "#222222" : "#ACACAC"
    readonly property color titleColor: dark ? "#C6C6C6" : "#161616"
    readonly property color textColor: dark ? "#8F8F8F" : "#2E2E2E"
    readonly property color dimColor: "#6B6B6B"
    readonly property color accentColor: "#D37918"
    readonly property real dp1: VLCStyle.dp(1, VLCStyle.scale)

    background: Rectangle {
        radius: 10 * root.dp1
        color: root.panelColor
    }

    contentItem: ColumnLayout {
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50 * root.dp1
            color: root.tabsColor
            radius: 10 * root.dp1

            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: parent.radius
                color: parent.color
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10 * root.dp1
                anchors.rightMargin: 10 * root.dp1
                spacing: 0

                Repeater {
                    model: [
                        { "text": qsTr("Video"), "glyph": VLCIcons.video },
                        { "text": qsTr("Audio"), "glyph": VLCIcons.visualization },
                        { "text": qsTr("Subtitles"), "glyph": VLCIcons.audiosub }
                    ]

                    delegate: T.TabButton {
                        id: tab

                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        checked: root.currentTab === index
                        onClicked: root.currentTab = index

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
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                font.family: VLCIcons.fontFamily
                                font.pixelSize: 15 * root.dp1
                                text: tab.modelData.glyph
                                color: tab.checked ? root.accentColor : root.dimColor
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

        Flickable {
            id: flick

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: column.implicitHeight + 20 * root.dp1
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: column

                x: 20 * root.dp1
                y: 14 * root.dp1
                width: flick.width - 40 * root.dp1
                spacing: 2 * root.dp1

                SectionTitle { text: qsTr("Embedded Tracks") }

                TrackList {
                    model: root.currentTab === 0 ? Player.videoTracks
                         : root.currentTab === 1 ? Player.audioTracks : Player.subtitleTracks
                }

                // subtitles: load a file
                Choice {
                    visible: root.currentTab === 2
                    label: qsTr("Add Subtitle File...")
                    // the Add Subtitles dialog (video 5:00): this file, its
                    // folder or the queue; local files only
                    onClicked: {
                        root.close()
                        const url = String(Player.url)
                        if (!url.startsWith("file:")) {
                            DialogsProvider.loadSubtitlesFile()
                            return
                        }
                        const queue = []
                        for (let i = 0; i < queueModel.count; ++i) {
                            const itemUrl = String(queueModel.itemAt(i).url)
                            if (itemUrl.startsWith("file:"))
                                queue.push(itemUrl)
                        }
                        DialogsProvider.addSubtitlesDialog({ "mode": "file", "mrl": url, "queue": queue })
                    }

                    PlaylistListModel {
                        id: queueModel
                        playlist: MainPlaylistController.playlist
                    }
                }

                // audio: output device
                Rectangle {
                    visible: root.currentTab === 1
                    Layout.fillWidth: true
                    Layout.leftMargin: -20 * root.dp1
                    Layout.rightMargin: -20 * root.dp1
                    Layout.topMargin: 10 * root.dp1
                    Layout.bottomMargin: 10 * root.dp1
                    implicitHeight: 1
                    color: root.dividerColor
                }
                SectionTitle { visible: root.currentTab === 1; text: qsTr("Output Device") }
                Repeater {
                    model: root.currentTab === 1 ? Player.audioDevices : null
                    delegate: Choice {
                        required property var model
                        label: model.display
                        selected: model.checked
                        onClicked: model.checked = true
                    }
                }
            }
        }

        T.Button {
            id: prefs

            Layout.fillWidth: true
            Layout.margins: 10 * root.dp1
            implicitHeight: 30 * root.dp1
            background: Rectangle {
                radius: 4 * root.dp1
                color: prefs.hovered ? root.tabsColor : Qt.darker(root.tabsColor, root.dark ? 1.2 : 1.05)
            }
            contentItem: Text {
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: qsTr("Show Preferences")
                color: root.dimColor
                font.pixelSize: 12 * root.dp1
            }
            onClicked: {
                root.close()
                DialogsProvider.settingsDialog()
            }
        }
    }

    component SectionTitle: Text {
        Layout.bottomMargin: 6 * root.dp1
        color: root.dimColor
        font.pixelSize: 12 * root.dp1
    }

    // "None" followed by the tracks; a check mark on the selected one(s)
    component TrackList: ColumnLayout {
        id: list

        property var model

        Layout.fillWidth: true
        spacing: 2 * root.dp1

        Choice {
            id: noneChoice
            property bool anyChecked: false
            label: qsTr("None")
            selected: !anyChecked
            onClicked: {
                for (let i = 0; i < tracks.count; ++i) {
                    if (tracks.itemAt(i)?.trackChecked)
                        tracks.itemAt(i).uncheck()
                }
            }
        }

        Repeater {
            id: tracks

            model: list.model

            function refresh() {
                let any = false
                for (let i = 0; i < count; ++i)
                    any = any || !!itemAt(i)?.trackChecked
                noneChoice.anyChecked = any
            }

            onItemAdded: refresh()
            onItemRemoved: refresh()

            delegate: Choice {
                required property var model
                readonly property bool trackChecked: model.checked

                function uncheck() { model.checked = false }

                label: model.display
                selected: trackChecked
                onTrackCheckedChanged: tracks.refresh()
                onClicked: model.checked = !model.checked
            }
        }
    }

    component Choice: T.ItemDelegate {
        id: choice

        property string label
        property bool selected: false

        Layout.fillWidth: true
        implicitHeight: 32 * root.dp1
        leftPadding: 6 * root.dp1

        background: Rectangle {
            radius: 4 * root.dp1
            color: choice.hovered ? root.tabsColor : "transparent"
        }
        contentItem: RowLayout {
            spacing: 10 * root.dp1
            Text {
                Layout.preferredWidth: 16 * root.dp1
                font.family: VLCIcons.fontFamily
                font.pixelSize: 14 * root.dp1
                text: choice.selected ? VLCIcons.check : ""
                color: root.accentColor
            }
            Text {
                Layout.fillWidth: true
                text: choice.label
                color: choice.selected ? root.titleColor : root.textColor
                font.pixelSize: 13 * root.dp1
                elide: Text.ElideRight
            }
        }
    }
}
