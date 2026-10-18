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

import VLC.Dialogs
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
    height: Math.min(VLCStyle.dp(640, VLCStyle.scale), (parent?.Window.height ?? 800) - VLCStyle.dp(144, VLCStyle.scale)) // 120 + the gap above the bar
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
    readonly property color accentColor: VLCStyle.palette.orange500
    readonly property color accentSurface: dark ? VLCStyle.palette.accentBrightDark : VLCStyle.palette.accentBrightLight
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
            // T.Button has no implicit width of its own: without it the
            // layout centres a zero-wide button and the text hangs right
            implicitWidth: contentItem.implicitWidth + leftPadding + rightPadding
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
            // the settings window on the page of the current tab
            onClicked: {
                const page = ["playback", "video", "audio", "subtitles"][root.currentTab] ?? "playback"
                root.close()
                DialogsProvider.settingsPageDialog(page)
            }
        }
    }

    // ===================================================================
    // pages

    component PlaybackPage: Page {
        Row2 {
            label: qsTr("Reverse")
            visible: Player.ratechangable
            Switch {
                checked: Player.rate < 0
                onToggled: Player.reverse()
            }
        }
        Row2 {
            label: qsTr("Sleep Timer")
            SleepTimer { Layout.preferredWidth: 216 * root.dp1 }
        }
        Row2 {
            // Applies to the current playback only, like VLC's Audio >
            // Visualizations menu. The saved default is in Settings > Audio.
            label: qsTr("Audio Visualizer")
            visible: visualizerDropdown.count > 0
            VarChoiceDropdown {
                id: visualizerDropdown
                Layout.preferredWidth: 216 * root.dp1
                model: Player.audioVisualization
            }
        }
        Row2 {
            // VLC Redesign: subtitle lines on the seek bar (read by
            // SliderBar.qml); works with subtitle files, not embedded tracks
            label: qsTr("Show Subtitle Timeline on Seekbar")
            Switch {
                checked: String(VLCConfig.uiValue("Player/SubtitleTimeline", false)) === "true"
                onToggled: VLCConfig.setUiValue("Player/SubtitleTimeline", checked)
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
        Row2 {
            label: qsTr("Subtitle Offset")
            UnitBox {
                implicitWidth: 136 * root.dp1
                Layout.fillWidth: false
                unit: "px"
                value: { root.configRevision; return Number(VLCConfig.value("sub-margin") ?? 0) || 0 }
                onEdited: (v) => VLCConfig.setValue("sub-margin", v)
            }
        }

        // video 8:00: size values as "Relative" (named steps) or "Scale"
        // (numbers in percent, VLC 4 has no font size in pixels)
        Row2 {
            label: qsTr("Size Values")
            Segmented {
                options: [qsTr("Relative"), qsTr("Scale")]
                current: root.subtitleSizeScale ? 1 : 0
                onChosen: (i) => {
                    root.subtitleSizeScale = (i === 1)
                    VLCConfig.setUiValue("Player/SubtitleSizeValues", root.subtitleSizeScale ? "scale" : "relative")
                }
            }
        }

        // ---- relative: sliders with named steps
        StepSlider {
            visible: !root.subtitleSizeScale
            label: qsTr("Font Size")
            steps: [10, 50, 75, 100, 150, 200, 300]
            names: [qsTr("Tiny"), qsTr("Smaller"), qsTr("Small"), qsTr("Normal"), qsTr("Large"), qsTr("Larger"), qsTr("Huge")]
            value: root.textScale
            onChosen: (v) => root.setTextScale(v)
        }
        StepSlider {
            visible: !root.subtitleSizeScale && VLCConfig.exists("freetype-outline-thickness")
            label: qsTr("Outline Thickness")
            steps: [0, 2, 4, 6]
            names: [qsTr("None"), qsTr("Thin"), qsTr("Normal"), qsTr("Thick")]
            value: { root.configRevision; return Number(VLCConfig.value("freetype-outline-thickness") ?? 4) }
            onChosen: (v) => root.setSubtitleOption("freetype-outline-thickness", v)
        }
        StepSlider {
            visible: !root.subtitleSizeScale && VLCConfig.exists("freetype-background-opacity")
            label: qsTr("Background Opacity")
            steps: [0, 64, 128, 191, 255]
            names: ["0 %", "25 %", "50 %", "75 %", "100 %"]
            value: { root.configRevision; return Number(VLCConfig.value("freetype-background-opacity") ?? 0) }
            onChosen: (v) => root.setSubtitleOption("freetype-background-opacity", v)
        }

        // ---- scale: numbers
        Row2 {
            visible: root.subtitleSizeScale
            label: qsTr("Font Size")
            UnitBox {
                implicitWidth: 136 * root.dp1
                Layout.fillWidth: false
                unit: "%"
                maxValue: 500
                value: root.textScale
                onEdited: (v) => root.setTextScale(v)
            }
        }
        Row2 {
            visible: root.subtitleSizeScale && VLCConfig.exists("freetype-outline-thickness")
            label: qsTr("Outline Thickness")
            UnitBox {
                implicitWidth: 136 * root.dp1
                Layout.fillWidth: false
                unit: "%"
                maxValue: 50
                value: { root.configRevision; return Number(VLCConfig.value("freetype-outline-thickness") ?? 4) }
                onEdited: (v) => root.setSubtitleOption("freetype-outline-thickness", Math.min(50, v))
            }
        }
        Row2 {
            visible: root.subtitleSizeScale && VLCConfig.exists("freetype-background-opacity")
            label: qsTr("Background Opacity")
            UnitBox {
                implicitWidth: 136 * root.dp1
                Layout.fillWidth: false
                unit: "%"
                maxValue: 100
                value: { root.configRevision; return Math.round(Number(VLCConfig.value("freetype-background-opacity") ?? 0) * 100 / 255) }
                onEdited: (v) => root.setSubtitleOption("freetype-background-opacity", Math.round(Math.min(100, v) * 255 / 100))
            }
        }

        // video 8:30: the subtitle settings saved as presets (per show)
        SubtitlePresetCard { Layout.topMargin: 6 * root.dp1 }
    }

    // ---- subtitle settings: size values, presets ------------------------

    // bumped when subtitle options change from a preset, so that the fields
    // read them again
    property int configRevision: 0
    property bool subtitleSizeScale: String(VLCConfig.uiValue("Player/SubtitleSizeValues", "relative")) === "scale"
    property int textScale: 100

    onOpened: textScale = Player.getSubtitleTextScale()

    function setTextScale(v) {
        textScale = Math.max(10, Math.min(500, v))
        Player.setSubtitleTextScale(textScale)
        VLCConfig.setValue("sub-text-scale", textScale)
    }

    // the text renderer reads these options for every subtitle: they apply
    // at once
    function setSubtitleOption(option, value) {
        VLCConfig.setValue(option, value)
        configRevision++
    }

    readonly property var presetOptions: ["freetype-font", "freetype-color", "freetype-outline-color",
                                          "freetype-outline-thickness", "freetype-background-opacity",
                                          "sub-margin", "sub-language"]

    function loadPresets() {
        try {
            const list = JSON.parse(VLCConfig.uiValue("Player/SubtitlePresets", "[]"))
            return Array.isArray(list) ? list : []
        } catch (e) {
            return []
        }
    }

    function savePresets(list) {
        VLCConfig.setUiValue("Player/SubtitlePresets", JSON.stringify(list))
    }

    function currentSubtitleSettings(name) {
        const values = {}
        for (const option of presetOptions)
            if (VLCConfig.exists(option))
                values[option] = VLCConfig.value(option)
        return { "name": name, "values": values, "textScale": textScale,
                 "delay": Player.subtitleDelayMS, "sizeValues": subtitleSizeScale ? "scale" : "relative" }
    }

    function applyPreset(preset) {
        for (const option in preset.values)
            if (VLCConfig.exists(option))
                VLCConfig.setValue(option, preset.values[option])
        if (preset.textScale !== undefined)
            setTextScale(preset.textScale)
        if (preset.delay !== undefined)
            Player.subtitleDelayMS = preset.delay
        subtitleSizeScale = preset.sizeValues === "scale"
        VLCConfig.setUiValue("Player/SubtitleSizeValues", preset.sizeValues ?? "relative")
        VLCConfig.setUiValue("Player/SubtitlePreset", preset.name)
        configRevision++
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
        text: { root.configRevision; return String(VLCConfig.value(option) ?? "") }
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
        property string value: { root.configRevision; return String(VLCConfig.value(option) ?? "#000000") }
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

    // number field with a unit ("px", "%")
    component UnitBox: Rectangle {
        id: ub
        property int value: 0
        property string unit: "px"
        property int maxValue: 10000
        signal edited(int value)
        Layout.fillWidth: true
        implicitHeight: 28 * root.dp1
        radius: 4 * root.dp1
        color: root.wellColor
        border.width: ubField.activeFocus ? 1 : 0
        border.color: root.accentColor
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10 * root.dp1
            anchors.rightMargin: 10 * root.dp1
            T.TextField {
                id: ubField
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: TextInput.AlignVCenter
                color: root.titleColor
                selectionColor: root.accentSurface
                font.pixelSize: 12 * root.dp1
                text: String(ub.value)
                validator: IntValidator { bottom: 0; top: ub.maxValue }
                background: null
                onEditingFinished: ub.edited(parseInt(text) || 0)
            }
            Text { text: ub.unit; color: root.faintColor; font.pixelSize: 12 * root.dp1 }
        }
    }

    // two-way choice ("Relative" | "Scale"), the chosen one in the accent
    component Segmented: Row {
        id: seg
        property var options: []
        property int current: 0
        signal chosen(int index)
        spacing: 0
        Repeater {
            model: seg.options
            T.Button {
                id: segButton
                required property var modelData
                required property int index
                readonly property bool selected: index === seg.current
                implicitWidth: 68 * root.dp1
                implicitHeight: 28 * root.dp1
                background: Rectangle {
                    radius: 4 * root.dp1
                    color: segButton.selected ? root.accentSurface : root.wellColor
                }
                contentItem: Text {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: segButton.modelData
                    font.pixelSize: 12 * root.dp1
                    color: segButton.selected ? root.accentColor : root.textColor
                }
                onClicked: seg.chosen(index)
            }
        }
    }

    // title, name of the current step on the right, slider over the steps
    component StepSlider: ColumnLayout {
        id: ss
        property string label
        property var steps: []
        property var names: []
        property real value: 0
        signal chosen(real value)
        readonly property int index: {
            let best = 0
            for (let i = 1; i < steps.length; ++i)
                if (Math.abs(steps[i] - value) < Math.abs(steps[best] - value))
                    best = i
            return best
        }
        Layout.fillWidth: true
        spacing: 6 * root.dp1
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: ss.label
                color: root.textColor
                font.pixelSize: 13 * root.dp1
            }
            Text {
                // the exact value when it is between two steps
                text: ss.steps[ss.index] === ss.value ? (ss.names[ss.index] ?? "") : (Math.round(ss.value) + "")
                color: root.textColor
                font.pixelSize: 12 * root.dp1
            }
        }
        FxSlider {
            from: 0
            to: Math.max(1, ss.steps.length - 1)
            stepSize: 1
            snapMode: T.Slider.SnapAlways
            value: ss.index
            onMoved: ss.chosen(ss.steps[Math.round(value)])
        }
    }

    // preset of the subtitle settings: name and chevron, a menu to apply,
    // save, rename or delete presets
    component SubtitlePresetCard: Rectangle {
        id: pc
        property var presets: root.loadPresets()
        property string current: String(VLCConfig.uiValue("Player/SubtitlePreset", ""))
        readonly property bool hasCurrent: presets.some((p) => p.name === current)

        Layout.fillWidth: true
        implicitHeight: 40 * root.dp1
        radius: 4 * root.dp1
        color: pcMouse.hovered ? root.cardColor : root.tabsColor

        function _newName() {
            for (let i = 1; ; ++i) {
                const name = qsTr("Custom Preset %1").arg(String(i).padStart(2, "0"))
                if (!presets.some((p) => p.name === name))
                    return name
            }
        }

        function _store(list) {
            root.savePresets(list)
            presets = list
        }

        HoverHandler { id: pcMouse }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10 * root.dp1
            anchors.rightMargin: 10 * root.dp1

            T.TextField {
                id: nameField
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: TextInput.AlignVCenter
                readOnly: !pc.hasCurrent
                color: pc.hasCurrent ? root.titleColor : root.textColor
                selectionColor: root.accentSurface
                font.pixelSize: 13 * root.dp1
                text: pc.hasCurrent ? pc.current : qsTr("No Subtitle Preset")
                background: null
                // rename the current preset
                onEditingFinished: {
                    const name = text.trim()
                    if (!pc.hasCurrent || name === "" || name === pc.current
                            || pc.presets.some((p) => p.name === name)) {
                        text = Qt.binding(() => pc.hasCurrent ? pc.current : qsTr("No Subtitle Preset"))
                        return
                    }
                    pc._store(pc.presets.map((p) => p.name === pc.current ? Object.assign({}, p, { "name": name }) : p))
                    VLCConfig.setUiValue("Player/SubtitlePreset", name)
                    pc.current = name
                }
            }

            T.Button {
                id: pcChevron
                implicitWidth: 28 * root.dp1
                implicitHeight: 28 * root.dp1
                background: null
                contentItem: Text {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: VLCIcons.fontFamily
                    font.pixelSize: 13 * root.dp1
                    text: VLCIcons.chevron_down
                    color: root.textColor
                }
                Accessible.name: qsTr("Subtitle presets")
                onClicked: {
                    const items = pc.presets.map((p) => ({ "text": p.name, "checked": p.name === pc.current }))
                    if (items.length > 0)
                        items.push({ "separator": true })
                    items.push({ "text": qsTr("Save as New Preset") })
                    if (pc.hasCurrent) {
                        items.push({ "text": qsTr("Update \"%1\"").arg(pc.current) })
                        items.push({ "text": qsTr("Delete \"%1\"").arg(pc.current) })
                    }
                    presetMenu.popup(pc.mapToGlobal(0, pc.height + 4 * root.dp1), items)
                }
            }
        }

        StringListMenu {
            id: presetMenu
            ctx: MainCtx
            onSelected: (index, _) => {
                const n = pc.presets.length
                if (index < n) {
                    root.applyPreset(pc.presets[index])
                    pc.current = pc.presets[index].name
                    return
                }
                // the separator is not counted by the menu
                const action = index - n
                if (action === 0) {
                    const name = pc._newName()
                    pc._store(pc.presets.concat([root.currentSubtitleSettings(name)]))
                    VLCConfig.setUiValue("Player/SubtitlePreset", name)
                    pc.current = name
                } else if (action === 1) {
                    pc._store(pc.presets.map((p) => p.name === pc.current ? root.currentSubtitleSettings(p.name) : p))
                } else if (action === 2) {
                    pc._store(pc.presets.filter((p) => p.name !== pc.current))
                    VLCConfig.setUiValue("Player/SubtitlePreset", "")
                    pc.current = ""
                }
            }
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
                Layout.fillHeight: true
                verticalAlignment: TextInput.AlignVCenter
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
    // Dropdown over a VLC object variable (VLCVarChoiceModel): the choice
    // applies to the current playback and is not saved in the preferences.
    component VarChoiceDropdown: T.Button {
        id: vd
        property var model: null
        property int _revision: 0
        readonly property int count: { _revision; return model ? model.rowCount() : 0 }
        readonly property int currentIndex: {
            _revision
            for (let i = 0; i < count; ++i) {
                if (model.data(model.index(i, 0), Qt.CheckStateRole))
                    return i
            }
            return -1
        }

        function itemText(i) {
            return model.data(model.index(i, 0), Qt.DisplayRole)
        }

        Connections {
            target: vd.model
            function onDataChanged() { vd._revision++ }
            function onModelReset() { vd._revision++ }
            function onRowsInserted() { vd._revision++ }
            function onRowsRemoved() { vd._revision++ }
        }

        implicitHeight: 34 * root.dp1
        background: Rectangle { radius: 4 * root.dp1; color: vd.hovered ? root.cardColor : root.tabsColor }
        contentItem: RowLayout {
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 4 * root.dp1
                text: vd.currentIndex >= 0 ? vd.itemText(vd.currentIndex) : ""
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
        onClicked: {
            const items = []
            for (let i = 0; i < count; ++i)
                items.push({ "text": itemText(i), "checked": i === currentIndex })
            varMenu.popup(mapToGlobal(0, height + 4 * root.dp1), items)
        }

        StringListMenu {
            id: varMenu
            ctx: MainCtx
            onSelected: (index, _) => vd.model.toggleIndex(index)
        }
    }

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

    // pauses playback after a delay (VLCEffects keeps the timer running)
    component SleepTimer: T.Button {
        id: st
        readonly property var minutes: [0, 15, 30, 45, 60, 90, 120]
        function label(m) { return m === 0 ? qsTr("Off") : qsTr("%1 min").arg(m) }

        implicitHeight: 34 * root.dp1
        background: Rectangle { radius: 4 * root.dp1; color: st.hovered ? root.cardColor : root.tabsColor }
        contentItem: RowLayout {
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 4 * root.dp1
                text: st.label(VLCEffects.sleepMinutes)
                color: root.titleColor
                font.pixelSize: 12 * root.dp1
            }
            Text { font.family: VLCIcons.fontFamily; font.pixelSize: 13 * root.dp1; text: VLCIcons.chevron_down; color: root.textColor }
        }
        onClicked: sleepMenu.popup(mapToGlobal(0, height + 4 * root.dp1),
                                   minutes.map((m) => ({ "text": label(m), "checked": m === VLCEffects.sleepMinutes })))

        StringListMenu {
            id: sleepMenu
            ctx: MainCtx
            onSelected: (index, _) => VLCEffects.setSleepTimer(st.minutes[index])
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
                // Figma EQ preset icons (:/menu/figma/eq_<preset>.svg)
                presets.map((p) => ({ "text": p.text, "icon": "eq_" + p.name,
                                      "checked": enabledEq && p.name === preset }))))

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
