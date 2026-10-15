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
// controls (VLC's original prompt was a line in the top bar): "You already
// watched till 00:00:02", Continue Watching, close.
FocusScope {
    id: resumePanel

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    visible: false
    enabled: visible

    Accessible.role: Accessible.Dialog
    Accessible.name: qsTr("Resume dialog")

    signal hidden()

    // saved progress of the current media, from the media library (-1: unknown);
    // the time uses the player's length (the library may not know the duration)
    property real _progress: -1
    readonly property real _positionMs: (_progress > 0 && Player.length.valid())
                                        ? _progress * Player.length.toMilliseconds() : -1

    function _hms(ms) {
        const total = Math.floor(ms / 1000)
        const pad = (n) => (n < 10 ? "0" : "") + n
        return pad(Math.floor(total / 3600)) + ":" + pad(Math.floor(total / 60) % 60) + ":" + pad(total % 60)
    }

    Connections {
        target: MainCtx.mediaLibrary
        enabled: MainCtx.mediaLibraryAvailable
        function onMediaProgressState(mrl, progress) {
            if (String(mrl) === String(Player.url))
                resumePanel._progress = progress
        }
    }

    function showResumePanel ()
    {
        _progress = -1
        if (MainCtx.mediaLibraryAvailable)
            MainCtx.mediaLibrary.queryMediaProgress(Player.url)
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

        // Figma: 52px high, #161616, text 20px from the left edge
        implicitWidth: row.implicitWidth + VLCStyle.dp(20 + 10, VLCStyle.scale)
        implicitHeight: VLCStyle.dp(52, VLCStyle.scale)

        radius: VLCStyle.dp(8, VLCStyle.scale)
        color: theme.palette.isDark ? "#161616" : "#E7E7E7"

        RowLayout {
            id: row

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
            spacing: VLCStyle.dp(8, VLCStyle.scale)

            T.Label {
                Layout.rightMargin: VLCStyle.dp(32, VLCStyle.scale)
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.dp(15, VLCStyle.scale)
                textFormat: Text.StyledText
                text: resumePanel._positionMs >= 0
                      ? qsTr("You already watched till %1").arg("<b><font color=\"%1\">%2</font></b>"
                                                                 .arg(theme.fg.primary).arg(resumePanel._hms(resumePanel._positionMs)))
                      : qsTr("Continue where you left off?")
            }

            T.Button {
                id: continueBtn

                implicitWidth: contentItem.implicitWidth + leftPadding + rightPadding
                implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
                leftPadding: VLCStyle.dp(12, VLCStyle.scale)
                rightPadding: VLCStyle.dp(12, VLCStyle.scale)

                text: qsTr("Continue Watching")
                focus: true

                AccessibleCompat.id: "resumeContinueButton"

                background: Rectangle {
                    radius: VLCStyle.dp(4, VLCStyle.scale)
                    color: continueBtn.hovered || continueBtn.visualFocus ? Qt.lighter(theme.accent, 1.15) : theme.accent
                }
                contentItem: Text {
                    text: continueBtn.text
                    color: "#161616"
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
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

                // Figma: a 32px square, #1E1E1E
                implicitWidth: VLCStyle.dp(32, VLCStyle.scale)
                implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
                background: Rectangle {
                    radius: VLCStyle.dp(4, VLCStyle.scale)
                    color: closeBtn.hovered ? Qt.lighter(closeColor, 1.3) : closeColor
                    readonly property color closeColor: theme.palette.isDark ? "#1E1E1E" : "#D5D5D5"
                }

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
