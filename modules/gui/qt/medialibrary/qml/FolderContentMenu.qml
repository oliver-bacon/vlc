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

import VLC.MainInterface
import VLC.Dialogs
import VLC.Util

// Right-click menu of folders and video files in the VLC Redesign folder
// views (Videos page, library side panel), with the Figma "folder context
// menu" / "file context menu" items. The view gives each entry as
// { name, mrl, isFolder, isLibraryRoot } through dataAt(index); an index
// of -1 is the folder that is shown (right-click on an empty area).
NativeMenu {
    id: root

    // function (index) -> entry object
    property var dataAt: function (index) { return null }
    // function (index), for files
    property var playAt: null
    property var enqueueAt: null
    // MLFolderModel of the library folders, for "Remove from Library"
    property var libraryFolders: null
    // function (index), called after the file of the entry was deleted
    // (the view reloads its list)
    property var deletedAt: null

    onRequestData: (requestID, indexes) => {
        const dataList = indexes.map((i) => root.dataAt(i)).filter((d) => !!d)
        if (dataList.length > 0)
            root.setData(requestID, dataList)
    }

    function _one(dataList) { return dataList.length === 1 ? dataList[0] : null }
    function _isFile(dataList) { const d = _one(dataList); return !!d && !d.isFolder }
    function _isFolder(dataList) { const d = _one(dataList); return !!d && d.isFolder }
    function _isLocal(dataList) { const d = _one(dataList); return !!d && String(d.mrl).startsWith("file://") }
    function _parentUrl(mrl) { const s = String(mrl); return s.substring(0, s.lastIndexOf("/")) }

    function _deleteFile(dataList, indexes) {
        const mrl = String(dataList[0].mrl)
        if (!DialogsProvider.questionDialog(qsTr("Are you sure you want to delete this file?")))
            return
        if (!VLCConfig.deleteFile(mrl))
            return
        // the media library drops the file when it scans the folder again
        if (MainCtx.mediaLibraryAvailable)
            MainCtx.mediaLibrary.reloadFolder(root._parentUrl(mrl))
        if (root.deletedAt)
            root.deletedAt(indexes[0])
    }

    function _pin(d) {
        const key = "Library/Pins"
        let list = []
        try { list = JSON.parse(VLCConfig.uiValue(key, "[]")) } catch (e) { list = [] }
        if (!Array.isArray(list))
            list = []
        const url = String(d.mrl)
        list = list.filter((p) => !(p.type === "folder" && p.url === url))
        list.push({ "type": "folder", "name": d.name, "url": url })
        VLCConfig.setUiValue(key, JSON.stringify(list))
    }

    actions: [{
            // ---- file
            "text": qsTr("Play"),
            "icon": "file_play",
            "action": (dataList, options, indexes) => root.playAt(indexes[0]),
            "visible": (dataList, options, indexes) => _isFile(dataList) && !!root.playAt && indexes[0] >= 0
        }, {
            "text": qsTr("Add to Queue"),
            "icon": "file_add_to_queue",
            "action": (dataList, options, indexes) => root.enqueueAt(indexes[0]),
            "visible": (dataList, options, indexes) => _isFile(dataList) && !!root.enqueueAt && indexes[0] >= 0
        }, {
            "text": qsTr("Stream"),
            "icon": "file_stream",
            "action": (dataList) => DialogsProvider.streamingDialog([dataList[0].mrl], true),
            "visible": (dataList) => _isFile(dataList)
        }, {
            "text": qsTr("Convert"),
            "icon": "file_convert",
            "action": (dataList) => DialogsProvider.streamingDialog([dataList[0].mrl], false),
            "visible": (dataList) => _isFile(dataList)
        }, {
            "text": qsTr("Add Subtitle Tracks"),
            "icon": "file_add_subtitle_tracks",
            "action": (dataList) => DialogsProvider.addSubtitlesDialog({ "mode": "file", "mrl": dataList[0].mrl }),
            "visible": (dataList) => _isFile(dataList) && _isLocal(dataList)
        }, {
            "text": qsTr("Add Audio Tracks"),
            "icon": "file_add_audio_tracks",
            "action": (dataList) => DialogsProvider.addSubtitlesDialog({ "mode": "file", "kind": "audio", "mrl": dataList[0].mrl }),
            "visible": (dataList) => _isFile(dataList) && _isLocal(dataList)
        }, {
            // ---- folder
            "text": qsTr("Add File"),
            "icon": "folder_add_file",
            "action": () => DialogsProvider.PLAppendDialog(),
            "visible": (dataList) => _isFolder(dataList)
        }, {
            "text": qsTr("Add Folder"),
            "icon": "folder_add_folder",
            "action": () => {
                const folder = VLCConfig.browseFolder(qsTr("Add a Folder to the Library"))
                if (folder !== "")
                    MainCtx.mediaLibrary.addFolder(folder)
            },
            "visible": (dataList) => _isFolder(dataList) && MainCtx.mediaLibraryAvailable
        }, {
            "text": qsTr("Edit Subtitle Tracks"),
            "icon": "folder_edit_subtitle_tracks",
            "action": (dataList) => DialogsProvider.addSubtitlesDialog({ "mode": "folder", "mrl": dataList[0].mrl }),
            "visible": (dataList) => _isFolder(dataList) && _isLocal(dataList)
        }, {
            "text": qsTr("Edit Audio Tracks"),
            "icon": "folder_edit_audio_tracks",
            "action": (dataList) => DialogsProvider.addSubtitlesDialog({ "mode": "folder", "kind": "audio", "mrl": dataList[0].mrl }),
            "visible": (dataList) => _isFolder(dataList) && _isLocal(dataList)
        }, {
            "text": qsTr("Resync"),
            "icon": "folder_resync",
            "action": (dataList) => MainCtx.mediaLibrary.reloadFolder(dataList[0].mrl),
            "visible": (dataList) => _isFolder(dataList) && _isLocal(dataList) && MainCtx.mediaLibraryAvailable
        }, {
            // ---- both
            "text": (Qt.platform.os === "windows") ? qsTr("Show in File Explorer") : qsTr("Show in Folder"),
            "icon": "file_show_in_file_explorer",
            "action": (dataList) => Qt.openUrlExternally(dataList[0].isFolder ? dataList[0].mrl : root._parentUrl(dataList[0].mrl)),
            "visible": (dataList) => _isLocal(dataList)
        }, {
            "text": qsTr("Pin to Sidebar"),
            "action": (dataList) => root._pin(dataList[0]),
            "visible": (dataList) => _isFolder(dataList) && _isLocal(dataList)
        }, {
            "separator": true
        }, {
            "text": qsTr("Remove from Library"),
            "action": (dataList) => root.libraryFolders.remove(dataList[0].mrl),
            "visible": (dataList) => _isFolder(dataList) && !!dataList[0].isLibraryRoot && !!root.libraryFolders
        }, {
            "text": qsTr("Delete File From System"),
            "action": (dataList, options, indexes) => root._deleteFile(dataList, indexes),
            "visible": (dataList, options, indexes) => _isFile(dataList) && indexes[0] >= 0
                       && VLCConfig.isDeletableFile(String(dataList[0].mrl))
        }
    ]
}
