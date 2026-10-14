/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * Authors: Benjamin Arnaud <bunjee@omega.gg>
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
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style

// Dialog frame of the "VLC Redesign" Figma file (Open Network Stream, New
// Playlist, Keyboard Shortcuts, Add Subtitles...): frameless rounded window
// with a dark header (title + close button) and Cancel / Save buttons.
// Content goes into the default property, between the header and the
// buttons. The inline components below are the shared building blocks.
Window {
    id: root

    default property alias content: contentArea.data
    // optional controls shown in the header, under the title (search...)
    property alias headerContent: headerExtra.data

    property string saveText: qsTr("Save")
    property bool saveEnabled: true
    property bool showButtons: true
    // optional third button next to Cancel (e.g. "Restore Default")
    property string extraText: ""
    signal extraClicked()
    property real contentMargins: VLCStyle.dp(20, VLCStyle.scale)

    signal accepted()
    signal rejected()

    transientParent: MainCtx.intfMainWindow
    flags: Qt.Dialog | Qt.FramelessWindowHint
    modality: Qt.ApplicationModal
    color: "transparent"

    // Figma tokens (dark); the light variant uses the light palette tokens
    readonly property bool dark: VLCStyle.palette?.isDark ?? true
    readonly property color panelColor: dark ? "#191919" : "#E7E7E7"
    readonly property color headerColor: dark ? "#090909" : "#D5D5D5"
    readonly property color wellColor: dark ? "#090909" : "#F4F4F4"
    readonly property color surfaceColor: dark ? "#1B1B1B" : "#DEDEDE"
    readonly property color raisedColor: dark ? "#161616" : "#D5D5D5"
    readonly property color dividerColor: dark ? "#222222" : "#ACACAC"
    readonly property color titleColor: dark ? "#C6C6C6" : "#161616"
    readonly property color textColor: dark ? "#8F8F8F" : "#2E2E2E"
    readonly property color dimColor: "#6B6B6B"
    readonly property color placeholderColor: dark ? "#404040" : "#9B9B9B"
    readonly property color accentColor: "#D37918"
    readonly property color accentSurface: dark ? "#371F06" : "#D8BA9A"
    readonly property int radius: VLCStyle.dp(5, VLCStyle.scale)

    function open() {
        const parentWindow = transientParent
        if (parentWindow) {
            x = parentWindow.x + (parentWindow.width - width) / 2
            y = parentWindow.y + (parentWindow.height - height) / 2
        }
        show()
        raise()
        requestActivate()
    }

    function accept() {
        accepted()
        close()
    }

    function reject() {
        rejected()
        close()
    }

    Rectangle {
        id: panel

        anchors.fill: parent
        radius: VLCStyle.dp(14, VLCStyle.scale)
        color: root.panelColor
        clip: true

        // colors for VLC components used inside the dialogs
        readonly property ColorContext colorContext: ColorContext {
            palette: VLCStyle.palette
            colorSet: ColorContext.Window
        }

        Keys.onEscapePressed: root.reject()

        // header: title and close button, drag to move the window
        Rectangle {
            id: header

            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: VLCStyle.dp(50, VLCStyle.scale)
                    + (headerExtra.children.length > 0 ? headerExtra.childrenRect.height + VLCStyle.dp(15, VLCStyle.scale) : 0)
            color: root.headerColor
            radius: panel.radius

            // square bottom corners
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: parent.radius
                color: parent.color
            }

            DragHandler {
                target: null
                onActiveChanged: if (active) root.startSystemMove()
            }

            Item {
                id: headerExtra

                anchors { left: parent.left; right: parent.right; top: parent.top; margins: VLCStyle.dp(9, VLCStyle.scale) }
                anchors.topMargin: VLCStyle.dp(53, VLCStyle.scale)
                height: childrenRect.height
            }

            Text {
                anchors { left: parent.left; leftMargin: VLCStyle.dp(19, VLCStyle.scale); top: parent.top }
                height: VLCStyle.dp(50, VLCStyle.scale)
                verticalAlignment: Text.AlignVCenter
                text: root.title
                color: root.textColor
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            }

            CloseButton {
                anchors { right: parent.right; rightMargin: VLCStyle.dp(10, VLCStyle.scale); top: parent.top; topMargin: VLCStyle.dp(10, VLCStyle.scale) }
                onClicked: root.reject()
            }
        }

        Item {
            id: contentArea

            anchors {
                left: parent.left; right: parent.right
                top: header.bottom; bottom: root.showButtons ? buttons.top : parent.bottom
                margins: root.contentMargins
            }
        }

        RowLayout {
            id: buttons

            visible: root.showButtons
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: root.contentMargins }

            Button {
                text: qsTr("Cancel")
                onClicked: root.reject()
            }

            Button {
                visible: root.extraText !== ""
                text: root.extraText
                onClicked: root.extraClicked()
            }

            Item { Layout.fillWidth: true }

            Button {
                text: root.saveText
                primary: true
                enabled: root.saveEnabled
                onClicked: root.accept()
            }
        }
    }

    // ---- building blocks ------------------------------------------------

    // 100x32 button; primary = accent "Save" button
    component Button: T.Button {
        id: button

        property bool primary: false

        implicitWidth: Math.max(VLCStyle.dp(100, VLCStyle.scale), contentItem.implicitWidth + VLCStyle.dp(32, VLCStyle.scale))
        implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

        background: Rectangle {
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: !button.enabled ? Qt.darker(root.surfaceColor, root.dark ? 1.0 : 1.05)
                 : button.primary ? root.accentSurface : root.surfaceColor
            opacity: button.hovered ? 0.85 : 1.0
            border.width: button.visualFocus ? VLCStyle.focus_border : 0
            border.color: root.accentColor
        }
        contentItem: Text {
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: button.text
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            font.weight: Font.DemiBold
            color: !button.enabled ? root.placeholderColor
                 : button.primary ? root.accentColor : root.textColor
        }
    }

    // small square button with a "+" (thumbnail / file pickers)
    component PlusButton: T.Button {
        id: plus

        implicitWidth: VLCStyle.dp(30, VLCStyle.scale)
        implicitHeight: VLCStyle.dp(30, VLCStyle.scale)
        background: Rectangle {
            radius: root.radius
            color: plus.hovered ? Qt.lighter(root.raisedColor, 1.4) : root.raisedColor
        }
        contentItem: Item {
            Rectangle { anchors.centerIn: parent; width: VLCStyle.dp(14, VLCStyle.scale); height: VLCStyle.dp(1.5, VLCStyle.scale); color: root.textColor }
            Rectangle { anchors.centerIn: parent; width: VLCStyle.dp(1.5, VLCStyle.scale); height: VLCStyle.dp(14, VLCStyle.scale); color: root.textColor }
        }
    }

    component CloseButton: T.Button {
        id: close

        implicitWidth: VLCStyle.dp(30, VLCStyle.scale)
        implicitHeight: VLCStyle.dp(30, VLCStyle.scale)
        background: Rectangle {
            radius: root.radius
            color: close.hovered ? root.surfaceColor : "transparent"
        }
        contentItem: Text {
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: VLCIcons.fontFamily
            font.pixelSize: VLCStyle.icon_small
            text: VLCIcons.close
            color: root.textColor
        }
    }

    // section title (16px) with an optional dimmed suffix, and a description
    component SectionHeader: Column {
        property string title
        property string suffix
        property string description

        spacing: VLCStyle.dp(14, VLCStyle.scale)

        Text {
            textFormat: Text.StyledText
            text: parent.title + (parent.suffix ? " <font color=\"" + root.dimColor + "\">" + parent.suffix + "</font>" : "")
            color: root.titleColor
            font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
        }
        Text {
            visible: text !== ""
            text: parent.description
            color: root.dimColor
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
        }
    }

    component Divider: Rectangle {
        implicitHeight: 1
        color: root.dividerColor
    }

    // single line input with a placeholder
    component TextField: T.TextField {
        id: field

        implicitHeight: VLCStyle.dp(35, VLCStyle.scale)
        leftPadding: VLCStyle.dp(13, VLCStyle.scale)
        rightPadding: VLCStyle.dp(13, VLCStyle.scale)
        verticalAlignment: TextInput.AlignVCenter
        color: root.titleColor
        selectionColor: root.accentSurface
        selectedTextColor: root.titleColor
        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)

        background: Rectangle {
            radius: root.radius
            color: root.wellColor
            border.width: 1
            border.color: field.activeFocus ? root.accentColor : root.panelColor
        }

        Text {
            anchors { fill: parent; leftMargin: field.leftPadding; rightMargin: field.rightPadding }
            verticalAlignment: Text.AlignVCenter
            visible: field.text === "" && !field.preeditText
            text: field.placeholderText
            color: root.placeholderColor
            font: field.font
            elide: Text.ElideRight
        }
    }
}
