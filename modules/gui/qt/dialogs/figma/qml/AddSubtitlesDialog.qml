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
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Menus
import VLC.Style
import VLC.Dialogs

// "Add Subtitles" from the VLC Redesign Figma file.
//  - To This Folder: every video of the folder is paired with the subtitle
//    file of the same name found in the subtitle folder (path box)
//  - To This File: pick one or more subtitle files for one video
// Saved subtitles are attached to the videos in the media library, so they
// are loaded every time (and the playing media gets them at once).
//  - To This Playlist: the videos of a library playlist, or of the queue
//    when the dialog is opened from the player
//  - From Link: one subtitle file on the web, for one video
//  - From OpenSubtitles: search opensubtitles.com (VLCOpenSubtitles). One
//    video: pick one of the results; a folder or playlist: the best result
//    for each video, which can be changed per row. Save downloads them next
//    to the videos, then attaches them like the other origins.
FigmaDialog {
    id: root

    title: kind === "audio" ? qsTr("Add Audio Tracks") : qsTr("Add Subtitles")

    width: VLCStyle.dp(1048, VLCStyle.scale)
    height: VLCStyle.dp(800, VLCStyle.scale)

    readonly property var videoExtensions: ["mp4", "mkv", "avi", "mov", "m4v", "webm", "wmv", "flv", "mpg", "mpeg", "ts", "m2ts", "ogv", "3gp"]
    readonly property var subtitleExtensions: ["srt", "ass", "ssa", "sub", "vtt", "idx", "smi", "txt", "usf", "jss", "sbv"]

    property string kind: "subtitles"   // "subtitles" or "audio"
    readonly property var audioExtensions: ["mka", "mp3", "aac", "ac3", "eac3", "dts", "flac", "ogg", "opus", "wav", "m4a", "wma"]
    readonly property var trackExtensions: kind === "audio" ? audioExtensions : subtitleExtensions
    property var listMedia: []          // "list" mode: URLs of the videos (library playlist)
    property string mode: "folder"      // "folder", "file" or "list"
    property string mediaUrl: ""        // the video, in file mode
    property string mediaFolder: ""     // folder of the videos
    property string subtitleFolder: ""  // folder the subtitles come from
    property bool fileAvailable: false
    property var playlistMedia: []      // videos offered by "To This Playlist"
    property string origin: "computer"  // "computer", "opensubtitles" or "link"
    property string linkUrl: ""
    readonly property bool _linkValid: /^(https?|ftp):\/\/\S+$/i.test(linkUrl.trim())

    property var _rows: []              // folder mode: { video, subtitle, checked }
    property var _subtitles: []         // file mode: { name, checked }

    // From OpenSubtitles
    readonly property bool _os: origin === "opensubtitles"
    property string osLanguage: ""
    property string osQuery: ""         // text typed by the user (file mode)
    property var _osResults: []         // file mode: search results
    property int _osChoice: -1          // file mode: chosen result
    property var _osRows: []            // folder mode: { video, media, results, choice, checked, pending }
    property var _osRequests: ({})      // pending search id -> row (-1: file mode)
    property var _osMenuLanguages: []   // languages of the open language menu
    property int _osMenuRow: -1         // row of the open result menu
    property string _osError: ""
    property int _osDownloadId: 0
    property string _osProgress: ""
    readonly property bool _osSearching: Object.keys(_osRequests).length > 0

    saveEnabled: MainCtx.mediaLibraryAvailable
                 && (origin === "link" ? (mode === "file" && _linkValid)
                     : _os ? (_osDownloadId === 0
                              && (mode === "file" ? _osChoice >= 0
                                                  : _osRows.some((r) => r.checked && r.choice >= 0)))
                     : mode !== "file" ? _rows.some((r) => r.checked && r.subtitle)
                                       : _subtitles.some((s) => s.checked))

    // OpenSubtitles downloads first, the dialog closes when they are done
    closeOnAccept: !_os

    function _folderOf(url) {
        const str = String(url)
        return str.substring(0, str.lastIndexOf("/"))
    }

    function _baseName(name) {
        const dot = name.lastIndexOf(".")
        return dot > 0 ? name.substring(0, dot) : name
    }

    function _fileName(url) {
        const str = decodeURIComponent(String(url))
        return str.substring(str.lastIndexOf("/") + 1)
    }

    // args: { mode: "file", mrl: <video URL> } or { mode: "folder", mrl: <folder URL> }
    // args: { mode: "file", mrl: <video URL> }, { mode: "folder", mrl: <folder URL> }
    //       or { mode: "list", mrls: [<video URLs>] }; kind: "subtitles" or "audio"
    //       queue: [<video URLs>] (player: the queue, for "To This Playlist")
    function reset(args) {
        _osCancel()
        kind = args?.kind ?? "subtitles"
        mode = args?.mode ?? "folder"
        origin = "computer"
        linkUrl = ""
        osQuery = ""
        osLanguage = VLCOpenSubtitles.defaultLanguage()
        _osResults = []
        _osChoice = -1
        _osRows = []
        _osError = ""
        _osProgress = ""
        fileAvailable = (mode === "file")
        listMedia = (mode === "list") ? (args.mrls ?? []).map(String) : []
        playlistMedia = (mode === "list") ? listMedia : (args?.queue ?? []).map(String)
        mediaUrl = fileAvailable ? String(args.mrl) : ""
        mediaFolder = fileAvailable ? _folderOf(args.mrl)
                    : mode === "list" ? (listMedia.length > 0 ? _folderOf(listMedia[0]) : "")
                    : String(args?.mrl ?? "")
        subtitleFolder = mediaFolder
        _refresh()
    }

    function _refresh() {
        if (_os) {
            _osSearch()
            return
        }
        const subtitles = VLCConfig.listFiles(subtitleFolder, trackExtensions)
        if (mode === "folder" || mode === "list") {
            const videos = mode === "list" ? listMedia.map(_fileName)
                                           : VLCConfig.listFiles(mediaFolder, videoExtensions)
            _rows = videos.map((video) => {
                const base = _baseName(video).toLowerCase()
                const match = subtitles.find((s) => _baseName(s).toLowerCase() === base)
                              ?? subtitles.find((s) => s.toLowerCase().startsWith(base))
                              ?? ""
                return { "video": video, "subtitle": match, "checked": match !== "" }
            })
        } else {
            const base = _baseName(_fileName(mediaUrl)).toLowerCase()
            let list = subtitles.filter((s) => s.toLowerCase().startsWith(base))
            if (list.length === 0)
                list = subtitles
            _subtitles = list.map((name) => ({ "name": name, "checked": false }))
        }
    }

    // ---- From OpenSubtitles ---------------------------------------------

    // the videos of the folder or playlist (URLs), in the order of the rows
    function _videoUrls() {
        if (mode === "list")
            return listMedia
        return VLCConfig.listFiles(mediaFolder, videoExtensions)
                        .map((video) => mediaFolder + "/" + encodeURIComponent(video))
    }

    function _osCancel() {
        for (const id in _osRequests)
            VLCOpenSubtitles.cancel(Number(id))
        _osRequests = ({})
        if (_osDownloadId !== 0)
            VLCOpenSubtitles.cancel(_osDownloadId)
        _osDownloadId = 0
        _osProgress = ""
    }

    function _osSearch() {
        _osCancel()
        _osError = ""
        if (!_os)
            return
        const requests = {}
        if (mode === "file") {
            _osResults = []
            _osChoice = -1
            const id = VLCOpenSubtitles.search(mediaUrl, osQuery, osLanguage)
            if (id)
                requests[id] = -1
        } else {
            const urls = _videoUrls()
            _osRows = urls.map((url) => ({ "video": _fileName(url), "media": url, "results": [],
                                           "choice": -1, "checked": false, "pending": true }))
            urls.forEach((url, index) => {
                const id = VLCOpenSubtitles.search(url, "", osLanguage)
                if (id)
                    requests[id] = index
            })
        }
        _osRequests = requests
    }

    function _languageName(code) {
        return VLCOpenSubtitles.languages.find((l) => l.code === code)?.name ?? code
    }

    // "English · 12,345 downloads · matches this file"
    function _osDetails(result) {
        const parts = [_languageName(result.language),
                       qsTr("%1 downloads").arg(Number(result.downloads).toLocaleString(Qt.locale(), "f", 0))]
        if (result.hashMatch)
            parts.push(qsTr("matches this file"))
        if (result.hearingImpaired)
            parts.push(qsTr("hearing impaired"))
        if (result.machine)
            parts.push(qsTr("machine translated"))
        return parts.join(" · ")
    }

    function _osPick(media, result) {
        return { "media": media, "fileId": result.fileId, "language": result.language, "fileName": result.fileName }
    }

    readonly property string _osAccountText: {
        if (VLCOpenSubtitles.signedIn)
            return VLCOpenSubtitles.remaining >= 0
                 ? qsTr("Signed in as %1, %2 downloads left today").arg(VLCOpenSubtitles.username).arg(VLCOpenSubtitles.remaining)
                 : qsTr("Signed in as %1").arg(VLCOpenSubtitles.username)
        return VLCOpenSubtitles.remaining >= 0
             ? qsTr("%1 downloads left today. Sign in under Settings › Network for more.").arg(VLCOpenSubtitles.remaining)
             : qsTr("Without an account: 5 downloads a day. Sign in under Settings › Network for more.")
    }

    Connections {
        target: VLCOpenSubtitles

        function onSearchFinished(id, results, error) {
            if (!(id in root._osRequests))
                return
            const index = root._osRequests[id]
            const requests = Object.assign({}, root._osRequests)
            delete requests[id]
            root._osRequests = requests
            if (error !== "")
                root._osError = error

            if (index < 0) {
                root._osResults = results
                root._osChoice = results.length > 0 ? 0 : -1
            } else {
                const rows = root._osRows.slice()
                rows[index] = Object.assign({}, rows[index], { "results": results, "pending": false,
                                                              "choice": results.length > 0 ? 0 : -1,
                                                              "checked": results.length > 0 })
                root._osRows = rows
            }
        }

        function onDownloadProgress(id, done, total) {
            if (id === root._osDownloadId && done < total)
                root._osProgress = qsTr("Downloading %1 of %2…").arg(done + 1).arg(total)
        }

        function onDownloadFinished(id, saved, error) {
            if (id !== root._osDownloadId)
                return
            root._osDownloadId = 0
            root._osProgress = ""
            if (saved.length > 0)
                MainCtx.mediaLibrary.addExternalSubtitles(saved.map((s) => ({ "media": s.media, "subtitle": s.subtitle, "audio": false })))
            if (error === "") {
                root.close()
                return
            }
            // keep what failed checked, so Save tries it again
            root._osError = error
            const done = saved.map((s) => s.media)
            root._osRows = root._osRows.map((r) => done.includes(r.media) ? Object.assign({}, r, { "checked": false }) : r)
            if (root.mode === "file" && saved.length > 0)
                root._osChoice = -1
        }
    }

    onVisibleChanged: {
        if (!visible)
            _osCancel()
    }

    onAccepted: {
        if (_os) {
            const items = (mode === "file")
                ? (_osChoice >= 0 ? [_osPick(mediaUrl, _osResults[_osChoice])] : [])
                : _osRows.filter((r) => r.checked && r.choice >= 0).map((r) => _osPick(r.media, r.results[r.choice]))
            if (items.length === 0)
                return
            _osError = ""
            _osDownloadId = VLCOpenSubtitles.download(items)
            _osProgress = qsTr("Downloading 1 of %1…").arg(items.length)
            return
        }

        const pairs = []
        const audio = (kind === "audio")
        if (origin === "link") {
            if (mode === "file" && _linkValid)
                pairs.push({ "media": mediaUrl, "subtitle": linkUrl.trim(), "audio": audio })
        } else if (mode === "folder" || mode === "list") {
            for (let i = 0; i < _rows.length; ++i) {
                const r = _rows[i]
                if (r.checked && r.subtitle)
                    pairs.push({ "media": mode === "list" ? listMedia[i] : mediaFolder + "/" + encodeURIComponent(r.video),
                                 "subtitle": subtitleFolder + "/" + encodeURIComponent(r.subtitle),
                                 "audio": audio })
            }
        } else {
            for (const s of _subtitles) {
                if (s.checked)
                    pairs.push({ "media": mediaUrl, "subtitle": subtitleFolder + "/" + encodeURIComponent(s.name), "audio": audio })
            }
        }
        MainCtx.mediaLibrary.addExternalSubtitles(pairs)
    }

    // ---- header: target, origin, subtitle folder -------------------------

    headerContent: RowLayout {
        width: parent.width
        spacing: VLCStyle.dp(10, VLCStyle.scale)

        // where the subtitles apply
        HeaderBox {
            Layout.preferredWidth: VLCStyle.dp(166, VLCStyle.scale)
            text: root.mode === "list" ? qsTr("To This Playlist")
                : root.mode === "folder" ? qsTr("To This Folder") : qsTr("To This File")
            chevron: true
            onClicked: targetMenu.popup(mapToGlobal(0, height + VLCStyle.dp(4, VLCStyle.scale)), [
                { "text": qsTr("To This File"), "checked": root.mode === "file", "enabled": root.fileAvailable },
                { "text": qsTr("To This Folder"), "checked": root.mode === "folder",
                  "enabled": root.origin !== "link" && (root.fileAvailable || root.mode === "folder") },
                { "text": qsTr("To This Playlist"), "checked": root.mode === "list",
                  "enabled": root.origin !== "link" && root.playlistMedia.length > 0 }
            ])

            StringListMenu {
                id: targetMenu
                ctx: MainCtx
                onSelected: (index, _) => {
                    if (index === 0) {
                        root.mode = "file"
                        root.mediaFolder = root._folderOf(root.mediaUrl)
                    } else if (index === 1) {
                        if (root.fileAvailable)
                            root.mediaFolder = root._folderOf(root.mediaUrl)
                        root.mode = "folder"
                    } else {
                        root.mode = "list"
                        root.listMedia = root.playlistMedia
                        root.mediaFolder = root.listMedia.length > 0 ? root._folderOf(root.listMedia[0]) : ""
                    }
                    root.subtitleFolder = root.mediaFolder
                    root._refresh()
                }
            }
        }

        // where the subtitles come from
        HeaderBox {
            Layout.preferredWidth: VLCStyle.dp(166, VLCStyle.scale)
            text: root.origin === "link" ? qsTr("From Link")
                : root._os ? qsTr("From OpenSubtitles") : qsTr("From Computer")
            chevron: true
            onClicked: originMenu.popup(mapToGlobal(0, height + VLCStyle.dp(4, VLCStyle.scale)), [
                { "text": qsTr("From Computer"), "checked": root.origin === "computer" },
                { "text": VLCOpenSubtitles.available ? qsTr("From OpenSubtitles")
                                                     : qsTr("From OpenSubtitles (not in this build)"),
                  "checked": root._os,
                  "enabled": VLCOpenSubtitles.available && root.kind !== "audio" },
                { "text": qsTr("From Link"), "checked": root.origin === "link", "enabled": root.fileAvailable }
            ])

            StringListMenu {
                id: originMenu
                ctx: MainCtx
                onSelected: (index, _) => {
                    const before = root.origin
                    if (index === 2) {
                        // one link is one subtitle file: for one video
                        root.origin = "link"
                        if (root.mode !== "file") {
                            root.mode = "file"
                            root.mediaFolder = root._folderOf(root.mediaUrl)
                            root.subtitleFolder = root.mediaFolder
                        }
                    } else if (index === 1) {
                        root.origin = "opensubtitles"
                    } else {
                        root.origin = "computer"
                    }
                    if (root.origin !== before) {
                        root._osCancel()
                        root._refresh()
                    }
                }
            }
        }

        // OpenSubtitles: language of the subtitles
        HeaderBox {
            Layout.preferredWidth: VLCStyle.dp(166, VLCStyle.scale)
            visible: root._os
            iconText: VLCIcons.subtitle
            text: root._languageName(root.osLanguage)
            chevron: true
            onClicked: {
                root._osMenuLanguages = VLCOpenSubtitles.languages
                languageMenu.popup(mapToGlobal(0, height + VLCStyle.dp(4, VLCStyle.scale)),
                                   root._osMenuLanguages.map((l) => ({ "text": l.name, "checked": l.code === root.osLanguage })))
            }

            StringListMenu {
                id: languageMenu
                ctx: MainCtx
                onSelected: (index, _) => {
                    const code = root._osMenuLanguages[index]?.code
                    if (!code || code === root.osLanguage)
                        return
                    root.osLanguage = code
                    VLCOpenSubtitles.setDefaultLanguage(code)
                    root._osSearch()
                }
            }
        }

        // OpenSubtitles, one video: search by title (empty: by file)
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: VLCStyle.dp(34, VLCStyle.scale)
            visible: root._os && root.mode === "file"
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: root.dark ? "#151515" : "#DEDEDE"
            border.width: queryField.activeFocus ? 1 : 0
            border.color: root.accentColor

            RowLayout {
                anchors.fill: parent
                spacing: 0

                T.TextField {
                    id: queryField
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    leftPadding: VLCStyle.dp(10, VLCStyle.scale)
                    rightPadding: VLCStyle.dp(10, VLCStyle.scale)
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.dark ? "#C6C6C6" : root.textColor
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    background: null
                    text: root.osQuery
                    onTextEdited: root.osQuery = text
                    onAccepted: root._osSearch()

                    Text {
                        anchors.fill: parent
                        leftPadding: queryField.leftPadding
                        verticalAlignment: Text.AlignVCenter
                        visible: queryField.text === ""
                        text: qsTr("Search by title, or leave empty to search for this file")
                        color: root.dark ? "#6B6B6B" : "#8F8F8F"
                        font: queryField.font
                        elide: Text.ElideRight
                    }
                }

                T.Button {
                    id: searchButton
                    Layout.fillHeight: true
                    implicitWidth: VLCStyle.dp(34, VLCStyle.scale)
                    onClicked: root._osSearch()
                    background: null
                    contentItem: Text {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: VLCIcons.fontFamily
                        font.pixelSize: VLCStyle.icon_small
                        text: VLCIcons.search
                        color: searchButton.hovered ? root.accentColor : root.textColor
                    }
                }
            }
        }

        // OpenSubtitles, several videos: keeps the boxes on the left
        Item {
            Layout.fillWidth: true
            visible: root._os && root.mode !== "file"
        }

        // link of the subtitle file
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: VLCStyle.dp(34, VLCStyle.scale)
            visible: root.origin === "link"
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: root.dark ? "#151515" : "#DEDEDE"
            border.width: linkField.activeFocus ? 1 : 0
            border.color: root.accentColor

            T.TextField {
                id: linkField
                anchors.fill: parent
                leftPadding: VLCStyle.dp(10, VLCStyle.scale)
                rightPadding: VLCStyle.dp(10, VLCStyle.scale)
                verticalAlignment: TextInput.AlignVCenter
                color: root.dark ? "#C6C6C6" : root.textColor
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                background: null
                text: root.linkUrl
                onTextEdited: root.linkUrl = text

                // the templates text field draws no placeholder
                Text {
                    anchors.fill: parent
                    leftPadding: linkField.leftPadding
                    verticalAlignment: Text.AlignVCenter
                    visible: linkField.text === ""
                    text: root.kind === "audio" ? qsTr("https://… link of the audio file")
                                                : qsTr("https://… link of the subtitle file")
                    color: root.dark ? "#6B6B6B" : "#8F8F8F"
                    font: linkField.font
                }
            }
        }

        HeaderBox {
            Layout.fillWidth: true
            visible: root.origin === "computer"
            iconText: VLCIcons.topbar_network
            text: decodeURIComponent(root.subtitleFolder.replace(/^file:\/\//, "")).split("/").filter((p) => p).slice(-4).join(" / ")
            onClicked: {
                const folder = VLCConfig.browseFolder(qsTr("Subtitle Folder"))
                if (folder !== "") {
                    root.subtitleFolder = folder
                    root._refresh()
                }
            }
        }
    }

    // ---- folder mode: videos paired with subtitles --------------------------

    ListView {
        anchors.fill: parent
        visible: root.origin === "computer" && root.mode !== "file"
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root._rows

        delegate: RowLayout {
            required property var modelData
            required property int index

            width: ListView.view.width
            height: VLCStyle.dp(33.5, VLCStyle.scale)
            spacing: VLCStyle.dp(12, VLCStyle.scale)

            CheckBox {
                Layout.leftMargin: VLCStyle.dp(10, VLCStyle.scale)
                checked: modelData.checked
                enabled: modelData.subtitle !== ""
                onToggled: {
                    const rows = root._rows.slice()
                    rows[index] = Object.assign({}, rows[index], { "checked": !rows[index].checked })
                    root._rows = rows
                }
            }

            Text {
                Layout.preferredWidth: Math.min(implicitWidth, parent.width * 0.35)
                text: modelData.video
                color: root.textColor
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                elide: Text.ElideMiddle
            }

            DashedLine {}

            SubtitleName {
                Layout.preferredWidth: parent.width * 0.45
                Layout.maximumWidth: parent.width * 0.45
                Layout.fillWidth: false
                text: modelData.subtitle !== "" ? modelData.subtitle
                    : root.kind === "audio" ? qsTr("No audio track found") : qsTr("No subtitle found")
                dim: modelData.subtitle === ""
            }
        }
    }

    // ---- file mode: pick subtitle files ------------------------------------

    ListView {
        anchors.fill: parent
        visible: root.mode === "file" && root.origin === "computer"
        clip: true
        spacing: VLCStyle.dp(3, VLCStyle.scale)
        boundsBehavior: Flickable.StopAtBounds
        model: root._subtitles

        delegate: T.Button {
            id: subtitleRow

            required property var modelData
            required property int index

            width: ListView.view.width
            height: VLCStyle.dp(30, VLCStyle.scale)

            background: Rectangle {
                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: subtitleRow.modelData.checked ? root.wellColor
                     : subtitleRow.hovered ? Qt.lighter(root.panelColor, 1.15) : "transparent"
            }

            contentItem: RowLayout {
                SubtitleName {
                    Layout.fillWidth: true
                    Layout.leftMargin: VLCStyle.dp(8, VLCStyle.scale)
                    text: subtitleRow.modelData.name
                }
                Text {
                    Layout.rightMargin: VLCStyle.dp(10, VLCStyle.scale)
                    visible: subtitleRow.modelData.checked
                    font.family: VLCIcons.fontFamily
                    font.pixelSize: VLCStyle.icon_small
                    text: VLCIcons.check
                    color: root.accentColor
                }
            }

            onClicked: {
                const list = root._subtitles.slice()
                list[index] = Object.assign({}, list[index], { "checked": !list[index].checked })
                root._subtitles = list
            }
        }
    }

    // ---- From OpenSubtitles: one video, pick a result -----------------------

    ListView {
        anchors.fill: parent
        anchors.bottomMargin: osFooter.height + VLCStyle.dp(10, VLCStyle.scale)
        visible: root._os && root.mode === "file"
        clip: true
        spacing: VLCStyle.dp(3, VLCStyle.scale)
        boundsBehavior: Flickable.StopAtBounds
        model: root._osResults

        delegate: T.Button {
            id: resultRow

            required property var modelData
            required property int index
            readonly property bool chosen: index === root._osChoice

            width: ListView.view.width
            height: VLCStyle.dp(30, VLCStyle.scale)

            background: Rectangle {
                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: resultRow.chosen ? root.wellColor
                     : resultRow.hovered ? Qt.lighter(root.panelColor, 1.15) : "transparent"
            }

            contentItem: RowLayout {
                spacing: VLCStyle.dp(12, VLCStyle.scale)

                SubtitleName {
                    Layout.fillWidth: true
                    Layout.leftMargin: VLCStyle.dp(8, VLCStyle.scale)
                    text: resultRow.modelData.release
                }
                Text {
                    text: root._osDetails(resultRow.modelData)
                    color: root.dimColor
                    font.pixelSize: VLCStyle.dp(12, VLCStyle.scale)
                }
                Text {
                    Layout.rightMargin: VLCStyle.dp(10, VLCStyle.scale)
                    Layout.preferredWidth: VLCStyle.icon_small
                    font.family: VLCIcons.fontFamily
                    font.pixelSize: VLCStyle.icon_small
                    text: resultRow.chosen ? VLCIcons.check : ""
                    color: root.accentColor
                }
            }

            onClicked: root._osChoice = resultRow.chosen ? -1 : index
        }
    }

    // ---- From OpenSubtitles: folder or playlist, best result per video ----------

    ListView {
        anchors.fill: parent
        anchors.bottomMargin: osFooter.height + VLCStyle.dp(10, VLCStyle.scale)
        visible: root._os && root.mode !== "file"
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root._osRows

        delegate: RowLayout {
            id: osRow

            required property var modelData
            required property int index
            readonly property var result: modelData.choice >= 0 ? modelData.results[modelData.choice] : null

            width: ListView.view.width
            height: VLCStyle.dp(33.5, VLCStyle.scale)
            spacing: VLCStyle.dp(12, VLCStyle.scale)

            CheckBox {
                Layout.leftMargin: VLCStyle.dp(10, VLCStyle.scale)
                checked: osRow.modelData.checked
                enabled: osRow.result !== null
                onToggled: {
                    const rows = root._osRows.slice()
                    rows[osRow.index] = Object.assign({}, rows[osRow.index], { "checked": !rows[osRow.index].checked })
                    root._osRows = rows
                }
            }

            Text {
                Layout.preferredWidth: Math.min(implicitWidth, parent.width * 0.35)
                text: osRow.modelData.video
                color: root.textColor
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                elide: Text.ElideMiddle
            }

            DashedLine {}

            // the chosen result; click for the others
            T.Button {
                id: choiceButton

                Layout.preferredWidth: osRow.width * 0.45
                Layout.fillHeight: true
                enabled: osRow.modelData.results.length > 0
                background: Rectangle {
                    radius: VLCStyle.dp(6, VLCStyle.scale)
                    color: choiceButton.hovered ? Qt.lighter(root.panelColor, 1.15) : "transparent"
                }
                contentItem: RowLayout {
                    SubtitleName {
                        Layout.fillWidth: true
                        text: osRow.modelData.pending ? qsTr("Searching…")
                            : osRow.result ? osRow.result.release : qsTr("No subtitle found")
                        dim: osRow.result === null
                    }
                    Text {
                        Layout.rightMargin: VLCStyle.dp(6, VLCStyle.scale)
                        visible: choiceButton.enabled
                        font.family: VLCIcons.fontFamily
                        font.pixelSize: VLCStyle.icon_small
                        text: VLCIcons.chevron_down
                        color: root.textColor
                    }
                }
                onClicked: {
                    root._osMenuRow = osRow.index
                    const entries = osRow.modelData.results.slice(0, 20).map((r, i) => ({
                        "text": r.release + "  (" + root._osDetails(r) + ")",
                        "checked": i === osRow.modelData.choice }))
                    entries.push({ "separator": true })
                    entries.push({ "text": qsTr("No subtitles"), "checked": osRow.modelData.choice < 0 })
                    resultMenu.popup(mapToGlobal(0, height + VLCStyle.dp(4, VLCStyle.scale)), entries)
                }
            }
        }

        StringListMenu {
            id: resultMenu
            ctx: MainCtx
            onSelected: (index, _) => {
                const rows = root._osRows.slice()
                const row = rows[root._osMenuRow]
                if (!row)
                    return
                const choice = index < Math.min(row.results.length, 20) ? index : -1
                rows[root._osMenuRow] = Object.assign({}, row, { "choice": choice, "checked": choice >= 0 })
                root._osRows = rows
            }
        }
    }

    Text {
        anchors.centerIn: parent
        width: parent.width * 0.8
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        visible: root._os && (root.mode === "file" ? root._osResults.length === 0 : root._osRows.length === 0)
        text: root._osSearching ? qsTr("Searching OpenSubtitles…")
            : root.mode !== "file" ? qsTr("No videos found.")
            : root._osError !== "" ? ""
            : qsTr("No subtitles found. Try another language, or search by title.")
        color: root.placeholderColor
        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
    }

    // account / progress / error, and where the subtitles come from
    RowLayout {
        id: osFooter

        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        visible: root._os
        spacing: VLCStyle.dp(12, VLCStyle.scale)

        Text {
            Layout.fillWidth: true
            text: root._osProgress !== "" ? root._osProgress
                : root._osError !== "" ? root._osError
                : root._osAccountText
            color: root._osError !== "" && root._osProgress === "" ? root.accentColor : root.dimColor
            font.pixelSize: VLCStyle.dp(12, VLCStyle.scale)
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        Text {
            text: qsTr("Subtitles from opensubtitles.com")
            color: root.dimColor
            font.pixelSize: VLCStyle.dp(12, VLCStyle.scale)
        }
    }

    // From Link: what is saved
    Text {
        anchors.centerIn: parent
        width: parent.width * 0.8
        visible: root.origin === "link"
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: (root.kind === "audio" ? qsTr("The audio track at this link is added to %1.")
                                     : qsTr("The subtitles at this link are added to %1."))
              .arg(root._fileName(root.mediaUrl))
        color: root.textColor
        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
    }

    Text {
        anchors.centerIn: parent
        visible: root.origin === "computer" && (root.mode !== "file" ? root._rows.length : root._subtitles.length) === 0
        text: root.mode !== "file" ? qsTr("No videos found.")
            : root.kind === "audio" ? qsTr("No audio files found. Click the folder above to choose where to look.")
                                    : qsTr("No subtitle files found. Click the folder above to choose where to look.")
        color: root.placeholderColor
        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
    }

    // ---- components ----------------------------------------------------------

    component HeaderBox: T.Button {
        id: box

        property string iconText: ""
        property bool chevron: false

        implicitHeight: VLCStyle.dp(34, VLCStyle.scale)
        background: Rectangle {
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: root.dark ? (box.hovered ? "#1B1B1B" : "#151515") : "#DEDEDE"
        }
        contentItem: RowLayout {
            spacing: VLCStyle.dp(10, VLCStyle.scale)
            Text {
                Layout.leftMargin: VLCStyle.dp(10, VLCStyle.scale)
                visible: box.iconText !== ""
                font.family: VLCIcons.fontFamily
                font.pixelSize: VLCStyle.icon_small
                text: box.iconText
                color: root.textColor
            }
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: box.iconText === "" ? VLCStyle.dp(10, VLCStyle.scale) : 0
                text: box.text
                color: root.dark ? "#969696" : root.textColor
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                elide: Text.ElideLeft
            }
            Text {
                Layout.rightMargin: VLCStyle.dp(10, VLCStyle.scale)
                visible: box.chevron
                font.family: VLCIcons.fontFamily
                font.pixelSize: VLCStyle.icon_small
                text: VLCIcons.chevron_down
                color: root.textColor
            }
        }
    }

    // dashed connector between a video and its subtitle
    component DashedLine: Item {
        id: dashedLine
        Layout.fillWidth: true
        Layout.minimumWidth: VLCStyle.dp(40, VLCStyle.scale)
        Layout.preferredHeight: 2
        clip: true

        Repeater {
            model: Math.ceil(dashedLine.width / 6)
            Rectangle {
                required property int index
                x: index * 6
                y: 0.5
                width: 3
                height: 1
                color: root.dark ? "#404040" : "#9B9B9B"
            }
        }
    }

    component SubtitleName: RowLayout {
        property alias text: label.text
        property bool dim: false

        spacing: VLCStyle.dp(12, VLCStyle.scale)

        Text {
            visible: !parent.dim
            font.family: VLCIcons.fontFamily
            font.pixelSize: VLCStyle.icon_small
            text: root.kind === "audio" ? VLCIcons.visualization : VLCIcons.subtitle
            color: root.textColor
        }
        Text {
            id: label
            Layout.fillWidth: true
            color: parent.dim ? root.placeholderColor : root.textColor
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            elide: Text.ElideMiddle
        }
    }

    component CheckBox: T.CheckBox {
        id: check

        implicitWidth: VLCStyle.dp(16, VLCStyle.scale)
        implicitHeight: VLCStyle.dp(16, VLCStyle.scale)
        indicator: Rectangle {
            anchors.fill: parent
            radius: VLCStyle.dp(3, VLCStyle.scale)
            color: check.checked ? root.accentSurface : "transparent"
            border.width: 1.5
            border.color: check.checked ? root.accentColor : (check.enabled ? root.textColor : root.placeholderColor)

            Text {
                anchors.centerIn: parent
                visible: check.checked
                font.family: VLCIcons.fontFamily
                font.pixelSize: VLCStyle.dp(12, VLCStyle.scale)
                text: VLCIcons.check
                color: root.accentColor
            }
        }
    }
}
