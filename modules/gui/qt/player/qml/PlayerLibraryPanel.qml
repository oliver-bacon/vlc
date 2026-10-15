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
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.Dialogs
import VLC.MainInterface
import VLC.Network
import VLC.Player
import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets
import VLC.Menus

// Compact library on the left of the player (VLC Redesign video, 11:44):
// a rail with Videos / Music / Network / Playlists, and a narrow browser
// with back / forward, the path, item count, sort and search. Folders are
// browsed like in VLC's Browse view; double-click plays, "+" or dragging
// an item onto the play queue adds it. The pop-out button opens the same
// place in the full library.
FocusScope {
    id: root

    // ---- public

    signal closeRequested()

    // open the folder of the media being played (top bar folder button)
    function showFolder(folderUrl) {
        const levels = []
        if (_hasML)
            levels.push({ kind: "videoFolders", title: qsTr("Videos") })
        const parts = folderUrl.split("/")
        const name = decodeURIComponent(parts[parts.length - 1])
        const parentUrl = parts.slice(0, -1).join("/")
        const parentName = decodeURIComponent(parts[parts.length - 2] ?? "")
        if (parentName !== "" && parentUrl.length > "file://".length)
            levels.push(_browseLevel(parentUrl, parentName))
        levels.push(_browseLevel(folderUrl, name))
        _section = "video"
        _setLevels(levels, levels.length - 1)
    }

    function showSection(section) {
        _section = section
        _setLevels([_rootLevel(section)], 0)
    }

    // ---- private

    readonly property bool _hasML: MainCtx.mediaLibraryAvailable
    readonly property var _ml: mlLoader.item

    property string _section: "video"
    property var _levels: []
    property int _levelIndex: -1
    readonly property var _level: (_levelIndex >= 0 && _levelIndex < _levels.length) ? _levels[_levelIndex] : null
    readonly property string _kind: _level ? _level.kind : ""

    property bool _searchVisible: false

    readonly property bool dark: VLCStyle.palette?.isDark ?? true
    readonly property color railColor: dark ? "#151515" : "#DEDEDE"
    readonly property color panelColor: dark ? "#191919" : "#E7E7E7"
    readonly property color hoverColor: dark ? "#222222" : "#D5D5D5"
    readonly property color dividerColor: dark ? "#222222" : "#ACACAC"
    readonly property color titleColor: dark ? "#C6C6C6" : "#161616"
    readonly property color textColor: dark ? "#8F8F8F" : "#2E2E2E"
    readonly property color dimColor: "#6B6B6B"
    readonly property color accentColor: "#D37918"
    readonly property real dp1: VLCStyle.dp(1, VLCStyle.scale)

    readonly property var _musicRoot: [
        { kind: "tracks", title: qsTr("Songs"), glyph: VLCIcons.songs },
        { kind: "albums", title: qsTr("Albums"), glyph: VLCIcons.album_cover },
        { kind: "artists", title: qsTr("Artists"), glyph: VLCIcons.artist },
        { kind: "genres", title: qsTr("Genres"), glyph: VLCIcons.genre }
    ]

    // Home sections (Figma "sidebar" frame): a header and the first items
    readonly property var _homeSections: _ml ? [
        { kind: "continue", title: qsTr("Continue Watching"), model: _ml.recentVideosPreview },
        { kind: "listenAgain", title: qsTr("Listen Again"), model: _ml.recentAudioPreview }
    ] : []

    // the levels that start with an "Add" row (add a folder to the library)
    readonly property bool _showAdd: _hasML && (_kind === "musicRoot" || _kind === "videoFolders")

    function _addFolder() {
        const folder = VLCConfig.browseFolder(qsTr("Add a Folder to the Library"))
        if (folder !== "")
            MainCtx.mediaLibrary.addFolder(folder)
    }

    // ---- pinned items, shared with the library side navigation
    // (SideNavigationPane.qml, interface setting "Library/Pins")

    readonly property string _pinsKey: "Library/Pins"
    property var _pins: []

    function _loadPins() {
        try {
            const list = JSON.parse(VLCConfig.uiValue(_pinsKey, "[]"))
            _pins = Array.isArray(list) ? list : []
        } catch (e) {
            _pins = []
        }
    }

    function _pin(item) {
        const list = _pins.filter((p) => !(p.type === item.type && p.url === item.url && p.id === item.id))
        list.push(item)
        VLCConfig.setUiValue(_pinsKey, JSON.stringify(list))
    }

    function _openPin(index) {
        const pin = _pins[index]
        _section = "pin" + index
        if (pin.type === "folder")
            _setLevels([_browseLevel(pin.url, pin.name)], 0)
        else if (pin.type === "playlist" && MainCtx.mediaLibrary)
            _setLevels([{ kind: "playlistMedia", title: pin.name,
                          parentId: MainCtx.mediaLibrary.deserializeMlItemIdFromString(pin.id) }], 0)
    }

    function _addItemMenu() {
        const items = [{ "text": qsTr("Pin a Folder…") }]
        const playlists = _ml ? _ml.playlists : null
        if (playlists && playlists.count > 0) {
            const children = []
            for (let i = 0; i < Math.min(playlists.count, 50); ++i)
                children.push({ "text": playlists.getDataAt(i).name })
            items.push({ "text": qsTr("Pin a Playlist"), "children": children })
        }
        return items
    }

    Connections {
        target: VLCConfig
        function onUiValueChanged(key) {
            if (key === root._pinsKey)
                root._loadPins()
        }
    }

    function _browseLevel(url, title) {
        return { kind: "browse", title: title, url: url, tree: VLCConfig.browseNode(url) }
    }

    function _rootLevel(section) {
        switch (section) {
        case "home": return { kind: "home", title: qsTr("Home") }
        case "recent": return { kind: "recent", title: qsTr("Recent") }
        case "music": return { kind: "musicRoot", title: qsTr("Music") }
        case "network": return { kind: "streams", title: qsTr("Network") }
        case "playlists": return { kind: "playlists", title: qsTr("Playlists") }
        default: return { kind: "videoFolders", title: qsTr("Videos") }
        }
    }

    function _setLevels(levels, index) {
        _levels = levels
        _levelIndex = index
        _applyLevel()
    }

    function _push(level) {
        const levels = _levels.slice(0, _levelIndex + 1)
        levels.push(level)
        _setLevels(levels, levels.length - 1)
    }

    function _go(delta) {
        const i = _levelIndex + delta
        if (i < 0 || i >= _levels.length)
            return
        _levelIndex = i
        _applyLevel()
    }

    // models that depend on the level
    function _applyLevel() {
        _searchVisible = false
        searchField.text = ""
        if (!_level)
            return
        if (_level.kind === "browse")
            browseModel.tree = _level.tree
        else if (_ml && _level.kind === "tracksOf")
            _ml.tracksOf.parentId = _level.parentId
        else if (_ml && _level.kind === "playlistMedia")
            _ml.playlistMedia.parentId = _level.parentId
    }

    readonly property var _model: {
        switch (_kind) {
        case "browse": return browseModel
        case "musicRoot": return _musicRoot
        case "videoFolders": return _ml ? _ml.videoFolders : null
        case "tracks": return _ml ? _ml.tracks : null
        case "tracksOf": return _ml ? _ml.tracksOf : null
        case "albums": return _ml ? _ml.albums : null
        case "artists": return _ml ? _ml.artists : null
        case "genres": return _ml ? _ml.genres : null
        case "streams": return _ml ? _ml.streams : null
        case "playlists": return _ml ? _ml.playlists : null
        case "playlistMedia": return _ml ? _ml.playlistMedia : null
        case "continue": return _ml ? _ml.recentVideos : null
        case "listenAgain": return _ml ? _ml.recentAudio : null
        case "recent": return _ml ? _ml.recentMedia : null
        }
        return null
    }

    readonly property bool _isArray: Array.isArray(_model)

    readonly property int _count: _isArray ? _model.length : (_model ? _model.count : 0)

    // [text, criteria, order]
    readonly property var _sortOptions: {
        const az = (c) => [[qsTr("Title A-Z"), c, Qt.AscendingOrder], [qsTr("Title Z-A"), c, Qt.DescendingOrder]]
        switch (_kind) {
        case "browse":
            return az("name").concat([[qsTr("Newest First"), "fileModified", Qt.DescendingOrder],
                                      [qsTr("Oldest First"), "fileModified", Qt.AscendingOrder]])
        case "tracks": case "tracksOf":
            return az("title").concat([[qsTr("Newest First"), "insertion", Qt.DescendingOrder],
                                       [qsTr("Oldest First"), "insertion", Qt.AscendingOrder]])
        case "albums":
            return az("title").concat([[qsTr("Newest First"), "release_year", Qt.DescendingOrder],
                                       [qsTr("Oldest First"), "release_year", Qt.AscendingOrder]])
        case "videoFolders": case "playlistMedia": return az("title")
        case "artists": case "genres": case "playlists": return az("name")
        case "streams": return az("url")
        }
        return []
    }

    // ---- row helpers (data of a row as a JS object)

    function _rowTitle(d) {
        switch (_kind) {
        case "browse": return d.name ?? ""
        case "musicRoot": return d.title
        case "artists": case "genres": case "playlists": return d.name ?? ""
        case "streams": return d.url ?? ""
        }
        return d.title ?? ""
    }

    function _rowGlyph(d) {
        switch (_kind) {
        case "musicRoot": return d.glyph
        case "videoFolders": return VLCIcons.topbar_network
        case "browse": return _rowIsNav(d) ? VLCIcons.topbar_network : VLCIcons.topbar_video
        case "albums": case "artists": case "genres": case "tracks": case "tracksOf":
        case "listenAgain":
            return VLCIcons.topbar_music
        case "streams": return VLCIcons.stream
        case "playlists": return VLCIcons.lists
        }
        return VLCIcons.topbar_video
    }

    function _rowArtwork(d) {
        if (_isArray)
            return ""
        return d.thumbnail || d.small_cover || d.cover || d.artwork || ""
    }

    function _rowIsNav(d) {
        switch (_kind) {
        case "browse":
            return d.type === NetworkMediaModel.TYPE_DIRECTORY
                || d.type === NetworkMediaModel.TYPE_NODE
                || d.type === NetworkMediaModel.TYPE_PLAYLIST
        case "musicRoot": case "videoFolders": case "albums": case "artists":
        case "genres": case "playlists":
            return true
        }
        return false
    }

    function _rowIsCurrent(d) {
        const mrl = d.mrl ?? d.url
        return !!mrl && String(mrl) === String(Player.url)
    }

    function _open(index, d) {
        switch (_kind) {
        case "browse":
            _push({ kind: "browse", title: d.name, tree: d.tree, url: d.mrl })
            return
        case "musicRoot":
            _push({ kind: d.kind, title: d.title })
            return
        case "videoFolders":
            _push(_browseLevel(String(d.mrl), d.title))
            return
        case "albums":
            _push({ kind: "tracksOf", title: d.title, parentId: d.id })
            return
        case "artists": case "genres":
            _push({ kind: "tracksOf", title: d.name, parentId: d.id })
            return
        case "playlists":
            _push({ kind: "playlistMedia", title: d.name, parentId: d.id })
            return
        }
    }

    function _play(index, d, enqueue) {
        if (_kind === "browse") {
            if (enqueue) browseModel.addToPlaylist(index)
            else browseModel.addAndPlay(index)
        } else if (MainCtx.mediaLibrary && d.id !== undefined) {
            if (enqueue) MainCtx.mediaLibrary.addToPlaylist(d.id)
            else MainCtx.mediaLibrary.addAndPlay(d.id)
        }
    }

    function _rowData(index) {
        if (_isArray)
            return _model[index]
        return _model.getDataAt(index)
    }

    // the same place in the full library
    function _popOut() {
        let path = ["video"]
        let props = undefined
        switch (_kind) {
        case "browse": path = ["network", "browse"]; props = { "tree": _level.tree }; break
        case "home": case "continue": case "listenAgain": path = ["home"]; break
        case "recent": path = ["recent"]; break
        case "musicRoot": case "tracks": case "tracksOf": path = ["music"]; break
        case "albums": path = ["music", "albums"]; break
        case "artists": path = ["music", "artists"]; break
        case "genres": path = ["music", "genres"]; break
        case "streams": path = ["discover", "url"]; break
        case "playlists": case "playlistMedia": path = ["video", "playlists"]; break
        }
        MainCtx.playerView = false
        if (props !== undefined)
            History.push(path, props)
        else
            History.push(path)
    }

    Component.onCompleted: {
        _loadPins()
        showSection("video")
    }

    implicitWidth: rail.width + VLCStyle.dp(260, VLCStyle.scale)

    Loader {
        id: mlLoader
        active: root._hasML
        source: "qrc:///qt/qml/VLC/Player/PlayerLibraryModels.qml"
        onLoaded: root._applyLevel()
    }

    NetworkMediaModel {
        id: browseModel
        ctx: MainCtx
    }

    Rectangle {
        anchors.fill: parent
        color: root.panelColor
    }

    // ---- rail
    Rectangle {
        id: rail

        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: VLCStyle.dp(40, VLCStyle.scale)
        color: root.railColor
        visible: root._hasML

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: VLCStyle.margin_small
            spacing: VLCStyle.margin_xxsmall

            Repeater {
                // Figma "sidebar" frame: Home, Videos, Music, Network,
                // Playlists, Recent, then the pins and "+"
                model: [
                    { section: "home", glyph: VLCIcons.home, text: qsTr("Home") },
                    { section: "video", glyph: VLCIcons.topbar_video, text: qsTr("Videos") },
                    { section: "music", glyph: VLCIcons.topbar_music, text: qsTr("Music") },
                    { section: "network", glyph: VLCIcons.stream, text: qsTr("Network") },
                    { section: "playlists", glyph: VLCIcons.lists, text: qsTr("Playlists") },
                    { section: "recent", glyph: VLCIcons.history, text: qsTr("Recent") }
                ].concat(root._pins.map((p, i) => ({
                    section: "pin" + i,
                    glyph: p.type === "folder" ? VLCIcons.topbar_network : VLCIcons.lists,
                    text: p.name,
                    pin: i
                }))).concat([{ section: "", glyph: VLCIcons.add, text: qsTr("Add item"), add: true }])

                T.Button {
                    id: railButton

                    required property var modelData

                    width: VLCStyle.dp(32, VLCStyle.scale)
                    height: width

                    Accessible.name: modelData.text

                    readonly property bool current: root._section === modelData.section

                    background: Rectangle {
                        radius: 4 * root.dp1
                        color: railButton.hovered ? root.hoverColor : "transparent"
                    }
                    contentItem: Text {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: VLCIcons.fontFamily
                        font.pixelSize: VLCStyle.icon_normal
                        text: railButton.modelData.glyph
                        color: railButton.current ? root.accentColor : root.textColor
                    }
                    onClicked: {
                        if (modelData.add)
                            addItemMenu.popup(railButton.mapToGlobal(railButton.width, 0), root._addItemMenu())
                        else if (modelData.pin !== undefined)
                            root._openPin(modelData.pin)
                        else
                            root.showSection(modelData.section)
                    }
                }
            }
        }
    }

    StringListMenu {
        id: addItemMenu
        ctx: MainCtx
        onSelected: (index, text) => {
            if (index === 0) {
                const folder = VLCConfig.browseFolder(qsTr("Pin a Folder to the Sidebar"))
                if (folder !== "") {
                    const parts = decodeURIComponent(folder).split("/").filter((p) => p !== "")
                    root._pin({ "type": "folder", "name": parts[parts.length - 1] ?? folder, "url": folder })
                }
            } else if (root._ml) {
                // playlist entries follow "Pin a Folder…"
                const data = root._ml.playlists.getDataAt(index - 1)
                root._pin({ "type": "playlist", "name": data.name, "id": data.id.toString() })
            }
        }
    }

    // ---- browser
    ColumnLayout {
        anchors {
            left: rail.visible ? rail.right : parent.left
            right: parent.right; top: parent.top; bottom: parent.bottom
            leftMargin: VLCStyle.margin_small; rightMargin: VLCStyle.margin_small
            topMargin: VLCStyle.margin_xsmall
        }
        spacing: VLCStyle.margin_xxsmall

        // back / forward, path, menu, pop-out
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Widgets.IconToolButton {
                text: VLCIcons.back
                description: qsTr("Back")
                font.pixelSize: VLCStyle.icon_normal
                Layout.preferredWidth: VLCStyle.dp(28, VLCStyle.scale)
                Layout.preferredHeight: VLCStyle.dp(28, VLCStyle.scale)
                enabled: root._levelIndex > 0
                onClicked: root._go(-1)
            }
            Widgets.IconToolButton {
                text: VLCIcons.arrow_right
                description: qsTr("Forward")
                font.pixelSize: VLCStyle.icon_normal
                Layout.preferredWidth: VLCStyle.dp(28, VLCStyle.scale)
                Layout.preferredHeight: VLCStyle.dp(28, VLCStyle.scale)
                enabled: root._levelIndex < root._levels.length - 1
                onClicked: root._go(1)
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: VLCStyle.margin_xxsmall
                text: root._levels.slice(0, root._levelIndex + 1).map((l) => l.title).join("  ›  ")
                elide: Text.ElideLeft
                color: root.titleColor
                font.pixelSize: VLCStyle.fontSize_normal
            }

            Widgets.IconToolButton {
                id: menuButton
                text: VLCIcons.more
                description: qsTr("More")
                font.pixelSize: VLCStyle.icon_normal
                Layout.preferredWidth: VLCStyle.dp(28, VLCStyle.scale)
                Layout.preferredHeight: VLCStyle.dp(28, VLCStyle.scale)
                onClicked: {
                    const items = [{ "text": qsTr("Add File to the Play Queue") }]
                    if (root._hasML)
                        items.push({ "text": qsTr("Add Folder to the Library") })
                    if (root._kind === "streams")
                        items.push({ "text": qsTr("Add Network Stream") })
                    moreMenu.popup(mapToGlobal(0, height), items)
                }

                StringListMenu {
                    id: moreMenu
                    ctx: MainCtx
                    onSelected: (index, text) => {
                        if (text === qsTr("Add File to the Play Queue")) {
                            DialogsProvider.PLAppendDialog()
                        } else if (text === qsTr("Add Folder to the Library")) {
                            const folder = VLCConfig.browseFolder(qsTr("Add a Folder to the Library"))
                            if (folder !== "")
                                MainCtx.mediaLibrary.addFolder(folder)
                        } else {
                            DialogsProvider.openNetDialog()
                        }
                    }
                }
            }
            Widgets.IconToolButton {
                text: VLCIcons.open
                description: qsTr("Open in the full library")
                font.pixelSize: VLCStyle.icon_normal
                Layout.preferredWidth: VLCStyle.dp(28, VLCStyle.scale)
                Layout.preferredHeight: VLCStyle.dp(28, VLCStyle.scale)
                onClicked: root._popOut()
            }
        }

        // count, sort, search (none of them on Home: an empty row layout
        // would take all the height)
        RowLayout {
            Layout.fillWidth: true
            visible: root._kind !== "home"
            spacing: 0

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: VLCStyle.margin_xxsmall
                text: root._count === 1 ? qsTr("1 item") : qsTr("%1 items").arg(root._count)
                color: root.dimColor
                font.pixelSize: VLCStyle.fontSize_small
            }

            Widgets.IconToolButton {
                text: VLCIcons.topbar_sort
                description: qsTr("Sort")
                font.pixelSize: VLCStyle.icon_normal
                Layout.preferredWidth: VLCStyle.dp(28, VLCStyle.scale)
                Layout.preferredHeight: VLCStyle.dp(28, VLCStyle.scale)
                visible: root._sortOptions.length > 0 && !root._isArray
                onClicked: {
                    const m = root._model
                    sortMenu.popup(mapToGlobal(0, height), root._sortOptions.map((o) => ({
                        "text": o[0],
                        "checked": m.sortCriteria === o[1] && m.sortOrder === o[2]
                    })))
                }

                StringListMenu {
                    id: sortMenu
                    ctx: MainCtx
                    onSelected: (index, _) => {
                        const o = root._sortOptions[index]
                        root._model.sortCriteria = o[1]
                        root._model.sortOrder = o[2]
                    }
                }
            }
            Widgets.IconToolButton {
                text: VLCIcons.search
                description: qsTr("Search")
                font.pixelSize: VLCStyle.icon_normal
                Layout.preferredWidth: VLCStyle.dp(28, VLCStyle.scale)
                Layout.preferredHeight: VLCStyle.dp(28, VLCStyle.scale)
                checked: root._searchVisible
                visible: !root._isArray && root._model !== null
                onClicked: {
                    root._searchVisible = !root._searchVisible
                    if (root._searchVisible)
                        searchField.forceActiveFocus()
                    else
                        searchField.text = ""
                }
            }
        }

        T.TextField {
            id: searchField

            Layout.fillWidth: true
            visible: root._searchVisible
            implicitHeight: VLCStyle.dp(28, VLCStyle.scale)
            leftPadding: VLCStyle.margin_xsmall
            rightPadding: VLCStyle.margin_xsmall
            placeholderText: qsTr("Search")
            placeholderTextColor: root.dimColor
            color: root.titleColor
            font.pixelSize: VLCStyle.fontSize_normal
            verticalAlignment: TextInput.AlignVCenter
            background: Rectangle { radius: 4 * root.dp1; color: root.hoverColor }

            onTextChanged: {
                if (root._model && !root._isArray)
                    root._model.searchPattern = text
            }
            Keys.onEscapePressed: root._searchVisible = false
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.dividerColor
        }

        ListView {
            id: listView

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root._model

            // "Add" row of the Videos and Music roots (Figma "sidebar" frame)
            header: T.ItemDelegate {
                id: addRow

                width: ListView.view.width
                height: root._showAdd ? VLCStyle.dp(32, VLCStyle.scale) : 0
                visible: root._showAdd
                leftPadding: VLCStyle.margin_xxsmall

                Accessible.name: qsTr("Add a Folder to the Library")

                background: Rectangle {
                    radius: 4 * root.dp1
                    color: addRow.hovered ? root.hoverColor : "transparent"
                }
                contentItem: RowLayout {
                    spacing: VLCStyle.margin_xsmall
                    Text {
                        Layout.preferredWidth: VLCStyle.dp(24, VLCStyle.scale)
                        horizontalAlignment: Text.AlignHCenter
                        font.family: VLCIcons.fontFamily
                        font.pixelSize: VLCStyle.icon_normal
                        text: VLCIcons.add
                        color: root.textColor
                    }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Add")
                        font.pixelSize: VLCStyle.fontSize_normal
                        color: root.titleColor
                    }
                }
                onClicked: root._addFolder()
            }

            T.ScrollBar.vertical: Widgets.ScrollBarExt { }

            delegate: T.ItemDelegate {
                id: row

                required property int index
                // C++ models: role values of the row; array model: the entry
                readonly property var rowData: {
                    root._kind // re-evaluate when the level changes
                    return root._rowData(index)
                }
                readonly property bool isNav: root._rowIsNav(rowData)
                readonly property bool isCurrent: root._rowIsCurrent(rowData)
                // folders always show the folder icon
                readonly property string artwork: isNav ? "" : root._rowArtwork(rowData)

                width: ListView.view.width
                height: VLCStyle.dp(32, VLCStyle.scale)
                leftPadding: VLCStyle.margin_xxsmall
                rightPadding: VLCStyle.margin_xxsmall

                Accessible.name: root._rowTitle(rowData)

                background: Rectangle {
                    radius: 4 * root.dp1
                    color: row.hovered ? root.hoverColor : "transparent"
                }

                contentItem: RowLayout {
                    spacing: VLCStyle.margin_xsmall

                    Item {
                        Layout.preferredWidth: VLCStyle.dp(24, VLCStyle.scale)
                        Layout.preferredHeight: VLCStyle.dp(24, VLCStyle.scale)

                        Image {
                            id: thumb
                            anchors.fill: parent
                            source: row.artwork
                            sourceSize: Qt.size(width * 2, height * 2)
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                            asynchronous: true
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !thumb.visible
                            font.family: VLCIcons.fontFamily
                            font.pixelSize: VLCStyle.icon_normal
                Layout.preferredWidth: VLCStyle.dp(28, VLCStyle.scale)
                Layout.preferredHeight: VLCStyle.dp(28, VLCStyle.scale)
                            text: row.isCurrent ? VLCIcons.play : root._rowGlyph(row.rowData)
                            color: row.isCurrent ? root.accentColor : root.textColor
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root._rowTitle(row.rowData)
                        elide: Text.ElideMiddle
                        font.pixelSize: VLCStyle.fontSize_normal
                        color: row.isCurrent ? root.accentColor
                             : ((row.rowData.progress ?? 0) >= 0.95 ? root.dimColor : root.titleColor)
                    }

                    // add to the play queue
                    Widgets.IconToolButton {
                        visible: row.hovered && !row.isNav
                        text: VLCIcons.add
                        description: qsTr("Add to the Play Queue")
                        font.pixelSize: VLCStyle.icon_normal
                Layout.preferredWidth: VLCStyle.dp(28, VLCStyle.scale)
                Layout.preferredHeight: VLCStyle.dp(28, VLCStyle.scale)
                        onClicked: root._play(row.index, row.rowData, true)
                    }
                }

                onClicked: listView.currentIndex = index
                onDoubleClicked: {
                    if (isNav)
                        root._open(index, rowData)
                    else
                        root._play(index, rowData, false)
                }

                // drag an item onto the play queue
                DragHandler {
                    id: rowDrag
                    target: null
                    enabled: !row.isNav && !root._isArray
                    onActiveChanged: {
                        if (active) {
                            dragItem.indexes = [root._model.index(row.index, 0)]
                            dragItem.Drag.active = true
                        } else {
                            dragItem.Drag.drop()
                        }
                    }
                }
            }

            // a ListView child would go into the scrolling content; parent it
            // to the view itself so that it stays centered
            Text {
                parent: listView
                anchors.centerIn: parent
                visible: listView.count === 0 && root._kind !== "home"
                text: root._kind === "browse" && browseModel.loading ? qsTr("Loading…") : qsTr("Nothing here")
                color: root.dimColor
                font.pixelSize: VLCStyle.fontSize_normal
            }
        }

        // Home: a header per section (opens the whole list) and its first
        // items, over the (empty) list
        Flickable {
            id: homeView

            parent: listView
            anchors.fill: parent
            z: 1
            visible: root._kind === "home"
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: homeColumn.implicitHeight

            T.ScrollBar.vertical: Widgets.ScrollBarExt { }

            Column {
                id: homeColumn

                width: homeView.width

                Repeater {
                    model: root._homeSections

                    delegate: Column {
                        id: section

                        required property var modelData

                        width: homeColumn.width
                        visible: modelData.model.count > 0

                        T.ItemDelegate {
                            id: sectionHeader

                            width: section.width
                            height: VLCStyle.dp(36, VLCStyle.scale)
                            leftPadding: VLCStyle.margin_xxsmall
                            rightPadding: VLCStyle.margin_xxsmall

                            Accessible.name: section.modelData.title

                            background: Rectangle {
                                radius: 4 * root.dp1
                                color: sectionHeader.hovered ? root.hoverColor : "transparent"
                            }
                            contentItem: RowLayout {
                                Text {
                                    Layout.fillWidth: true
                                    text: section.modelData.title
                                    elide: Text.ElideRight
                                    font.pixelSize: VLCStyle.fontSize_large
                                    color: root.titleColor
                                }
                                Text {
                                    text: "\u203A"
                                    font.pixelSize: VLCStyle.fontSize_xlarge
                                    color: root.textColor
                                }
                            }
                            onClicked: root._push({ kind: section.modelData.kind, title: section.modelData.title })
                        }

                        Repeater {
                            model: section.modelData.model

                            delegate: T.ItemDelegate {
                                id: homeRow

                                required property var model

                                width: section.width
                                height: VLCStyle.dp(32, VLCStyle.scale)
                                leftPadding: VLCStyle.margin_xxsmall
                                rightPadding: VLCStyle.margin_xxsmall

                                Accessible.name: model.title ?? ""

                                background: Rectangle {
                                    radius: 4 * root.dp1
                                    color: homeRow.hovered ? root.hoverColor : "transparent"
                                }
                                contentItem: RowLayout {
                                    spacing: VLCStyle.margin_xsmall
                                    Item {
                                        Layout.preferredWidth: VLCStyle.dp(24, VLCStyle.scale)
                                        Layout.preferredHeight: VLCStyle.dp(24, VLCStyle.scale)
                                        Image {
                                            id: homeThumb
                                            anchors.fill: parent
                                            source: homeRow.model.thumbnail || homeRow.model.cover || ""
                                            sourceSize: Qt.size(width * 2, height * 2)
                                            fillMode: Image.PreserveAspectCrop
                                            visible: status === Image.Ready
                                            asynchronous: true
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            visible: !homeThumb.visible
                                            font.family: VLCIcons.fontFamily
                                            font.pixelSize: VLCStyle.icon_normal
                                            text: section.modelData.kind === "listenAgain" ? VLCIcons.topbar_music : VLCIcons.topbar_video
                                            color: root.textColor
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: homeRow.model.title ?? ""
                                        elide: Text.ElideMiddle
                                        font.pixelSize: VLCStyle.fontSize_normal
                                        color: root.titleColor
                                    }
                                }
                                onDoubleClicked: MainCtx.mediaLibrary.addAndPlay(homeRow.model.id)
                            }
                        }
                    }
                }
            }

            Text {
                parent: homeView
                anchors.centerIn: parent
                visible: homeColumn.implicitHeight === 0
                text: qsTr("Nothing here")
                color: root.dimColor
                font.pixelSize: VLCStyle.fontSize_normal
            }
        }
    }

    Widgets.DragItem {
        id: dragItem

        view: listView
        getTextureProvider: null
        defaultText: qsTr("Unknown")

        coverProvider: (index, data) => ({
            artwork: data.thumbnail || data.small_cover || data.cover || data.artwork || "",
            fallback: VLCStyle.noArtVideoCover
        })

        onRequestData: (indexes, resolve, reject) => {
            resolve(indexes.map((i) => root._model.getDataAt(i.row)))
        }

        onRequestInputItems: (indexes, data, resolve, reject) => {
            if (root._kind === "browse")
                browseModel.getItemsForIndexes(indexes, resolve)
            else
                MainCtx.mediaLibrary.mlInputItem(data.map((o) => o.id), resolve)
        }
    }
}
