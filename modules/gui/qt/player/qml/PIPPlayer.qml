/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
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
import QtQuick.Templates as T
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Playlist
import VLC.Player
import VLC.Util

T.Control {
    id: root
    // Figma "Miniplayer" card: video, progress, title, folder / artist and
    // the play queue toggle; controls over the video on hover
    width: Math.round(VLCStyle.dp(360, VLCStyle.scale))
    height: Math.round(cardColumn.implicitHeight + 2 * cardPadding)

    readonly property real cardPadding: VLCStyle.dp(6, VLCStyle.scale)
    padding: cardPadding
    readonly property bool dark: VLCStyle.palette?.isDark ?? true
    readonly property bool cardHovered: hoverHandler.hovered || playButton.hovered || closeButton.hovered
                                    || fullscreenButton.hovered || prevButton.hovered || nextButton.hovered

    objectName: "pip window"

    property real dragXMin: 0
    property real dragXMax: 0
    property real dragYMin: undefined
    property real dragYMax: undefined

    property int textStyle: Text.Outline

    // `hideControls` being `false` does not necessarily mean that the buttons are shown:
    property bool hideControls: MainCtx.usingTouch // By default controls are hidden with touch

    Accessible.role: Accessible.Graphic
    Accessible.focusable: false
    Accessible.name: qsTr("video content")

    Drag.active: dragHandler.active

    Drag.onActiveChanged: {
        root.anchors.left = undefined
        root.anchors.right = undefined
        root.anchors.top = undefined
        root.anchors.bottom = undefined
        root.anchors.verticalCenter = undefined
        root.anchors.horizontalCenter = undefined
    }

    DoubleClickIgnoringItem {
        anchors.fill: parent

        TapHandler {
            gesturePolicy: TapHandler.WithinBounds

            onDoubleTapped: (eventPoint, button) => {
                // Docs are lying, there is no `deviceType`: QTBUG-135104
                if (eventPoint.device.type !== PointerDevice.TouchScreen)
                    MainCtx.playerView = true
            }

            onTapped: (eventPoint, button) => {
                // Docs are lying, there is no `deviceType`: QTBUG-135104
                if (eventPoint.device.type === PointerDevice.TouchScreen) {
                    // Breaking the initial binding is intentional here:
                    root.hideControls = !root.hideControls
                } else {
                    MainPlaylistController.togglePlayPause()
                }
            }
        }

        DragHandler {
            id: dragHandler

            target: root

            cursorShape: Qt.DragMoveCursor

            dragThreshold: 0

            grabPermissions: PointerHandler.CanTakeOverFromAnything

            xAxis.minimum: root.dragXMin
            xAxis.maximum: root.dragXMax
            yAxis.minimum: root.dragYMin
            yAxis.maximum: root.dragYMax
        }

        HoverHandler {
            id: hoverHandler

            grabPermissions: PointerHandler.CanTakeOverFromAnything
            cursorShape: Qt.ArrowCursor

            Component.onCompleted: {
                if (typeof blocking === 'boolean')
                    blocking = true // Qt 6.3 feature
            }
        }
    }

    background: Rectangle {
        radius: VLCStyle.dp(12, VLCStyle.scale)
        color: root.dark ? "#1F1F1F" : "#E7E7E7"

        Widgets.DefaultShadow {
        }
    }

    contentItem: ColumnLayout {
        id: cardColumn

        spacing: VLCStyle.dp(8, VLCStyle.scale)

        // video, with the controls on hover
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(width * 9 / 16)

            VideoSurface {
                id: videoSurface

                anchors.fill: parent
                videoSurfaceProvider: MainCtx.videoSurfaceProvider
                color: root.cardHovered ? "#40000000" : "transparent"
            }

            Item {
                anchors.fill: parent
                visible: !root.hideControls && root.cardHovered

                Widgets.IconButton {
                    id: closeButton
                    anchors { top: parent.top; left: parent.left; margins: VLCStyle.margin_small }
                    font.pixelSize: VLCStyle.icon_PIP
                    description: qsTr("close video")
                    AccessibleCompat.id: "pipCloseButton"
                    text: VLCIcons.close
                    textStyle: root.textStyle
                    onClicked: MainPlaylistController.stop()
                }

                Widgets.IconButton {
                    id: fullscreenButton
                    anchors { top: parent.top; right: parent.right; margins: VLCStyle.margin_small }
                    font.pixelSize: VLCStyle.icon_PIP
                    description: qsTr("open the player")
                    AccessibleCompat.id: "pipFullscreenButton"
                    text: VLCIcons.open
                    textStyle: root.textStyle
                    onClicked: MainCtx.playerView = true
                }

                Row {
                    anchors.centerIn: parent
                    spacing: VLCStyle.margin_large

                    Widgets.IconButton {
                        id: prevButton
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: VLCStyle.icon_medium
                        description: qsTr("previous")
                        text: VLCIcons.previous
                        textStyle: root.textStyle
                        onClicked: MainPlaylistController.prev()
                    }

                    Widgets.IconButton {
                        id: playButton
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: VLCStyle.icon_large
                        description: qsTr("play/pause")
                        AccessibleCompat.id: "pipPlayButton"
                        text: (Player.playingState !== Player.PLAYING_STATE_PAUSED
                               && Player.playingState !== Player.PLAYING_STATE_STOPPED)
                              ? VLCIcons.pause_filled
                              : VLCIcons.play_filled
                        textStyle: root.textStyle
                        onClicked: MainPlaylistController.togglePlayPause()
                    }

                    Widgets.IconButton {
                        id: nextButton
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: VLCStyle.icon_medium
                        description: qsTr("next")
                        text: VLCIcons.next
                        textStyle: root.textStyle
                        onClicked: MainPlaylistController.next()
                    }
                }
            }
        }

        // progress
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(8, VLCStyle.scale)
            radius: height / 2
            color: root.dark ? "#090909" : "#D5D5D5"

            Rectangle {
                width: Math.max(height, parent.width * Player.position)
                height: parent.height
                radius: parent.radius
                color: root.dark ? "#371F06" : "#D8BA9A"
            }
            Rectangle {
                x: Math.max(0, parent.width * Player.position - width)
                width: VLCStyle.dp(4, VLCStyle.scale)
                height: parent.height
                radius: width / 2
                color: "#D37918"
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: VLCStyle.dp(6, VLCStyle.scale)
            text: Player.title || Player.name
            color: root.dark ? "#C6C6C6" : "#161616"
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            elide: Text.ElideRight
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: VLCStyle.dp(6, VLCStyle.scale)
            Layout.rightMargin: VLCStyle.dp(6, VLCStyle.scale)
            Layout.bottomMargin: VLCStyle.dp(4, VLCStyle.scale)
            spacing: VLCStyle.dp(8, VLCStyle.scale)

            readonly property string folder: {
                const parts = decodeURIComponent(String(Player.url)).split("/").filter((p) => p !== "")
                return parts.length > 1 ? parts[parts.length - 2] : ""
            }

            MetaText { glyph: VLCIcons.topbar_network; text: parent.folder; visible: parent.folder !== "" }
            MetaText { glyph: VLCIcons.artist; text: Player.artist; visible: Player.artist !== "" }
            Item { Layout.fillWidth: true }
            Widgets.IconToolButton {
                text: VLCIcons.playlist
                description: qsTr("Play Queue")
                checked: MainCtx.playqueuePanel.visible
                onClicked: MainCtx.playqueuePanel.visible = !MainCtx.playqueuePanel.visible
            }
        }
    }

    component MetaText: Row {
        property string glyph
        property alias text: metaLabel.text
        spacing: VLCStyle.dp(6, VLCStyle.scale)
        Text {
            anchors.verticalCenter: parent.verticalCenter
            font.family: VLCIcons.fontFamily
            font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
            text: parent.glyph
            color: "#8F8F8F"
        }
        Text {
            id: metaLabel
            anchors.verticalCenter: parent.verticalCenter
            color: "#8F8F8F"
            font.pixelSize: VLCStyle.dp(13, VLCStyle.scale)
            elide: Text.ElideRight
            width: Math.min(implicitWidth, VLCStyle.dp(110, VLCStyle.scale))
        }
    }
}
