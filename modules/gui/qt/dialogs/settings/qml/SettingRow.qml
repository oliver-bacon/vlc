/*****************************************************************************
 * Copyright (C) 2026 the VideoLAN team
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
import VLC.Util

// One line of the settings window: a label (with the option's own
// description as a tooltip) on the left and a control on the right,
// styled after the "VLC Redesign" Figma file.
FocusScope {
    id: root

    // Row description, see SettingsModel.qml
    required property var row

    signal actionRequested(string action)

    readonly property string option: row.option ?? ""
    readonly property string kind: row.kind ?? ""

    // Whether the row can be shown in this build
    readonly property bool available: {
        if (kind === "colorScheme" || kind === "action")
            return true
        if (kind === "filter")
            return VLCConfig.exists(row.list) && VLCConfig.moduleExists(row.module)
        return VLCConfig.exists(option)
    }

    readonly property string type: (option !== "") ? VLCConfig.type(option) : ""
    readonly property var choices: (option !== "" && kind !== "accent") ? VLCConfig.choices(option) : []
    readonly property var range: (option !== "") ? VLCConfig.range(option) : ({})

    // Current value, refreshed when the option changes from anywhere
    property var value: _read()

    function _read() {
        if (kind === "filter")
            return VLCConfig.hasModule(row.list, row.module)
        if (option === "")
            return undefined
        return VLCConfig.value(option)
    }

    function write(newValue) {
        if (kind === "filter")
            VLCConfig.setModule(row.list, row.module, newValue)
        else if (option !== "")
            VLCConfig.setValue(option, newValue)
    }

    Connections {
        target: VLCConfig
        function onValueChanged(name) {
            if (name === root.option || name === root.row.list)
                root.value = root._read()
        }
    }

    // The control used for this row
    readonly property Component _control: {
        switch (kind) {
        case "colorScheme": return colorSchemeComponent
        case "accent": return accentComponent
        case "filter": return toggleComponent
        case "action": return actionComponent
        case "slider": return sliderComponent
        case "number": return numberComponent
        }
        switch (type) {
        case "bool": return toggleComponent
        case "file":
        case "directory": return pathComponent
        case "rgb": return textComponent
        }
        if (choices.length > 0)
            return (choices.length <= 3 && type !== "module") ? segmentedComponent : dropdownComponent
        if ((type === "int" || type === "float") && range.min !== undefined && (range.max - range.min) <= 1000)
            return sliderComponent
        if (type === "int" || type === "float")
            return numberComponent
        return textComponent
    }

    visible: available

    implicitWidth: rowLayout.implicitWidth
    implicitHeight: available ? Math.max(VLCStyle.dp(46, VLCStyle.scale), rowLayout.implicitHeight) : 0

    readonly property real controlWidth: VLCStyle.dp(320, VLCStyle.scale)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.View
    }

    readonly property ColorContext windowColorContext: ColorContext {
        id: windowTheme
        colorSet: ColorContext.Window
    }

    readonly property ColorContext itemColorContext: ColorContext {
        id: itemTheme
        colorSet: ColorContext.Item
    }

    // Figma colors expressed with palette roles:
    // well (#090909), surface (#191919), selected (#371F06)
    readonly property color _well: windowTheme.bg.secondary
    readonly property color _surface: windowTheme.bg.primary
    readonly property color _selected: itemTheme.bg.highlight
    readonly property color _text: theme.fg.secondary
    readonly property color _mutedText: Qt.alpha(theme.fg.secondary, 0.7)
    readonly property real _radius: VLCStyle.dp(6, VLCStyle.scale)

    RowLayout {
        id: rowLayout

        anchors.fill: parent
        spacing: VLCStyle.margin_normal

        RowLayout {
            Layout.fillWidth: true
            spacing: VLCStyle.margin_xsmall

            T.Label {
                // Natural width; the layout shrinks it (and it elides) only
                // when the window is too narrow for the label and the control
                text: root.row.label
                color: root._text
                font.pixelSize: VLCStyle.fontSize_large
                elide: Text.ElideRight
            }

            // Info icon with the option's description from VLC itself
            T.Label {
                id: infoIcon

                visible: root.option !== "" && VLCConfig.longText(root.option) !== ""
                text: VLCIcons.info
                font.family: VLCIcons.fontFamily
                font.pixelSize: VLCStyle.dp(18, VLCStyle.scale)
                color: infoHover.hovered ? root._text : root._mutedText

                HoverHandler { id: infoHover }

                T.ToolTip {
                    id: infoTip

                    visible: infoHover.hovered
                    delay: VLCStyle.delayToolTipAppear
                    text: root.option !== "" ? VLCConfig.longText(root.option) : ""

                    width: Math.min(implicitWidth, VLCStyle.dp(360, VLCStyle.scale))
                    padding: VLCStyle.margin_xsmall

                    contentItem: T.Label {
                        text: infoTip.text
                        color: theme.fg.primary
                        wrapMode: Text.Wrap
                        font.pixelSize: VLCStyle.fontSize_normal
                    }
                    background: Rectangle {
                        color: windowTheme.bg.primary
                        radius: VLCStyle.dp(4, VLCStyle.scale)
                    }
                }
            }
        }

        Loader {
            id: controlLoader

            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            focus: true
            active: root.available
            sourceComponent: root._control
        }
    }

    // ------------------------------------------------------------------
    // Controls

    // ON/OFF switch (Figma "Toggle": 68x32)
    Component {
        id: toggleComponent

        T.AbstractButton {
            id: toggle

            checkable: true
            checked: !!root.value
            onToggled: root.write(checked)

            implicitWidth: VLCStyle.dp(68, VLCStyle.scale)
            implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

            Accessible.role: Accessible.CheckBox
            Accessible.name: root.row.label

            readonly property real _inset: VLCStyle.dp(3, VLCStyle.scale)
            readonly property real _knob: height - 2 * _inset

            background: Rectangle {
                color: root._well
                radius: root._radius
                border.width: toggle.visualFocus ? VLCStyle.focus_border : 0
                border.color: theme.visualFocus

                // Label half
                Rectangle {
                    x: toggle.checked ? toggle._inset : (toggle.width - width - toggle._inset)
                    anchors.verticalCenter: parent.verticalCenter
                    width: toggle.width - toggle._knob - 3 * toggle._inset
                    height: toggle._knob
                    radius: VLCStyle.dp(3, VLCStyle.scale)
                    color: toggle.checked ? root._selected : root._surface

                    T.Label {
                        anchors.centerIn: parent
                        text: toggle.checked ? qsTr("ON") : qsTr("OFF")
                        font.pixelSize: VLCStyle.fontSize_normal
                        color: toggle.checked ? theme.accent : root._mutedText
                    }
                }

                // Knob
                Rectangle {
                    x: toggle.checked ? (toggle.width - width - toggle._inset) : toggle._inset
                    anchors.verticalCenter: parent.verticalCenter
                    width: toggle._knob
                    height: toggle._knob
                    radius: VLCStyle.dp(3, VLCStyle.scale)
                    color: toggle.checked ? Qt.darker(theme.accent, 1.23) : theme.border

                    Behavior on x {
                        NumberAnimation { duration: VLCStyle.duration_veryShort; easing.type: Easing.InOutSine }
                    }
                }
            }
        }
    }

    // Drop-down list (Figma "Dropdown": 320x36, inner 32px surface)
    Component {
        id: dropdownComponent

        T.ComboBox {
            id: combo

            implicitWidth: root.controlWidth
            implicitHeight: VLCStyle.dp(36, VLCStyle.scale)

            model: root.choices
            textRole: "text"
            valueRole: "value"

            Component.onCompleted: currentIndex = indexOfValue(root.value)
            Connections {
                target: root
                function onValueChanged() { combo.currentIndex = combo.indexOfValue(root.value) }
            }

            onActivated: (index) => root.write(valueAt(index))

            Accessible.name: root.row.label

            background: Rectangle {
                color: root._well
                radius: root._radius
                border.width: combo.visualFocus ? VLCStyle.focus_border : 0
                border.color: theme.visualFocus

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: VLCStyle.dp(2, VLCStyle.scale)
                    radius: VLCStyle.dp(4, VLCStyle.scale)
                    color: combo.hovered ? Qt.lighter(root._surface, 1.2) : root._surface
                }
            }

            contentItem: T.Label {
                leftPadding: VLCStyle.dp(14, VLCStyle.scale)
                rightPadding: VLCStyle.dp(14, VLCStyle.scale) + VLCStyle.icon_normal
                verticalAlignment: Text.AlignVCenter
                text: (combo.currentIndex >= 0) ? combo.displayText : String(root.value ?? "")
                color: root._text
                font.pixelSize: VLCStyle.fontSize_large
                elide: Text.ElideRight
            }

            indicator: T.Label {
                x: combo.width - width - VLCStyle.dp(10, VLCStyle.scale)
                anchors.verticalCenter: combo.verticalCenter
                text: VLCIcons.chevron_down
                font.family: VLCIcons.fontFamily
                font.pixelSize: VLCStyle.icon_normal
                color: root._text
            }

            delegate: T.ItemDelegate {
                required property var modelData
                required property int index

                width: combo.width - VLCStyle.dp(4, VLCStyle.scale)
                implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
                highlighted: combo.highlightedIndex === index

                contentItem: T.Label {
                    leftPadding: VLCStyle.dp(12, VLCStyle.scale)
                    verticalAlignment: Text.AlignVCenter
                    text: modelData.text
                    color: (combo.currentIndex === index) ? theme.accent : root._text
                    font.pixelSize: VLCStyle.fontSize_large
                    elide: Text.ElideRight
                }
                background: Rectangle {
                    radius: VLCStyle.dp(4, VLCStyle.scale)
                    color: parent.highlighted ? root._surface : "transparent"
                }
            }

            popup: T.Popup {
                y: combo.height + VLCStyle.dp(2, VLCStyle.scale)
                width: combo.width
                implicitHeight: Math.min(contentItem.implicitHeight + 2 * padding, VLCStyle.dp(320, VLCStyle.scale))
                padding: VLCStyle.dp(2, VLCStyle.scale)

                contentItem: ListView {
                    clip: true
                    implicitHeight: contentHeight
                    model: combo.popup.visible ? combo.delegateModel : null
                    currentIndex: combo.highlightedIndex
                }

                background: Rectangle {
                    color: root._well
                    radius: root._radius
                    border.width: VLCStyle.border
                    border.color: windowTheme.border
                }
            }
        }
    }

    // Segmented choice (Figma "Values": up to three options side by side)
    Component {
        id: segmentedComponent

        Rectangle {
            id: segmented

            implicitWidth: root.controlWidth
            implicitHeight: VLCStyle.dp(36, VLCStyle.scale)
            color: root._well
            radius: root._radius

            property var options: root.choices
            property var current: root.value
            signal picked(var value)
            onPicked: (v) => root.write(v)

            RowLayout {
                anchors.fill: parent
                anchors.margins: VLCStyle.dp(2, VLCStyle.scale)
                spacing: VLCStyle.dp(2, VLCStyle.scale)

                Repeater {
                    model: segmented.options

                    T.AbstractButton {
                        id: segment

                        required property var modelData

                        readonly property bool selected: modelData.value == segmented.current

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        onClicked: segmented.picked(modelData.value)

                        Accessible.role: Accessible.RadioButton
                        Accessible.name: modelData.text

                        background: Rectangle {
                            radius: VLCStyle.dp(4, VLCStyle.scale)
                            color: segment.selected ? root._selected : root._surface
                            border.width: segment.visualFocus ? VLCStyle.focus_border : 0
                            border.color: theme.visualFocus
                        }
                        contentItem: T.Label {
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: segment.modelData.text
                            elide: Text.ElideRight
                            font.pixelSize: VLCStyle.fontSize_large
                            color: segment.selected ? theme.accent : root._mutedText
                        }
                    }
                }
            }
        }
    }

    // Day / Night / System, stored by the interface rather than the core
    Component {
        id: colorSchemeComponent

        Loader {
            sourceComponent: segmentedComponent
            onLoaded: {
                item.options = [
                    { value: 2, text: qsTr("Dark") },
                    { value: 1, text: qsTr("Light") },
                    { value: 0, text: qsTr("System") }
                ]
                item.current = Qt.binding(() => MainCtx.colorScheme.scheme)
                // root.write() ignores this row (it has no option); the
                // scheme is changed through the interface model instead
                item.picked.connect((v) => {
                    const model = MainCtx.colorScheme
                    model.setData(model.index(v, 0), true, Qt.CheckStateRole)
                })
            }
        }
    }

    // Accent color swatches (Figma presets); applied on next start
    Component {
        id: accentComponent

        Rectangle {
            id: swatches

            implicitWidth: root.controlWidth
            implicitHeight: VLCStyle.dp(36, VLCStyle.scale)
            color: root._well
            radius: root._radius

            // "default" keeps the built-in accent (the first swatch)
            readonly property var presets: ["default", "#E15032", "#C49E23", "#19A234",
                                            "#18AAD3", "#185DD3", "#8E42FF", "#F052B3", "#AFAFAF"]

            RowLayout {
                anchors.fill: parent
                anchors.margins: VLCStyle.dp(2, VLCStyle.scale)
                spacing: VLCStyle.dp(4, VLCStyle.scale)

                Repeater {
                    model: swatches.presets

                    T.AbstractButton {
                        id: swatch

                        required property string modelData
                        required property int index

                        readonly property bool selected: String(root.value).toLowerCase() === modelData.toLowerCase()

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        onClicked: root.write(modelData)

                        Accessible.role: Accessible.RadioButton
                        Accessible.name: (index === 0) ? qsTr("Default") : modelData

                        background: Rectangle {
                            radius: VLCStyle.dp(4, VLCStyle.scale)
                            color: swatch.selected ? root._selected : "transparent"
                            border.width: swatch.visualFocus ? VLCStyle.focus_border : 0
                            border.color: theme.visualFocus

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: VLCStyle.dp(6, VLCStyle.scale)
                                radius: VLCStyle.dp(1, VLCStyle.scale)
                                // The first swatch shows the built-in VLC orange
                                color: (swatch.index === 0) ? "#D37918" : swatch.modelData
                                opacity: swatch.selected ? 1.0 : 0.7
                            }
                        }
                    }
                }
            }

            T.Label {
                anchors.top: parent.bottom
                anchors.right: parent.right
                anchors.topMargin: VLCStyle.dp(2, VLCStyle.scale)
                visible: String(root.value) !== String(swatches._initial)
                text: qsTr("Applies after restarting VLC")
                font.pixelSize: VLCStyle.fontSize_small
                color: root._mutedText
            }

            readonly property var _initial: VLCConfig.value(root.option)
        }
    }

    // Slider with tick marks (Figma "range": 16px track, 8x24 handle)
    Component {
        id: sliderComponent

        ColumnLayout {
            id: sliderColumn

            spacing: VLCStyle.dp(4, VLCStyle.scale)

            readonly property real scale: root.row.scale ?? 1
            readonly property real from: root.row.min ?? ((root.range.min ?? 0) / scale)
            readonly property real to: root.row.max ?? ((root.range.max ?? 100) / scale)
            readonly property real step: root.row.step ?? ((root.type === "int" && scale === 1) ? 1 : 0)
            readonly property string unit: root.row.unit ?? ""

            function format(v) {
                const rounded = Math.round(v * 100) / 100
                return rounded + (unit !== "" ? " " + unit : "")
            }

            T.Slider {
                id: slider

                Layout.preferredWidth: root.controlWidth
                implicitHeight: VLCStyle.dp(24, VLCStyle.scale)

                from: sliderColumn.from
                to: sliderColumn.to
                stepSize: sliderColumn.step
                snapMode: (stepSize > 0) ? T.Slider.SnapAlways : T.Slider.NoSnap
                value: Number(root.value) / sliderColumn.scale

                Accessible.name: root.row.label

                onMoved: {
                    let v = value * sliderColumn.scale
                    if (root.type === "int")
                        v = Math.round(v)
                    root.write(v)
                }

                background: Rectangle {
                    x: slider.leftPadding
                    y: slider.topPadding + (slider.availableHeight - height) / 2
                    width: slider.availableWidth
                    height: VLCStyle.dp(16, VLCStyle.scale)
                    radius: VLCStyle.dp(4, VLCStyle.scale)
                    color: root._well
                    border.width: slider.visualFocus ? VLCStyle.focus_border : 0
                    border.color: theme.visualFocus

                    Rectangle {
                        x: VLCStyle.dp(2, VLCStyle.scale)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, slider.visualPosition * (parent.width - 2 * x))
                        height: parent.height - 2 * VLCStyle.dp(2, VLCStyle.scale)
                        radius: VLCStyle.dp(3, VLCStyle.scale)
                        color: root._selected
                    }
                }

                handle: Rectangle {
                    x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                    y: slider.topPadding + (slider.availableHeight - height) / 2
                    implicitWidth: VLCStyle.dp(8, VLCStyle.scale)
                    implicitHeight: VLCStyle.dp(24, VLCStyle.scale)
                    radius: VLCStyle.dp(3, VLCStyle.scale)
                    color: theme.accent
                }

                T.ToolTip {
                    id: sliderTip

                    parent: slider.handle
                    visible: slider.pressed || slider.hovered
                    text: sliderColumn.format(slider.value)
                    y: -height - VLCStyle.dp(4, VLCStyle.scale)
                    padding: VLCStyle.dp(4, VLCStyle.scale)
                    contentItem: T.Label {
                        text: sliderTip.text
                        color: theme.fg.primary
                        font.pixelSize: VLCStyle.fontSize_normal
                    }
                    background: Rectangle {
                        color: windowTheme.bg.primary
                        radius: VLCStyle.dp(4, VLCStyle.scale)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                T.Label {
                    text: sliderColumn.format(slider.from)
                    font.pixelSize: VLCStyle.fontSize_small
                    color: root._mutedText
                }
                Item { Layout.fillWidth: true }
                T.Label {
                    text: sliderColumn.format(slider.value)
                    font.pixelSize: VLCStyle.fontSize_small
                    color: root._text
                }
                Item { Layout.fillWidth: true }
                T.Label {
                    text: sliderColumn.format(slider.to)
                    font.pixelSize: VLCStyle.fontSize_small
                    color: root._mutedText
                }
            }
        }
    }

    // Shared look for text inputs (Figma: well with a 2px surface border)
    component InputField: T.TextField {
        id: field

        implicitHeight: VLCStyle.dp(36, VLCStyle.scale)
        leftPadding: VLCStyle.dp(12, VLCStyle.scale)
        rightPadding: VLCStyle.dp(12, VLCStyle.scale)
        verticalAlignment: TextInput.AlignVCenter

        color: root._text
        selectionColor: root._selected
        selectedTextColor: theme.fg.primary
        font.pixelSize: VLCStyle.fontSize_large

        background: Rectangle {
            color: root._well
            radius: root._radius
            border.width: VLCStyle.dp(2, VLCStyle.scale)
            border.color: field.activeFocus ? theme.accent : root._surface
        }
    }

    // Plain text, colors as #RRGGBB, and passwords
    Component {
        id: textComponent

        InputField {
            implicitWidth: root.controlWidth
            text: String(root.value ?? "")
            echoMode: (root.type === "password") ? TextInput.Password : TextInput.Normal
            onEditingFinished: {
                if (text !== String(root.value ?? ""))
                    root.write(text)
            }
            Accessible.name: root.row.label
        }
    }

    // Numbers without a meaningful range
    Component {
        id: numberComponent

        RowLayout {
            spacing: VLCStyle.margin_xsmall

            InputField {
                id: numberField

                Layout.preferredWidth: VLCStyle.dp(120, VLCStyle.scale)
                horizontalAlignment: TextInput.AlignRight

                readonly property real scale: root.row.scale ?? 1

                // Floats are stored with binary rounding noise (e.g. 1.0000019),
                // show them with at most three decimals
                text: (root.value === undefined) ? "" : String(Math.round(Number(root.value) / scale * 1000) / 1000)
                validator: (root.type === "int" && scale === 1) ? intValidator : doubleValidator
                onEditingFinished: {
                    let v = Number(text) * scale
                    if (root.type === "int")
                        v = Math.round(v)
                    if (!isNaN(v) && v !== Number(root.value))
                        root.write(v)
                }
                Accessible.name: root.row.label

                IntValidator { id: intValidator }
                DoubleValidator { id: doubleValidator; notation: DoubleValidator.StandardNotation; locale: "C" }
            }

            T.Label {
                visible: text !== ""
                text: root.row.unit ?? ""
                font.pixelSize: VLCStyle.fontSize_large
                color: root._mutedText
            }
        }
    }

    // File or folder path with a Browse button
    Component {
        id: pathComponent

        RowLayout {
            spacing: VLCStyle.margin_xsmall

            InputField {
                id: pathField
                Layout.preferredWidth: root.controlWidth - VLCStyle.dp(100, VLCStyle.scale) - VLCStyle.margin_xsmall
                text: String(root.value ?? "")
                onEditingFinished: {
                    if (text !== String(root.value ?? ""))
                        root.write(text)
                }
                Accessible.name: root.row.label
            }

            SettingButton {
                text: qsTr("Browse")
                onClicked: {
                    const path = VLCConfig.browse(root.row.label, pathField.text,
                                                  root.type === "directory",
                                                  VLCConfig.type(root.option) === "file")
                    if (path !== "")
                        root.write(path)
                }
            }
        }
    }

    // A button that triggers something in the window
    Component {
        id: actionComponent

        SettingButton {
            text: root.row.buttonText ?? qsTr("Open")
            onClicked: root.actionRequested(root.row.action)
        }
    }

    component SettingButton: T.Button {
        id: button

        implicitWidth: VLCStyle.dp(100, VLCStyle.scale)
        implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

        background: Rectangle {
            radius: root._radius
            color: button.hovered ? Qt.lighter(root._surface, 1.2) : root._surface
            border.width: button.visualFocus ? VLCStyle.focus_border : 0
            border.color: theme.visualFocus
        }
        contentItem: T.Label {
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: button.text
            font.pixelSize: VLCStyle.fontSize_large
            font.weight: Font.DemiBold
            color: root._text
        }
    }
}
