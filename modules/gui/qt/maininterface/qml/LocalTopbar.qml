/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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
import QtQml.Models
import QtQuick.Window


import VLC.MainInterface
import VLC.Player
import VLC.Style
import VLC.Playlist
import VLC.Widgets as Widgets
import VLC.Menus as Menus
import VLC.Util

T.ToolBar {
    id: root

    Accessible.name: qsTr("Local top bar")
    AccessibleCompat.id: "localTopbar"

    property bool useAcrylic: true

    // For now, used for d&d functionality
    // Not strictly necessary to set
    property Item plListView

    property bool _showCSD: MainCtx.clientSideDecoration
        && !(MainCtx.intfMainWindow.visibility === Window.FullScreen)
        && !MainCtx.hasToolbarMenu

    // VLC Redesign: the window buttons also show in fullscreen, with "exit
    // fullscreen" instead of maximize (WindowButtons.qml)
    readonly property bool _fullscreen: MainCtx.intfMainWindow.visibility === Window.FullScreen
    property bool _showWindowButtons: _showCSD || (_fullscreen && !MainCtx.hasToolbarMenu)

    //whether the navigation pannel is actually visible or not
    property alias navigationVisible: navigationVisibilty.checked
    property alias playqueueVisible: playlistBtn.checked

    property alias navigationButton: navigationVisibilty

    signal toggleNavigationVisibility()
    signal togglePlayqueueVisibility()

    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                             implicitContentWidth + leftPadding + rightPadding + (_showWindowButtons ? csdButtons.implicitWidth : 0))

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    background:  Widgets.AcrylicBackground {
        enabled: root.useAcrylic
        tintColor: theme.bg.primary
    }

    contentItem: Item {

        implicitHeight: VLCStyle.globalToolbar_height
        implicitWidth: navigationButtons.implicitWidth
                     + playqueueButtonsTop.implicitWidth
                     + VLCStyle.margin_xsmall * 2

        Item {
            id: navigationButtons

            implicitWidth: navigationButtonsRow.implicitWidth

            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
                leftMargin: VLCStyle.margin_xsmall
            }

            Navigation.parentItem: root

            Row {
                id: navigationButtonsRow

                anchors.verticalCenter: parent.verticalCenter
                spacing: VLCStyle.margin_xsmall

                Navigation.parentItem: root
                Navigation.rightItem: playqueueButtonsTop

                Widgets.BannerCone {
                    id: logo

                    anchors.verticalCenter: parent.verticalCenter

                    sourceSize.width: VLCStyle.icon_normal
                    sourceSize.height: VLCStyle.icon_normal
                    color: theme.accent
                }

                Widgets.IconToolButton {
                    id: menuBtn

                    visible: !MainCtx.hasToolbarMenu
                    font.pixelSize: VLCStyle.icon_banner
                    text: VLCIcons.more
                    description: qsTr("Menu")
                    width: VLCStyle.bannerButton_width
                    height: VLCStyle.bannerButton_height
                    checked: contextMenu.shown

                    Navigation.parentItem: navigationButtons
                    Navigation.rightItem: navigationVisibilty

                    onClicked: contextMenu.popup(this.mapToGlobal(0, height))

                    Menus.QmlGlobalMenu {
                        id: contextMenu
                        ctx: MainCtx
                        onPageRequested: (uri) => History.push(uri)
                    }
                }

                Widgets.IconToolButton {
                    id: navigationVisibilty

                    focus: true

                    text: VLCIcons.panel_left
                    description: qsTr("Show navigation menu")

                    AccessibleCompat.id: "sidebarToggleButton"

                    font.pixelSize: VLCStyle.icon_banner
                    height: VLCStyle.bannerButton_height
                    width: VLCStyle.bannerButton_width

                    onClicked: root.toggleNavigationVisibility()

                    Navigation.parentItem: navigationButtons
                    Navigation.leftItem: menuBtn.visible ? menuBtn : null
                }

                // VLC Redesign: back / forward are in the page header (PageExt.qml)
            }
        }

        // Title of the current media, centered in the bar as in the Figma
        // file; falls back to the application name when nothing is playing.
        T.Label {
            id: centerTitle

            readonly property real _leftLimit: navigationButtons.x + navigationButtons.width + VLCStyle.margin_normal
            readonly property real _rightLimit: playqueueButtonsTop.x - VLCStyle.margin_normal

            anchors.verticalCenter: parent.verticalCenter

            x: Math.max(_leftLimit, Math.min((parent.width - width) / 2, _rightLimit - width))
            width: Math.min(implicitWidth, Math.max(0, _rightLimit - _leftLimit))

            text: Player.name || qsTr("VLC media player")
            color: theme.fg.secondary
            font.pixelSize: VLCStyle.fontSize_large
            elide: Text.ElideRight

            Accessible.ignored: true
        }

        Item {
            id: playqueueButtonsTop

            implicitWidth: playqueueButtonsTopRow.implicitWidth

            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
                //put the buttons below the CSD if we have enough space
                rightMargin: VLCStyle.margin_xsmall
                    + ((root._showWindowButtons && root.topPadding < csdButtons.height)
                        ? Math.max(csdButtons.width - root.rightPadding, 0)
                        : 0)
            }

            Navigation.parentItem: root

            Row {
                id: playqueueButtonsTopRow

                anchors.verticalCenter: parent.verticalCenter
                spacing: VLCStyle.margin_normal

                Navigation.parentItem: root
                Navigation.leftItem: navigationButtons

                PlaylistPane.PlaylistToggleButton {
                    id: playlistBtn

                    // VLC Redesign: no queue button in the top bar; the queue is in the
                    // library video card and behind the player bar's queue button
                    visible: false

                    plListView: root.plListView

                    Navigation.parentItem: playqueueButtonsTop
                    Navigation.leftItem: navigationVisibilty

                    onClicked:  root.togglePlayqueueVisibility()
                }
            }
        }

        Loader {
            z: -1

            anchors.fill: parent
            active: root._showCSD
            sourceComponent: Widgets.CSDTitlebarTapNDrapHandler {
            }
        }
    }

    Loader {
        id: csdButtons

        //csd button are
        parent:  root
        anchors {
            right: parent.right
            top: parent.top
        }

        height: VLCStyle.globalToolbar_height
        active: root._showWindowButtons
        source: root._fullscreen
                  ? "qrc:///qt/qml/VLC/Player/WindowButtons.qml"
                  : VLCStyle.palette.hasCSDImage
                  ? "qrc:///qt/qml/VLC/Widgets/CSDThemeButtonSet.qml"
                  : "qrc:///qt/qml/VLC/Widgets/CSDWindowButtonSet.qml"
    }
}
