/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * Authors: Oliver Bacon <oliverbacon@tutamail.com>
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
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style

// Equalizer bands of the settings window (Figma "EQ": an "Open Equalizer"
// bar that expands to Preamp + 10 bands, 784 x 489). The values are the
// ones of VLC's equalizer filter (equalizer-preamp, equalizer-bands): they
// follow the chosen preset and apply to the audio that is playing.
Item {
    id: root

    // colours of the settings window (SettingRow.qml)
    property color wellColor: "#090909"
    property color surfaceColor: "#191919"
    property color fillColor: "#371F06"
    property color handleColor: "#AB6314"
    property color textColor: "#8F8F8F"
    property color labelColor: "#6B6B6B"

    property bool expanded: String(VLCConfig.uiValue("Settings/EqualizerOpen", "false")) === "true"
    onExpandedChanged: VLCConfig.setUiValue("Settings/EqualizerOpen", expanded ? "true" : "false")

    readonly property real dp1: VLCStyle.dp(1, VLCStyle.scale)

    readonly property var labels: [qsTr("Preamp"), "60 Hz", "170 Hz", "310 Hz", "600 Hz", "1 KHz",
                                   "3 KHz", "6 KHz", "12 KHz", "14 KHz", "16 KHz"]

    // [preamp, band 1 … band 10] in dB
    property var values: _read()

    function _read() {
        return [Number(VLCEffects.audioValue("equalizer-preamp")) || 0].concat(VLCEffects.equalizerBands())
    }

    function setValue(index, value) {
        const v = Math.round(Math.max(-20, Math.min(20, value)) * 10) / 10
        if (index === 0)
            VLCEffects.setAudioValue("equalizer-preamp", v)
        else
            VLCEffects.setEqualizerBand(index - 1, v)
    }

    Connections {
        target: VLCEffects
        function onChanged() { root.values = root._read() }
    }

    implicitHeight: expanded ? 489 * dp1 : 36 * dp1

    // ---- collapsed: "Open Equalizer"
    T.AbstractButton {
        id: openBar

        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 36 * root.dp1
        visible: !root.expanded

        Accessible.name: qsTr("Open Equalizer")

        background: Rectangle {
            radius: 2 * root.dp1
            color: openBar.hovered ? Qt.lighter(root.wellColor, 1.6) : root.wellColor
        }
        contentItem: Item {
            Row {
                anchors.centerIn: parent
                spacing: 8 * root.dp1
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Open Equalizer")
                    color: root.textColor
                    font.pixelSize: 14 * root.dp1
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: VLCIcons.chevron_down
                    font.family: VLCIcons.fontFamily
                    font.pixelSize: 16 * root.dp1
                    color: root.textColor
                }
            }
        }
        onClicked: root.expanded = true
    }

    // ---- expanded: header + 11 sliders
    Rectangle {
        anchors.fill: parent
        visible: root.expanded
        radius: 2 * root.dp1
        color: root.surfaceColor

        T.AbstractButton {
            id: closeBar

            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 36 * root.dp1

            Accessible.name: qsTr("Close Equalizer")

            background: null
            contentItem: Item {
                Row {
                    anchors.centerIn: parent
                    spacing: 8 * root.dp1
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Close Equalizer")
                        color: closeBar.hovered ? Qt.lighter(root.textColor, 1.3) : root.textColor
                        font.pixelSize: 14 * root.dp1
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: VLCIcons.chevron_down
                        font.family: VLCIcons.fontFamily
                        font.pixelSize: 16 * root.dp1
                        color: root.textColor
                    }
                }
            }
            onClicked: root.expanded = false
        }

        // Figma: first track 44 px from the left, 68 px apart at 784 px
        readonly property real _margin: 44 * root.dp1
        readonly property real _pitch: (width - 2 * _margin - 16 * root.dp1) / 10

        Repeater {
            model: 11

            delegate: Item {
                id: column

                required property int index

                readonly property real value: root.values[index] ?? 0

                x: parent._margin + index * parent._pitch + 8 * root.dp1 - width / 2
                y: 0
                width: 60 * root.dp1
                height: parent.height

                // track: 16 x 320, fill inset 2 px
                Rectangle {
                    id: track

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 54 * root.dp1
                    width: 16 * root.dp1
                    height: 320 * root.dp1
                    radius: 6 * root.dp1
                    color: root.wellColor

                    readonly property real _inner: height - 4 * root.dp1
                    readonly property real _fill: (column.value + 20) / 40 * _inner

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height - 2 * root.dp1 - height
                        width: 12 * root.dp1
                        height: track._fill
                        radius: 4 * root.dp1
                        color: root.fillColor
                    }

                    // handle: 24 x 8, top edge on the top of the fill
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Math.min(parent.height - height, parent.height - 2 * root.dp1 - track._fill)
                        width: 24 * root.dp1
                        height: 8 * root.dp1
                        radius: 4 * root.dp1
                        color: drag.containsMouse || drag.pressed ? Qt.lighter(root.handleColor, 1.15) : root.handleColor

                        Rectangle {
                            anchors.centerIn: parent
                            width: 6 * root.dp1
                            height: 2 * root.dp1
                            radius: 1 * root.dp1
                            color: "#1A1611"
                        }
                    }

                    MouseArea {
                        id: drag

                        anchors.fill: parent
                        anchors.leftMargin: -8 * root.dp1
                        anchors.rightMargin: -8 * root.dp1
                        anchors.topMargin: -6 * root.dp1
                        anchors.bottomMargin: -6 * root.dp1
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true

                        function _set(mouseY) {
                            const y = mouseY - anchors.topMargin - 2 * root.dp1
                            const ratio = 1 - Math.max(0, Math.min(track._inner, y)) / track._inner
                            root.setValue(column.index, ratio * 40 - 20)
                        }
                        onPressed: (mouse) => _set(mouse.y)
                        onPositionChanged: (mouse) => { if (pressed) _set(mouse.y) }
                        onDoubleClicked: root.setValue(column.index, 0)
                        onWheel: (wheel) => root.setValue(column.index, column.value + (wheel.angleDelta.y > 0 ? 0.5 : -0.5))
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 407 * root.dp1
                    text: root.labels[column.index]
                    color: root.labelColor
                    font.pixelSize: 14 * root.dp1
                }

                // value box: 60 x 32, editable
                Rectangle {
                    y: 437 * root.dp1
                    width: parent.width
                    height: 32 * root.dp1
                    radius: 6 * root.dp1
                    color: root.wellColor

                    TextInput {
                        id: input

                        anchors.fill: parent
                        horizontalAlignment: TextInput.AlignHCenter
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.textColor
                        selectByMouse: true
                        font.pixelSize: 12 * root.dp1
                        readonly property string shown: column.value.toFixed(1) + " dB"
                        text: shown

                        // the number alone while editing, "x.x dB" otherwise
                        onActiveFocusChanged: {
                            if (activeFocus) {
                                text = column.value.toFixed(1)
                                selectAll()
                            } else {
                                text = Qt.binding(() => input.shown)
                            }
                        }
                        onEditingFinished: {
                            const v = parseFloat(text.replace(",", "."))
                            if (!isNaN(v))
                                root.setValue(column.index, v)
                            focus = false
                        }
                    }
                }
            }
        }
    }
}
