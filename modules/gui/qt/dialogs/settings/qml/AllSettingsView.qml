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
import VLC.Style
import VLC.Dialogs
import VLC.Widgets as Widgets

// "All Settings": every VLC option, in the style of the settings window,
// shown inside it (SettingsWindow.qml toggles between the two). The sidebar
// holds VLC's categories (opened with the arrow) and their pages, as the
// classic preferences tree, but without the modules: a page lists its
// modules in a "Choose a module" drop-down, and shows the settings of the
// chosen one. Every change is saved immediately.
Item {
    id: root

    // room kept free at the right of the header (the window's toggle button)
    property real headerRightInset: 0

    // Escape with an empty search field
    signal closeRequested()

    readonly property var tree: VLCConfig.settingsTree()
    property int currentSubcat: tree.length > 0 ? tree[0].subcat : -1
    // categories opened in the sidebar, by id
    property var expanded: ({})

    readonly property var page: (currentSubcat >= 0) ? VLCConfig.settingsPage(currentSubcat) : null

    readonly property string searchText: searchField.text.trim()
    readonly property bool searching: searchText.length >= 2
    readonly property int searchLimit: 150
    property var searchResults: []

    readonly property var catIcons: ({
        interface: VLCIcons.interface,
        audio: VLCIcons.visualization,
        video: VLCIcons.video,
        input: VLCIcons.playback_settings,
        sout: VLCIcons.stream,
        playlist: VLCIcons.playlist,
        advanced: VLCIcons.settings
    })

    function showPage(subcat) {
        searchField.text = ""
        currentSubcat = subcat
    }

    function setExpanded(cat, on) {
        const e = Object.assign({}, expanded)
        e[cat] = on
        expanded = e
    }

    function openShortcuts() {
        DialogsProvider.keyboardShortcutsDialog()
    }

    onCurrentSubcatChanged: contentFlickable.contentY = 0
    onSearchTextChanged: searchTimer.restart()

    Component.onCompleted: {
        if (tree.length > 0)
            setExpanded(tree[0].cat, true)
    }

    // searching every module takes a moment: wait for a pause in typing
    Timer {
        id: searchTimer
        interval: 250
        onTriggered: {
            root.searchResults = root.searching ? VLCConfig.searchSettings(root.searchText, root.searchLimit) : []
            contentFlickable.contentY = 0
        }
    }

    Shortcut {
        enabled: root.visible
        sequence: StandardKey.Find
        onActivated: searchField.forceActiveFocus()
    }

    Shortcut {
        enabled: root.visible
        sequence: StandardKey.Cancel
        onActivated: {
            if (searchField.text !== "")
                searchField.text = ""
            else
                root.closeRequested()
        }
    }

    Item {
        id: content

        anchors.fill: parent

        readonly property ColorContext colorContext: ColorContext {
            id: theme
            palette: VLCStyle.palette
            colorSet: ColorContext.View
        }

        readonly property ColorContext windowColorContext: ColorContext {
            id: windowTheme
            palette: VLCStyle.palette
            colorSet: ColorContext.Window
        }

        readonly property ColorContext tabColorContext: ColorContext {
            id: selectedTheme
            palette: VLCStyle.palette
            colorSet: ColorContext.TabButton
            focused: true
        }

        // Header: search field and the title of the page
        Rectangle {
            id: header

            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: VLCStyle.dp(50, VLCStyle.scale)
            color: windowTheme.bg.secondary

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: VLCStyle.margin_xsmall
                anchors.rightMargin: VLCStyle.dp(14, VLCStyle.scale) + root.headerRightInset
                spacing: 0

                T.TextField {
                    id: searchField

                    // as wide as the sidebar's panel, so the title below
                    // starts where the page does
                    Layout.preferredWidth: sidebar.width - 2 * VLCStyle.margin_xsmall
                    Layout.preferredHeight: VLCStyle.dp(34, VLCStyle.scale)

                    leftPadding: VLCStyle.dp(42, VLCStyle.scale)
                    rightPadding: VLCStyle.margin_xsmall
                    verticalAlignment: TextInput.AlignVCenter

                    placeholderText: qsTr("Search")
                    placeholderTextColor: Qt.alpha(theme.fg.secondary, 0.5)
                    color: theme.fg.primary
                    selectionColor: theme.accent
                    font.pixelSize: VLCStyle.fontSize_large

                    Accessible.name: qsTr("Search settings")

                    background: Rectangle {
                        radius: VLCStyle.dp(6, VLCStyle.scale)
                        color: windowTheme.bg.primary
                        border.width: searchField.activeFocus ? VLCStyle.border : 0
                        border.color: theme.accent

                        T.Label {
                            anchors.left: parent.left
                            anchors.leftMargin: VLCStyle.margin_xsmall
                            anchors.verticalCenter: parent.verticalCenter
                            text: VLCIcons.search
                            font.family: VLCIcons.fontFamily
                            font.pixelSize: VLCStyle.icon_normal
                            color: theme.fg.secondary
                        }

                        // Templates do not draw the placeholder text
                        T.Label {
                            anchors.left: parent.left
                            anchors.leftMargin: searchField.leftPadding
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchField.text === "" && !searchField.activeFocus
                            text: searchField.placeholderText
                            color: searchField.placeholderTextColor
                            font: searchField.font
                        }
                    }
                }

                T.Label {
                    Layout.fillWidth: true
                    Layout.leftMargin: VLCStyle.margin_xsmall + VLCStyle.margin_large
                    text: root.searching ? qsTr("Search results") : (root.page ? root.page.path : "")
                    color: theme.fg.secondary
                    font.pixelSize: VLCStyle.fontSize_xlarge
                    elide: Text.ElideRight
                }
            }
        }

        // Categories, each with its pages under an arrow
        Rectangle {
            id: sidebar

            anchors { top: header.bottom; left: parent.left; bottom: parent.bottom }
            width: VLCStyle.dp(236, VLCStyle.scale)
            color: theme.bg.primary

            Rectangle {
                anchors.fill: parent
                anchors.margins: VLCStyle.margin_xsmall
                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: windowTheme.bg.primary

                Flickable {
                    anchors.fill: parent
                    anchors.margins: VLCStyle.dp(6, VLCStyle.scale)
                    contentHeight: categoryColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    T.ScrollBar.vertical: Widgets.ScrollBarExt { id: sidebarScrollBar }

                    ColumnLayout {
                        id: categoryColumn

                        // keep the list clear of the scroll bar
                        width: parent.width - (sidebarScrollBar._shown
                                               ? VLCStyle.scrollBarInteractingSize + VLCStyle.margin_xsmall : 0)
                        spacing: VLCStyle.dp(2, VLCStyle.scale)

                        Repeater {
                            model: root.tree

                            // an opened category: the tab and its pages share one outline
                            Rectangle {
                                id: category

                                required property var modelData

                                readonly property bool isOpen: !!root.expanded[modelData.cat]
                                // the pages panel sits right inside the outline
                                readonly property real pad: isOpen ? border.width : 0

                                Layout.fillWidth: true
                                implicitHeight: categoryItems.implicitHeight + 2 * pad
                                radius: VLCStyle.dp(6, VLCStyle.scale)
                                color: "transparent"
                                border.width: isOpen ? 2 * VLCStyle.border : 0
                                border.color: windowTheme.border

                                ColumnLayout {
                                id: categoryItems

                                anchors { left: parent.left; right: parent.right; top: parent.top }
                                anchors.margins: category.pad
                                spacing: 0

                                SidebarButton {
                                    id: categoryButton

                                    Layout.fillWidth: true
                                    implicitHeight: VLCStyle.dp(40, VLCStyle.scale)

                                    text: category.modelData.name
                                    selected: !root.searching && root.currentSubcat === category.modelData.subcat

                                    onClicked: {
                                        root.showPage(category.modelData.subcat)
                                        root.setExpanded(category.modelData.cat, true)
                                    }

                                    contentItem: RowLayout {
                                        spacing: VLCStyle.margin_xsmall

                                        T.Label {
                                            Layout.preferredWidth: VLCStyle.dp(32, VLCStyle.scale)
                                            Layout.leftMargin: VLCStyle.dp(4, VLCStyle.scale)
                                            horizontalAlignment: Text.AlignHCenter
                                            text: root.catIcons[category.modelData.icon] ?? VLCIcons.settings
                                            font.family: VLCIcons.fontFamily
                                            font.pixelSize: VLCStyle.icon_normal
                                            color: categoryButton.selected ? theme.accent : theme.fg.secondary
                                        }

                                        T.Label {
                                            Layout.fillWidth: true
                                            text: categoryButton.text
                                            elide: Text.ElideRight
                                            font.pixelSize: VLCStyle.fontSize_large
                                            color: categoryButton.selected ? theme.fg.primary : theme.fg.secondary
                                        }

                                        // opens and closes the category's pages
                                        T.AbstractButton {
                                            id: arrow

                                            Layout.preferredWidth: VLCStyle.dp(32, VLCStyle.scale)
                                            Layout.fillHeight: true
                                            visible: category.modelData.subcats.length > 0

                                            onClicked: root.setExpanded(category.modelData.cat, !category.isOpen)

                                            Accessible.role: Accessible.Button
                                            Accessible.name: category.isOpen ? qsTr("Collapse %1").arg(categoryButton.text)
                                                                           : qsTr("Expand %1").arg(categoryButton.text)

                                            background: Rectangle {
                                                radius: VLCStyle.dp(2, VLCStyle.scale)
                                                color: arrow.hovered ? Qt.alpha(theme.fg.primary, 0.08) : "transparent"
                                                border.width: arrow.visualFocus ? VLCStyle.focus_border : 0
                                                border.color: theme.visualFocus
                                            }
                                            contentItem: T.Label {
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                text: category.isOpen ? VLCIcons.ic_fluent_chevron_down_24 : VLCIcons.ic_fluent_chevron_right_24
                                                font.family: VLCIcons.fontFamily
                                                font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                                                color: theme.fg.secondary
                                            }
                                        }
                                    }
                                }

                                // the category's pages, on a darker rounded panel
                                Rectangle {
                                    Layout.fillWidth: true
                                    visible: category.isOpen && category.modelData.subcats.length > 0
                                    implicitHeight: pageList.implicitHeight + 2 * pageList.anchors.margins
                                    // sharp under the tab, rounded with the outline below
                                    topLeftRadius: 0
                                    topRightRadius: 0
                                    bottomLeftRadius: category.radius - category.border.width
                                    bottomRightRadius: category.radius - category.border.width
                                    color: Qt.darker(windowTheme.bg.primary, 1.25)

                                    ColumnLayout {
                                        id: pageList

                                        anchors { left: parent.left; right: parent.right; top: parent.top }
                                        anchors.margins: VLCStyle.dp(4, VLCStyle.scale)
                                        spacing: VLCStyle.dp(2, VLCStyle.scale)

                                Repeater {
                                    model: category.isOpen ? category.modelData.subcats : []

                                    SidebarButton {
                                        id: pageButton

                                        required property var modelData

                                        Layout.fillWidth: true
                                        implicitHeight: VLCStyle.dp(34, VLCStyle.scale)

                                        text: modelData.name
                                        selected: !root.searching && root.currentSubcat === modelData.subcat

                                        onClicked: root.showPage(modelData.subcat)

                                        contentItem: T.Label {
                                            leftPadding: VLCStyle.dp(42, VLCStyle.scale)
                                            rightPadding: VLCStyle.margin_xsmall
                                            verticalAlignment: Text.AlignVCenter
                                            text: pageButton.text
                                            elide: Text.ElideRight
                                            font.pixelSize: VLCStyle.fontSize_normal
                                            color: pageButton.selected ? theme.fg.primary : theme.fg.secondary
                                        }
                                    }
                                }
                                    }
                                }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Options
        Flickable {
            id: contentFlickable

            anchors { top: header.bottom; left: sidebar.right; right: parent.right; bottom: parent.bottom }

            contentHeight: (root.searching ? searchColumn.implicitHeight : pageColumn.implicitHeight)
                           + VLCStyle.dp(100, VLCStyle.scale)
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            T.ScrollBar.vertical: Widgets.ScrollBarExt { }

            // The selected page
            ColumnLayout {
                id: pageColumn

                x: VLCStyle.margin_large
                y: VLCStyle.dp(20, VLCStyle.scale)
                width: contentFlickable.width - 2 * VLCStyle.margin_large
                spacing: VLCStyle.dp(20, VLCStyle.scale)
                visible: !root.searching && root.page !== null

                T.Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.page ? root.page.help : ""
                    wrapMode: Text.Wrap
                    color: Qt.alpha(theme.fg.secondary, 0.7)
                    font.pixelSize: VLCStyle.fontSize_normal
                }

                Repeater {
                    model: root.page ? root.page.sections : []

                    OptionSection {
                        required property var modelData

                        Layout.fillWidth: true
                        title: modelData.title
                        options: modelData.options
                    }
                }

                // The page's modules (the classic tree's module nodes): the
                // drop-down only picks which module's settings are shown
                ColumnLayout {
                    id: modulesColumn

                    property string shownModule: ""

                    Layout.fillWidth: true
                    visible: root.page !== null && root.page.modules.length > 0
                    spacing: VLCStyle.margin_xsmall

                    Connections {
                        target: root
                        function onCurrentSubcatChanged() { modulesColumn.shownModule = "" }
                    }

                    SettingRow {
                        Layout.fillWidth: true
                        row: ({
                            label: "",
                            kind: "picker",
                            value: modulesColumn.shownModule,
                            choices: [{ value: "", text: qsTr("Choose a module") }].concat(
                                         root.page ? root.page.modules.map((m) => ({ value: m.name, text: m.text })) : [])
                        })
                        onPicked: (value) => modulesColumn.shownModule = value
                    }

                    ModuleCard {
                        Layout.fillWidth: true
                        visible: modulesColumn.shownModule !== ""
                        module: modulesColumn.shownModule
                    }
                }

                T.Label {
                    visible: root.page !== null && root.page.sections.length === 0 && root.page.modules.length === 0
                    text: qsTr("This page has no settings.")
                    color: Qt.alpha(theme.fg.secondary, 0.7)
                    font.pixelSize: VLCStyle.fontSize_large
                }
            }

            // Search results, grouped by where the options live
            ColumnLayout {
                id: searchColumn

                x: VLCStyle.margin_large
                y: VLCStyle.dp(20, VLCStyle.scale)
                width: contentFlickable.width - 2 * VLCStyle.margin_large
                spacing: 0
                visible: root.searching

                Repeater {
                    model: root.searching ? root.searchResults : []

                    ColumnLayout {
                        id: result

                        required property var modelData
                        required property int index

                        readonly property bool firstOfPlace: index === 0
                                                             || root.searchResults[index - 1].place !== modelData.place

                        Layout.fillWidth: true
                        spacing: 0

                        T.Label {
                            Layout.fillWidth: true
                            visible: result.firstOfPlace
                            topPadding: result.index > 0 ? VLCStyle.dp(20, VLCStyle.scale) : 0
                            bottomPadding: VLCStyle.margin_xsmall
                            text: result.modelData.place
                            elide: Text.ElideRight
                            color: theme.accent
                            font.pixelSize: VLCStyle.fontSize_large
                            font.weight: Font.DemiBold
                        }

                        SettingRow {
                            Layout.fillWidth: true
                            row: ({ label: VLCConfig.text(result.modelData.option), option: result.modelData.option })
                        }
                    }
                }

                T.Label {
                    Layout.topMargin: VLCStyle.margin_normal
                    visible: root.searchResults.length === 0 || root.searchResults.length >= root.searchLimit
                    text: root.searchResults.length === 0 ? qsTr("No settings found.")
                                                          : qsTr("Showing the first %1 results.").arg(root.searchLimit)
                    color: Qt.alpha(theme.fg.secondary, 0.7)
                    font.pixelSize: VLCStyle.fontSize_large
                }
            }
        }
    }

    component SidebarButton: T.AbstractButton {
        id: sidebarButton

        property bool selected: false

        Accessible.role: Accessible.PageTab
        Accessible.name: text

        background: Rectangle {
            radius: VLCStyle.dp(2, VLCStyle.scale)
            color: (sidebarButton.selected || sidebarButton.hovered) ? selectedTheme.bg.primary : "transparent"
            border.width: sidebarButton.visualFocus ? VLCStyle.focus_border : 0
            border.color: theme.visualFocus
        }
    }

    component SectionTitle: T.Label {
        Layout.fillWidth: true
        topPadding: VLCStyle.dp(10, VLCStyle.scale)
        bottomPadding: VLCStyle.dp(10, VLCStyle.scale)
        color: theme.fg.primary
        opacity: 0.85
        font.pixelSize: VLCStyle.fontSize_xlarge
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    // A titled group of options
    component OptionSection: ColumnLayout {
        id: section

        property string title
        property var options: []

        spacing: 0

        SectionTitle {
            visible: section.title !== ""
            text: section.title
        }

        Repeater {
            model: section.options

            SettingRow {
                required property string modelData

                Layout.fillWidth: true
                row: (modelData === "#hotkeys")
                     ? ({ label: qsTr("Keyboard shortcuts"), kind: "action", action: "openShortcuts", buttonText: qsTr("Edit") })
                     : ({ label: VLCConfig.text(modelData), option: modelData })
                onActionRequested: (action) => root[action]()
            }
        }
    }

    // One module's settings, on a card
    component ModuleCard: Rectangle {
        id: card

        property string module

        readonly property var settings: module !== "" ? VLCConfig.moduleSettings(module) : ({})
        readonly property var sections: settings.sections ?? []

        visible: module !== ""
        implicitHeight: visible ? cardColumn.implicitHeight + 2 * VLCStyle.margin_small : 0
        radius: VLCStyle.dp(6, VLCStyle.scale)
        color: windowTheme.bg.primary

        ColumnLayout {
            id: cardColumn

            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.margins: VLCStyle.margin_small
            anchors.leftMargin: VLCStyle.margin_normal
            anchors.rightMargin: VLCStyle.margin_normal
            spacing: 0

            T.Label {
                Layout.fillWidth: true
                text: card.settings.title ?? ""
                elide: Text.ElideRight
                color: theme.fg.primary
                font.pixelSize: VLCStyle.fontSize_large
                font.weight: Font.DemiBold
            }

            T.Label {
                Layout.fillWidth: true
                Layout.topMargin: VLCStyle.dp(2, VLCStyle.scale)
                visible: text !== ""
                text: card.settings.help ?? ""
                textFormat: card.settings.helpIsHtml ? Text.RichText : Text.PlainText
                onLinkActivated: (link) => Qt.openUrlExternally(link)
                wrapMode: Text.Wrap
                color: Qt.alpha(theme.fg.secondary, 0.7)
                font.pixelSize: VLCStyle.fontSize_normal
            }

            T.Label {
                Layout.topMargin: VLCStyle.margin_xsmall
                visible: card.sections.length === 0
                text: qsTr("This module has no settings.")
                color: Qt.alpha(theme.fg.secondary, 0.7)
                font.pixelSize: VLCStyle.fontSize_normal
            }

            Repeater {
                model: card.sections

                OptionSection {
                    required property var modelData

                    Layout.fillWidth: true
                    title: modelData.title
                    options: modelData.options
                }
            }
        }
    }
}
