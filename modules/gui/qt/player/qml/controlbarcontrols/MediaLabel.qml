/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * Authors: Oliver Bacon <oliverbacon@tutamail.com>
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

import VLC.MainInterface
import VLC.Player
import VLC.Style

// "File Name", "Artist Name", "Folder Name", "Playlist Name", "Title": a
// text of the current media; the playlist name is the library playlist the
// media was started from. The folder name is a button that shows the folder
// in the player's library panel (VLC Redesign top bar).
Item {
    id: root

    property bool paintOnly: false
    // "file", "artist", "folder", "playlist" or "title"
    property string kind: "file"

    signal requestLockUnlockAutoHide(bool lock)

    readonly property bool _isFolder: kind === "folder"
    readonly property bool _isTitle: kind === "title"
    readonly property bool _inPlayer: (typeof rootPlayer !== 'undefined') && rootPlayer !== null

    readonly property string _text: {
        if (paintOnly)
            return kind === "artist" ? qsTr("Artist Name") : kind === "folder" ? qsTr("Folder Name")
                 : kind === "playlist" ? qsTr("Playlist Name") : kind === "title" ? qsTr("Title")
                 : qsTr("File Name")
        if (kind === "playlist")
            return MainCtx.mediaLibrary?.currentPlaylistName ?? ""
        if (kind === "artist")
            return Player.artist
        if (kind === "title")
            return Player.title || Player.name
        const url = decodeURIComponent(String(Player.url))
        if (kind === "folder" && !url.startsWith("file://"))
            return ""
        const parts = url.split("/").filter((p) => p !== "")
        if (kind === "folder")
            return parts.length > 2 ? parts[parts.length - 2] : ""
        return parts.length > 0 ? parts[parts.length - 1] : Player.name
    }

    readonly property real _maxWidth: VLCStyle.dp(_isTitle ? 480 : 220, VLCStyle.scale)
    readonly property real _iconWidth: _isFolder ? icon.implicitWidth + VLCStyle.margin_xsmall : 0

    visible: paintOnly || _text !== ""

    implicitWidth: Math.min(label.implicitWidth, _maxWidth) + _iconWidth + VLCStyle.margin_xsmall * 2
    implicitHeight: _isFolder ? VLCStyle.bannerButton_height : VLCStyle.icon_toolbar

    Accessible.role: _isFolder ? Accessible.Button : Accessible.StaticText
    Accessible.name: _isFolder ? qsTr("Open the folder in the library") : _text

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    Rectangle {
        anchors.fill: parent
        visible: root._isFolder
        radius: VLCStyle.dp(4, VLCStyle.scale)
        color: (folderHover.hovered && !root.paintOnly) ? theme.bg.secondary : "transparent"
    }

    Text {
        id: icon

        anchors.left: parent.left
        anchors.leftMargin: VLCStyle.margin_xsmall
        anchors.verticalCenter: parent.verticalCenter
        visible: root._isFolder
        font.family: VLCIcons.fontFamily
        font.pixelSize: VLCStyle.icon_normal
        text: VLCIcons.topbar_network
        color: theme.fg.secondary
    }

    Text {
        id: label

        anchors.fill: parent
        anchors.leftMargin: VLCStyle.margin_xsmall + root._iconWidth
        anchors.rightMargin: VLCStyle.margin_xsmall
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: root._isTitle ? Text.AlignHCenter : Text.AlignLeft
        text: root._text
        elide: root._isTitle ? Text.ElideRight : Text.ElideMiddle
        color: theme.fg.secondary
        font.pixelSize: root._isTitle ? VLCStyle.fontSize_large : VLCStyle.fontSize_normal
    }

    HoverHandler {
        id: folderHover
        enabled: root._isFolder && !root.paintOnly
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: root.requestLockUnlockAutoHide(hovered)
    }

    TapHandler {
        enabled: root._isFolder && !root.paintOnly && root._inPlayer
        onTapped: rootPlayer.showMediaFolderInLibrary()
    }
}
