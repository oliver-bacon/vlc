
/*****************************************************************************
 * Copyright (C) 2022 VLC authors and VideoLAN
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
import QtQml

import VLC.MainInterface
import VLC.Menus

// @brief - a class that can be used to create native menus with support
// to asyncronously retreive data from MLBaseModel like model

QtObject {
    id: root

    /**
      actions - list of action to show

      each action is an Object and contains following keys
        "text" - (string) display text of the action

        "action" - (function(dataList, options, indexes)) a function that will be called when action is selected

        "visible" - (Boolean or function(dataList,options, indexes) -> Boolean) (optional) a boolean value or function which
                    controls whether the action is shown in the menu following 'popup' call

       e.g see MLContextMenu.qml
    **/

    property var actions: []

    property alias visible: menu.visible

    readonly property int currentRequest: _currentRequest

    signal requestData(var requestID, var indexes)


    property var _options: null

    property var _indexes: []

    property var _dataList: null

    property int _currentRequest: 0

    property var _effectiveActions: null

    property point _popupPoint

    // requests data for '_indexes' and shows popup menu
    // with 'NativeMenu::actions' based on '_options'
    // returns unique request id
    function popup(_indexes, point, _options) {
        root._options = _options
        root._indexes = _indexes
        _dataList = null
        _popupPoint = point

        const requestID = ++_currentRequest
        requestData(requestID, _indexes)
        return requestID
    }

    function setData(id, data) {
        if (_currentRequest !== id)
            return;

        _dataList = data
        _effectiveActions = []

        menu.popup(_popupPoint, _buildItems(actions))
    }

    function _isVisible(action) {
        return !action.hasOwnProperty("visible")
                || (typeof action.visible === "boolean" && action.visible)
                || (typeof action.visible === "function" && action.visible(_dataList, _options, _indexes))
    }

    // actions may also have:
    //  "icon": name of a :/menu/figma/ icon
    //  "checked": bool or function(dataList, options, indexes), shows a check mark
    //  "separator": true, a divider
    //  "children": [actions], a submenu (hidden when it has no visible action)
    function _buildItems(list) {
        const items = []
        for (let i in list) {
            const action = list[i]
            if (!_isVisible(action))
                continue

            if (action.separator) {
                if (items.length > 0 && !items[items.length - 1].separator)
                    items.push({ "separator": true })
                continue
            }

            if (action.children) {
                const children = _buildItems(action.children)
                if (children.length > 0)
                    items.push({ "text": action.text, "icon": action.icon ?? "", "children": children })
                continue
            }

            const item = { "text": action.text, "icon": action.icon ?? "" }
            if (action.hasOwnProperty("checked")) {
                item.checked = (typeof action.checked === "function")
                        ? action.checked(_dataList, _options, _indexes)
                        : action.checked
            }
            _effectiveActions.push(action)
            items.push(item)
        }
        if (items.length > 0 && items[items.length - 1].separator)
            items.pop()
        return items
    }

    function _executeAction(index) {
        const action = root._effectiveActions[index]
        action.action(_dataList, _options, _indexes)
    }


    readonly property StringListMenu _menu: StringListMenu {
        id: menu

        ctx: MainCtx

        onSelected: (index, _) => {
            root._executeAction(index)
        }
    }
}
