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
#ifndef VLC_QT_CONFIG_BRIDGE_HPP
#define VLC_QT_CONFIG_BRIDGE_HPP

#include <QObject>
#include <QVariant>

#include "qt.hpp"

/**
 * Read and write VLC configuration options from QML.
 *
 * This is what the settings window uses: every row of the window is bound
 * to an option name, and this class reads its type, value, range, choices
 * and (localized) description from the core configuration, and saves
 * changes to the configuration file. Options that do not exist in the
 * current build (for instance because a module is not built on that
 * platform) are reported as missing, so the window can hide them.
 */
class ConfigBridge : public QObject
{
    Q_OBJECT

public:
    explicit ConfigBridge(qt_intf_t* intf, QObject* parent = nullptr);

    /// Whether the option exists (and is not obsolete) in this build
    Q_INVOKABLE bool exists(const QString& name) const;

    /// One of "bool", "int", "rgb", "float", "string", "password",
    /// "file", "directory", "font", "module", "modulelist", "key"
    /// or "" when the option does not exist
    Q_INVOKABLE QString type(const QString& name) const;

    Q_INVOKABLE QVariant value(const QString& name) const;
    Q_INVOKABLE QVariant defaultValue(const QString& name) const;
    Q_INVOKABLE void setValue(const QString& name, const QVariant& value);
    Q_INVOKABLE void resetValue(const QString& name);

    /// Suggested values, as a list of { value, text } maps
    Q_INVOKABLE QVariantList choices(const QString& name) const;

    /// { min, max } for bounded integer and float options, empty otherwise
    Q_INVOKABLE QVariantMap range(const QString& name) const;

    /// Localized short and long descriptions of the option
    Q_INVOKABLE QString text(const QString& name) const;
    Q_INVOKABLE QString longText(const QString& name) const;

    /// Helpers for colon-separated module lists such as "audio-filter"
    Q_INVOKABLE bool hasModule(const QString& listName, const QString& module) const;
    Q_INVOKABLE void setModule(const QString& listName, const QString& module, bool enabled);

    /// Whether a module with this name is available in this build
    Q_INVOKABLE bool moduleExists(const QString& module) const;

    /// Asks the user for a file or directory, returns "" when cancelled
    Q_INVOKABLE QString browse(const QString& title, const QString& current,
                               bool directory, bool save) const;

    /// Asks the user for several files, returns their URLs
    Q_INVOKABLE QVariantList browseFiles(const QString& title, const QString& filter = {}) const;
    /// Asks the user for a folder, returns its URL or an empty string
    Q_INVOKABLE QString browseFolder(const QString& title) const;

    /// All hotkey options, in VLC's order: list of
    /// { name, text, global (name of the matching global hotkey option) }
    Q_INVOKABLE QVariantList hotkeys() const;
    /// VLC key string ("Ctrl+Shift+a") for a key event received in QML,
    /// empty for lone modifiers
    Q_INVOKABLE QString keyFromEvent(int key, int modifiers, const QString& text) const;
    /// Human readable form of a VLC key string, as shown by the design
    Q_INVOKABLE QString keyDisplayText(const QString& key) const;

    /// Names of the files of a folder (URL) with one of these extensions,
    /// sorted naturally
    Q_INVOKABLE QStringList listFiles(const QString& folderUrl, const QStringList& extensions) const;

    /// Browse view node of a local folder, to open it in the Browse view
    /// ("Go to Source")
    Q_INVOKABLE QVariant browseNode(const QString& folderUrl) const;

    /// Interface state that is not a VLC option (for instance the items
    /// pinned to the library sidebar), kept in the Qt interface settings
    Q_INVOKABLE QVariant uiValue(const QString& key, const QVariant& defaultValue = {}) const;
    Q_INVOKABLE void setUiValue(const QString& key, const QVariant& value);

signals:
    /// `name` / `key` is empty when a settings profile changed all of them
    void valueChanged(const QString& name);
    void uiValueChanged(const QString& key);

private:
    void save();

    qt_intf_t* m_intf = nullptr;
};

#endif // VLC_QT_CONFIG_BRIDGE_HPP
