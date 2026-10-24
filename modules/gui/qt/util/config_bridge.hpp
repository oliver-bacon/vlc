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

    /// Whether a local file (URL) can be deleted: its folder is writable
    /// (read-only files count, as in File Explorer)
    Q_INVOKABLE bool isDeletableFile(const QString& fileUrl) const;
    /// Deletes a local file (URL) from the disk, returns false on failure
    Q_INVOKABLE bool deleteFile(const QString& fileUrl) const;

    /// Browse view node of a local folder, to open it in the Browse view
    /// ("Go to Source")
    Q_INVOKABLE QVariant browseNode(const QString& folderUrl) const;

    /// "All Settings" window: VLC's categories in their usual order, as
    /// { cat, name, icon, subcat (the category's own page),
    ///   subcats: [{ subcat, name }] }
    Q_INVOKABLE QVariantList settingsTree() const;
    /// One page of the "All Settings" window:
    /// { title, help, sections: [{ title, options }], modules: [{ name, text }] }
    /// `options` are option names, "#hotkeys" stands for all hotkey options;
    /// `modules` are the modules whose settings belong to this page
    Q_INVOKABLE QVariantMap settingsPage(int subcat) const;
    /// Settings of one module: { name, title, help, helpIsHtml, sections: [{ title, options }] }
    Q_INVOKABLE QVariantMap moduleSettings(const QString& module) const;
    /// Options whose name or description contains `text`:
    /// [{ option, place }], at most `limit`
    Q_INVOKABLE QVariantList searchSettings(const QString& text, int limit = 150) const;

    // Settings of the classic simple preferences that are not one option

    /// Whether an extra interface (e.g. "audioscrobbler") is started
    Q_INVOKABLE bool hasIntf(const QString& module) const;
    Q_INVOKABLE void setIntf(const QString& module, bool enabled);
    /// Volume (%) the current audio output starts with when the volume is
    /// not remembered; -1 when the output keeps its own volume
    Q_INVOKABLE int startVolume() const;
    Q_INVOKABLE void setStartVolume(int percent);
    /// Interface language (Windows only; empty list elsewhere)
    Q_INVOKABLE QVariantList languages() const;
    Q_INVOKABLE QString language() const;
    Q_INVOKABLE void setLanguage(const QString& iso);
    /// Qt widget style of the classic dialogs ("" = system default)
    Q_INVOKABLE QVariantList qtStyles() const;
    Q_INVOKABLE QString qtStyle() const;
    Q_INVOKABLE void setQtStyle(const QString& style);
    /// Resets every preference, as the classic dialog's "Reset Preferences"
    Q_INVOKABLE void resetPreferences();
    /// Windows' file associations dialog
    Q_INVOKABLE void fileAssociations() const;
    /// Media library: forget the recently played media
    Q_INVOKABLE void clearRecentMedia() const;
    /// Media library folders (banned: the excluded ones), a list model with
    /// the roles "display_url" and "url", add(url) and removeAt(index);
    /// null without a media library
    Q_INVOKABLE QObject* mediaFolders(bool banned);
    /// Media library: scan the folders again
    Q_INVOKABLE void reloadMediaLibrary() const;

    /// Interface state that is not a VLC option (for instance the items
    /// pinned to the library sidebar), kept in the Qt interface settings
    Q_INVOKABLE QVariant uiValue(const QString& key, const QVariant& defaultValue = {}) const;
    Q_INVOKABLE void setUiValue(const QString& key, const QVariant& value);

    /// Library folders added from Music (interface setting
    /// "Library/MusicFolders"): "Videos" leaves them out. Adding a folder
    /// from Videos takes it off the list again (music = false).
    Q_INVOKABLE QStringList musicFolders() const;
    Q_INVOKABLE void setMusicFolder(const QString& url, bool music);

signals:
    /// `name` / `key` is empty when a settings profile changed all of them
    void valueChanged(const QString& name);
    void uiValueChanged(const QString& key);

private:
    void save();

    qt_intf_t* m_intf = nullptr;
    QObject* m_mediaFolders = nullptr;
    QObject* m_bannedFolders = nullptr;
};

#endif // VLC_QT_CONFIG_BRIDGE_HPP
