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
import QtQuick.Templates as T

import VLC.Player
import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets

// Subtitle timeline of the VLC Redesign seek bar (video 6:48-7:12, Figma
// "Controls"): the bar shows a window of time around the playhead with a
// block for each subtitle line. "<" / ">" move the subtitles earlier /
// later (subtitle delay), "-" / "+" zoom the window out / in. Clicking or
// dragging in the bar seeks, like the normal seek bar.
Item {
    id: root

    // [start0, end0, start1, end1, ...] in ms, from SubtitleCues
    property var cues: []

    property color trackColor: "#0D0D0D"
    property color playedColor: "#371F06"
    property color accentColor: "#D37918"
    property color cueColor: "#2E2E2E"
    property color playedCueColor: "#5A3F2A"
    property real radius: VLCStyle.dp(6, VLCStyle.scale)

    // milliseconds
    readonly property real timeMs: Player.time.valid() ? Player.time.toMilliseconds() : 0
    readonly property real lengthMs: Player.length.valid() ? Player.length.toMilliseconds() : 0
    readonly property real delayMs: Player.subtitleDelayMS

    readonly property var zoomLevels: [10000, 30000, 60000, 120000, 300000, 600000, 1800000]
    property int zoomIndex: 2 // one minute, as in the video

    readonly property real spanMs: lengthMs > 0 ? Math.min(zoomLevels[zoomIndex], lengthMs) : zoomLevels[zoomIndex]
    // the window is the "page" of the timeline holding the playhead
    readonly property real windowStart: {
        const start = Math.floor(timeMs / spanMs) * spanMs
        return lengthMs > 0 ? Math.max(0, Math.min(start, lengthMs - spanMs)) : start
    }
    readonly property real windowEnd: windowStart + spanMs

    readonly property real _step: 50 // subtitle delay step, ms

    function _x(ms) {
        return band.width * (ms - windowStart) / spanMs
    }

    // cues of the window, shifted by the subtitle delay: [[x, width], ...]
    readonly property var _blocks: {
        const result = []
        const list = cues ?? []
        for (let i = 0; i + 1 < list.length; i += 2) {
            const start = list[i] + delayMs
            const end = list[i + 1] + delayMs
            if (end <= windowStart || start >= windowEnd)
                continue
            const x0 = Math.max(0, _x(start))
            const x1 = Math.min(band.width, _x(end))
            if (x1 - x0 >= 0.5)
                result.push([x0, x1 - x0])
        }
        return result
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.trackColor
    }

    // the timeline between the two button groups
    Item {
        id: band

        anchors.left: leftButtons.right
        anchors.right: rightButtons.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: VLCStyle.dp(2, VLCStyle.scale)
        anchors.rightMargin: VLCStyle.dp(2, VLCStyle.scale)

        readonly property real playheadX: Math.max(0, Math.min(width, root._x(root.timeMs)))

        // played part
        Rectangle {
            width: band.playheadX
            height: parent.height
            color: root.playedColor
        }

        // subtitle lines, then the played part of them on top
        Repeater {
            model: root._blocks
            Rectangle {
                required property var modelData
                x: modelData[0]
                width: modelData[1]
                height: band.height
                color: root.cueColor
            }
        }

        Item {
            width: band.playheadX
            height: band.height
            clip: true

            Repeater {
                model: root._blocks
                Rectangle {
                    required property var modelData
                    x: modelData[0]
                    width: modelData[1]
                    height: band.height
                    color: root.playedCueColor
                }
            }
        }

        // playhead
        Rectangle {
            width: VLCStyle.dp(4, VLCStyle.scale)
            height: Math.max(0, band.height - 2 * VLCStyle.dp(2, VLCStyle.scale))
            y: VLCStyle.dp(2, VLCStyle.scale)
            x: Math.max(0, Math.min(band.width - width, band.playheadX - width / 2))
            radius: width
            color: root.accentColor
        }

        MouseArea {
            anchors.fill: parent
            preventStealing: true

            function seek(mouseX) {
                if (root.lengthMs <= 0)
                    return
                const ms = root.windowStart + root.spanMs * Math.max(0, Math.min(1, mouseX / width))
                Player.position = ms / root.lengthMs
            }

            onPressed: (mouse) => seek(mouse.x)
            onPositionChanged: (mouse) => { if (pressed) seek(mouse.x) }
        }
    }

    Row {
        id: leftButtons

        anchors.left: parent.left
        anchors.leftMargin: VLCStyle.dp(2, VLCStyle.scale)
        anchors.verticalCenter: parent.verticalCenter
        spacing: VLCStyle.dp(2, VLCStyle.scale)

        TimelineButton {
            glyph: VLCIcons.ic_fluent_chevron_left_24
            tip: qsTr("Show the subtitles earlier (%1 ms)").arg(root._step)
            autoRepeat: true
            onClicked: Player.subtitleDelayMS = Player.subtitleDelayMS - root._step
        }

        TimelineButton {
            glyph: VLCIcons.remove
            tip: qsTr("Zoom out")
            enabled: root.zoomIndex < root.zoomLevels.length - 1
            onClicked: root.zoomIndex = root.zoomIndex + 1
        }
    }

    Row {
        id: rightButtons

        anchors.right: parent.right
        anchors.rightMargin: VLCStyle.dp(2, VLCStyle.scale)
        anchors.verticalCenter: parent.verticalCenter
        spacing: VLCStyle.dp(2, VLCStyle.scale)

        TimelineButton {
            glyph: VLCIcons.add
            tip: qsTr("Zoom in")
            enabled: root.zoomIndex > 0
            onClicked: root.zoomIndex = root.zoomIndex - 1
        }

        TimelineButton {
            glyph: VLCIcons.ic_fluent_chevron_right_24
            tip: qsTr("Show the subtitles later (%1 ms)").arg(root._step)
            autoRepeat: true
            onClicked: Player.subtitleDelayMS = Player.subtitleDelayMS + root._step
        }
    }

    component TimelineButton: T.Button {
        id: button

        property string glyph
        property string tip

        implicitWidth: Math.round(root.height - 2 * VLCStyle.dp(2, VLCStyle.scale))
        implicitHeight: implicitWidth

        focusPolicy: Qt.NoFocus
        autoRepeatDelay: 400
        autoRepeatInterval: 120

        Accessible.name: tip

        Widgets.ToolTipExt {
            visible: button.hovered
            delay: VLCStyle.delayToolTipAppear
            text: button.tip
        }

        background: Rectangle {
            radius: VLCStyle.dp(4, VLCStyle.scale)
            color: root.accentColor
            opacity: button.enabled ? (button.pressed ? 0.8 : 1.0) : 0.4
        }

        contentItem: Text {
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: VLCIcons.fontFamily
            font.pixelSize: Math.round(button.height * 0.7)
            text: button.glyph
            color: "#1A1A1A"
        }
    }
}
