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
import QtQuick.Window

import VLC.MainInterface
import VLC.PlayerControls
import VLC.Style
import VLC.Widgets as Widgets

// Top right corner of the VLC Redesign player when VLC draws its own title
// bar: minimize, picture-in-picture, maximize, fullscreen, close (video
// notes; the Figma "Player" frame has the same buttons without PiP).
// Replaces CSDWindowButtonSet.qml in TopBar.qml.
Row {
    id: root

    spacing: 0
    padding: 0
    width: implicitWidth

    property color color: theme.fg.primary
    property color hoverColor: theme.bg.primary.alpha(0.5)

    readonly property bool useWinIcons: ((MainCtx.osName === MainCtx.Windows) && (MainCtx.osVersion >= 10))

    readonly property bool buttonHovered: minimize.hovered || minimize.showHovered
                                          || maximize.hovered || maximize.showHovered
                                          || close.hovered || close.showHovered
                                          || pip.hovered || fullscreen.hovered

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    function _button(type) {
        const list = MainCtx.csdButtonModel.windowCSDButtons
        for (let i = 0; i < list.length; ++i)
            if (list[i].type === type)
                return list[i]
        return null
    }

    component WindowButton: Widgets.CSDWindowButton {
        id: button

        property var modelData: null

        visible: !!modelData
        height: root.height

        showHovered: modelData?.showHovered ?? false
        externalPressed: modelData?.externalPressed ?? false
        isThemeDark: theme.palette.isDark

        color: (modelData?.type === CSDButton.Close && (hovered || showHovered)) ? "white" : root.color
        hoverColor: (modelData?.type === CSDButton.Close) ? "red" : root.hoverColor

        onClicked: modelData?.click()

        // the window system needs the place of the buttons (Windows snap
        // layouts on maximize)
        function updateRect() {
            if (!modelData)
                return
            const point = mapToItem(null, 0, 0)
            modelData.rect = Qt.rect(point.x, point.y, width, height)
        }

        onXChanged: Qt.callLater(updateRect)
        onWidthChanged: Qt.callLater(updateRect)
        onHeightChanged: Qt.callLater(updateRect)
        onModelDataChanged: Qt.callLater(updateRect)

        Connections {
            target: VLCStyle
            function onAppWidthChanged() { Qt.callLater(button.updateRect) }
            function onAppHeightChanged() { Qt.callLater(button.updateRect) }
        }
    }

    WindowButton {
        id: minimize
        modelData: root._button(CSDButton.Minimize)
        iconTxt: root.useWinIcons ? "" : VLCIcons.window_minimize
    }

    PipButton {
        id: pip
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: VLCStyle.icon_banner
    }

    WindowButton {
        id: maximize
        modelData: root._button(CSDButton.MaximizeRestore)
        iconTxt: {
            const maximized = MainCtx.intfMainWindow.visibility === Window.Maximized
            if (root.useWinIcons)
                return maximized ? "" : ""
            return maximized ? VLCIcons.window_restore : VLCIcons.window_maximize
        }
    }

    FullscreenButton {
        id: fullscreen
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: VLCStyle.icon_banner
    }

    WindowButton {
        id: close
        modelData: root._button(CSDButton.Close)
        iconTxt: root.useWinIcons ? "" : VLCIcons.window_close
    }
}
