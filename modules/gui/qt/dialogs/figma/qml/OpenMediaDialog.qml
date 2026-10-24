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

// VLC's Open Media window in the style of the redesign's dialogs (no Figma
// frame): File, Disc, Network and Capture Device tabs with the Figma "Open"
// menu icons, "More Options" (caching, start / stop time, extra media,
// options), Enqueue, and Play with Stream / Convert in its menu. The MRLs
// and options are the ones of the classic dialog (dialogs/open).
FigmaDialog {
    id: root

    title: qsTr("Open Media")

    width: VLCStyle.dp(880, VLCStyle.scale)
    height: VLCStyle.dp(650, VLCStyle.scale)

    showButtons: false

    readonly property var _tabs: ["file", "disc", "network", "capture"]
    property int currentTab: 0
    // opened to add to the queue (playlist "Add"): Enqueue is the main button
    property bool enqueueMode: false

    property bool moreOptions: false

    // tab icons: grey with accent details when selected, all dim otherwise
    readonly property color iconColor: dark ? "#8F8F8F" : "#2E2E2E"
    readonly property color accentDimColor: VLCStyle.palette.accentDim
    readonly property real labelWidth: VLCStyle.dp(180, VLCStyle.scale)

    // args: { tab: "file" | "disc" | "network" | "capture", enqueue: bool }
    function reset(args) {
        const tab = _tabs.indexOf(args?.tab ?? "file")
        currentTab = tab >= 0 ? tab : 0
        enqueueMode = args?.enqueue ?? false
        moreOptions = VLCConfig.uiValue("OpenDialog/advanced", false) === true
                   || VLCConfig.uiValue("OpenDialog/advanced", false) === "true"

        files = []
        subtitleCheck.checked = false
        subtitleUrl = ""
        urls.text = ""
        discDevices = VLCOpenMedia.discDevices()
        _setDiscType(discType)
        titleField.text = ""
        chapterField.text = ""
        audioTrackField.text = ""
        subTrackField.text = ""
        startField.text = ""
        stopField.text = ""
        slaveCheck.checked = false
        slaveField.text = ""
        extraField.text = ""
        _resetCaching()
        _refreshCapture()
        _focusTab()
    }

    function _focusTab() {
        if (currentTab === 2)
            urls.forceActiveFocus()
        else
            tabBar.forceActiveFocus()
    }

    onCurrentTabChanged: {
        _resetCaching()
        if (currentTab === 3)
            _refreshCapture()
        if (currentTab === 1)
            discDevices = VLCOpenMedia.discDevices()
    }

    onMoreOptionsChanged: VLCConfig.setUiValue("OpenDialog/advanced", moreOptions)

    // ---- result: MRLs and options ---------------------------------------

    function _escape(s) {
        return String(s).replace(/:/g, "\\:")
    }

    // "1:02:03.5", "2:03" or "45" -> seconds, -1 when invalid or empty
    function _seconds(text) {
        const t = text.trim()
        if (t === "")
            return -1
        const parts = t.split(":")
        if (parts.length > 3)
            return -1
        let total = 0
        for (const part of parts) {
            const v = Number(part)
            if (part === "" || isNaN(v) || v < 0)
                return -1
            total = total * 60 + v
        }
        return total
    }

    readonly property string cachingMethod: ["file-caching", "disc-caching", "network-caching", "live-caching"][currentTab]

    function _resetCaching() {
        cachingField.text = String(VLCConfig.value(cachingMethod) ?? "")
    }

    function _build() {
        let mrls = []
        let options = []

        switch (currentTab) {
        case 0:
            mrls = files.slice()
            if (subtitleCheck.checked && subtitleUrl !== "")
                options.push(":sub-file=" + VLCOpenMedia.optionPath(subtitleUrl))
            break
        case 1: {
            const d = _discMrl()
            if (d.mrl !== "")
                mrls = [d.mrl]
            options = d.options
            break
        }
        case 2:
            mrls = urls.text.split(/\s+/).filter((u) => u !== "").map((u) => VLCOpenMedia.fixupUrl(u))
                                                                 .filter((u) => u !== "")
            break
        case 3: {
            const c = _captureMrl()
            mrls = c.mrls
            options = c.options
            break
        }
        }

        // more options
        if (moreOptions) {
            if (slaveCheck.checked && slaveField.text.trim() !== "")
                options.push(":input-slave=" + slaveField.text.trim())
            const caching = parseInt(cachingField.text)
            if (!isNaN(caching) && caching >= 0 && String(caching) !== String(VLCConfig.value(cachingMethod)))
                options.push(":" + cachingMethod + "=" + caching)
            const start = _seconds(startField.text)
            const stop = _seconds(stopField.text)
            if (start > 0)
                options.push(":start-time=" + start.toFixed(3))
            if (stop > 0 && stop > Math.max(start, 0))
                options.push(":stop-time=" + stop.toFixed(3))
            // as typed, separated by " :" like the classic dialog
            const extra = extraField.text.trim()
            if (extra !== "")
                for (const o of (" " + extra).split(" :"))
                    if (o.trim() !== "")
                        options.push(":" + o.trim().replace(/^:/, ""))
        }
        return { "mrls": mrls, "options": options }
    }

    // the binding follows every value _build() reads
    readonly property var result: { captureRevision; return _build() }

    readonly property bool canOpen: result.mrls.length > 0

    function _open(play) {
        if (!canOpen)
            return
        VLCOpenMedia.open(result.mrls, result.options, play)
        close()
    }

    function _stream(convert) {
        if (!canOpen)
            return
        const r = result
        close()
        // the classic wizards wait for their answer: after this window is gone
        Qt.callLater(() => VLCOpenMedia.stream(r.mrls, r.options, convert))
    }

    // ---- File ---------------------------------------------------------------

    property var files: []
    property string subtitleUrl: ""

    function _addFiles(list) {
        const merged = files.slice()
        for (const url of list) {
            const s = url.toString()
            if (merged.indexOf(s) < 0)
                merged.push(s)
        }
        files = merged
    }

    function _fileName(url) {
        const path = decodeURIComponent(url.toString())
        return path.substring(path.lastIndexOf("/") + 1) || path
    }

    // ---- Disc ---------------------------------------------------------------

    // id, label, scheme; dvda has no menus option
    readonly property var _discTypes: [
        { "id": "dvd", "text": qsTr("DVD") },
        { "id": "bluray", "text": qsTr("Blu-ray") },
        { "id": "cdda", "text": qsTr("Audio CD") },
        { "id": "vcd", "text": qsTr("SVCD/VCD") },
        { "id": "dvda", "text": qsTr("DVD-Audio") }
    ]
    property string discType: "dvd"
    property var discDevices: []

    function _setDiscType(type) {
        discType = type
        // the drive of the preferences for this kind of disc, as the classic dialog
        const option = (type === "vcd") ? "vcd" : (type === "cdda") ? "cd-audio" : "dvd"
        const configured = VLCConfig.exists(option) ? String(VLCConfig.value(option) ?? "") : ""
        let device = configured
        for (const d of discDevices) {
            if (configured !== "" && d.value.startsWith(configured)) {
                device = d.text
                break
            }
        }
        if (device === "" && discDevices.length > 0)
            device = discDevices[0].text
        deviceField.text = device
        if (type === "bluray")
            noMenusCheck.checked = !VLCConfig.value("bluray-menu")
    }

    function _discDevicePath() {
        const text = deviceField.text.trim()
        for (const d of discDevices)
            if (d.text === text)
                return d.value
        return text
    }

    function _discMrl() {
        const type = discType
        const scheme = (type === "dvd" && noMenusCheck.checked) ? "dvdsimple" : type
        const mrl = VLCOpenMedia.discMrl(_discDevicePath(), scheme)
        if (mrl === "")
            return { "mrl": "", "options": [] }

        const title = parseInt(titleField.text)
        const chapter = parseInt(chapterField.text)
        let anchor = ""
        if (title > 0) {
            if (type === "dvd" || type === "bluray" || type === "dvda") {
                anchor = "#" + title
                if (chapter > 0 && type !== "bluray")
                    anchor += ":" + chapter
            } else if (type === "vcd") {
                anchor = "#" + title
            }
        }

        const options = []
        if (type === "dvd" || type === "vcd") {
            const audio = parseInt(audioTrackField.text)
            const sub = parseInt(subTrackField.text)
            if (audio >= 0)
                options.push(":audio-track=" + audio)
            if (sub >= 0)
                options.push(":sub-track=" + sub)
        } else if (type === "cdda") {
            if (title > 0)
                options.push(":cdda-track=" + title)
        } else if (type === "bluray") {
            if (noMenusCheck.checked)
                options.push(":no-bluray-menu")
        }
        return { "mrl": mrl + anchor, "options": options }
    }

    // ---- Capture -------------------------------------------------------------

    readonly property bool _windows: MainCtx.osName === MainCtx.Windows

    readonly property var captureModes: {
        const modes = []
        if (_windows) {
            if (VLCConfig.moduleExists("dshow"))
                modes.push({ "id": "dshow", "text": qsTr("DirectShow") })
        } else {
            if (VLCConfig.moduleExists("v4l2"))
                modes.push({ "id": "v4l2", "text": qsTr("Video Camera") })
            if (VLCConfig.moduleExists("jack"))
                modes.push({ "id": "jack", "text": qsTr("JACK Audio") })
        }
        if (VLCConfig.moduleExists("dtv"))
            modes.push({ "id": "dtv", "text": qsTr("TV - Digital") })
        if (!_windows && VLCConfig.moduleExists("v4l2"))
            modes.push({ "id": "pvr", "text": qsTr("TV - Analog") })
        modes.push({ "id": "screen", "text": qsTr("Desktop") })
        return modes
    }
    property string captureMode: captureModes.length > 0 ? captureModes[0].id : "screen"
    // bumped when a capture value that is not a text field changes
    property int captureRevision: 0

    property var dshowVideoDevices: []
    property var dshowAudioDevices: []
    property string dshowVideo: ""
    property string dshowAudio: ""
    property var videoStandards: []
    property string videoStandard: ""
    property string dvbSystem: "dvb-t"
    property var dvbBandwidths: []
    property var dvbBandwidth: 0
    property string dvbQam: "QAM"
    property string dvbPsk: "QPSK"
    property bool jackPace: false
    property bool jackConnect: false

    readonly property var _dvbSystems: [
        { "id": "dvb-c", "text": "DVB-C" }, { "id": "dvb-s", "text": "DVB-S" },
        { "id": "dvb-s2", "text": "DVB-S2" }, { "id": "dvb-t", "text": "DVB-T" },
        { "id": "dvb-t2", "text": "DVB-T2" }, { "id": "atsc", "text": "ATSC" },
        { "id": "cqam", "text": qsTr("Clear QAM") }
    ]
    readonly property var _qamModes: [
        { "value": "QAM", "text": qsTr("Automatic") }, { "value": "256QAM", "text": "256-QAM" },
        { "value": "128QAM", "text": "128-QAM" }, { "value": "64QAM", "text": "64-QAM" },
        { "value": "32QAM", "text": "32-QAM" }, { "value": "16QAM", "text": "16-QAM" }
    ]
    readonly property var _pskModes: [
        { "value": "QPSK", "text": "QPSK" }, { "value": "DQPSK", "text": "DQPSK" },
        { "value": "8PSK", "text": "8-PSK" }, { "value": "16APSK", "text": "16-APSK" },
        { "value": "32APSK", "text": "32-APSK" }
    ]

    function _refreshCapture() {
        if (_windows && VLCConfig.exists("dshow-vdev")) {
            dshowVideoDevices = VLCConfig.choices("dshow-vdev")
            dshowAudioDevices = VLCConfig.choices("dshow-adev")
            dshowVideo = String(VLCConfig.value("dshow-vdev") ?? "")
            dshowAudio = String(VLCConfig.value("dshow-adev") ?? "")
        }
        if (VLCConfig.exists("v4l2-standard")) {
            videoStandards = VLCConfig.choices("v4l2-standard")
            videoStandard = String(VLCConfig.value("v4l2-standard") ?? "")
        }
        if (VLCConfig.exists("dvb-bandwidth")) {
            dvbBandwidths = VLCConfig.choices("dvb-bandwidth")
            dvbBandwidth = VLCConfig.value("dvb-bandwidth") ?? 0
        }
        if (VLCConfig.exists("screen-fps") && screenFpsField.text === "")
            screenFpsField.text = String(VLCConfig.value("screen-fps"))
        const videos = VLCOpenMedia.videoDevices()
        videoDeviceField.suggestions = videos
        pvrDeviceField.suggestions = videos
        const alsa = VLCOpenMedia.alsaDevices()
        audioDeviceField.suggestions = alsa
        pvrAudioField.suggestions = alsa
        if (videoDeviceField.text === "" && videos.length > 0)
            videoDeviceField.text = videos[0]
        if (pvrDeviceField.text === "" && videos.length > 0)
            pvrDeviceField.text = videos[0]
        captureRevision++
    }

    function _captureMrl() {
        const mrls = []
        const options = []
        switch (captureMode) {
        case "dshow":
            mrls.push("dshow://")
            options.push(":dshow-vdev=" + _escape(dshowVideo))
            options.push(":dshow-adev=" + _escape(dshowAudio))
            if (dshowSizeField.text.trim() !== "")
                options.push(":dshow-size=" + dshowSizeField.text.trim())
            break
        case "v4l2":
            mrls.push("v4l2://" + videoDeviceField.text.trim())
            if (videoStandard !== "")
                options.push(":v4l2-standard=" + videoStandard)
            if (audioDeviceField.text.trim() !== "")
                options.push(":input-slave=alsa://" + audioDeviceField.text.trim())
            break
        case "jack":
            mrls.push("jack://channels=" + (parseInt(jackChannelsField.text) || 2)
                      + ":ports=" + (jackPortsField.text || ".*"))
            if (jackPace)
                options.push(":jack-input-use-vlc-pace")
            if (jackConnect)
                options.push(":jack-input-auto-connect")
            break
        case "pvr": {
            mrls.push("v4l2://" + pvrDeviceField.text.trim())
            if (videoStandard !== "")
                options.push(":v4l2-standard=" + videoStandard)
            const freq = parseInt(pvrFreqField.text)
            if (freq > 0)
                options.push(":v4l2-tuner-frequency=" + freq)
            if (pvrAudioField.text.trim() !== "")
                options.push(":input-slave=alsa://" + pvrAudioField.text.trim())
            break
        }
        case "dtv": {
            const sys = dvbSystem
            let mrl = sys + "://frequency=" + (parseInt(dvbFreqField.text) || 0) + "000"
            if (sys === "dvb-c" || sys === "cqam")
                mrl += ":modulation=" + dvbQam
            if (sys === "dvb-s2")
                mrl += ":modulation=" + dvbPsk
            if (sys === "dvb-c" || sys === "dvb-s" || sys === "dvb-s2")
                mrl += ":srate=" + (parseInt(dvbSrateField.text) || 0)
            if (sys === "dvb-t" || sys === "dvb-t2")
                mrl += ":bandwidth=" + dvbBandwidth
            mrls.push(mrl)
            options.push(":dvb-adapter=" + (parseInt(dvbCardField.text) || 0))
            break
        }
        case "screen": {
            mrls.push("screen://")
            const fps = parseFloat(screenFpsField.text)
            if (fps > 0)
                options.push(":screen-fps=" + fps)
            break
        }
        }
        return { "mrls": mrls, "options": options }
    }

    // ---- header: tabs ---------------------------------------------------------

    headerContent: Row {
        id: tabBar

        width: parent.width
        height: VLCStyle.dp(38, VLCStyle.scale)
        spacing: VLCStyle.dp(4, VLCStyle.scale)
        focus: true

        Keys.onLeftPressed: root.currentTab = Math.max(0, root.currentTab - 1)
        Keys.onRightPressed: root.currentTab = Math.min(3, root.currentTab + 1)

        Repeater {
            model: [
                { "text": qsTr("File"), "icon": "main_open_file_s" },
                { "text": qsTr("Disc"), "icon": "main_open_disc" },
                { "text": qsTr("Network"), "icon": "main_open_network_stream" },
                { "text": qsTr("Capture Device"), "icon": "main_open_capture_device" }
            ]

            delegate: T.TabButton {
                id: tab

                required property var modelData
                required property int index

                height: tabBar.height
                leftPadding: VLCStyle.dp(12, VLCStyle.scale)
                rightPadding: VLCStyle.dp(12, VLCStyle.scale)
                checked: root.currentTab === index
                focusPolicy: Qt.NoFocus
                onClicked: root.currentTab = index

                background: Item {
                    Rectangle {
                        anchors.fill: parent
                        anchors.bottomMargin: VLCStyle.dp(2, VLCStyle.scale)
                        radius: VLCStyle.dp(6, VLCStyle.scale)
                        color: tab.hovered && !tab.checked ? root.surfaceColor : "transparent"
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                                  leftMargin: VLCStyle.dp(4, VLCStyle.scale); rightMargin: VLCStyle.dp(4, VLCStyle.scale) }
                        height: VLCStyle.dp(2, VLCStyle.scale)
                        visible: tab.checked
                        color: root.accentColor
                    }
                }
                contentItem: Row {
                    spacing: VLCStyle.dp(8, VLCStyle.scale)

                    // Figma menu icon: two-tone when selected
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: VLCStyle.dp(20, VLCStyle.scale)
                        height: width
                        sourceSize: Qt.size(width * 2, height * 2)
                        source: SVGColorImage.colorize("qrc:///menu/figma/" + tab.modelData.icon + ".svg")
                                    .any({
                                        "#8F8F8F": tab.checked ? root.iconColor : root.dimColor,
                                        "#AB6314": tab.checked ? root.accentDimColor : root.dimColor
                                    }).uri()
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.modelData.text
                        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                        color: tab.checked ? root.titleColor : root.dimColor
                    }
                }
            }
        }
    }

    // ---- pages -----------------------------------------------------------------

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Flickable {
            id: flick

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: pageColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            T.ScrollBar.vertical: T.ScrollBar {
                policy: flick.contentHeight > flick.height ? T.ScrollBar.AlwaysOn : T.ScrollBar.AlwaysOff
                contentItem: Rectangle {
                    implicitWidth: VLCStyle.dp(4, VLCStyle.scale)
                    radius: width / 2
                    color: root.dividerColor
                }
            }

            ColumnLayout {
                id: pageColumn

                width: flick.width - VLCStyle.dp(12, VLCStyle.scale)
                spacing: VLCStyle.dp(16, VLCStyle.scale)

                // File
                ColumnLayout {
                    visible: root.currentTab === 0
                    Layout.fillWidth: true
                    spacing: VLCStyle.dp(16, VLCStyle.scale)

                    FigmaDialog.SectionHeader {
                        title: qsTr("Files")
                        description: qsTr("Drag files into the box or click here to select files.")
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: VLCStyle.dp(200, VLCStyle.scale)
                        radius: root.radius
                        color: dropArea.containsDrag ? Qt.lighter(root.wellColor, 1.6) : root.wellColor

                        DashedBorder {
                            anchors.fill: parent
                            radius: root.radius
                            dash: 4
                            gap: 3
                            color: root.dark ? "#2D2D2D" : "#9B9B9B"
                        }

                        DropArea {
                            id: dropArea

                            anchors.fill: parent
                            onDropped: (drop) => {
                                if (drop.hasUrls)
                                    root._addFiles(drop.urls)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._addFiles(VLCConfig.browseFiles(qsTr("Select Files")))
                        }

                        Column {
                            anchors.centerIn: parent
                            visible: root.files.length === 0
                            spacing: VLCStyle.dp(16, VLCStyle.scale)

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("No files selected.")
                                color: root.placeholderColor
                                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                            }

                            FigmaDialog.PlusButton {
                                anchors.horizontalCenter: parent.horizontalCenter
                                implicitWidth: VLCStyle.dp(84, VLCStyle.scale)
                                onClicked: root._addFiles(VLCConfig.browseFiles(qsTr("Select Files")))
                            }
                        }

                        ListView {
                            anchors.fill: parent
                            anchors.margins: VLCStyle.dp(13, VLCStyle.scale)
                            visible: root.files.length > 0
                            clip: true
                            model: root.files
                            spacing: VLCStyle.dp(6, VLCStyle.scale)

                            delegate: Item {
                                required property var modelData
                                required property int index

                                width: ListView.view.width
                                height: VLCStyle.dp(24, VLCStyle.scale)

                                Text {
                                    anchors { left: parent.left; right: remove.left; verticalCenter: parent.verticalCenter }
                                    text: root._fileName(modelData)
                                    color: root.textColor
                                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                                    elide: Text.ElideMiddle
                                }

                                FigmaDialog.CloseButton {
                                    id: remove

                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                    implicitWidth: VLCStyle.dp(24, VLCStyle.scale)
                                    implicitHeight: VLCStyle.dp(24, VLCStyle.scale)
                                    onClicked: {
                                        const list = root.files.slice()
                                        list.splice(index, 1)
                                        root.files = list
                                    }
                                }
                            }
                        }
                    }

                    FigmaDialog.Divider { Layout.fillWidth: true }

                    FigmaDialog.SectionHeader {
                        title: qsTr("Subtitle File")
                        suffix: qsTr("(optional)")
                        description: qsTr("Loaded with the files above.")
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: VLCStyle.dp(10, VLCStyle.scale)
                        enabled: root.files.length > 0

                        CheckBox {
                            id: subtitleCheck
                        }

                        FigmaDialog.TextField {
                            Layout.fillWidth: true
                            readOnly: true
                            enabled: subtitleCheck.checked
                            text: root.subtitleUrl !== "" ? VLCOpenMedia.displayPath(root.subtitleUrl) : ""
                            placeholderText: qsTr("Use a subtitle file")
                        }

                        FigmaDialog.Button {
                            text: qsTr("Browse...")
                            enabled: subtitleCheck.checked
                            onClicked: {
                                const list = VLCConfig.browseFiles(qsTr("Open subtitle file"))
                                if (list.length > 0)
                                    root.subtitleUrl = list[0].toString()
                            }
                        }
                    }
                }

                // Disc
                ColumnLayout {
                    visible: root.currentTab === 1
                    Layout.fillWidth: true
                    spacing: VLCStyle.dp(16, VLCStyle.scale)

                    FigmaDialog.SectionHeader {
                        title: qsTr("Disc Type")
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: VLCStyle.dp(8, VLCStyle.scale)

                        Repeater {
                            model: root._discTypes
                            delegate: Choice {
                                required property var modelData
                                text: modelData.text
                                checked: root.discType === modelData.id
                                onClicked: root._setDiscType(modelData.id)
                            }
                        }
                    }

                    FigmaDialog.Divider { Layout.fillWidth: true }

                    FigmaDialog.SectionHeader {
                        title: qsTr("Disc Device")
                        description: MainCtx.osName === MainCtx.Windows
                                     ? qsTr("Select a drive or a VIDEO_TS folder.")
                                     : qsTr("Select a device or a VIDEO_TS directory.")
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: VLCStyle.dp(10, VLCStyle.scale)

                        ComboField {
                            id: deviceField
                            Layout.fillWidth: true
                            suggestions: root.discDevices.map((d) => d.text)
                        }

                        FigmaDialog.Button {
                            text: qsTr("Browse...")
                            onClicked: {
                                const url = VLCConfig.browseFolder(qsTr("Select a device or a VIDEO_TS folder"))
                                if (url !== "")
                                    deviceField.text = VLCOpenMedia.displayPath(url)
                            }
                        }

                        FigmaDialog.Button {
                            text: qsTr("Eject")
                            onClicked: VLCOpenMedia.eject(root._discDevicePath())
                        }
                    }

                    CheckRow {
                        id: noMenusCheck
                        visible: root.discType === "dvd" || root.discType === "bluray"
                        text: qsTr("No disc menus")
                    }

                    FigmaDialog.Divider { Layout.fillWidth: true }

                    FigmaDialog.SectionHeader {
                        title: qsTr("Starting Position")
                    }

                    FormRow {
                        label: root.discType === "cdda" ? qsTr("Track")
                             : root.discType === "vcd" ? qsTr("Entry") : qsTr("Title")
                        NumberField { id: titleField }
                    }

                    FormRow {
                        visible: root.discType === "dvd" || root.discType === "dvda"
                        label: qsTr("Chapter")
                        NumberField { id: chapterField }
                    }

                    FigmaDialog.SectionHeader {
                        visible: root.discType === "dvd" || root.discType === "vcd"
                        Layout.topMargin: VLCStyle.dp(4, VLCStyle.scale)
                        title: qsTr("Audio and Subtitles")
                    }

                    FormRow {
                        visible: root.discType === "dvd" || root.discType === "vcd"
                        label: qsTr("Audio track")
                        NumberField { id: audioTrackField }
                    }

                    FormRow {
                        visible: root.discType === "dvd" || root.discType === "vcd"
                        label: qsTr("Subtitle track")
                        NumberField { id: subTrackField }
                    }
                }

                // Network
                ColumnLayout {
                    visible: root.currentTab === 2
                    Layout.fillWidth: true
                    spacing: VLCStyle.dp(16, VLCStyle.scale)

                    FigmaDialog.SectionHeader {
                        title: qsTr("Network URL")
                        description: qsTr("You can enter multiple links to load.")
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: VLCStyle.dp(192, VLCStyle.scale)
                        radius: root.radius
                        color: root.wellColor
                        border.width: 1
                        border.color: urls.activeFocus ? root.accentColor : root.panelColor

                        Flickable {
                            id: urlFlick

                            anchors.fill: parent
                            anchors.margins: VLCStyle.dp(13, VLCStyle.scale)
                            contentHeight: urls.implicitHeight
                            clip: true

                            T.TextArea {
                                id: urls

                                width: urlFlick.width
                                wrapMode: TextEdit.WrapAnywhere
                                color: root.titleColor
                                selectionColor: root.accentSurface
                                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                                placeholderText: qsTr("e.g., https://www.example.com/stream.avi")

                                Text {
                                    visible: urls.text === ""
                                    text: urls.placeholderText
                                    color: root.placeholderColor
                                    font: urls.font
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: root.dimColor
                        font.pixelSize: VLCStyle.dp(13, VLCStyle.scale)
                        text: qsTr("For example: http://www.example.com/stream.avi, rtp://@:1234, mms://mms.examples.com/stream.asx, rtsp://server.example.org:8080/test.sdp")
                    }
                }

                // Capture Device
                ColumnLayout {
                    visible: root.currentTab === 3
                    Layout.fillWidth: true
                    spacing: VLCStyle.dp(16, VLCStyle.scale)

                    FigmaDialog.SectionHeader {
                        title: qsTr("Capture Mode")
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: VLCStyle.dp(8, VLCStyle.scale)

                        Repeater {
                            model: root.captureModes
                            delegate: Choice {
                                required property var modelData
                                text: modelData.text
                                checked: root.captureMode === modelData.id
                                onClicked: root.captureMode = modelData.id
                            }
                        }
                    }

                    FigmaDialog.Divider { Layout.fillWidth: true }

                    // DirectShow (Windows)
                    FormRow {
                        visible: root.captureMode === "dshow"
                        label: qsTr("Video device")
                        Dropdown {
                            Layout.fillWidth: true
                            model: root.dshowVideoDevices
                            value: root.dshowVideo
                            onActivated: (v) => root.dshowVideo = v
                        }
                    }
                    FormRow {
                        visible: root.captureMode === "dshow"
                        label: qsTr("Audio device")
                        Dropdown {
                            Layout.fillWidth: true
                            model: root.dshowAudioDevices
                            value: root.dshowAudio
                            onActivated: (v) => root.dshowAudio = v
                        }
                    }
                    FormRow {
                        visible: root.captureMode === "dshow"
                        label: qsTr("Video size")
                        FigmaDialog.TextField {
                            id: dshowSizeField
                            Layout.preferredWidth: VLCStyle.dp(200, VLCStyle.scale)
                            placeholderText: qsTr("e.g., 1280x720")
                        }
                    }

                    // Video camera (V4L2)
                    FormRow {
                        visible: root.captureMode === "v4l2"
                        label: qsTr("Video device")
                        ComboField { id: videoDeviceField; Layout.fillWidth: true }
                    }
                    FormRow {
                        visible: root.captureMode === "v4l2"
                        label: qsTr("Audio device")
                        ComboField {
                            id: audioDeviceField
                            Layout.fillWidth: true
                            placeholderText: qsTr("None")
                        }
                    }

                    // JACK
                    FormRow {
                        visible: root.captureMode === "jack"
                        label: qsTr("Selected ports")
                        FigmaDialog.TextField {
                            id: jackPortsField
                            Layout.fillWidth: true
                            text: ".*"
                        }
                    }
                    FormRow {
                        visible: root.captureMode === "jack"
                        label: qsTr("Channels")
                        NumberField { id: jackChannelsField; text: "2"; placeholderText: "2" }
                    }
                    CheckRow {
                        visible: root.captureMode === "jack"
                        text: qsTr("Use VLC pace")
                        checked: root.jackPace
                        onToggled: root.jackPace = checked
                    }
                    CheckRow {
                        visible: root.captureMode === "jack"
                        text: qsTr("Auto connection")
                        checked: root.jackConnect
                        onToggled: root.jackConnect = checked
                    }

                    // TV - analog
                    FormRow {
                        visible: root.captureMode === "pvr"
                        label: qsTr("Device name")
                        ComboField { id: pvrDeviceField; Layout.fillWidth: true }
                    }
                    FormRow {
                        visible: root.captureMode === "pvr"
                        label: qsTr("Audio device")
                        ComboField {
                            id: pvrAudioField
                            Layout.fillWidth: true
                            placeholderText: qsTr("None")
                        }
                    }
                    FormRow {
                        visible: root.captureMode === "pvr"
                        label: qsTr("Frequency")
                        NumberField { id: pvrFreqField; unit: qsTr("kHz") }
                    }

                    // video standard: camera and analog TV
                    FormRow {
                        visible: (root.captureMode === "v4l2" || root.captureMode === "pvr")
                                 && root.videoStandards.length > 0
                        label: qsTr("Video standard")
                        Dropdown {
                            Layout.preferredWidth: VLCStyle.dp(260, VLCStyle.scale)
                            model: root.videoStandards
                            value: root.videoStandard
                            onActivated: (v) => root.videoStandard = v
                        }
                    }

                    // TV - digital
                    FormRow {
                        visible: root.captureMode === "dtv"
                        label: qsTr("Tuner card")
                        NumberField {
                            id: dvbCardField
                            text: "0"
                            prefix: MainCtx.osName === MainCtx.Windows ? "" : "/dev/dvb/adapter"
                        }
                    }
                    FormRow {
                        visible: root.captureMode === "dtv"
                        label: qsTr("Delivery system")
                        Flow {
                            Layout.fillWidth: true
                            spacing: VLCStyle.dp(8, VLCStyle.scale)
                            Repeater {
                                model: root._dvbSystems
                                delegate: Choice {
                                    required property var modelData
                                    text: modelData.text
                                    checked: root.dvbSystem === modelData.id
                                    onClicked: root.dvbSystem = modelData.id
                                }
                            }
                        }
                    }
                    FormRow {
                        visible: root.captureMode === "dtv"
                        label: qsTr("Frequency")
                        NumberField { id: dvbFreqField; unit: qsTr("kHz") }
                    }
                    FormRow {
                        visible: root.captureMode === "dtv"
                                 && (root.dvbSystem === "dvb-c" || root.dvbSystem === "dvb-s" || root.dvbSystem === "dvb-s2")
                        label: qsTr("Symbol rate")
                        NumberField { id: dvbSrateField; unit: qsTr("bauds") }
                    }
                    FormRow {
                        visible: root.captureMode === "dtv"
                                 && (root.dvbSystem === "dvb-c" || root.dvbSystem === "cqam" || root.dvbSystem === "dvb-s2")
                        label: qsTr("Modulation")
                        Dropdown {
                            Layout.preferredWidth: VLCStyle.dp(200, VLCStyle.scale)
                            model: root.dvbSystem === "dvb-s2" ? root._pskModes : root._qamModes
                            value: root.dvbSystem === "dvb-s2" ? root.dvbPsk : root.dvbQam
                            onActivated: (v) => {
                                if (root.dvbSystem === "dvb-s2")
                                    root.dvbPsk = v
                                else
                                    root.dvbQam = v
                            }
                        }
                    }
                    FormRow {
                        visible: root.captureMode === "dtv"
                                 && (root.dvbSystem === "dvb-t" || root.dvbSystem === "dvb-t2")
                                 && root.dvbBandwidths.length > 0
                        label: qsTr("Bandwidth")
                        Dropdown {
                            Layout.preferredWidth: VLCStyle.dp(200, VLCStyle.scale)
                            model: root.dvbBandwidths
                            value: root.dvbBandwidth
                            onActivated: (v) => root.dvbBandwidth = v
                        }
                    }

                    // Desktop
                    Text {
                        visible: root.captureMode === "screen"
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: root.dimColor
                        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                        text: qsTr("Your display will be opened and played in order to stream or save it.")
                    }
                    FormRow {
                        visible: root.captureMode === "screen"
                        label: qsTr("Frame rate")
                        NumberField {
                            id: screenFpsField
                            unit: qsTr("f/s")
                            decimals: true
                        }
                    }
                }

                // More Options
                ColumnLayout {
                    visible: root.moreOptions
                    Layout.fillWidth: true
                    spacing: VLCStyle.dp(16, VLCStyle.scale)

                    FigmaDialog.Divider { Layout.fillWidth: true }

                    FigmaDialog.SectionHeader {
                        title: qsTr("More Options")
                    }

                    FormRow {
                        label: qsTr("Caching")
                        NumberField { id: cachingField; unit: qsTr("ms") }
                    }

                    FormRow {
                        label: qsTr("Start time")
                        FigmaDialog.TextField {
                            id: startField
                            Layout.preferredWidth: VLCStyle.dp(140, VLCStyle.scale)
                            placeholderText: "00:00:00"
                        }
                    }

                    FormRow {
                        label: qsTr("Stop time")
                        FigmaDialog.TextField {
                            id: stopField
                            Layout.preferredWidth: VLCStyle.dp(140, VLCStyle.scale)
                            placeholderText: "00:00:00"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: VLCStyle.dp(10, VLCStyle.scale)

                        CheckRow {
                            id: slaveCheck
                            Layout.preferredWidth: root.labelWidth
                            text: qsTr("Extra media")
                        }

                        FigmaDialog.TextField {
                            id: slaveField
                            Layout.fillWidth: true
                            enabled: slaveCheck.checked
                            placeholderText: qsTr("Play another media synchronously (extra audio file, ...)")
                        }

                        FigmaDialog.Button {
                            text: qsTr("Browse...")
                            enabled: slaveCheck.checked
                            onClicked: {
                                const list = VLCConfig.browseFiles(qsTr("Select the file"))
                                if (list.length > 0)
                                    slaveField.text = list[0].toString()
                            }
                        }
                    }

                    FormRow {
                        label: qsTr("Edit options")
                        FigmaDialog.TextField {
                            id: extraField
                            Layout.fillWidth: true
                            placeholderText: qsTr("e.g., :option=value :other-option")
                        }
                    }

                    FormRow {
                        label: qsTr("MRL")
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            color: root.textColor
                            font.pixelSize: VLCStyle.dp(13, VLCStyle.scale)
                            text: root.result.mrls.concat(root.result.options).join(" ")
                        }
                    }
                }

                Item { Layout.preferredHeight: VLCStyle.dp(4, VLCStyle.scale) }
            }
        }

        // ---- buttons ----------------------------------------------------------

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: VLCStyle.dp(14, VLCStyle.scale)
            spacing: VLCStyle.dp(10, VLCStyle.scale)

            FigmaDialog.Button {
                text: root.cancelText
                onClicked: root.reject()
            }

            // flat: text and chevron
            T.Button {
                id: moreButton

                implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
                leftPadding: VLCStyle.dp(10, VLCStyle.scale)
                rightPadding: VLCStyle.dp(6, VLCStyle.scale)
                onClicked: root.moreOptions = !root.moreOptions

                background: Rectangle {
                    radius: VLCStyle.dp(6, VLCStyle.scale)
                    color: moreButton.hovered ? root.surfaceColor : "transparent"
                }
                contentItem: Row {
                    spacing: VLCStyle.dp(4, VLCStyle.scale)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("More Options")
                        color: root.textColor
                        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: VLCIcons.fontFamily
                        font.pixelSize: VLCStyle.icon_small
                        text: root.moreOptions ? VLCIcons.chevron_up : VLCIcons.chevron_down
                        color: root.textColor
                    }
                }
            }

            Item { Layout.fillWidth: true }

            FigmaDialog.Button {
                text: root.enqueueMode ? qsTr("Play") : qsTr("Enqueue")
                enabled: root.canOpen
                onClicked: root._open(root.enqueueMode)
            }

            // main button and its menu (Stream, Convert)
            Row {
                spacing: 1

                FigmaDialog.Button {
                    primary: true
                    text: root.enqueueMode ? qsTr("Enqueue") : qsTr("Play")
                    enabled: root.canOpen
                    onClicked: root._open(!root.enqueueMode)
                }

                FigmaDialog.Button {
                    id: menuButton

                    primary: true
                    enabled: root.canOpen
                    implicitWidth: VLCStyle.dp(32, VLCStyle.scale)
                    contentItem: Text {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: VLCIcons.fontFamily
                        font.pixelSize: VLCStyle.icon_small
                        text: VLCIcons.chevron_down
                        color: menuButton.enabled ? root.accentColor : root.placeholderColor
                    }
                    onClicked: actionMenu.popup(mapToGlobal(0, height + VLCStyle.dp(4, VLCStyle.scale)), [
                        { "text": qsTr("Stream...") },
                        { "text": qsTr("Convert / Save...") }
                    ])

                    StringListMenu {
                        id: actionMenu
                        ctx: MainCtx
                        onSelected: (index, _) => root._stream(index === 1)
                    }
                }
            }
        }
    }

    // ---- components -------------------------------------------------------------

    // label on the left, controls on the right
    component FormRow: RowLayout {
        property string label

        Layout.fillWidth: true
        spacing: VLCStyle.dp(10, VLCStyle.scale)

        Text {
            Layout.preferredWidth: root.labelWidth
            text: parent.label
            color: root.dimColor
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            elide: Text.ElideRight
        }
    }

    // selectable chip (disc type, capture mode): accent when selected
    component Choice: T.Button {
        id: choice

        checkable: false
        implicitHeight: VLCStyle.dp(34, VLCStyle.scale)
        implicitWidth: Math.max(VLCStyle.dp(90, VLCStyle.scale), label.implicitWidth + VLCStyle.dp(28, VLCStyle.scale))

        background: Rectangle {
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: choice.checked ? root.accentSurface
                 : choice.hovered ? (root.dark ? Qt.lighter(root.surfaceColor, 1.3) : Qt.darker(root.surfaceColor, 1.06))
                 : root.surfaceColor
            border.width: choice.visualFocus ? VLCStyle.focus_border : 0
            border.color: root.accentColor
        }
        contentItem: Text {
            id: label
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: choice.text
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            font.weight: choice.checked ? Font.DemiBold : Font.Normal
            color: choice.checked ? root.accentColor : root.textColor
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

    // check box and its text
    component CheckRow: T.CheckBox {
        id: checkRow

        implicitHeight: VLCStyle.dp(24, VLCStyle.scale)
        implicitWidth: box.width + spacing + rowText.implicitWidth
        spacing: VLCStyle.dp(10, VLCStyle.scale)

        indicator: Rectangle {
            id: box
            anchors.verticalCenter: parent.verticalCenter
            width: VLCStyle.dp(16, VLCStyle.scale)
            height: width
            radius: VLCStyle.dp(3, VLCStyle.scale)
            color: checkRow.checked ? root.accentSurface : "transparent"
            border.width: 1.5
            border.color: checkRow.checked ? root.accentColor : (checkRow.enabled ? root.textColor : root.placeholderColor)

            Text {
                anchors.centerIn: parent
                visible: checkRow.checked
                font.family: VLCIcons.fontFamily
                font.pixelSize: VLCStyle.dp(12, VLCStyle.scale)
                text: VLCIcons.check
                color: root.accentColor
            }
        }
        contentItem: Text {
            id: rowText
            leftPadding: box.width + checkRow.spacing
            verticalAlignment: Text.AlignVCenter
            text: checkRow.text
            color: checkRow.enabled ? root.textColor : root.placeholderColor
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            elide: Text.ElideRight
        }
    }

    // whole numbers (or decimals), with an optional prefix and unit
    component NumberField: RowLayout {
        id: numberField

        property alias text: numberInput.text
        property alias placeholderText: numberInput.placeholderText
        property string unit: ""
        property string prefix: ""
        property bool decimals: false

        spacing: VLCStyle.dp(8, VLCStyle.scale)

        Text {
            visible: parent.prefix !== ""
            text: parent.prefix
            color: root.dimColor
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
        }

        FigmaDialog.TextField {
            id: numberInput
            Layout.preferredWidth: VLCStyle.dp(140, VLCStyle.scale)
            placeholderText: qsTr("Default")
            validator: RegularExpressionValidator {
                regularExpression: numberField.decimals ? /[0-9]*[.,]?[0-9]*/ : /-?[0-9]*/
            }
        }

        Text {
            visible: parent.unit !== ""
            text: parent.unit
            color: root.dimColor
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
        }
    }

    // choice among { value, text } items
    component Dropdown: T.Button {
        id: dropdown

        property var model: []
        property var value
        signal activated(var value)

        readonly property var _current: model.find((m) => String(m.value) === String(value))

        implicitWidth: VLCStyle.dp(200, VLCStyle.scale)
        implicitHeight: VLCStyle.dp(35, VLCStyle.scale)

        background: Rectangle {
            radius: root.radius
            color: dropdown.hovered ? Qt.lighter(root.wellColor, root.dark ? 1.6 : 0.98) : root.wellColor
            border.width: dropdown.visualFocus ? 1 : 0
            border.color: root.accentColor
        }
        contentItem: RowLayout {
            spacing: VLCStyle.dp(6, VLCStyle.scale)
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: VLCStyle.dp(13, VLCStyle.scale)
                text: dropdown._current ? dropdown._current.text : String(dropdown.value ?? "")
                color: root.titleColor
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                elide: Text.ElideRight
            }
            Text {
                Layout.rightMargin: VLCStyle.dp(8, VLCStyle.scale)
                font.family: VLCIcons.fontFamily
                font.pixelSize: VLCStyle.icon_small
                text: VLCIcons.chevron_down
                color: root.textColor
            }
        }

        onClicked: dropdownMenu.popup(mapToGlobal(0, height + VLCStyle.dp(4, VLCStyle.scale)),
                                      model.map((m) => ({ "text": m.text || String(m.value), "checked": String(m.value) === String(value) })))

        StringListMenu {
            id: dropdownMenu
            ctx: MainCtx
            onSelected: (index, _) => {
                const item = dropdown.model[index]
                if (item !== undefined)
                    dropdown.activated(item.value)
            }
        }
    }

    // text field with a list of suggestions (devices)
    component ComboField: FigmaDialog.TextField {
        id: combo

        property var suggestions: []

        rightPadding: VLCStyle.dp(36, VLCStyle.scale)

        T.Button {
            id: comboButton

            visible: combo.suggestions.length > 0
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: VLCStyle.dp(34, VLCStyle.scale)
            focusPolicy: Qt.NoFocus

            background: Rectangle {
                radius: root.radius
                color: comboButton.hovered ? root.surfaceColor : "transparent"
            }
            contentItem: Text {
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: VLCIcons.fontFamily
                font.pixelSize: VLCStyle.icon_small
                text: VLCIcons.chevron_down
                color: root.textColor
            }
            onClicked: comboMenu.popup(combo.mapToGlobal(0, combo.height + VLCStyle.dp(4, VLCStyle.scale)),
                                       combo.suggestions.map((s) => ({ "text": s, "checked": s === combo.text })))
        }

        StringListMenu {
            id: comboMenu
            ctx: MainCtx
            onSelected: (index, _) => combo.text = combo.suggestions[index] ?? combo.text
        }
    }
}
