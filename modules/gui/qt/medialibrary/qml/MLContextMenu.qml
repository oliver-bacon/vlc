
/*****************************************************************************
 * Copyright (C) 2022 VLC authors and VideoLAN
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
import QtQml

import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Dialogs

import VLC.Util

// @brief - a generic ML context menu
NativeMenu {
    id: root

    // Properties

    required property MLBaseModel model

    property string idDataRole: "id"
    property string albumIdDataRole: "album_id"

    property bool showPlayAsAudioAction: false

    // This is only applicable when the model is `MLAudioModel`:
    property bool showPlayAsAlbumAction: implicitShowPlayAsAlbumAction
    property bool implicitShowPlayAsAlbumAction: !showPlayAsAudioAction

    // Signals

    signal showMediaInformation(int index)


    // required by TableViewExt
    property var tableView_popup: function (index/* reserved for future */, selectedIndexes, globalPos) {
        return popup(selectedIndexes, globalPos)
    }

    // Settings

    // Laid out like the "file context menu" / "folder context menu" of the
    // VLC Redesign Figma file. Design items that VLC cannot do yet are left
    // out; VLC actions the design does not show are in "More".
    readonly property bool _folderMenu: (root.model instanceof MLVideoFoldersModel)

    readonly property var _moreActions: [{
            "text": qsTr("Play"),
            "action": addAndPlay,
            "visible": root._folderMenu
        }, {
            "text": qsTr("Enqueue"),
            "action": enqueue,
            "visible": root._folderMenu
        }, {
            "text": qsTr("Play as audio"),
            "action": playAsAudio,
            "visible": root.showPlayAsAudioAction
        }, {
            "text": qsTr("Play as album"),
            "action": playAsAlbum,
            "visible": root.showPlayAsAlbumAction &&
                       (root.model instanceof MLAudioModel)
        }, {
            "text": qsTr("Enqueue as album"),
            "action": enqueueAsAlbum,
            "visible": root.showPlayAsAlbumAction &&
                       (root.model instanceof MLAudioModel)
        }, {
            "text": (root.showPlayAsAudioAction ? qsTr("Add to a video-only playlist") : qsTr("Add to an audio-only playlist")),
            "action": (root.showPlayAsAudioAction ? root.addToVideoOnlyPlaylist : root.addToAudioOnlyPlaylist)
        }, {
            "text": qsTr("Add to a playlist"),
            "action": addToAPlaylist,
            "visible": root._folderMenu
        }, {
            "text": qsTr("Delete"),
            "action": deleteStream,
            "visible": _deleteStream
        }, {
            "text": qsTr("Delete File From System"),
            "action": deleteFileFromSource,
            "visible": _deleteFileFromSource
        }, {
            "text": qsTr("Information"),
            "action": _signalShowInformation,
            "visible": function(dataList, options, indexes) {
                return !root._folderMenu && showInformationAvailable(dataList, options, indexes)
            }
        }
    ]

    actions: [{
            "text": qsTr("Play"),
            "icon": "file_play",
            "action": addAndPlay,
            "visible": !root._folderMenu
        }, {
            "text": qsTr("Mark as Watched"),
            "icon": "file_mark_as_watched",
            "action": _toggleWatched,
            "checked": _showUnseen,
            "visible": function(dataList, options, indexes) {
                return !root._folderMenu && (_showSeen(dataList) || _showUnseen(dataList))
            }
        }, {
            "text": qsTr("Favorite"),
            "icon": "file_favorite",
            "action": _toggleFavorite,
            "checked": _showRemoveFavorite,
            "visible": function(dataList, options, indexes) {
                return !root._folderMenu && (_showAddFavorite(dataList) || _showRemoveFavorite(dataList))
            }
        }, {
            "text": qsTr("Stream"),
            "icon": "file_stream",
            "action": function(dataList, options, indexes) {
                DialogsProvider.streamingDialog(_mrlList(dataList), true)
            },
            "visible": _hasMrl
        }, {
            "text": qsTr("Convert"),
            "icon": "file_convert",
            "action": function(dataList, options, indexes) {
                DialogsProvider.streamingDialog(_mrlList(dataList), false)
            },
            "visible": _hasMrl
        }, {
            "text": qsTr("Add to Queue"),
            "icon": "file_add_to_queue",
            "action": enqueue,
            "visible": !root._folderMenu
        }, {
            "text": qsTr("Add to Playlist"),
            "icon": "file_add_to_playlist",
            "action": addToAPlaylist,
            "visible": !root._folderMenu
        }, {
            "text": (Qt.platform.os === "windows") ? qsTr("Show in File Explorer") : qsTr("Show in Folder"),
            "icon": "file_show_in_file_explorer",
            "action": openContainingFolder,
            "visible": _openContainingFolder
        }, {
            "text": qsTr("Properties & Metadata"),
            "icon": "file_properties_metadata",
            "action": function(dataList, options, indexes) {
                DialogsProvider.mediaInfoDialog(dataList[0][idDataRole])
            },
            "visible": function(dataList, options, indexes) {
                return !root._folderMenu
                        && (dataList.length === 1)
                        && !(dataList[0][idDataRole].hasParent())
            }
        }, {
            "text": qsTr("Info"),
            "icon": "folder_info",
            "action": _signalShowInformation,
            "visible": function(dataList, options, indexes) {
                return root._folderMenu && showInformationAvailable(dataList, options, indexes)
            }
        }, {
            "text": qsTr("More"),
            "children": _moreActions
        }
    ]

    // Events

    onRequestData: (requestID, indexes) => {
        model.getData(indexes, function (data) {
            setData(requestID, data)
        })
    }

    // Functions

    function addAndPlay(dataList, options, indexes) {
        model.ml.addAndPlay(_mlIDList(dataList), _playerOptions(options))
    }

    function playAsAudio(dataList, options, indexes) {
        model.ml.addAndPlay(_mlIDList(dataList), _playerOptions(options, ":no-video"))
    }

    function playAsAlbum(dataList, options, indexes) {
        model.ml.addAndPlay(_mlIDList(dataList, root.albumIdDataRole), _playerOptions(options))
    }

    function enqueue(dataList, options, indexes) {
        model.ml.addToPlaylist(_mlIDList(dataList), _playerOptions(options))
    }

    function enqueueAsAlbum(dataList, options, indexes) {
        model.ml.addToPlaylist(_mlIDList(dataList, root.albumIdDataRole), _playerOptions(options))
    }

    function addToAudioOnlyPlaylist(dataList, options, indexes) {
        addToAPlaylist(dataList, options, indexes, MLPlaylistListModel.PLAYLIST_TYPE_AUDIO_ONLY)
    }

    function addToVideoOnlyPlaylist(dataList, options, indexes) {
        addToAPlaylist(dataList, options, indexes, MLPlaylistListModel.PLAYLIST_TYPE_VIDEO_ONLY)
    }

    function addToAPlaylist(dataList, options, indexes, type) {
        if (type === undefined)
            type = MLPlaylistListModel.PLAYLIST_TYPE_ALL

        DialogsProvider.playlistsDialog(_mlIDList(dataList), type)
    }

    function addFavorite(dataList, options, indexes) {
        model.setMediaIsFavorite(indexes[0], true)
    }

    function removeFavorite(dataList, options, indexes) {
        model.setMediaIsFavorite(indexes[0], false)
    }

    function markSeen(dataList, options, indexes) {
        model.setItemPlayed(indexes[0], true)
    }

    function markUnseen(dataList, options, indexes) {
        model.setItemPlayed(indexes[0], false)
    }

    function openContainingFolder(dataList, options, indexes) {
        const parentDir = model.getParentURL(indexes[0]);

        Qt.openUrlExternally(parentDir)
    }

    function deleteStream(dataList, options, indexes) {
        model.deleteStream(dataList[0][idDataRole])
    }

    function deleteFileFromSource(dataList, options, indexes) {
        let confirm = DialogsProvider.questionDialog(qsTr("Are you sure you want to delete this file?"));
        
        if (confirm) {
            model.deleteFileFromSource(indexes[0]);
            console.log("File Deleted !!");
        }
    }

    function showInformationAvailable(dataList, options, indexes) {
        return indexes.length === 1
                && Helpers.isInteger(options?.["information"] ?? null)
    }

    // Private

    function _checkRole(dataList, role, expected) {
        if (dataList.length !== 1)
            return false

        if (!(role in dataList[0]))
            return false

        return (dataList[0][role] === expected)
    }

    function _showAddFavorite(dataList, options, indexes) {
        return _checkRole(dataList, "isFavorite", false)
    }

    function _showRemoveFavorite(dataList, options, indexes) {
        return _checkRole(dataList, "isFavorite", true)
    }

    function _showSeen(dataList, options, indexes) {
        return _checkRole(dataList, "isNew", true)
    }

    function _showUnseen(dataList, options, indexes) {
        return _checkRole(dataList, "isNew", false)
    }

    function _openContainingFolder(dataList, options, indexes) {
        return _checkRole(dataList, "isLocal", true)
    }

    function _deleteStream(dataList,options, indexes) {
        return _checkRole(dataList, "isDeletable", true)
    }

    function _deleteFileFromSource(dataList, options, indexes) {
        return  _checkRole(dataList, "isDeletableFile", true)
    }

    function _toggleWatched(dataList, options, indexes) {
        if (_showSeen(dataList))
            markSeen(dataList, options, indexes)
        else
            markUnseen(dataList, options, indexes)
    }

    function _toggleFavorite(dataList, options, indexes) {
        if (_showAddFavorite(dataList))
            addFavorite(dataList, options, indexes)
        else
            removeFavorite(dataList, options, indexes)
    }

    function _hasMrl(dataList, options, indexes) {
        return !root._folderMenu
                && dataList.length > 0
                && dataList.every((data) => !!data["mrl"])
    }

    function _mrlList(dataList) {
        return dataList.map((data) => data["mrl"])
    }

    function _signalShowInformation(dataList, options) {
        const index = options?.["information"] ?? null
        console.assert(Helpers.isInteger(index))
        showMediaInformation(index)
    }

    function _playerOptions(options, extraOptions) {
        const playerOpts = options?.["player-options"] ?? []
        return playerOpts.concat(extraOptions)
    }

    function _mlIDList(dataList, role = root.idDataRole) {
        const idList = []
        for (let i in dataList) {
            console.assert(dataList[i][role] !== undefined)
            idList.push(dataList[i][role])
        }

        return idList
    }
}
