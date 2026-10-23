/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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
import QtQuick.Templates as T
import QtQuick.Layouts
import QtQml.Models


import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Util
import VLC.Dialogs
import VLC.PlayerControls

T.Pane {
    id: root

    enum TimeTextPosition {
        Hide,
        AboveSlider,
        LeftRightSlider,
        // Single row: [left controls] time [seek track] length [right controls].
        // (not used by the VLC Redesign player bar, see `seekBarControl`)
        Inline
    }

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    topInset: sliderY

    bottomPadding: VLCStyle.margin_xsmall

    readonly property bool _inline: (textPosition === ControlBar.TimeTextPosition.Inline)

    // In the single-row layout the seek bar sits inside the controls row, so
    // the bar starts at the top of the pane (used to place the play queue).
    // (Customize Player: also from the top, the seek bar row is a dashed box)
    // (VLC Redesign: also with the times left and right of the seek bar row,
    // the bar is one solid surface)
    readonly property real sliderY: (_inline || _redesignRow || seekBarControl || MainCtx.playerCustomizing) ? 0 : mapFromItem(contentItem, 0, contentItem.sliderY).y
    // seek bar in a row of its own above the controls (VLC Redesign look)
    readonly property bool _redesignRow: (textPosition === ControlBar.TimeTextPosition.LeftRightSlider)
    property int textPosition: ControlBar.TimeTextPosition.AboveSlider

    // VLC Redesign: the seek bar is a control of the bar
    // (ControlListModel.SEEK_BAR, SeekBarWidget.qml) that can be anywhere in
    // the bar or in the row above it (the bar's `top` controls)
    property bool seekBarControl: false

    // SeekBarWidget: the seek bar control shows these items
    readonly property bool isSeekBarHost: seekBarControl
    property Item seekSlot: null
    readonly property list<Item> seekBarItems: [mediaTime, trackPositionSlider, mediaRemainingTime]

    // the seek bar is in the bar itself (single row)
    readonly property bool _seekInBar: seekBarControl && ((contentItem?.playerControlLayout?.seekPart ?? -1) >= 0)

    property int identifier: -1
    property real sliderHeight: VLCStyle.heightBar_xxsmall
    property real inlineSliderHeight: VLCStyle.dp(28, VLCStyle.scale)
    property real bookmarksHeight: VLCStyle.controlBarBookmarksHeight
    property bool showRemainingTime: true

    property var menu: undefined

    // "00:06:00*": a time of the subtitle timeline window (VLC Redesign)
    function _windowTime(ms) {
        const total = Math.max(0, Math.round(ms / 1000))
        const pad = (n) => String(n).padStart(2, "0")
        return pad(Math.floor(total / 3600)) + ":" + pad(Math.floor(total / 60) % 60) + ":" + pad(total % 60) + "*"
    }

    signal requestLockUnlockAutoHide(bool lock)

    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    enabled: visible

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => root.Navigation.defaultKeyAction(event)
    Navigation.cancelAction: function() { History.previous(Qt.BacktabFocusReason) }

    Accessible.name: qsTr("Player controls")
    AccessibleCompat.id: "playerControlBar"

    function showChapterMarks() {
        if (contentItem.trackPositionSlider)
            contentItem.trackPositionSlider.showChapterMarks()
    }

    function applyMenu(menu) {
        if (root.menu === menu)
            return

        // NOTE: When applying a new menu we hide the previous one.
        if (menu)
            dismiss()

        root.menu = menu
    }

    function dismiss() {
        if ((typeof menu === undefined) || !menu)
            return
        if (menu.hasOwnProperty("dismiss"))
            menu.dismiss()
        else if (menu.hasOwnProperty("close"))
            menu.close()
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    TextMetrics {
        id: timeTextMetrics
        // (the seek bar row of the redesign uses the size of the single-row bar)
        font.pixelSize: VLCStyle.fontSize_normal
        text: {
            // This text metrics is used for both the time and length, as we want them to have the same width.
            // Length might not be reported in some cases, for that reason we should check both and use the bigger one.

            // Some extra space to compensate non-monospaced fonts ("-" takes more space than ":", double "-" for guarantee)
            // The subtitle timeline always shows "HH:MM:SS*" (see _windowTime).
            if (root.contentItem?.trackPositionSlider?.timelineActive ?? false)
                return "00--00--00*"
            return (Player.time.isSubHour() && Player.length.isSubHour()) ? "00--00" : "00--00--00"
        }
    }

    background: Rectangle {
        color: theme.bg.primary

        // Hairline separating the single-row control bar from the video
        Rectangle {
            visible: root._inline || root._seekInBar
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: VLCStyle.border
            color: theme.border
        }
    }

    contentItem: ColumnLayout {
        spacing: VLCStyle.margin_xsmall

        readonly property real sliderY: row2.y

        property alias trackPositionSlider: trackPositionSlider

        property alias mediaRemainingTime: mediaRemainingTime

        property alias playerControlLayout: playerControlLayout

        readonly property list<Item> strayItems: [
            T.Label {
                id: mediaTime

                Layout.preferredWidth: (textPosition === ControlBar.TimeTextPosition.LeftRightSlider || root._inline) ? timeTextMetrics.width : -1

                text: {
                    // subtitle timeline: start of the shown window, marked with "*"
                    if (trackPositionSlider.timelineActive)
                        return root._windowTime(trackPositionSlider.timelineStart)
                    const length = Player.length
                    return Player.time.formatHMS(length.isSubSecond() ? VLCTick.SubSecondFormattedAsMS : 0)
                }
                // The redesign uses the muted text color for both times
                color: (root._inline || root._redesignRow) ? theme.fg.secondary : theme.fg.primary
                font: timeTextMetrics.font
                horizontalAlignment: Text.AlignHCenter

                // TODO: Do not use `Binding` when minimum Qt is 6.12:
                Binding {
                    target: mediaTime
                    property: "mutabilityGroup"
                    when: (mediaTime.mutabilityGroup !== undefined)
                    value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.ModerateMutabilityGroup
                                                                                  : Item.StaticMutabilityGroup
                }

                anchors.left: (parent === pseudoRow) ? parent.left : undefined
                anchors.verticalCenter: (parent === pseudoRow) ? parent.verticalCenter : undefined
            },
            T.Label {
                id: mediaRemainingTime

                Layout.preferredWidth: (textPosition === ControlBar.TimeTextPosition.LeftRightSlider || root._inline) ? timeTextMetrics.width : -1

                readonly property bool showRemainingTime: (MainCtx.showRemainingTime && Player.remainingTime.valid())

                text: trackPositionSlider.timelineActive
                      ? root._windowTime(trackPositionSlider.timelineEnd)
                      : showRemainingTime
                        ? "-" + Player.remainingTime.formatHMS()
                        : Player.length.formatHMS()
                color: mediaTime.color
                font: timeTextMetrics.font
                horizontalAlignment: Text.AlignHCenter

                visible: root.showRemainingTime

                // TODO: Do not use `Binding` when minimum Qt is 6.12:
                Binding {
                    target: mediaRemainingTime
                    property: "mutabilityGroup"
                    when: (mediaRemainingTime.mutabilityGroup !== undefined)
                    value: ((Player.playingState === Player.PLAYING_STATE_PLAYING) &&
                            mediaRemainingTime.showRemainingTime) ? Item.ModerateMutabilityGroup
                                                                  : Item.StaticMutabilityGroup
                }

                anchors.right: (parent === pseudoRow) ? parent.right : undefined
                anchors.verticalCenter: (parent === pseudoRow) ? parent.verticalCenter : undefined

                TapHandler {
                    onTapped: (eventPoint, button) => {
                        MainCtx.showRemainingTime = !MainCtx.showRemainingTime
                    }
                }

                HoverHandler {
                    id: mediaRemainingTimeHover
                }

                Widgets.ToolTipExt {
                    colorContext.palette: theme.palette

                    visible: mediaRemainingTimeHover.hovered && MainCtx.showRemainingTime && Player.rate !== 1
                    delay: VLCStyle.delayToolTipAppear
                    text: {
                        if (!visible)
                            return ""

                        const playbackSpeed = Math.abs(Player.rate)
                        const adjustedRemainingTime = Player.remainingTime.scale(1 / playbackSpeed)
                            ? Player.remainingTime.scale(1 / playbackSpeed)
                            : Player.remainingTime

                        return qsTr("%1 (%2x)")
                            .arg(adjustedRemainingTime.formatHMS())
                            .arg(+Player.rate.toFixed(2))
                    }

                    x: (parent.width - width) / 2
                }
            },
            SliderBar {
                id: trackPositionSlider

                barHeight: (root._inline || root._redesignRow) ? root.inlineSliderHeight : root.sliderHeight
                trackStyle: root._inline || root._redesignRow
                Layout.alignment: Qt.AlignVCenter

                Accessible.role: Accessible.Slider
                Accessible.name: qsTr("Progress")
                AccessibleCompat.id: "progressSlider"

                Layout.fillWidth: true
                enabled: Player.playingState === Player.PLAYING_STATE_PLAYING || Player.playingState === Player.PLAYING_STATE_PAUSED

                Navigation.parentItem: root
                Navigation.downItem: playerControlLayout

                activeFocusOnTab: true

                focus: true

                Keys.onPressed: (event) => {
                    Navigation.defaultKeyAction(event)
                }
            },
            Loader {
                id: bookmarksLoader

                // the seek bar control: below it
                readonly property Item slot: root.seekBarControl ? root.seekSlot : null

                parent: slot ?? root
                // FIXME: bookmarks are positioned below the seek bar row; in
                // the single-row layout they are not shown yet.
                active: MainCtx.mediaLibraryAvailable && !root._inline && !root._seekInBar &&
                        (!root.seekBarControl || !!slot)
                source: "qrc:///qt/qml/VLC/MediaLibrary/Bookmarks.qml"

                x: slot ? trackPositionSlider.x : root.leftPadding + trackPositionSlider.x + row2.Layout.leftMargin
                y: slot ? slot.height + VLCStyle.margin_xxsmall : row2.y + row2.height + VLCStyle.margin_xxsmall
                width: trackPositionSlider.width

                onLoaded: {
                   item.barHeight = Qt.binding(function() { return bookmarksHeight })
                   item.controlBarHovered = Qt.binding(function() { return root.hovered })
                   item.yShift = Qt.binding(function() {
                       return (slot ? slot.height : row2.height) + VLCStyle.margin_xxsmall
                   })
                }
            }
        ]

        Item {
            // BUG: RowLayout can not be used here
            // because of a Qt bug. (Height is
            // incorrectly determined. Could be
            // about nested layouting).

            id: pseudoRow
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.leftMargin: VLCStyle.margin_normal
            Layout.rightMargin: VLCStyle.margin_normal

            implicitHeight: visible ? Math.max(mediaTime.implicitHeight, mediaRemainingTime.implicitHeight) : 0

            visible: children.length > 0

            children: {
                if (root.seekBarControl)
                    return []
                switch (textPosition) {
                case ControlBar.TimeTextPosition.AboveSlider:
                    return [mediaTime, mediaRemainingTime]
                case ControlBar.TimeTextPosition.Hide:
                case ControlBar.TimeTextPosition.LeftRightSlider:
                case ControlBar.TimeTextPosition.Inline:
                default:
                    return []
                }
            }
        }

        RowLayout {
            id: row2

            children: {
                if (root.seekBarControl)
                    return []
                switch (textPosition) {
                case ControlBar.TimeTextPosition.Hide:
                case ControlBar.TimeTextPosition.AboveSlider:
                    return [trackPositionSlider]
                case ControlBar.TimeTextPosition.LeftRightSlider:
                    return [mediaTime, trackPositionSlider, mediaRemainingTime]
                case ControlBar.TimeTextPosition.Inline: // hosted by playerControlLayout
                default:
                    return []
                }
            }

            visible: children.length > 0

            spacing: VLCStyle.margin_xsmall

            Layout.fillWidth: true
            Layout.fillHeight: false
            // in line with the controls below (and the dashed boxes of
            // Customize Player)
            Layout.leftMargin: (textPosition === ControlBar.TimeTextPosition.LeftRightSlider) ? VLCStyle.margin_large + VLCStyle.margin_xsmall
                                                                                              : 0

            Layout.rightMargin: Layout.leftMargin
        }

        // VLC Redesign: the row above the bar (seek row), the bar's `top`
        // controls; while customizing a box to drop controls in, also empty
        Loader {
            id: topRowLoader

            readonly property var topModel: playerControlLayout.model?.top ?? null

            Layout.fillWidth: true
            Layout.leftMargin: VLCStyle.margin_large
            Layout.rightMargin: VLCStyle.margin_large

            active: root.seekBarControl && !!topModel && (MainCtx.playerCustomizing || topModel.count > 0)
            visible: active

            sourceComponent: MainCtx.playerCustomizing ? topEditComponent : topRowComponent

            Component {
                id: topRowComponent

                ControlLayout {
                    id: topRow

                    model: ControlListFilter {
                        sourceModel: topRowLoader.topModel

                        player: Player
                        ctx: MainCtx
                    }

                    // without the seek bar the controls start on the left
                    alignment: expands ? Qt.AlignVCenter : (Qt.AlignVCenter | Qt.AlignLeft)

                    spacing: playerControlLayout.spacing

                    focus: true

                    altFocusAction: () => Navigation.defaultNavigationDown()

                    Navigation.parentItem: root
                    Navigation.downItem: playerControlLayout

                    onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)

                    onMenuOpened: (menu) => root.applyMenu(menu)

                    Component.onCompleted: root.forceUnlock.connect(topRow.forceUnlock)
                }
            }

            Component {
                id: topEditComponent

                LiveBarSection {
                    model: topRowLoader.topModel
                    acceptsSeekBar: true
                }
            }
        }

        PlayerControlLayout {
            id: playerControlLayout

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: VLCStyle.margin_large
            Layout.rightMargin: VLCStyle.margin_large

            identifier: root.identifier

            implicitHeight: {
                const h = (MainCtx.pinVideoControls || root._inline || root._seekInBar) ? VLCStyle.controlLayoutHeightPinned
                                                                     : VLCStyle.controlLayoutHeight
                // the dashed boxes of Customize Player need a bit more
                return editing ? Math.max(h, editHeight) : h
            }

            visible: !model?.empty ?? false

            // In the single-row layout the slider is part of this row and
            // is reached with Tab / left-right navigation instead.
            Navigation.upItem: root.seekBarControl ? (topRowLoader.item && !MainCtx.playerCustomizing ? topRowLoader.item : root.Navigation.upItem)
                                                   : (trackPositionSlider.enabled && !root._inline) ? trackPositionSlider : root.Navigation.upItem

            onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)

            onMenuOpened: (menu) => root.applyMenu(menu)

            Component.onCompleted: {
                root.forceUnlock.connect(playerControlLayout.forceUnlock)
            }
        }
    }
}
