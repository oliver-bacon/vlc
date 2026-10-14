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
// are loaded every time. "From OpenSubtitles" of the design is not
// available yet.
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

    property var _rows: []              // folder mode: { video, subtitle, checked }
    property var _subtitles: []         // file mode: { name, checked }

    saveEnabled: MainCtx.mediaLibraryAvailable
                 && (mode !== "file" ? _rows.some((r) => r.checked && r.subtitle)
                                       : _subtitles.some((s) => s.checked))

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
    function reset(args) {
        kind = args?.kind ?? "subtitles"
        mode = args?.mode ?? "folder"
        fileAvailable = (mode === "file")
        listMedia = (mode === "list") ? (args.mrls ?? []).map(String) : []
        mediaUrl = fileAvailable ? String(args.mrl) : ""
        mediaFolder = fileAvailable ? _folderOf(args.mrl)
                    : mode === "list" ? (listMedia.length > 0 ? _folderOf(listMedia[0]) : "")
                    : String(args?.mrl ?? "")
        subtitleFolder = mediaFolder
        _refresh()
    }

    function _refresh() {
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

    onAccepted: {
        const pairs = []
        const audio = (kind === "audio")
        if (mode === "folder" || mode === "list") {
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

        HeaderBox {
            Layout.preferredWidth: VLCStyle.dp(166, VLCStyle.scale)
            text: root.mode === "list" ? qsTr("To This Playlist")
                : root.mode === "folder" ? qsTr("To This Folder") : qsTr("To This File")
            chevron: true
            onClicked: if (root.mode !== "list") targetMenu.popup(mapToGlobal(0, height + VLCStyle.dp(4, VLCStyle.scale)), [
                { "text": qsTr("To This Folder"), "checked": root.mode === "folder" },
                { "text": qsTr("To This File"), "checked": root.mode === "file", "enabled": root.fileAvailable }
            ])

            StringListMenu {
                id: targetMenu
                ctx: MainCtx
                onSelected: (index, _) => {
                    root.mode = (index === 0) ? "folder" : "file"
                    root._refresh()
                }
            }
        }

        HeaderBox {
            Layout.preferredWidth: VLCStyle.dp(166, VLCStyle.scale)
            text: qsTr("From Computer")
            chevron: true
        }

        HeaderBox {
            Layout.fillWidth: true
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
        visible: root.mode !== "file"
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

            // dashed connector
            Item {
                id: dashedConnector
                Layout.fillWidth: true
                Layout.minimumWidth: VLCStyle.dp(40, VLCStyle.scale)
                Layout.preferredHeight: 2
                clip: true

                Repeater {
                    model: Math.ceil(dashedConnector.width / 6)
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
        visible: root.mode === "file"
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

    Text {
        anchors.centerIn: parent
        visible: (root.mode !== "file" ? root._rows.length : root._subtitles.length) === 0
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
