/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
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


import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.PlayerControls

FocusScope {
    id: playerControlLayout

    // Properties

    property real spacing: VLCStyle.margin_normal // spacing between controls

    property real layoutSpacing: VLCStyle.margin_xxlarge // spacing between layouts (left, center, and right)

    property int identifier: -1

    // the part (0 left, 1 center, 2 right) with the seek bar
    // (ControlListModel.SEEK_BAR, VLC Redesign), -1 without: that part takes
    // the free width of the bar
    readonly property int seekPart: {
        if (!model?.left || !model?.center || !model?.right)
            return -1
        void model.left.count
        void model.center.count
        void model.right.count
        const parts = [model.left, model.center, model.right]
        return parts.findIndex((part) => part.getControls().includes(ControlListModel.SEEK_BAR))
    }
    readonly property bool hasCenterControls: (model?.center?.count ?? 0) > 0

    // the seek bar can be dropped in this bar (Customize Player)
    readonly property bool acceptsSeekBar: identifier === PlayerControlbarModel.Videoplayer ||
                                           identifier === PlayerControlbarModel.Audioplayer

    // VLC Redesign "Customize Player": the bar is edited in place
    readonly property bool editing: MainCtx.playerCustomizing && !!model
    readonly property real editHeight: editRow.implicitHeight

    readonly property PlayerControlbarModel model: {
        if (!!MainCtx.controlbarProfileModel.currentModel)
            return MainCtx.controlbarProfileModel.currentModel.getModel(identifier)
        else
            return null
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // Signals

    signal requestLockUnlockAutoHide(bool lock)
    signal menuOpened(var menu)
    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    // Settings

    implicitWidth: editing ? editRow.implicitWidth
                           : loaderSeek.active ? loaderSeek.implicitWidth
                           : loaderLeftRight.active ? loaderLeftRight.implicitWidth
                                                    : (loaderLeft.implicitWidth + loaderCenter.implicitWidth + loaderRight.implicitWidth)

    implicitHeight: editing ? editRow.implicitHeight
                            : loaderSeek.active ? loaderSeek.implicitHeight
                            : loaderLeftRight.active ? loaderLeftRight.implicitHeight
                                                     : Math.max(loaderLeft.implicitHeight, loaderCenter.implicitHeight, loaderRight.implicitHeight)

    // Events

    Component.onCompleted: console.assert(identifier >= 0)

    // Children

    // as in the normal bar: the center part in the middle, the left and
    // right parts take the free width on each side; with the seek bar, its
    // part takes the free width
    Item {
        id: editRow

        readonly property real gap: VLCStyle.margin_xsmall
        readonly property int seekPart: playerControlLayout.seekPart
        readonly property var sections: [editLeft, editCenter, editRight]

        // width of the part with the seek bar
        readonly property real seekWidth: {
            if (seekPart < 0)
                return 0
            let fixed = 2 * gap
            for (let i = 0; i < 3; ++i) {
                if (i !== seekPart)
                    fixed += sections[i].implicitWidth
            }
            return Math.max(sections[seekPart].implicitWidth, width - fixed)
        }

        function partWidth(part) {
            return (seekPart === part) ? seekWidth : sections[part].implicitWidth
        }

        anchors.fill: parent
        visible: playerControlLayout.editing

        implicitWidth: editLeft.implicitWidth + editCenter.implicitWidth + editRight.implicitWidth + 2 * gap
        implicitHeight: Math.max(editLeft.implicitHeight, editCenter.implicitHeight, editRight.implicitHeight)

        LiveBarSection {
            id: editLeft
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: editRow.seekPart >= 0 ? editRow.partWidth(0) : (editCenter.x - editRow.gap)
            model: playerControlLayout.model?.left ?? null
            acceptsSeekBar: playerControlLayout.acceptsSeekBar
        }
        LiveBarSection {
            id: editCenter
            anchors { top: parent.top; bottom: parent.bottom }
            x: editRow.seekPart >= 0 ? editLeft.width + editRow.gap : (parent.width - width) / 2
            width: editRow.seekPart >= 0 ? editRow.partWidth(1) : implicitWidth
            model: playerControlLayout.model?.center ?? null
            acceptsSeekBar: playerControlLayout.acceptsSeekBar
        }
        LiveBarSection {
            id: editRight
            anchors { top: parent.top; bottom: parent.bottom }
            width: editRow.seekPart >= 0 ? editRow.partWidth(2) : (parent.width - x)
            x: editRow.seekPart >= 0 ? parent.width - width : editCenter.x + editCenter.width + editRow.gap
            alignRight: true
            model: playerControlLayout.model?.right ?? null
            acceptsSeekBar: playerControlLayout.acceptsSeekBar
        }
    }

    // with the seek bar (VLC Redesign): the three parts in a row, the one
    // with the seek bar takes the free width
    Loader {
        id: loaderSeek

        visible: !playerControlLayout.editing

        anchors.fill: parent

        active: playerControlLayout.seekPart >= 0

        focus: active

        sourceComponent: RowLayout {
            id: seekRow

            spacing: playerControlLayout.layoutSpacing

            focus: true

            component Part: ControlLayout {
                id: part

                required property int index
                required property var sourceList

                readonly property bool _seekPart: playerControlLayout.seekPart === index

                visible: count > 0
                Layout.fillWidth: _seekPart
                Layout.fillHeight: true

                model: ControlListFilter {
                    sourceModel: part.sourceList

                    player: Player
                    ctx: MainCtx
                }

                // the seek bar's part has no filler around its controls
                alignment: _seekPart ? Qt.AlignVCenter
                                     : (index === 2) ? (Qt.AlignVCenter | Qt.AlignRight)
                                                     : (Qt.AlignVCenter | Qt.AlignLeft)

                spacing: playerControlLayout.spacing

                altFocusAction: () => Navigation.defaultNavigationUp()

                Navigation.parentItem: playerControlLayout

                Component.onCompleted: {
                    requestLockUnlockAutoHide.connect(playerControlLayout.requestLockUnlockAutoHide)
                    menuOpened.connect(playerControlLayout.menuOpened)
                    playerControlLayout.forceUnlock.connect(part.forceUnlock)
                }
            }

            Part {
                id: seekLeft
                index: 0
                sourceList: playerControlLayout.model.left
                focus: true
                Navigation.rightItem: seekCenter.visible ? seekCenter : seekRight
            }
            Part {
                id: seekCenter
                index: 1
                sourceList: playerControlLayout.model.center
                Navigation.leftItem: seekLeft
                Navigation.rightItem: seekRight
            }
            Part {
                id: seekRight
                index: 2
                sourceList: playerControlLayout.model.right
                Navigation.leftItem: seekCenter.visible ? seekCenter : seekLeft
            }
        }
    }

    Loader {
        id: loaderLeftRight

        visible: !playerControlLayout.editing

        anchors.fill: parent

        active: !loaderSeek.active && !loaderCenter.active &&
                playerControlLayout.model &&
                ((playerControlLayout.model.left && (playerControlLayout.model.left.count > 0)) ||
                (playerControlLayout.model.right && (playerControlLayout.model.right.count > 0)))

        focus: active

        sourceComponent: RowLayout {
            spacing: playerControlLayout.spacing

            focus: true

            // TODO: Qt >= 5.13 Use QConcatenateTablesProxyModel
            //       instead of multiple repeaters

            ControlRepeater {
                id: leftRepeater
                model: ControlListFilter {
                    sourceModel: playerControlLayout.model.left

                    player: Player
                    ctx: MainCtx
                }

                Navigation.parentItem: playerControlLayout
                Navigation.rightAction: function() {
                    const item = rightRepeater.itemAt(0)
                    if (item)
                        item.forceActiveFocus(Qt.TabFocusReason)
                    else
                        return false
                }

                availableWidth: loaderLeftRight.width
                availableHeight: loaderLeftRight.height

                Component.onCompleted: {
                    requestLockUnlockAutoHide.connect(playerControlLayout.requestLockUnlockAutoHide)
                    menuOpened.connect(playerControlLayout.menuOpened)
                    playerControlLayout.forceUnlock.connect(leftRepeater.forceUnlock)
                }
            }

            Item {
                function containsVisibleItem(repeater) {
                    for (let i = 0; i < repeater.count; ++i) {
                        const item = repeater.itemAt(i)

                        if (item && item.visible)
                            return true
                    }

                    return false
                }

                Layout.minimumWidth: (containsVisibleItem(leftRepeater) && containsVisibleItem(rightRepeater)) ? playerControlLayout.layoutSpacing
                                                                                                               : 0

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: true
            }

            ControlRepeater {
                id: rightRepeater
                model: ControlListFilter {
                    sourceModel: playerControlLayout.model.right

                    player: Player
                    ctx: MainCtx
                }

                Navigation.parentItem: playerControlLayout
                Navigation.leftAction: function() {
                    const item = leftRepeater.itemAt(leftRepeater.count - 1)
                    if (item)
                        item.forceActiveFocus(Qt.BacktabFocusReason)
                    else
                        return false
                }

                availableWidth: loaderLeftRight.width
                availableHeight: loaderLeftRight.height

                Component.onCompleted: {
                    requestLockUnlockAutoHide.connect(playerControlLayout.requestLockUnlockAutoHide)
                    menuOpened.connect(playerControlLayout.menuOpened)
                    playerControlLayout.forceUnlock.connect(rightRepeater.forceUnlock)
                }
            }

        }
    }


    Loader {
        id: loaderLeft

        visible: !playerControlLayout.editing

        anchors {
            right: loaderCenter.left
            left: parent.left
            top: parent.top
            bottom: parent.bottom

            // Spacing for the filler item acts as padding
            rightMargin: layoutSpacing - spacing
        }

        active: !loaderSeek.active &&
                !!playerControlLayout.model?.left && (playerControlLayout.model.left.count > 0) &&
                !loaderLeftRight.active

        focus: active

        sourceComponent: ControlLayout {
            id: leftControlLayout

            model: ControlListFilter {
                sourceModel: playerControlLayout.model.left

                player: Player
                ctx: MainCtx
            }

            alignment: (Qt.AlignVCenter | Qt.AlignLeft)

            spacing: playerControlLayout.spacing

            focus: true

            altFocusAction: () => Navigation.defaultNavigationRight()

            Navigation.parentItem: playerControlLayout
            Navigation.rightItem: loaderCenter.item

            Component.onCompleted: {
                requestLockUnlockAutoHide.connect(playerControlLayout.requestLockUnlockAutoHide)
                menuOpened.connect(playerControlLayout.menuOpened)
                playerControlLayout.forceUnlock.connect(leftControlLayout.forceUnlock)
            }
        }
    }

    Loader {
        id: loaderCenter

        visible: !playerControlLayout.editing

        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            bottom: parent.bottom
        }

        // TODO: "ControlListFilter"'s count......
        active: !loaderSeek.active && playerControlLayout.hasCenterControls

        Binding on width {
            delayed: true
            when: loaderCenter._componentCompleted
            value: {
                const item = loaderCenter.item

                const minimumWidth = (item && item.Layout.minimumWidth > 0) ? item.Layout.minimumWidth : implicitWidth
                const maximumWidth = (item && item.Layout.maximumWidth > 0) ? item.Layout.maximumWidth : implicitWidth

                if ((loaderLeft.active && (loaderLeft.width > 0)) || (loaderRight.active && (loaderRight.width > 0))) {
                    return minimumWidth
                } else {
                    return Math.min(loaderCenter.parent.width, maximumWidth)
                }
            }
        }

        property bool _componentCompleted: false

        Component.onCompleted: {
            _componentCompleted = true
        }

        sourceComponent: ControlLayout {
            id: centerControlLayout

            model: ControlListFilter {
                sourceModel: playerControlLayout.model.center

                player: Player
                ctx: MainCtx
            }

            focus: true

            spacing: playerControlLayout.spacing

            altFocusAction: () => Navigation.defaultNavigationUp()

            Navigation.parentItem: playerControlLayout
            Navigation.leftItem: loaderLeft.item
            Navigation.rightItem: loaderRight.item

            Component.onCompleted: {
                requestLockUnlockAutoHide.connect(playerControlLayout.requestLockUnlockAutoHide)
                menuOpened.connect(playerControlLayout.menuOpened)
                playerControlLayout.forceUnlock.connect(centerControlLayout.forceUnlock)
            }
        }
    }

    Loader {
        id: loaderRight

        visible: !playerControlLayout.editing

        anchors {
            left: loaderCenter.right
            right: parent.right
            top: parent.top
            bottom: parent.bottom

            // Spacing for the filler item acts as padding
            leftMargin: layoutSpacing - spacing
        }

        active: !loaderSeek.active &&
                !!playerControlLayout.model && !!playerControlLayout.model.right && (playerControlLayout.model.right.count > 0) &&
                !loaderLeftRight.active

        sourceComponent: ControlLayout {
            id: rightControlLayout

            model: ControlListFilter {
                sourceModel: playerControlLayout.model.right

                player: Player
                ctx: MainCtx
            }

            alignment: (Qt.AlignVCenter | Qt.AlignRight)

            spacing: playerControlLayout.spacing

            focus: true

            altFocusAction: () => Navigation.defaultNavigationLeft()

            Navigation.parentItem: playerControlLayout
            Navigation.leftItem: loaderCenter.item

            onRequestLockUnlockAutoHide: (lock) => playerControlLayout.requestLockUnlockAutoHide(lock)

            onMenuOpened: (menu) => playerControlLayout.menuOpened(menu)

            Component.onCompleted:{
                playerControlLayout.forceUnlock.connect(rightControlLayout.forceUnlock)
            }
        }
    }
}
