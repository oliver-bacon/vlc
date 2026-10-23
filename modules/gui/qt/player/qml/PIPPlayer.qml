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

import VLC.Dialogs
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
    width: Math.round(VLCStyle.dp(391, VLCStyle.scale))
    height: Math.round(cardColumn.implicitHeight + 2 * cardPadding)

    readonly property real cardPadding: VLCStyle.dp(9, VLCStyle.scale)
    padding: cardPadding
    readonly property bool dark: VLCStyle.palette?.isDark ?? true
    readonly property real videoRadius: VLCStyle.dp(5, VLCStyle.scale)
    readonly property color trackColor: dark ? "#090909" : "#D5D5D5"
    readonly property bool cardHovered: hoverHandler.hovered || playButton.hovered || closeButton.hovered
                                    || fullscreenButton.hovered || prevButton.hovered || nextButton.hovered

    objectName: "pip window"

    property real dragXMin: 0
    property real dragXMax: 0
    property real dragYMin: undefined
    property real dragYMax: undefined

    property int textStyle: Text.Outline

    // VLC Redesign: the play queue opens inside the card, above the video
    property bool queueOpen: false

    // the card keeps its bottom edge when the queue opens or closes; while
    // it is anchored the anchors do that, once dragged it is done here
    property bool _dragged: false
    property real _previousHeight: 0

    onHeightChanged: {
        if (_dragged && _previousHeight > 0)
            y = Math.max(dragYMin || 0, y - (height - _previousHeight))
        _previousHeight = height
    }

    // `hideControls` being `false` does not necessarily mean that the buttons are shown:
    property bool hideControls: MainCtx.usingTouch // By default controls are hidden with touch

    Accessible.role: Accessible.Graphic
    Accessible.focusable: false
    Accessible.name: qsTr("video content")

    Drag.active: dragHandler.active

    Drag.onActiveChanged: _detach()

    // the card stops following its anchors once it is dragged
    function _detach() {
        root._dragged = true
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
        id: cardBackground
        radius: VLCStyle.dp(14, VLCStyle.scale)
        color: root.dark ? "#1F1F1F" : "#E7E7E7"

        Widgets.DefaultShadow {
        }

        // The video is drawn in the background, under the tap / drag
        // handlers (like VLC's original PiP): VideoSurface accepts every
        // mouse button, so in the content item it would swallow the clicks
        // meant for tap-to-pause, dragging and double-click. It is placed
        // over `videoSlot` of the card layout.
        VideoSurface {
            id: videoSurface

            x: cardColumn.x + videoSlot.x
            y: cardColumn.y + videoSlot.y
            width: videoSlot.width
            height: videoSlot.height

            videoSurfaceProvider: MainCtx.videoSurfaceProvider
            color: root.cardHovered ? "#40000000" : "transparent"
        }

        // Figma "Miniplayer": the video has 5 px rounded corners and a 2 px
        // outline (#090909, centered on the edge). The corners are covered
        // with the card color: a border whose inner edge is the rounded video
        // frame, clipped to the video
        Item {
            x: videoSurface.x
            y: videoSurface.y
            width: videoSurface.width
            height: videoSurface.height
            clip: true

            Rectangle {
                readonly property real cover: root.videoRadius + VLCStyle.dp(2, VLCStyle.scale)
                anchors.fill: parent
                anchors.margins: -cover
                radius: root.videoRadius + cover
                color: "transparent"
                border.width: cover
                border.color: cardBackground.color
                antialiasing: true
            }
        }

        Rectangle {
            readonly property real lineWidth: VLCStyle.dp(2, VLCStyle.scale)
            x: videoSurface.x - lineWidth / 2
            y: videoSurface.y - lineWidth / 2
            width: videoSurface.width + lineWidth
            height: videoSurface.height + lineWidth
            radius: root.videoRadius + lineWidth / 2
            color: "transparent"
            border.width: lineWidth
            // no light Figma frame: same color as the progress track, like dark
            border.color: root.trackColor
            antialiasing: true
        }
    }

    contentItem: ColumnLayout {
        id: cardColumn

        // above the drag / tap handlers, so that the buttons get the clicks
        z: 1

        spacing: VLCStyle.dp(8, VLCStyle.scale)

        MiniQueue {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            visible: root.queueOpen

            dragTarget: root
            dragXMin: root.dragXMin
            dragXMax: root.dragXMax
            dragYMin: root.dragYMin
            dragYMax: root.dragYMax

            onAddRequested: DialogsProvider.PLAppendDialog()
            onDragStarted: root._detach()
        }

        // video slot (the video itself is in the background), with the
        // controls on hover
        Item {
            id: videoSlot

            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(width * 9 / 16)

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

        // progress (Figma "Miniplayer"): 16 px track, 1 px wider than the
        // video on each side and 5 px below it; the fill is inset by 2 px;
        // the 8 x 12 knob only shows while the card is hovered
        Rectangle {
            id: progressTrack

            readonly property real inset: VLCStyle.dp(2, VLCStyle.scale)
            readonly property real fillWidth: width - 2 * inset

            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(16, VLCStyle.scale)
            Layout.leftMargin: -VLCStyle.dp(1, VLCStyle.scale)
            Layout.rightMargin: -VLCStyle.dp(1, VLCStyle.scale)
            Layout.topMargin: VLCStyle.dp(5, VLCStyle.scale) - cardColumn.spacing
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: root.trackColor

            Rectangle {
                x: progressTrack.inset
                y: progressTrack.inset
                width: Math.max(2 * radius, progressTrack.fillWidth * Player.position)
                height: parent.height - 2 * progressTrack.inset
                radius: VLCStyle.dp(4, VLCStyle.scale)
                color: root.dark ? VLCStyle.palette.accentBrightDark : VLCStyle.palette.accentBrightLight
            }
            Rectangle {
                visible: root.cardHovered
                x: progressTrack.inset + Math.max(0, progressTrack.fillWidth * Player.position - width)
                y: progressTrack.inset
                width: VLCStyle.dp(8, VLCStyle.scale)
                height: parent.height - 2 * progressTrack.inset
                radius: VLCStyle.dp(4, VLCStyle.scale)
                color: VLCStyle.palette.orange500
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
                id: queueButton

                text: VLCIcons.playlist
                description: qsTr("Play Queue")
                checked: root.queueOpen
                onClicked: root.queueOpen = !root.queueOpen
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
