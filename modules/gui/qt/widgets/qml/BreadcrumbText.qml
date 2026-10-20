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

// A path like "Music  ›  Songs" where every part but the last can be clicked
// to go back to it. When the path is too wide, the longest parts are shortened
// ("…") first, so every part stays visible; only if that is not enough, the
// start is cut off (like Text.ElideLeft).
Item {
    id: root

    // names, from the top to the current place
    property var crumbs: []
    // whether the part at an index can be opened (the last part never can)
    property var isClickable: (index) => true

    property color color
    property color hoverColor: color
    property font font

    signal crumbClicked(int index)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    clip: true

    FontMetrics {
        id: metrics
        font: root.font
    }

    readonly property real _separatorWidth: metrics.advanceWidth(_separator)
    readonly property string _separator: "  ›  "

    // widest a part may be: the same limit for all parts, as high as fits
    readonly property real _maxPartWidth: {
        const natural = crumbs.map((c) => Math.ceil(metrics.advanceWidth(String(c)))).sort((a, b) => a - b)
        const available = width - _separatorWidth * Math.max(0, natural.length - 1)
        let used = 0
        for (let i = 0; i < natural.length; i++) {
            const left = natural.length - i
            if (used + natural[i] * left > available)
                return Math.max(metrics.averageCharacterWidth * 4, (available - used) / left)
            used += natural[i]
        }
        return Infinity
    }

    Row {
        id: row

        x: Math.min(0, root.width - width)
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: root.crumbs

            Row {
                id: part

                required property int index
                required property var modelData

                readonly property bool _clickable: index < root.crumbs.length - 1 && root.isClickable(index)

                Text {
                    visible: part.index > 0
                    text: root._separator
                    color: root.color
                    font: root.font
                    textFormat: Text.PlainText
                }

                Text {
                    text: part.modelData
                    width: Math.min(implicitWidth, root._maxPartWidth)
                    elide: Text.ElideRight
                    color: mouse.containsMouse ? root.hoverColor : root.color
                    font.family: root.font.family
                    font.pixelSize: root.font.pixelSize
                    font.weight: root.font.weight
                    font.underline: mouse.containsMouse
                    textFormat: Text.PlainText

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        enabled: part._clickable
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.crumbClicked(part.index)
                    }
                }
            }
        }
    }
}
