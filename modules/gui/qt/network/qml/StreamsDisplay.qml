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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Network

// "Network" of the VLC Redesign side navigation (Figma "sidebar" frame):
// Add Network Stream, Podcasts, Radio, and the saved streams. Podcasts and
// Radio open VLC's services browser (podcast and radio modules: countries
// with their flags, stations with their icons) under this entry.
Widgets.PageLoader {
    id: root

    pageModel: [{
            displayText: qsTr("Network"),
            default: true,
            name: "sections",
            url: "qrc:///qt/qml/VLC/Network/NetworkSectionsDisplay.qml"
        }, {
            displayText: qsTr("Saved Streams"),
            name: "url",
            url: "qrc:///qt/qml/VLC/Network/DiscoverUrlDisplay.qml"
        }, {
            displayText: qsTr("Services"),
            name: "services",
            url: "qrc:///qt/qml/VLC/Network/ServicesHomeDisplay.qml"
        }
    ]

    property int displayMarginBeginning: 0
    property int displayMarginEnd: 0

    property bool enableBeginningFade: true
    property bool enableEndFade: true

    Accessible.role: Accessible.Client
    Accessible.name: qsTr("Network view")

    onCurrentItemChanged: {
        if (currentItem) {
            if (currentItem.displayMarginBeginning !== undefined)
                currentItem.displayMarginBeginning = Qt.binding(() => { return root.displayMarginBeginning })

            if (currentItem.displayMarginEnd !== undefined)
                currentItem.displayMarginEnd = Qt.binding(() => { return root.displayMarginEnd })

            if (currentItem.enableBeginningFade !== undefined)
                currentItem.enableBeginningFade = Qt.binding(() => { return root.enableBeginningFade })

            if (currentItem.enableEndFade !== undefined)
                currentItem.enableEndFade = Qt.binding(() => { return root.enableEndFade })
        }
    }
}
