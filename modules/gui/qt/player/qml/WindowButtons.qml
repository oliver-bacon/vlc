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
// bar: minimize, maximize, close (fullscreen is on the control bar). In
// fullscreen the maximize button becomes "exit fullscreen".
// Replaces CSDWindowButtonSet.qml in TopBar.qml.
Row {
    id: root

    spacing: 0
    padding: 0
    width: implicitWidth

    property color color: theme.fg.primary
    // visible on the dark and the light theme (bg.primary was invisible on
    // the dark one)
    property color hoverColor: theme.fg.primary.alpha(0.12)

    readonly property bool useWinIcons: ((MainCtx.osName === MainCtx.Windows) && (MainCtx.osVersion >= 10))

    readonly property bool fullscreen: MainCtx.intfMainWindow.visibility === Window.FullScreen

    readonly property bool buttonHovered: minimize.hovered || minimize.showHovered
                                          || maximize.hovered || maximize.showHovered
                                          || exitFullscreen.hovered
                                          || close.hovered || close.showHovered

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
            if (!visible || !root.visible || !root.parent || !root.parent.visible) {
                modelData.rect = Qt.rect(0, 0, 0, 0)
                return
            }
            const point = mapToItem(null, 0, 0)
            modelData.rect = Qt.rect(point.x, point.y, width, height)
        }

        onXChanged: Qt.callLater(updateRect)
        onWidthChanged: Qt.callLater(updateRect)
        onHeightChanged: Qt.callLater(updateRect)
        onModelDataChanged: Qt.callLater(updateRect)
        onVisibleChanged: Qt.callLater(updateRect)

        Connections {
            target: VLCStyle
            function onAppWidthChanged() { Qt.callLater(button.updateRect) }
            function onAppHeightChanged() { Qt.callLater(button.updateRect) }
        }

        // the row moves with the top bar (its buttons do not move inside it)
        Connections {
            target: root
            function onRowMoved() { Qt.callLater(button.updateRect) }
        }

        // Windows answers clicks in these rectangles itself (close, maximize):
        // a rectangle left behind would close or maximize the window when
        // something else is clicked there (fullscreen, CSD off, ...)
        Component.onDestruction: {
            if (modelData)
                modelData.rect = Qt.rect(0, 0, 0, 0)
        }
    }

    signal rowMoved()

    onXChanged: rowMoved()
    onYChanged: rowMoved()
    onWidthChanged: rowMoved()
    onVisibleChanged: rowMoved()

    Connections {
        target: root.parent
        ignoreUnknownSignals: true
        function onXChanged() { root.rowMoved() }
        function onYChanged() { root.rowMoved() }
        function onWidthChanged() { root.rowMoved() }
        function onVisibleChanged() { root.rowMoved() }
    }

    // once the top bar has its final layout
    Timer {
        running: true
        interval: 500
        onTriggered: root.rowMoved()
    }

    WindowButton {
        id: minimize
        modelData: root._button(CSDButton.Minimize)
        iconTxt: root.useWinIcons ? "" : VLCIcons.window_minimize
    }

    // not a window system button: Windows would maximize or restore the
    // window itself on a click in a maximize button's rectangle
    Widgets.CSDWindowButton {
        id: exitFullscreen

        visible: root.fullscreen
        height: root.height

        color: root.color
        hoverColor: root.hoverColor
        isThemeDark: theme.palette.isDark
        iconTxt: root.useWinIcons ? "\uE73F" : VLCIcons.defullscreen // Segoe: BackToWindow

        onClicked: MainCtx.toggleInterfaceFullScreen()
    }

    WindowButton {
        id: maximize
        modelData: root._button(CSDButton.MaximizeRestore)
        visible: !!modelData && !root.fullscreen
        iconTxt: {
            const maximized = MainCtx.intfMainWindow.visibility === Window.Maximized
            if (root.useWinIcons)
                return maximized ? "" : ""
            return maximized ? VLCIcons.window_restore : VLCIcons.window_maximize
        }
    }

    WindowButton {
        id: close
        modelData: root._button(CSDButton.Close)
        iconTxt: root.useWinIcons ? "" : VLCIcons.window_close
    }
}
