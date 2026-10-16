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
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets

// "Videos" of the VLC Redesign (video 10:48-10:56, Figma "sidebar" frame):
// the folders added to the library, then their real folder tree with only
// subfolders and video files ("Videos › Shows › The Wand › S01"). Each
// folder is a History page, so Back goes up again.
Widgets.PageExt {
    id: root

    // set by History.push(["video", "folders"], { tree, crumbs })
    property var tree: undefined
    // names of the folders opened so far, below "Videos"
    property var crumbs: []

    // with a single library folder, Videos opens directly on its content
    readonly property var _singleFolderTree: (libraryFolders.count === 1)
                                             ? VLCConfig.browseNode(String(libraryFolders.data(libraryFolders.index(0, 0), Qt.UserRole + 3)))
                                             : undefined
    readonly property var _tree: (tree !== undefined && tree !== null) ? tree : _singleFolderTree

    // the list of library folders (more than one folder in the library)
    readonly property bool _atRoot: _tree === undefined || _tree === null
    // first page of Videos ("Add" is shown there)
    readonly property bool _topLevel: crumbs.length === 0

    title: [qsTr("Videos")].concat(crumbs).join("  ›  ")

    isSearchable: !_atRoot
    hasGridListMode: true

    sortModel: _atRoot ? [] : [
        { text: qsTr("Title"), criteria: "name" },
        { text: qsTr("Modification date"), criteria: "fileModified" }
    ]

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    readonly property var _model: _atRoot ? libraryFolders : videoFilter
    readonly property int _count: _atRoot ? libraryFolders.count : videoFilter.count

    function _open(name, tree) {
        History.push(["video", "folders"], { "tree": tree, "crumbs": root.crumbs.concat([name]) })
    }

    function _lastSegment(url) {
        const parts = decodeURIComponent(String(url)).split("/").filter((p) => p !== "")
        return parts.length > 0 ? parts[parts.length - 1] : String(url)
    }

    function _addFolder() {
        const folder = VLCConfig.browseFolder(qsTr("Add a Folder to the Library"))
        if (folder !== "")
            MainCtx.mediaLibrary.addFolder(folder)
    }

    MLFolderModel {
        id: libraryFolders
        ctx: MainCtx

        // the model has no count property
        property int count: 0
        function _updateCount() { count = rowCount() }
        onRowsInserted: _updateCount()
        onRowsRemoved: _updateCount()
        onModelReset: _updateCount()
        Component.onCompleted: _updateCount()
    }

    NetworkMediaModel {
        id: folderModel

        ctx: MainCtx
        tree: root._atRoot ? undefined : root._tree
        // A-Z until a sort order is chosen (VLC's default order is descending)
        sortCriteria: root.sort.criteria !== "" ? root.sort.criteria : "name"
        sortOrder: root.sort.criteria !== "" ? root.sort.order : Qt.AscendingOrder
        searchPattern: root.search.pattern
    }

    VideoFolderFilter {
        id: videoFilter
        sourceModel: root._atRoot ? null : folderModel
    }

    // entry given to the right-click menu; -1 is the folder that is shown
    function _entryData(index) {
        if (index < 0) {
            if (root._atRoot)
                return null
            return {
                "name": root.crumbs.length > 0 ? root.crumbs[root.crumbs.length - 1] : folderModel.name,
                "mrl": String(folderModel.url),
                "isFolder": true,
                // Videos opened directly on the only library folder
                "isLibraryRoot": root._topLevel && root.tree === undefined
            }
        }
        if (root._atRoot) {
            const url = String(libraryFolders.data(libraryFolders.index(index, 0), Qt.UserRole + 3))
            return { "name": root._lastSegment(url), "mrl": url, "isFolder": true, "isLibraryRoot": true }
        }
        const d = videoFilter.getDataAt(index)
        return {
            "name": d.name,
            "mrl": String(d.mrl),
            "isFolder": d.type === NetworkMediaModel.TYPE_DIRECTORY || d.type === NetworkMediaModel.TYPE_NODE,
            "isLibraryRoot": false
        }
    }

    FolderContentMenu {
        id: contextMenu

        dataAt: root._entryData
        playAt: (i) => folderModel.addAndPlay(videoFilter.sourceRow(i))
        enqueueAt: (i) => folderModel.addToPlaylist(videoFilter.sourceRow(i))
        libraryFolders: libraryFolders
    }

    // right-click on an entry or on the empty part of the page
    function _contextMenu(point) {
        const view = MainCtx.gridView ? gridView : listView
        const p = view.mapFromItem(null, point.scenePosition)
        const inView = p.x >= 0 && p.y >= 0 && p.x < view.width && p.y < view.height
        const index = inView ? view.indexAt(p.x + view.contentX, p.y + view.contentY) : -1
        contextMenu.popup([index], view.mapToGlobal(p.x, p.y))
    }

    Item {
        id: content

        anchors.fill: parent
        focus: true

        function setCurrentItemFocus(reason) {
            (MainCtx.gridView ? gridView : listView).forceActiveFocus(reason)
        }

        // the entries only take the left button
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: (point) => root._contextMenu(point)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: VLCStyle.dynamicAppMargins(content.width) + VLCStyle.layout_left_margin
            anchors.rightMargin: VLCStyle.dynamicAppMargins(content.width) + VLCStyle.layout_right_margin
            spacing: VLCStyle.margin_xsmall

            Text {
                Layout.fillWidth: true
                text: root._count === 1 ? qsTr("1 item") : qsTr("%1 items").arg(root._count)
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_normal
            }

            // "Add" (add a folder to the library), first entry of the root
            T.ItemDelegate {
                id: addRow

                Layout.fillWidth: true
                Layout.preferredHeight: VLCStyle.dp(40, VLCStyle.scale)
                visible: root._topLevel
                leftPadding: VLCStyle.margin_xsmall

                Accessible.name: qsTr("Add a Folder to the Library")

                background: Rectangle {
                    radius: VLCStyle.dp(4, VLCStyle.scale)
                    color: addRow.hovered ? theme.bg.secondary : "transparent"
                }
                contentItem: RowLayout {
                    spacing: VLCStyle.margin_small
                    Widgets.IconLabel {
                        text: VLCIcons.add
                        color: theme.fg.secondary
                        font.pixelSize: VLCStyle.icon_normal
                    }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Add")
                        color: theme.fg.primary
                        font.pixelSize: VLCStyle.fontSize_normal
                    }
                }
                onClicked: root._addFolder()
            }

            GridView {
                id: gridView

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: MainCtx.gridView
                clip: true
                focus: MainCtx.gridView
                boundsBehavior: Flickable.StopAtBounds
                model: root._model

                readonly property int _columns: Math.max(1, Math.floor(width / (VLCStyle.gridCover_video_width + VLCStyle.margin_normal)))
                cellWidth: Math.floor(width / _columns)
                cellHeight: VLCStyle.gridCover_video_height + VLCStyle.dp(56, VLCStyle.scale)

                T.ScrollBar.vertical: Widgets.ScrollBarExt { }

                delegate: Entry {
                    width: GridView.view.cellWidth
                    height: GridView.view.cellHeight
                    grid: true
                }
            }

            ListView {
                id: listView

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !MainCtx.gridView
                clip: true
                focus: !MainCtx.gridView
                boundsBehavior: Flickable.StopAtBounds
                model: root._model

                T.ScrollBar.vertical: Widgets.ScrollBarExt { }

                delegate: Entry {
                    width: ListView.view.width
                    height: VLCStyle.dp(48, VLCStyle.scale)
                    grid: false
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root._count === 0

                Text {
                    anchors.centerIn: parent
                    text: root._atRoot ? qsTr("No folders in the library yet")
                                       : (folderModel.loading ? qsTr("Loading…") : qsTr("No videos in this folder"))
                    color: theme.fg.secondary
                    font.pixelSize: VLCStyle.fontSize_large
                }
            }
        }
    }

    // a folder or a video, as a card (grid) or a row (list)
    component Entry: T.ItemDelegate {
        id: entry

        required property var model
        required property int index
        property bool grid: false

        readonly property bool isFolder: root._atRoot
                                         || model.type === NetworkMediaModel.TYPE_DIRECTORY
                                         || model.type === NetworkMediaModel.TYPE_NODE
        readonly property string name: root._atRoot ? root._lastSegment(model.display_url ?? model.url)
                                                    : (model.name ?? "")
        readonly property string artwork: isFolder ? "" : (model.artwork ?? "")
        readonly property real progress: isFolder ? 0 : (model.progress ?? 0)

        padding: VLCStyle.margin_xxsmall

        Accessible.name: name

        function open() {
            if (root._atRoot)
                root._open(name, VLCConfig.browseNode(String(model.url)))
            else if (isFolder)
                root._open(name, model.tree)
            else
                folderModel.addAndPlay(videoFilter.sourceRow(index))
        }

        background: Rectangle {
            radius: VLCStyle.dp(4, VLCStyle.scale)
            color: entry.hovered ? theme.bg.secondary : "transparent"
        }

        contentItem: GridLayout {
            columns: entry.grid ? 1 : 3
            columnSpacing: VLCStyle.margin_small
            rowSpacing: VLCStyle.margin_xxsmall

            Rectangle {
                Layout.preferredWidth: entry.grid ? VLCStyle.gridCover_video_width : VLCStyle.dp(64, VLCStyle.scale)
                Layout.preferredHeight: entry.grid ? VLCStyle.gridCover_video_height : VLCStyle.dp(36, VLCStyle.scale)
                Layout.alignment: Qt.AlignHCenter
                radius: VLCStyle.dp(4, VLCStyle.scale)
                color: theme.bg.secondary
                clip: true

                Image {
                    id: cover
                    anchors.fill: parent
                    source: entry.artwork
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
                Widgets.IconLabel {
                    anchors.centerIn: parent
                    visible: !cover.visible
                    text: entry.isFolder ? VLCIcons.topbar_network : VLCIcons.topbar_video
                    color: theme.fg.secondary
                    font.pixelSize: entry.grid ? VLCStyle.icon_large : VLCStyle.icon_normal
                }
                // watched part
                Rectangle {
                    anchors { left: parent.left; bottom: parent.bottom }
                    height: VLCStyle.dp(3, VLCStyle.scale)
                    width: parent.width * Math.max(0, Math.min(1, entry.progress))
                    visible: entry.progress > 0
                    color: theme.accent
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: entry.grid ? VLCStyle.gridCover_video_width : -1
                Layout.alignment: entry.grid ? Qt.AlignHCenter : Qt.AlignVCenter
                text: entry.name
                elide: Text.ElideMiddle
                maximumLineCount: 1
                color: entry.progress >= 0.95 ? theme.fg.secondary : theme.fg.primary
                font.pixelSize: VLCStyle.fontSize_normal
            }

            // add a video to the play queue
            Widgets.IconToolButton {
                visible: !entry.grid && !entry.isFolder && entry.hovered
                text: VLCIcons.add
                description: qsTr("Add to the Play Queue")
                onClicked: folderModel.addToPlaylist(videoFilter.sourceRow(entry.index))
            }
        }

        // folders open with one click, videos play on double-click
        onClicked: if (isFolder) open()
        onDoubleClicked: if (!isFolder) open()
    }
}
