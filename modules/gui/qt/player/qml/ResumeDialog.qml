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
import QtQuick.Templates as T


import VLC.MainInterface
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util

// "Continue where you left off" prompt. In the VLC Redesign video it is a
// small bar centered just above the control bar, near the playback
// controls (VLC's original prompt was a line in the top bar).
FocusScope {
    id: resumePanel

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    visible: false
    enabled: visible

    Accessible.role: Accessible.Dialog
    Accessible.name: qsTr("Resume dialog")

    signal hidden()

    function showResumePanel ()
    {
        resumePanel.visible = true
        continueBtn.forceActiveFocus()
        resumeTimeout.start()
    }

    function hideResumePanel() {
        resumeTimeout.stop()
        resumePanel.visible = false
        Player.acknowledgeRestoreCallback()
        hidden()
    }

    Timer {
        id: resumeTimeout
        interval: 10000
        onTriggered: {
            resumePanel.visible = false
            hidden()
        }
    }

    Connections {
        target: Player
        function onCanRestorePlaybackChanged() {
            if (Player.canRestorePlayback) {
                showResumePanel()
            } else {
                hideResumePanel()
            }
        }
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    Component.onCompleted: {
        if (Player.canRestorePlayback) {
            showResumePanel()
        }
    }

    Navigation.cancelAction: function() {
        hideResumePanel()
    }

    Rectangle {
        id: pill

        anchors.fill: parent

        implicitWidth: row.implicitWidth + 2 * VLCStyle.margin_xsmall
        implicitHeight: row.implicitHeight + 2 * VLCStyle.margin_xxsmall

        radius: VLCStyle.dp(6, VLCStyle.scale)
        color: theme.bg.primary
        border.width: VLCStyle.border
        border.color: theme.border

        RowLayout {
            id: row

            anchors.centerIn: parent
            spacing: VLCStyle.margin_xsmall

            T.Label {
                Layout.leftMargin: VLCStyle.margin_xsmall
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_normal
                text: qsTr("Continue where you left off?")
            }

            T.Button {
                id: continueBtn

                implicitWidth: contentItem.implicitWidth + leftPadding + rightPadding
                implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding
                leftPadding: VLCStyle.margin_small
                rightPadding: VLCStyle.margin_small
                topPadding: VLCStyle.margin_xxsmall
                bottomPadding: VLCStyle.margin_xxsmall

                text: qsTr("Continue Watching")
                focus: true

                AccessibleCompat.id: "resumeContinueButton"

                background: Rectangle {
                    radius: VLCStyle.dp(4, VLCStyle.scale)
                    color: continueBtn.hovered || continueBtn.visualFocus ? Qt.lighter(theme.accent, 1.15) : theme.accent
                }
                contentItem: Text {
                    text: continueBtn.text
                    color: "white"
                    font.pixelSize: VLCStyle.fontSize_normal
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    Player.restorePlaybackPos()
                    hideResumePanel()
                }

                Navigation.parentItem: resumePanel
                Navigation.rightItem: closeBtn
                Keys.priority: Keys.AfterItem
                Keys.onPressed: (event) => continueBtn.Navigation.defaultKeyAction(event)
            }

            Widgets.IconToolButton {
                id: closeBtn

                font.pixelSize: VLCStyle.icon_small
                text: VLCIcons.close
                description: qsTr("Dismiss")

                AccessibleCompat.id: "resumeDismissButton"

                onClicked: hideResumePanel()

                Navigation.parentItem: resumePanel
                Navigation.leftItem: continueBtn
                Keys.priority: Keys.AfterItem
                Keys.onPressed: (event) => closeBtn.Navigation.defaultKeyAction(event)
            }
        }
    }
}
