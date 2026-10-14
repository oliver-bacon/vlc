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

import VLC.MainInterface
import VLC.Player
import VLC.Style

// "File Name", "Artist Name", "Folder Name", "Playlist Name": a text of the
// current media; the playlist name is the library playlist the media was
// started from
Item {
    id: root

    property bool paintOnly: false
    // "file", "artist", "folder" or "playlist"
    property string kind: "file"

    readonly property string _text: {
        if (paintOnly)
            return kind === "artist" ? qsTr("Artist Name") : kind === "folder" ? qsTr("Folder Name")
                 : kind === "playlist" ? qsTr("Playlist Name") : qsTr("File Name")
        if (kind === "playlist")
            return MainCtx.mediaLibrary?.currentPlaylistName ?? ""
        if (kind === "artist")
            return Player.artist
        const url = decodeURIComponent(String(Player.url))
        const parts = url.split("/").filter((p) => p !== "")
        if (kind === "folder")
            return parts.length > 1 ? parts[parts.length - 2] : ""
        return parts.length > 0 ? parts[parts.length - 1] : Player.name
    }

    implicitWidth: Math.min(label.implicitWidth, VLCStyle.dp(220, VLCStyle.scale)) + VLCStyle.margin_xsmall * 2
    implicitHeight: VLCStyle.icon_toolbar

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    Text {
        id: label

        anchors.fill: parent
        anchors.leftMargin: VLCStyle.margin_xsmall
        anchors.rightMargin: VLCStyle.margin_xsmall
        verticalAlignment: Text.AlignVCenter
        text: root._text
        elide: Text.ElideMiddle
        color: theme.fg.secondary
        font.pixelSize: VLCStyle.fontSize_normal
    }
}
