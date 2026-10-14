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

// Dashed (optionally rounded) border built from plain rectangles. VLC's
// Qt build has neither the Canvas item nor QtQuick.Shapes, so this is how
// dashed outlines are drawn. The corners are drawn solid.
Item {
    id: root

    property color color: "gray"
    property real dash: 4
    property real gap: 3
    property real lineWidth: 1
    property real radius: 0

    readonly property real _r: Math.max(0, Math.min(radius, width / 2, height / 2))
    readonly property real _step: Math.max(1, dash + gap)

    function _count(length) {
        return Math.max(0, Math.ceil(length / _step))
    }

    // edges (top, bottom, left, right); the last dash is cut by `clip`
    Repeater {
        model: [
            { x: root._r, y: 0, horizontal: true },
            { x: root._r, y: root.height - root.lineWidth, horizontal: true },
            { x: 0, y: root._r, horizontal: false },
            { x: root.width - root.lineWidth, y: root._r, horizontal: false }
        ]

        Item {
            required property var modelData

            x: modelData.x
            y: modelData.y
            width: modelData.horizontal ? root.width - 2 * root._r : root.lineWidth
            height: modelData.horizontal ? root.lineWidth : root.height - 2 * root._r
            clip: true

            Repeater {
                model: root._count(parent.modelData.horizontal ? parent.width : parent.height)

                Rectangle {
                    required property int index

                    x: parent.modelData.horizontal ? index * root._step : 0
                    y: parent.modelData.horizontal ? 0 : index * root._step
                    width: parent.modelData.horizontal ? root.dash : root.lineWidth
                    height: parent.modelData.horizontal ? root.lineWidth : root.dash
                    color: root.color
                }
            }
        }
    }

    // rounded corners: a quarter of a bordered circle each
    Repeater {
        model: root._r > 0 ? [ [0, 0], [1, 0], [0, 1], [1, 1] ] : []

        Item {
            required property var modelData

            x: modelData[0] ? root.width - root._r : 0
            y: modelData[1] ? root.height - root._r : 0
            width: root._r
            height: root._r
            clip: true

            Rectangle {
                x: parent.modelData[0] ? -root._r : 0
                y: parent.modelData[1] ? -root._r : 0
                width: 2 * root._r
                height: 2 * root._r
                radius: root._r
                color: "transparent"
                border.width: root.lineWidth
                border.color: root.color
            }
        }
    }
}
