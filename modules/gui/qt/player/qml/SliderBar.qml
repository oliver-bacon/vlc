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

import VLC.Player
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util
import VLC.MainInterface

T.ProgressBar {
    id: control

    // "Track" style from the VLC Redesign Figma file: a tall rounded track,
    // played part filled with the dim accent background, and a thin
    // always-visible accent playhead instead of the round hover handle.
    property bool trackStyle: false
    readonly property int trackRadius: VLCStyle.dp(6, VLCStyle.scale)
    readonly property int playheadWidth: VLCStyle.dp(4, VLCStyle.scale)
    readonly property int playheadMargin: VLCStyle.dp(2, VLCStyle.scale)

    readonly property real _hoveredScalingFactor: trackStyle ? 1.0 : 1.8
    property int barHeight: VLCStyle.dp(5, VLCStyle.scale)
    readonly property real _scaledBarHeight: control.barHeight * _hoveredScalingFactor
    readonly property real _scaledY: (-control.barHeight / 2) * (control._hoveredScalingFactor - 1)

    property bool _isSeekPointsShown: true
    readonly property int _seekPointsDistance: VLCStyle.dp(2, VLCStyle.scale)
    readonly property int _seekPointsRadius: trackStyle ? trackRadius : VLCStyle.dp(0.5, VLCStyle.scale)
    // Played part of the track: the accent over the track color. Derived
    // from the accent rather than a palette role so that it also works with
    // system/external palettes (Figma: BG/Accent Bright, about 24% / 35%).
    readonly property color _progressColor: trackStyle ? Qt.alpha(theme.fg.primary, (theme.palette?.isDark ?? true) ? 0.24 : 0.35)
                                                       : theme.fg.primary
    readonly property real _scaledSeekPointsRadius: _seekPointsRadius * _hoveredScalingFactor

    property bool _currentChapterHovered: false
    property real _tooltipPosition: (Widgets.PointingToolTipAttached.instance?.pos.x ?? 0.0) / width

    property color backgroundColor: theme.bg.primary
    property real touchHandlerMargin: VLCStyle.touchHandlerMargin

    // VLC Redesign subtitle timeline (Playback tab switch), shown in track
    // style when the subtitle file of the selected track could be read
    property bool subtitleTimelineEnabled: false
    property var subtitleCues: []
    readonly property bool timelineActive: trackStyle && subtitleTimelineEnabled && subtitleCues.length > 0
    readonly property real timelineStart: timelineLoader.item?.windowStart ?? 0
    readonly property real timelineEnd: timelineLoader.item?.windowEnd ?? 0

    function _readTimelineSetting() {
        subtitleTimelineEnabled = String(VLCConfig.uiValue("Player/SubtitleTimeline", false)) === "true"
    }

    Component.onCompleted: {
        value = Player.position
        _readTimelineSetting()
    }

    Connections {
        target: VLCConfig
        function onUiValueChanged(key) {
            if (key === "Player/SubtitleTimeline")
                control._readTimelineSetting()
        }
    }

    onSubtitleTimelineEnabledChanged: cueReload.restart()

    // the cues are read again when the media or the subtitle track changes
    Timer {
        id: cueReload
        interval: 300
        onTriggered: {
            if (!control.trackStyle || !control.subtitleTimelineEnabled) {
                control.subtitleCues = []
                return
            }
            control.subtitleCues = SubtitleCues.load().cues ?? []
        }
    }

    Connections {
        target: Player.subtitleTracks
        enabled: control.subtitleTimelineEnabled
        function onDataChanged() { cueReload.restart() }
        function onModelReset() { cueReload.restart() }
        function onRowsInserted() { cueReload.restart() }
        function onRowsRemoved() { cueReload.restart() }
    }

    // seek preview thumbnails (VLC Redesign): video files only
    readonly property bool _previewEnabled: trackStyle && !timelineActive && Player.hasVideoOutput
                                            && String(Player.url).startsWith("file:")
    readonly property real _hoverMs: {
        if (!hoverHandler.hovered || !Player.length.valid())
            return -1
        const x = Helpers.clamp(hoverHandler.point.position.x, 0, control.availableWidth)
        return Player.length.toMilliseconds() * x / Math.max(1, control.availableWidth)
    }

    // one frame per second at most, fewer for long media
    readonly property real _previewStep: Math.max(1000, Math.round(Player.length.toMilliseconds() / 400 / 1000) * 1000)

    Timer {
        id: previewRequest
        interval: 120
        onTriggered: {
            if (control._hoverMs < 0)
                return
            const step = control._previewStep
            SeekPreview.request(String(Player.url), Math.round(control._hoverMs / step) * step)
        }
    }

    on_HoverMsChanged: {
        if (_previewEnabled && _hoverMs >= 0)
            previewRequest.restart()
    }

    Keys.onRightPressed: Player.jumpFwd()
    Keys.onLeftPressed: Player.jumpBwd()

    Accessible.onIncreaseAction: Player.jumpFwd()
    Accessible.onDecreaseAction: Player.jumpBwd()

    function showChapterMarks() {
        _isSeekPointsShown = true
        seekpointTimer.restart()
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Slider

        enabled: control.enabled
        focused: control.visualFocus
        hovered: hoverHandler.hovered
    }

    Timer {
        id: seekpointTimer
        running: Player.hasChapters && !hoverHandler.hovered && _isSeekPointsShown
        interval: 3000
        onTriggered: control._isSeekPointsShown = false
    }

    Widgets.PointingToolTipAttached.visible: (hoverHandler.hovered || control.visualFocus || dragHandler.active)
                                             && !control.timelineActive && !previewCard.visible

    Widgets.PointingToolTipAttached.text: {
        if (!Widgets.PointingToolTipAttached.instance?.visible)
            return ""

        let _text

        const length = Player.length
        if (hoverHandler.hovered)
            _text = length.scale(Widgets.PointingToolTipAttached.instance.pos.x / control.width)
        else
            _text = Player.time

        _text = _text.formatHMS(length.isSubSecond() ? VLCTick.SubSecondFormattedAsMS : 0)

        if (Player.hasChapters)
            _text += " - " + Player.chapters.getNameAtPosition(control._tooltipPosition)

        return _text
    }

    Widgets.PointingToolTipAttached.pos: Qt.point(hoverHandler.hovered ? Helpers.clamp(hoverHandler.point.position.x, 0, control.availableWidth)
                                                                       : (control.visualPosition * control.width), 0)

    FSM {
        id: fsm
        signal playerUpdatePosition(real position)
        signal pressControl(real position, bool forcePrecise)
        signal releaseControl(real position, bool forcePrecise)
        signal moveControl(real position, bool forcePrecise)
        signal inputChanged()

        //each signal is associated to a key, when a signal is received,
        //transitions of active state for the given key are evaluated
        signalMap: ({
            "playerUpdatePosition": fsm.playerUpdatePosition,
            "pressControl": fsm.pressControl,
            "releaseControl": fsm.releaseControl,
            "moveControl": fsm.moveControl,
            "inputChanged": fsm.inputChanged
        })

        initialState: fsmReleased

        function _setPositionFromValue(position) {
            control.value = position
        }

        function _seekToPosition(position, threshold, forcePrecise) {
            position = Helpers.clamp(position, 0., 1.)
            control.value = position
            if (!forcePrecise) {
                const chapter = Player.chapters.getClosestChapterFromPos(position, threshold)
                if (chapter !== -1) {
                    Player.chapters.selectChapter(chapter)
                    return
                }
            }
            Player.position = position
        }

        FSMState {
            id: fsmReleased

            transitions: ({
                "playerUpdatePosition": {
                    action: (position) => {
                        control.value = position
                    }
                },
                "pressControl": {
                    action: (position, forcePrecise) => {
                        control.forceActiveFocus()
                        fsm._seekToPosition(position, VLCStyle.dp(4, VLCStyle.scale) / control.width, forcePrecise)
                    },
                    target: fsmHeld
                }
            })
        }

        FSMState  {
            id: fsmHeld

            transitions: ({
                "moveControl": {
                    action: (position, forcePrecise) => {
                        fsm._seekToPosition(position, VLCStyle.dp(2, VLCStyle.scale) / control.width, forcePrecise)
                    }
                },
                "releaseControl": {
                    target: fsmReleased
                },
                "inputChanged": {
                    target: fsmHeldWrongInput
                }
            })
        }

        FSMState  {
            id: fsmHeldWrongInput

            function enter() {
                fsm._setPositionFromValue(Player.position)
            }

            transitions: ({
                "playerUpdatePosition": {
                    action: fsm._setPositionFromValue
                },
                "releaseControl": {
                    target: fsmReleased
                }
            })
        }
    }

    Connections {
        target: Player
        function onPositionChanged() {  fsm.playerUpdatePosition(Player.position) }
        function onInputChanged() {
            fsm.inputChanged()
            SeekPreview.clear()
            cueReload.restart()
        }
    }

    implicitHeight: control.barHeight
    height: implicitHeight

    padding: 0

    //we use our own HoverHandler
    hoverEnabled: false

    HoverHandler {
        id: hoverHandler

        onHoveredChanged: () => {
            if (hovered) {
                if(Player.hasChapters)
                    control._isSeekPointsShown = true
            } else {
                if(Player.hasChapters)
                    seekpointTimer.restart()
            }
        }
    }

    contentItem: Item {
        implicitHeight: control.implicitHeight
        implicitWidth: control.implicitWidth

        //placing the TapHandler directly in the Control doesn't work with 6.2
        TapHandler {
            acceptedButtons: Qt.LeftButton

            gesturePolicy: TapHandler.WithinBounds

            // Make it easier to tap with touch screen:
            margin: MainCtx.usingTouch ? control.touchHandlerMargin : 0.0

            onPressedChanged: {
                if (pressed) {
                    fsm.pressControl(point.position.x / control.width, point.modifiers === Qt.ShiftModifier)
                } else {
                    // NOTE: Point is still valid at this point.
                    fsm.releaseControl(point.position.x / control.width, point.modifiers === Qt.ShiftModifier)
                }
            }
        }

        DragHandler {
            id: dragHandler
            acceptedButtons: Qt.LeftButton

            // Make it easier to drag with touch screen:
            margin: MainCtx.usingTouch ? control.touchHandlerMargin : 0

            target: null
            dragThreshold: 0
            grabPermissions: PointerHandler.CanTakeOverFromAnything

            property bool filterEvents: false

            function moveControl() {
                fsm.moveControl(dragHandler.centroid.position.x / control.width,
                                dragHandler.centroid.modifiers === Qt.ShiftModifier)
            }

            onActiveChanged: {
                if (active) {
                    filterEvents = false
                    fsm.pressControl(centroid.position.x / control.width, centroid.modifiers === Qt.ShiftModifier)
                } else {
                    fsm.releaseControl( centroid.position.x / control.width, centroid.modifiers === Qt.ShiftModifier)
                }
            }

            onCentroidChanged: {
                // FIXME: Qt 6.5 use xAxis.onActiveValueChanged in the DragHandler
                if (filterEvents) {
                    Qt.callLater(dragHandler.moveControl)
                } else {
                    dragHandler.moveControl()
                    filterEvents = true
                }
            }
        }

        WheelHandler {
            orientation: Qt.Vertical | Qt.Horizontal

            acceptedDevices: PointerDevice.AllDevices

            onWheel: (wheel) => {
                wheelToVLC.qmlWheelEvent(wheel)
                wheel.accepted = true
            }
        }

        WheelToVLCConverter {
            id: wheelToVLC

            function handleVertical(steps: int) {
                if (steps > 0)
                    Player.jumpFwd()
                else
                    Player.jumpBwd()
            }

            function handleHorizontal(steps: int) {
                if (steps > 0)
                    Player.jumpBwd()
                else
                    Player.jumpFwd()
            }

            Component.onCompleted: {
                wheelUpDown.connect(wheelToVLC, wheelToVLC.handleVertical)
                wheelLeftRight.connect(wheelToVLC, wheelToVLC.handleHorizontal)
            }
        }
    }

    background: Item {
        width: control.availableWidth
        implicitHeight: control.implicitHeight
        height: implicitHeight

        Rectangle {
            id: sliderRect
            visible: !Player.hasChapters
            color: control.backgroundColor
            anchors.fill: parent
            radius: control.trackStyle ? control.trackRadius : implicitHeight
        }

        Repeater {
            id: seekpointsRptr

            anchors.left: parent.left
            anchors.right: parent.right
            height: control.barHeight
            visible: Player.hasChapters

            model: Player.chapters
            Item {
                Rectangle {
                    id: seekpointsRect
                    readonly property real startPosition: model.startPosition ??  0.0
                    readonly property real endPosition: model.endPosition ?? 1.0

                    readonly property int _currentChapter: {
                        if (control.visualPosition < seekpointsRect.startPosition)
                            return 1
                        else if (control.visualPosition > seekpointsRect.endPosition)
                            return -1
                        return 0
                    }
                    on_CurrentChapterChanged: {
                        if(_hovered)
                            control._currentChapterHovered = _currentChapter === 0
                    }

                    readonly property bool _hovered: hoverHandler.hovered &&
                                            (hoverHandler.point.position.x > x && hoverHandler.point.position.x < x+width)

                    color: _currentChapter < 0 ? control._progressColor : control.backgroundColor
                    width: sliderRect.width * seekpointsRect.endPosition - x - control._seekPointsDistance
                    x: sliderRect.width * seekpointsRect.startPosition

                    Rectangle {
                        id: progressRepRect
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: parent.radius

                        width: sliderRect.width * control.visualPosition - parent.x - control._seekPointsDistance
                        visible: parent._currentChapter === 0
                        color: control._progressColor

                        // We use dynamic mutability group because time interpolation
                        // may induce rapid change:
                        // TODO: Do not use `Binding` when minimum Qt is 6.12:
                        Binding {
                            target: progressRepRect
                            property: "mutabilityGroup"
                            when: (progressRepRect.mutabilityGroup !== undefined)
                            value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.DynamicMutabilityGroup
                                                                                          : Item.StaticMutabilityGroup
                        }
                    }
                }

                transitions: [
                    Transition {
                        to: "*"
                        SequentialAnimation{
                            PropertyAction { targets: control; property: "_currentChapterHovered" }
                            NumberAnimation {
                                targets: [seekpointsRect, progressRepRect]; properties: "height, y, radius"
                                duration: VLCStyle.duration_short; easing.type: Easing.InSine
                            }
                        }
                    }
                ]

                states:[
                    State {
                        name: "visible"
                        PropertyChanges {
                            target: control;
                            _currentChapterHovered: seekpointsRect._currentChapter === 0 ? false : control._currentChapterHovered
                        }
                        PropertyChanges { target: seekpointsRect; height: control.barHeight }
                        PropertyChanges { target: seekpointsRect; y: 0 }
                        PropertyChanges { target: seekpointsRect; radius: control._seekPointsRadius }
                    },
                    State {
                        name: "visibleLarge"
                        PropertyChanges {
                            target: control;
                            _currentChapterHovered: seekpointsRect._currentChapter === 0 ? true : control._currentChapterHovered
                        }
                        PropertyChanges { target: seekpointsRect; height: control._scaledBarHeight }
                        PropertyChanges { target: seekpointsRect; y: control._scaledY }
                        PropertyChanges { target: seekpointsRect; radius: control._scaledSeekPointsRadius }
                    }
                ]

                state: (seekpointsRect._hovered || (seekpointsRect._currentChapter === 0 && fsm._state === fsm.fsmHeld))
                       ? "visibleLarge"
                       : "visible"
            }
        }

        Rectangle {
            id: progressRect
            width: control.visualPosition * parent.width
            visible: !Player.hasChapters
            color: control._progressColor
            height: control.barHeight
            radius: control._seekPointsRadius

            // We use dynamic mutability group because time interpolation
            // may induce rapid change:
            // TODO: Do not use `Binding` when minimum Qt is 6.12:
            Binding {
                target: progressRect
                property: "mutabilityGroup"
                when: (progressRect.mutabilityGroup !== undefined)
                value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.DynamicMutabilityGroup
                                                                              : Item.StaticMutabilityGroup
            }
        }

        Rectangle {
            id: bufferRect
            property int bufferAnimWidth: VLCStyle.dp(100, VLCStyle.scale)
            property int bufferAnimPosition: 0
            property int bufferFrames: 1000
            property alias animateLoading: loadingAnim.running
            property bool display: false
            property bool buffering: Player.buffering > 0 && Player.buffering < 1

            height: control.barHeight
            opacity: 0.4
            color: theme.fg.neutral //FIXME buffer color ?
            radius: control.trackStyle ? control.trackRadius : control.barHeight

            // TODO: Do not use `Binding` when minimum Qt is 6.12:
            Binding {
                target: bufferRect
                property: "mutabilityGroup"
                when: bufferRect.mutabilityGroup !== undefined
                value: bufferRect.buffering ? Item.DynamicMutabilityGroup
                                            : Item.StaticMutabilityGroup
            }

            Timer {
                id: bufferingTimer
                interval: VLCStyle.duration_humanMoment
                repeat: false
                running: false
                onTriggered: {
                    bufferRect.display = true
                }
            }

            onBufferingChanged: {
                if(buffering)
                {
                    bufferingTimer.start()
                }
                else
                {
                    bufferingTimer.stop()
                    bufferRect.display = false
                }
            }

            states: [
                State {
                    name: "hidden"
                    when: !control.visible
                    PropertyChanges {
                        target: bufferRect
                        width: bufferAnimWidth
                        visible: false
                        x: 0
                        animateLoading: false
                    }
                },
                State {
                    name: "buffering not started"
                    when: control.visible && Player.buffering === 0
                    PropertyChanges {
                        target: bufferRect
                        width: bufferAnimWidth
                        visible: true
                        x: (bufferAnimPosition / bufferFrames) * (parent.width - bufferAnimWidth)
                        animateLoading: true
                    }
                },
                State {
                    name: "time to start playing known"
                    when: control.visible && bufferRect.display
                    PropertyChanges {
                        target: bufferRect
                        width: Player.buffering * parent.width
                        visible: true
                        x: 0
                        animateLoading: false
                    }
                },
                State {
                    name: "playing from buffer"
                    when: control.visible && !bufferRect.display
                    PropertyChanges {
                        target: bufferRect
                        width: Player.buffering * parent.width
                        visible: false
                        x: 0
                        animateLoading: false
                    }
                }
            ]

            SequentialAnimation on bufferAnimPosition {
                id: loadingAnim
                running: bufferRect.animateLoading
                loops: Animation.Infinite
                PropertyAnimation {
                    from: 0.0
                    to: bufferRect.bufferFrames
                    duration: VLCStyle.durationSliderBouncing
                    easing.type: "OutBounce"
                }
                PauseAnimation {
                    duration: VLCStyle.duration_veryLong
                }
                PropertyAnimation {
                    from: bufferRect.bufferFrames
                    to: 0.0
                    duration: VLCStyle.durationSliderBouncing
                    easing.type: "OutBounce"
                }
                PauseAnimation {
                    duration: VLCStyle.duration_veryLong
                }
            }
        }
    }

    Rectangle {
        id: sliderHandle

        property int _size: control.barHeight * 3

        x: (control.visualPosition * control.availableWidth) - width / 2
        y: (control.barHeight - height) / 2

        implicitWidth: sliderHandle._size
        implicitHeight: sliderHandle._size
        radius: VLCStyle.margin_small
        color: theme.fg.primary

        // Replaced by trackPlayhead in track style. The state machine below
        // toggles `visible` itself, so hide through opacity instead.
        opacity: control.trackStyle ? 0.0 : 1.0

        // We use dynamic mutability group because time interpolation
        // may induce rapid change:
        // TODO: Do not use `Binding` when minimum Qt is 6.12:
        Binding {
            target: sliderHandle
            property: "mutabilityGroup"
            when: (sliderHandle.mutabilityGroup !== undefined)
            value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.DynamicMutabilityGroup
                                                                          : Item.StaticMutabilityGroup
        }

        transitions: [
            Transition {
                to: "hidden"
                SequentialAnimation {
                    NumberAnimation {
                        target: sliderHandle; properties: "implicitWidth,implicitHeight"
                        to: 0
                        duration: VLCStyle.duration_short; easing.type: Easing.OutSine
                    }
                    PropertyAction { target: sliderHandle; property: "visible"; value: false; }
                }
            },
            Transition {
                to: "visible"
                SequentialAnimation {
                    PropertyAction { target: sliderHandle; property: "visible"; value: true; }
                    NumberAnimation {
                        target: sliderHandle; properties: "implicitWidth,implicitHeight"
                        to: sliderHandle._size
                        duration: VLCStyle.duration_short; easing.type: Easing.InSine
                    }
                }
            },
            Transition {
                to: "visibleLarge"
                SequentialAnimation {
                    PropertyAction { target: sliderHandle; property: "visible"; value: true; }
                    NumberAnimation {
                        target: sliderHandle; properties: "implicitWidth,implicitHeight"
                        to: sliderHandle._size * (0.8 * control._hoveredScalingFactor)
                        duration: VLCStyle.duration_short; easing.type: Easing.InSine
                    }
                }
            }
        ]

        state: (!control.trackStyle && (hoverHandler.hovered || control.visualFocus))
               ? ((control._currentChapterHovered || (Player.hasChapters && fsm._state === fsm.fsmHeld)) ? "visibleLarge" : "visible")
               : "hidden"
    }

    // Track style playhead: thin accent pill, always visible, inset by
    // playheadMargin from the top and bottom of the track.
    Rectangle {
        id: trackPlayhead

        visible: control.trackStyle

        width: control.playheadWidth
        height: Math.max(0, control.barHeight - 2 * control.playheadMargin)

        x: Helpers.clamp((control.visualPosition * control.availableWidth) - width / 2,
                         0, control.availableWidth - width)
        y: control.playheadMargin

        radius: control.playheadWidth
        color: theme.fg.primary

        // Keyboard focus is otherwise invisible in track style, as the
        // round handle that used to signal it is hidden.
        border.width: control.visualFocus ? VLCStyle.focus_border : 0
        border.color: theme.visualFocus

        // TODO: Do not use `Binding` when minimum Qt is 6.12:
        Binding {
            target: trackPlayhead
            property: "mutabilityGroup"
            when: (trackPlayhead.mutabilityGroup !== undefined)
            value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.DynamicMutabilityGroup
                                                                          : Item.StaticMutabilityGroup
        }
    }

    // subtitle timeline over the bar
    Loader {
        id: timelineLoader

        anchors.fill: parent
        z: 10
        active: control.timelineActive

        sourceComponent: SubtitleTimeline {
            cues: control.subtitleCues
            radius: control.trackRadius
            trackColor: control.backgroundColor
            playedColor: control._progressColor
            accentColor: theme.fg.primary
            playedCueColor: Qt.alpha(theme.fg.primary, 0.45)
            cueColor: (theme.palette?.isDark ?? true) ? "#2E2E2E" : "#C8C8C8"
        }
    }

    // seek preview (Figma "thumbnail": 272 x 189 card, 252 x 142 frame)
    Rectangle {
        id: previewCard

        readonly property real dp1: VLCStyle.dp(1, VLCStyle.scale)

        visible: control._previewEnabled && hoverHandler.hovered && SeekPreview.source !== ""
        z: 11

        width: 272 * dp1
        height: 189 * dp1
        radius: 14 * dp1
        color: Qt.alpha((theme.palette?.isDark ?? true) ? "#191919" : "#F0F0F0", 0.95)

        x: Helpers.clamp((hoverHandler.point.position.x) - width / 2, 0, Math.max(0, control.width - width))
        y: -height - 12 * dp1

        Image {
            x: 10 * previewCard.dp1
            y: 10 * previewCard.dp1
            width: 252 * previewCard.dp1
            height: 142 * previewCard.dp1
            fillMode: Image.PreserveAspectFit
            asynchronous: false
            cache: false
            source: SeekPreview.source
            // dimmed while the frame of the hovered time is on its way
            opacity: Math.abs(SeekPreview.time - control._hoverMs) <= 1.5 * control._previewStep ? 1.0 : 0.5
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10 * previewCard.dp1
            text: Player.length.scale(Math.max(0, control._hoverMs) / Math.max(1, Player.length.toMilliseconds()))
                  .formatHMS(Player.length.isSubSecond() ? VLCTick.SubSecondFormattedAsMS : 0)
            color: "#8F8F8F"
            font.pixelSize: 15 * previewCard.dp1
        }
    }
}
