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

import VLC.MediaLibrary

// Media library models of the compact library in the player
// (PlayerLibraryPanel.qml). Kept in their own file: the model types only
// exist when VLC runs with a media library, and this file is loaded only
// then.
Item {
    readonly property MLVideoFoldersModel videoFolders: MLVideoFoldersModel { ml: MediaLib }
    readonly property MLAudioModel tracks: MLAudioModel { ml: MediaLib }
    // tracks of an album, artist or genre (parentId set by the panel)
    readonly property MLAudioModel tracksOf: MLAudioModel { ml: MediaLib }
    readonly property MLAlbumModel albums: MLAlbumModel { ml: MediaLib }
    readonly property MLArtistModel artists: MLArtistModel { ml: MediaLib }
    readonly property MLGenreModel genres: MLGenreModel { ml: MediaLib }
    readonly property MLUrlModel streams: MLUrlModel { ml: MediaLib }
    readonly property MLPlaylistListModel playlists: MLPlaylistListModel { ml: MediaLib }
    // media of a playlist (parentId set by the panel)
    readonly property MLPlaylistModel playlistMedia: MLPlaylistModel { ml: MediaLib }
    // Home and Recent
    readonly property MLRecentVideoModel recentVideos: MLRecentVideoModel { ml: MediaLib }
    readonly property MLRecentAudioModel recentAudio: MLRecentAudioModel { ml: MediaLib }
    readonly property MLRecentMediaModel recentMedia: MLRecentMediaModel { ml: MediaLib }
    // the first items of each Home section
    readonly property MLRecentVideoModel recentVideosPreview: MLRecentVideoModel { ml: MediaLib; limit: 3 }
    readonly property MLRecentAudioModel recentAudioPreview: MLRecentAudioModel { ml: MediaLib; limit: 3 }
}
