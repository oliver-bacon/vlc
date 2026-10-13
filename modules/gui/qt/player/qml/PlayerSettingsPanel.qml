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
import VLC.Player
import VLC.Style

// Player settings panel of the VLC Redesign Figma file (gear button of the
// player bar): Playback / Video / Audio / Subtitles tabs, with the audio
// effects (Equalizer, Compressor, Spatializer, Stereo Widener) and video
// effects (Essential, Crop, Colors) as expandable cards. Changes apply live
// and are kept for the next media.
T.Popup {
    id: root

    property int currentTab: 2 // Audio, as in the design

    width: VLCStyle.dp(400, VLCStyle.scale)
    height: Math.min(VLCStyle.dp(640, VLCStyle.scale), (parent?.Window.height ?? 800) - VLCStyle.dp(120, VLCStyle.scale))
    padding: 0
    modal: false
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutsideParent

    // Figma tokens (dark), light palette tokens otherwise
    readonly property bool dark: VLCStyle.palette?.isDark ?? true
    readonly property color panelColor: dark ? "#191919" : "#E7E7E7"
    readonly property color tabsColor: dark ? "#151515" : "#DEDEDE"
    readonly property color cardColor: dark ? "#1F1F1F" : "#DEDEDE"
    readonly property color wellColor: dark ? "#090909" : "#F4F4F4"
    readonly property color dividerColor: dark ? "#222222" : "#ACACAC"
    readonly property color titleColor: dark ? "#C6C6C6" : "#161616"
    readonly property color textColor: dark ? "#8F8F8F" : "#2E2E2E"
    readonly property color dimColor: "#6B6B6B"
    readonly property color faintColor: dark ? "#404040" : "#9B9B9B"
    readonly property color accentColor: "#D37918"
    readonly property color accentSurface: dark ? "#371F06" : "#D8BA9A"
    readonly property real dp1: VLCStyle.dp(1, VLCStyle.scale)

    background: Rectangle {
        radius: 10 * root.dp1
        color: root.panelColor
    }

    contentItem: ColumnLayout {
        spacing: 0

        // tabs
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50 * root.dp1
            color: root.tabsColor
            radius: 10 * root.dp1

            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: parent.radius
                color: parent.color
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10 * root.dp1
                anchors.rightMargin: 10 * root.dp1
                spacing: 0

                Repeater {
                    model: [
                        { "text": qsTr("Playback"), "glyph": VLCIcons.playback_settings },
                        { "text": qsTr("Video"), "glyph": VLCIcons.video },
                        { "text": qsTr("Audio"), "glyph": VLCIcons.visualization },
                        { "text": qsTr("Subtitles"), "glyph": VLCIcons.audiosub }
                    ]

                    delegate: T.TabButton {
                        id: tab

                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        checked: root.currentTab === index
                        onClicked: root.currentTab = index

                        background: Rectangle {
                            color: "transparent"
                            Rectangle {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 4 * root.dp1; rightMargin: 4 * root.dp1 }
                                height: 2 * root.dp1
                                visible: tab.checked
                                color: root.accentColor
                            }
                        }
                        contentItem: Row {
                            spacing: 6 * root.dp1
                            leftPadding: Math.max(0, (tab.width - implicitWidth) / 2)
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                font.family: VLCIcons.fontFamily
                                font.pixelSize: 15 * root.dp1
                                text: tab.modelData.glyph
                                color: tab.checked ? root.accentColor : root.dimColor
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tab.modelData.text
                                font.pixelSize: 13 * root.dp1
                                color: tab.checked ? root.titleColor : root.dimColor
                            }
                        }
                    }
                }
            }
        }

        // pages
        Flickable {
            id: flick

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: pages.implicitHeight + 20 * root.dp1
            boundsBehavior: Flickable.StopAtBounds

            StackLayout {
                id: pages

                x: 20 * root.dp1
                width: flick.width - 40 * root.dp1
                currentIndex: root.currentTab
                implicitHeight: children[currentIndex]?.implicitHeight ?? 0

                PlaybackPage {}
                VideoPage {}
                AudioPage {}
                SubtitlesPage {}
            }
        }

        // footer
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.dividerColor
        }

        T.Button {
            id: advanced

            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6 * root.dp1
            Layout.bottomMargin: 8 * root.dp1
            implicitHeight: 32 * root.dp1
            background: null
            contentItem: Row {
                spacing: 8 * root.dp1
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: VLCIcons.fontFamily
                    font.pixelSize: 14 * root.dp1
                    text: VLCIcons.settings
                    color: advanced.hovered ? root.titleColor : root.textColor
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Open Advanced Settings")
                    font.pixelSize: 13 * root.dp1
                    color: advanced.hovered ? root.titleColor : root.textColor
                }
            }
            onClicked: {
                root.close()
                DialogsProvider.extendedDialog()
            }
        }
    }

    // ===================================================================
    // pages

    component PlaybackPage: Page {
        Row2 {
            label: qsTr("Audio Visualizer")
            visible: VLCConfig.exists("audio-visual")
            Dropdown {
                Layout.preferredWidth: 216 * root.dp1
                option: "audio-visual"
                noneText: qsTr("Disabled")
            }
        }
        Row2 {
            label: qsTr("Speed")
            ValueBox { text: (Math.round(Player.rate * 100) / 100) + "x" }
        }
        FxSlider {
            from: 0.25; to: 2; stepSize: 0.05
            tickLabels: ["0.25", "0.5", "0.75", "1", "1.25", "1.5", "1.75", "2"]
            value: Player.rate
            enabled: Player.ratechangable
            onMoved: Player.rate = value
        }
    }

    component VideoPage: Page {
        SectionTitle { text: qsTr("Filters") }

        Label2 { text: qsTr("Essential") }
        Card {
            FilterSlider { label: qsTr("Hue"); module: "adjust"; option: "hue"; decimals: 0 }
            FilterSlider { label: qsTr("Brightness"); module: "adjust"; option: "brightness" }
            FilterSlider { label: qsTr("Contrast"); module: "adjust"; option: "contrast" }
            FilterSlider { label: qsTr("Saturation"); module: "adjust"; option: "saturation" }
            FilterSlider { label: qsTr("Gamma"); module: "adjust"; option: "gamma" }
            FilterSlider { label: qsTr("Sharpen Sigma"); module: "sharpen"; option: "sharpen-sigma" }
            FilterSlider { label: qsTr("Banding Removal Radius"); module: "gradfun"; option: "gradfun-radius"; decimals: 0 }
            FilterSlider { label: qsTr("Film Grain Variance"); module: "grain"; option: "grain-variance" }
        }

        Label2 { text: qsTr("Crop") }
        Card {
            id: cropCard

            property int cropTop: 0
            property int cropBottom: 0
            property int cropLeft: 0
            property int cropRight: 0
            property bool linkVertical: false
            property bool linkHorizontal: false

            function apply() { VLCEffects.setCrop(cropTop, cropBottom, cropLeft, cropRight) }

            RowLayout {
                spacing: 8 * root.dp1
                PixelBox { label: qsTr("Top"); value: cropCard.cropTop
                    onEdited: (v) => { cropCard.cropTop = v; if (cropCard.linkVertical) cropCard.cropBottom = v; cropCard.apply() } }
                PixelBox { label: qsTr("Bottom"); value: cropCard.cropBottom
                    onEdited: (v) => { cropCard.cropBottom = v; if (cropCard.linkVertical) cropCard.cropTop = v; cropCard.apply() } }
                LinkButton { checked: cropCard.linkVertical; onClicked: cropCard.linkVertical = !cropCard.linkVertical }
            }
            RowLayout {
                spacing: 8 * root.dp1
                PixelBox { label: qsTr("Left"); value: cropCard.cropLeft
                    onEdited: (v) => { cropCard.cropLeft = v; if (cropCard.linkHorizontal) cropCard.cropRight = v; cropCard.apply() } }
                PixelBox { label: qsTr("Right"); value: cropCard.cropRight
                    onEdited: (v) => { cropCard.cropRight = v; if (cropCard.linkHorizontal) cropCard.cropLeft = v; cropCard.apply() } }
                LinkButton { checked: cropCard.linkHorizontal; onClicked: cropCard.linkHorizontal = !cropCard.linkHorizontal }
            }
        }

        Label2 { text: qsTr("Colors") }
        Card {
            ColorFilterRow { label: qsTr("Color Extraction"); module: "extract"; option: "extract-component" }
            ColorFilterRow { label: qsTr("Color Threshold"); module: "colorthres"; option: "colorthres-color" }
            FilterSlider { label: qsTr("Saturation"); module: "colorthres"; option: "colorthres-saturationthres"; decimals: 0; enables: false }
            FilterSlider { label: qsTr("Similarity"); module: "colorthres"; option: "colorthres-similaritythres"; decimals: 0; enables: false }
            FilterToggle { label: qsTr("Negate Colors"); module: "invert" }
            FilterToggle { label: qsTr("Posterize"); module: "posterize" }
            FilterToggle { label: qsTr("Gradient"); module: "gradient" }
            Dropdown {
                Layout.fillWidth: true
                visible: VLCConfig.exists("gradient-mode")
                option: "gradient-mode"
                video: true
            }
            OptionToggle { label: qsTr("Color"); option: "gradient-color" }
            OptionToggle { label: qsTr("Cartoon"); option: "gradient-cartoon" }
            FilterSlider { label: qsTr("Sepia Intensity"); module: "sepia"; option: "sepia-intensity"; decimals: 0 }
        }
    }

    component AudioPage: Page {
        SectionTitle { text: qsTr("Defaults") }
        Row2 { label: qsTr("Audio Track"); ConfigBox { option: "audio-track" } }
        Row2 { label: qsTr("Audio Language"); ConfigBox { option: "audio-language" } }
        Row2 { label: qsTr("Stereo Mode"); visible: VLCConfig.exists("stereo-mode") }
        Dropdown { Layout.fillWidth: true; option: "stereo-mode"; audio: true; visible: VLCConfig.exists("stereo-mode") }

        Divider {}
        SectionTitle { text: qsTr("Synchronization") }
        Row2 {
            label: qsTr("Audio Track Delay")
            ValueBox { text: (Player.audioDelayMS / 1000).toFixed(3) + " s" }
        }
        FxSlider {
            from: -10000; to: 10000; stepSize: 50
            tickLabels: ["-10 s", "0 s", "+10 s"]
            value: Player.audioDelayMS
            onMoved: Player.audioDelayMS = value
        }

        Divider {}
        SectionTitle { text: qsTr("Filters") }

        Label2 { text: qsTr("Equalizer") }
        EqualizerPreset { Layout.fillWidth: true }
        Card {
            id: eqCard

            property var bands: VLCEffects.equalizerBands()
            readonly property var labels: ["60 Hz", "170 Hz", "310 Hz", "600 Hz", "1 KHz", "3 KHz", "6 KHz", "12 KHz", "14 KHz", "16 KHz"]

            FilterSlider { label: qsTr("Preamp"); module: "equalizer"; option: "equalizer-preamp"; audio: true; unit: " dB"; boxed: true }
            Repeater {
                model: 10
                delegate: FilterSlider {
                    required property int index
                    label: eqCard.labels[index]
                    module: "equalizer"
                    audio: true
                    unit: " dB"
                    boxed: true
                    from: -20; to: 20
                    current: eqCard.bands[index] ?? 0
                    onValueSet: (v) => VLCEffects.setEqualizerBand(index, v)
                }
            }
            Connections {
                target: VLCEffects
                function onChanged() { eqCard.bands = VLCEffects.equalizerBands() }
            }
        }
        OptionToggle { label: qsTr("2 Pass"); option: "equalizer-2pass"; audio: true }

        AudioEffect {
            label: qsTr("Compressor"); module: "compressor"
            FilterSlider { label: qsTr("RMS / Peak"); module: "compressor"; option: "compressor-rms-peak"; audio: true }
            FilterSlider { label: qsTr("Attack"); module: "compressor"; option: "compressor-attack"; audio: true; unit: " ms" }
            FilterSlider { label: qsTr("Release"); module: "compressor"; option: "compressor-release"; audio: true; unit: " ms" }
            FilterSlider { label: qsTr("Threshold"); module: "compressor"; option: "compressor-threshold"; audio: true; unit: " dB" }
            FilterSlider { label: qsTr("Ratio"); module: "compressor"; option: "compressor-ratio"; audio: true; unit: " : 1" }
            FilterSlider { label: qsTr("Knee Radius"); module: "compressor"; option: "compressor-knee"; audio: true; unit: " dB" }
            FilterSlider { label: qsTr("Makeup Gain"); module: "compressor"; option: "compressor-makeup-gain"; audio: true; unit: " dB" }
        }
        AudioEffect {
            label: qsTr("Spatializer"); module: "spatializer"
            FilterSlider { label: qsTr("Size"); module: "spatializer"; option: "spatializer-roomsize"; audio: true }
            FilterSlider { label: qsTr("Width"); module: "spatializer"; option: "spatializer-width"; audio: true }
            FilterSlider { label: qsTr("Wet"); module: "spatializer"; option: "spatializer-wet"; audio: true }
            FilterSlider { label: qsTr("Dry"); module: "spatializer"; option: "spatializer-dry"; audio: true }
            FilterSlider { label: qsTr("Damp"); module: "spatializer"; option: "spatializer-damp"; audio: true }
        }
        AudioEffect {
            label: qsTr("Stereo Widener"); module: "stereo_widen"
            FilterSlider { label: qsTr("Delay Time"); module: "stereo_widen"; option: "stereowiden-delay"; audio: true; unit: " ms" }
            FilterSlider { label: qsTr("Feedback Gain"); module: "stereo_widen"; option: "stereowiden-feedback"; audio: true }
            FilterSlider { label: qsTr("Crossfeed"); module: "stereo_widen"; option: "stereowiden-crossfeed"; audio: true }
            FilterSlider { label: qsTr("Dry Mix"); module: "stereo_widen"; option: "stereowiden-dry-mix"; audio: true }
        }
    }

    component SubtitlesPage: Page {
        SectionTitle { text: qsTr("Defaults") }
        Row2 { label: qsTr("Subtitle Track"); ConfigBox { option: "sub-track" } }
        Row2 { label: qsTr("Subtitle Language"); ConfigBox { option: "sub-language" } }

        Divider {}
        SectionTitle { text: qsTr("Synchronization") }
        Row2 {
            label: qsTr("Subtitle Track Delay")
            ValueBox { text: (Player.subtitleDelayMS / 1000).toFixed(3) + " s" }
        }
        FxSlider {
            from: -10000; to: 10000; stepSize: 50
            tickLabels: ["-10 s", "0 s", "+10 s"]
            value: Player.subtitleDelayMS
            onMoved: Player.subtitleDelayMS = value
        }
        Row2 {
            label: qsTr("Subtitle Speed")
            ValueBox { text: Player.subtitleFPS.toFixed(3) + " fps" }
        }
        FxSlider {
            from: 0.1; to: 10; stepSize: 0.01
            value: Player.subtitleFPS
            onMoved: Player.subtitleFPS = value
        }

        Divider {}
        SectionTitle { text: qsTr("Appearance") }
        Row2 { label: qsTr("Subtitle Font"); visible: VLCConfig.exists("freetype-font"); ConfigBox { option: "freetype-font" } }
        Row2 { label: qsTr("Text Color"); visible: VLCConfig.exists("freetype-color"); ColorBox { option: "freetype-color" } }
        Row2 { label: qsTr("Outline Color"); visible: VLCConfig.exists("freetype-outline-color"); ColorBox { option: "freetype-outline-color" } }
    }

    // ===================================================================
    // building blocks

    component Page: ColumnLayout {
        spacing: 12 * root.dp1
        Item { Layout.preferredHeight: 4 * root.dp1 }
    }

    component SectionTitle: Text {
        Layout.topMargin: 6 * root.dp1
        color: root.titleColor
        font.pixelSize: 15 * root.dp1
    }

    component Label2: Text {
        color: root.textColor
        font.pixelSize: 13 * root.dp1
    }

    component Divider: Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: -20 * root.dp1
        Layout.rightMargin: -20 * root.dp1
        Layout.topMargin: 6 * root.dp1
        implicitHeight: 1
        color: root.dividerColor
    }

    // label on the left, controls on the right
    component Row2: RowLayout {
        property string label
        Layout.fillWidth: true
        spacing: 10 * root.dp1
        Text {
            Layout.fillWidth: true
            text: parent.label
            color: root.textColor
            font.pixelSize: 13 * root.dp1
            elide: Text.ElideRight
        }
    }

    component ValueBox: Rectangle {
        property alias text: valueText.text
        implicitWidth: 136 * root.dp1
        implicitHeight: 28 * root.dp1
        radius: 4 * root.dp1
        color: root.wellColor
        Text {
            id: valueText
            anchors { fill: parent; leftMargin: 10 * root.dp1; rightMargin: 10 * root.dp1 }
            verticalAlignment: Text.AlignVCenter
            color: root.titleColor
            font.pixelSize: 12 * root.dp1
            elide: Text.ElideRight
        }
    }

    // editable config value (text or number)
    component ConfigBox: T.TextField {
        id: configBox
        property string option
        implicitWidth: 136 * root.dp1
        implicitHeight: 28 * root.dp1
        leftPadding: 10 * root.dp1
        verticalAlignment: TextInput.AlignVCenter
        color: root.titleColor
        selectionColor: root.accentSurface
        font.pixelSize: 12 * root.dp1
        text: String(VLCConfig.value(option) ?? "")
        background: Rectangle {
            radius: 4 * root.dp1
            color: root.wellColor
            border.width: configBox.activeFocus ? 1 : 0
            border.color: root.accentColor
        }
        onEditingFinished: VLCConfig.setValue(option, text)
    }

    component ColorBox: RowLayout {
        id: colorBox
        property string option
        property string value: String(VLCConfig.value(option) ?? "#000000")
        spacing: 0
        ConfigBox {
            option: colorBox.option
            implicitWidth: 108 * root.dp1
            text: colorBox.value.toUpperCase()
            onEditingFinished: colorBox.value = String(VLCConfig.value(colorBox.option))
        }
        Rectangle {
            implicitWidth: 28 * root.dp1
            implicitHeight: 28 * root.dp1
            color: root.wellColor
            Rectangle { anchors.centerIn: parent; width: 14 * root.dp1; height: 14 * root.dp1; radius: 2 * root.dp1; color: colorBox.value }
        }
    }

    // slider of the design: thin dark track, accent fill and a 4px handle
    component FxSlider: T.Slider {
        id: slider
        property var tickLabels: []
        Layout.fillWidth: true
        implicitHeight: (tickLabels.length > 0 ? 34 : 18) * root.dp1
        live: true

        background: Item {
            Rectangle {
                id: track
                y: 4 * root.dp1
                width: slider.availableWidth
                height: 10 * root.dp1
                radius: 3 * root.dp1
                color: root.wellColor
                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: root.accentSurface
                }
                Repeater {
                    model: slider.tickLabels.length > 1 ? slider.tickLabels.length : 0
                    Rectangle {
                        required property int index
                        x: index * (track.width - 1) / (slider.tickLabels.length - 1)
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1; height: 4 * root.dp1
                        color: root.faintColor
                    }
                }
            }
            Repeater {
                model: slider.tickLabels
                Text {
                    required property var modelData
                    required property int index
                    y: 18 * root.dp1
                    x: Math.max(0, Math.min(track.width - implicitWidth,
                         index * track.width / Math.max(1, slider.tickLabels.length - 1) - implicitWidth / 2))
                    text: modelData
                    color: root.dimColor
                    font.pixelSize: 10 * root.dp1
                }
            }
        }
        handle: Rectangle {
            x: slider.visualPosition * (slider.availableWidth - width)
            y: 1 * root.dp1
            width: 5 * root.dp1
            height: 16 * root.dp1
            radius: 2 * root.dp1
            color: slider.enabled ? root.accentColor : root.faintColor
        }
    }

    // label + value + slider bound to a filter option; moving it enables
    // the filter (unless enables is false)
    component FilterSlider: ColumnLayout {
        id: fs
        property string label
        property string module
        property string option
        property bool audio: false
        property bool enables: true
        property bool boxed: false
        property string unit: ""
        property int decimals: 1
        property real from: VLCConfig.range(option)?.min ?? 0
        property real to: VLCConfig.range(option)?.max ?? 1
        property real current: option !== "" ? Number(audio ? VLCEffects.audioValue(option) : VLCEffects.videoValue(option)) : 0
        signal valueSet(real value)

        Layout.fillWidth: true
        visible: option === "" || VLCConfig.exists(option)
        spacing: 4 * root.dp1

        RowLayout {
            Text { Layout.fillWidth: true; text: fs.label; color: root.textColor; font.pixelSize: 13 * root.dp1 }
            Text {
                visible: !fs.boxed
                text: fs.current.toFixed(fs.decimals) + fs.unit
                color: root.textColor
                font.pixelSize: 13 * root.dp1
            }
            ValueBox { visible: fs.boxed; implicitWidth: 96 * root.dp1; text: fs.current.toFixed(fs.decimals) + fs.unit }
        }
        FxSlider {
            from: fs.from; to: fs.to
            stepSize: fs.decimals === 0 ? 1 : (fs.to - fs.from) / 200
            value: fs.current
            tickLabels: []
            onMoved: {
                fs.current = value
                if (fs.option === "") {
                    fs.valueSet(value)
                } else if (fs.audio) {
                    VLCEffects.setAudioValue(fs.option, value)
                } else {
                    VLCEffects.setVideoValue(fs.option, value)
                }
                if (fs.enables && fs.module !== "") {
                    if (fs.audio)
                        VLCEffects.setAudioFilterEnabled(fs.module, true)
                    else
                        VLCEffects.setVideoFilterEnabled(fs.module, true)
                }
            }
        }
    }

    // ON/OFF switch of the design
    component Switch: T.Switch {
        id: sw
        implicitWidth: 34 * root.dp1 + 26 * root.dp1
        implicitHeight: 22 * root.dp1
        indicator: Rectangle {
            anchors.fill: parent
            radius: 4 * root.dp1
            color: root.wellColor
            Rectangle {
                x: sw.checked ? parent.width - width - 2 * root.dp1 : 2 * root.dp1
                anchors.verticalCenter: parent.verticalCenter
                width: 18 * root.dp1; height: 18 * root.dp1
                radius: 3 * root.dp1
                color: sw.checked ? root.accentColor : root.faintColor
                Behavior on x { NumberAnimation { duration: VLCStyle.duration_short } }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: sw.checked ? 6 * root.dp1 : parent.width - width - 6 * root.dp1
                text: sw.checked ? qsTr("ON") : qsTr("OFF")
                color: sw.checked ? root.accentColor : root.dimColor
                font.pixelSize: 10 * root.dp1
            }
        }
    }

    component FilterToggle: Row2 {
        property string module
        property bool audio: false
        Switch {
            checked: parent.audio ? VLCEffects.audioFilterEnabled(parent.module) : VLCEffects.videoFilterEnabled(parent.module)
            onToggled: parent.audio ? VLCEffects.setAudioFilterEnabled(parent.module, checked)
                                    : VLCEffects.setVideoFilterEnabled(parent.module, checked)
        }
    }

    component OptionToggle: Row2 {
        property string option
        property bool audio: false
        visible: VLCConfig.exists(option)
        Switch {
            checked: Boolean(parent.audio ? VLCEffects.audioValue(parent.option) : VLCEffects.videoValue(parent.option))
            onToggled: parent.audio ? VLCEffects.setAudioValue(parent.option, checked)
                                    : VLCEffects.setVideoValue(parent.option, checked)
        }
    }

    // hex color value + swatch + filter toggle
    component ColorFilterRow: Row2 {
        id: cfr
        property string module
        property string option
        property string hex: {
            const v = Number(VLCEffects.videoValue(option) ?? 0)
            return "#" + ("000000" + v.toString(16).toUpperCase()).slice(-6)
        }
        visible: VLCConfig.exists(option)
        T.TextField {
            implicitWidth: 76 * root.dp1
            implicitHeight: 28 * root.dp1
            leftPadding: 8 * root.dp1
            verticalAlignment: TextInput.AlignVCenter
            color: root.titleColor
            font.pixelSize: 12 * root.dp1
            text: cfr.hex
            background: Rectangle { radius: 4 * root.dp1; color: root.wellColor }
            onEditingFinished: {
                const v = parseInt(text.replace("#", ""), 16)
                if (!isNaN(v))
                    VLCEffects.setVideoValue(cfr.option, v)
            }
        }
        Rectangle { implicitWidth: 14 * root.dp1; implicitHeight: 14 * root.dp1; radius: 2 * root.dp1; color: cfr.hex }
        Switch {
            checked: VLCEffects.videoFilterEnabled(cfr.module)
            onToggled: VLCEffects.setVideoFilterEnabled(cfr.module, checked)
        }
    }

    component PixelBox: Rectangle {
        id: pb
        property string label
        property int value: 0
        signal edited(int value)
        Layout.fillWidth: true
        implicitHeight: 28 * root.dp1
        radius: 4 * root.dp1
        color: root.wellColor
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10 * root.dp1
            anchors.rightMargin: 10 * root.dp1
            Text { text: pb.label; color: root.textColor; font.pixelSize: 12 * root.dp1 }
            T.TextField {
                Layout.fillWidth: true
                horizontalAlignment: TextInput.AlignRight
                color: root.titleColor
                font.pixelSize: 12 * root.dp1
                text: String(pb.value)
                validator: IntValidator { bottom: 0; top: 10000 }
                background: null
                onEditingFinished: pb.edited(parseInt(text) || 0)
            }
            Text { text: "px"; color: root.faintColor; font.pixelSize: 12 * root.dp1 }
        }
    }

    component LinkButton: T.Button {
        id: link
        implicitWidth: 24 * root.dp1
        implicitHeight: 28 * root.dp1
        background: null
        contentItem: Text {
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: VLCIcons.fontFamily
            font.pixelSize: 15 * root.dp1
            text: VLCIcons.link
            color: link.checked ? root.accentColor : root.textColor
        }
    }

    // dropdown bound to an option with choices; "None" entry for modules
    component Dropdown: T.Button {
        id: dd
        property string option
        property string noneText: ""
        property bool audio: false
        property bool video: false
        readonly property var choices: VLCConfig.choices(option)
        property var current: audio ? VLCEffects.audioValue(option) : video ? VLCEffects.videoValue(option) : VLCConfig.value(option)

        implicitHeight: 34 * root.dp1
        background: Rectangle { radius: 4 * root.dp1; color: dd.hovered ? root.cardColor : root.tabsColor }
        contentItem: RowLayout {
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 4 * root.dp1
                text: {
                    const found = dd.choices.find((c) => String(c.value) === String(dd.current))
                    if (found && found.value !== "" && found.value !== "any")
                        return found.text
                    return dd.noneText !== "" ? dd.noneText : (found?.text ?? String(dd.current))
                }
                color: root.titleColor
                font.pixelSize: 12 * root.dp1
                elide: Text.ElideRight
            }
            Text {
                font.family: VLCIcons.fontFamily
                font.pixelSize: 13 * root.dp1
                text: VLCIcons.chevron_down
                color: root.textColor
            }
        }
        onClicked: menu.popup(mapToGlobal(0, height + 4 * root.dp1),
                              choices.map((c) => ({ "text": c.text, "checked": String(c.value) === String(current) })))

        StringListMenu {
            id: menu
            ctx: MainCtx
            onSelected: (index, _) => {
                const value = dd.choices[index].value
                if (dd.audio) VLCEffects.setAudioValue(dd.option, value)
                else if (dd.video) VLCEffects.setVideoValue(dd.option, value)
                else VLCConfig.setValue(dd.option, value)
                dd.current = value
            }
        }
    }

    component EqualizerPreset: T.Button {
        id: eqp
        readonly property var presets: VLCEffects.equalizerPresets()
        property bool enabledEq: VLCEffects.audioFilterEnabled("equalizer")
        property string preset: String(VLCEffects.audioValue("equalizer-preset") ?? "")

        implicitHeight: 34 * root.dp1
        background: Rectangle { radius: 4 * root.dp1; color: eqp.hovered ? root.cardColor : root.tabsColor }
        contentItem: RowLayout {
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 4 * root.dp1
                text: eqp.enabledEq ? (eqp.presets.find((p) => p.name === eqp.preset)?.text ?? qsTr("Custom")) : qsTr("None")
                color: root.titleColor
                font.pixelSize: 12 * root.dp1
            }
            Text { font.family: VLCIcons.fontFamily; font.pixelSize: 13 * root.dp1; text: VLCIcons.chevron_down; color: root.textColor }
        }
        onClicked: presetMenu.popup(mapToGlobal(0, height + 4 * root.dp1),
            [{ "text": qsTr("None"), "checked": !enabledEq }].concat(
                presets.map((p) => ({ "text": p.text, "checked": enabledEq && p.name === preset }))))

        StringListMenu {
            id: presetMenu
            ctx: MainCtx
            onSelected: (index, _) => {
                if (index === 0) {
                    VLCEffects.setAudioFilterEnabled("equalizer", false)
                    eqp.enabledEq = false
                    return
                }
                const name = eqp.presets[index - 1].name
                VLCEffects.applyEqualizerPreset(name)
                VLCEffects.setAudioFilterEnabled("equalizer", true)
                eqp.enabledEq = true
                eqp.preset = name
            }
        }
    }

    // "Expand Settings >" / "Collapse Settings v" card
    component Card: ColumnLayout {
        id: card
        default property alias cardContent: inner.data
        property bool expanded: false
        Layout.fillWidth: true
        spacing: 0

        T.Button {
            id: header
            Layout.fillWidth: true
            implicitHeight: 34 * root.dp1
            background: Rectangle {
                radius: 4 * root.dp1
                color: header.hovered ? Qt.lighter(root.cardColor, 1.1) : root.cardColor
                Rectangle {
                    visible: card.expanded
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: parent.radius; color: parent.color
                }
            }
            contentItem: RowLayout {
                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4 * root.dp1
                    text: card.expanded ? qsTr("Collapse Settings") : qsTr("Expand Settings")
                    color: root.textColor
                    font.pixelSize: 12 * root.dp1
                }
                Text {
                    font.family: VLCIcons.fontFamily
                    font.pixelSize: 13 * root.dp1
                    text: card.expanded ? VLCIcons.chevron_down : VLCIcons.breadcrumb_sep
                    color: root.textColor
                }
            }
            onClicked: card.expanded = !card.expanded
        }

        Rectangle {
            Layout.fillWidth: true
            visible: card.expanded
            implicitHeight: inner.implicitHeight + 24 * root.dp1
            color: root.cardColor
            radius: 4 * root.dp1

            ColumnLayout {
                id: inner
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 * root.dp1 }
                spacing: 10 * root.dp1
            }
        }
    }

    // an audio filter: name + ON/OFF, then its card
    component AudioEffect: ColumnLayout {
        id: effect
        property string label
        property string module
        default property alias effectContent: effectCard.cardContent
        Layout.fillWidth: true
        visible: VLCConfig.moduleExists(module)
        spacing: 8 * root.dp1
        Row2 {
            label: effect.label
            Switch {
                checked: VLCEffects.audioFilterEnabled(effect.module)
                onToggled: VLCEffects.setAudioFilterEnabled(effect.module, checked)
            }
        }
        Card { id: effectCard }
    }
}
