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
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "settings_profiles.hpp"

#include "maininterface/mainctx.hpp"
#include "dialogs/toolbar/controlbar_profile_model.hpp"

#include <QDir>
#include <QSettings>

#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_modules.h>
#include <vlc_plugin.h>

namespace {

const char* const kGroup = "SettingsProfiles";

// group of the profile file with the Qt interface settings
const QString kInterfaceGroup = QStringLiteral("Interface");

/* Whether an interface setting (key of vlc-qt-interface.conf) belongs to a
 * profile: the look, the player bars and the other choices do; the window
 * state, the profile list itself and what the user keeps in the library
 * (pins, hidden Home items, recent media, sorting of the views) and the
 * crash recovery file don't. */
bool isProfileKey(const QString& key)
{
    if (!key.contains(QLatin1Char('/')))
        return false; // [General]: recovery file, dialog folder, graphics API...
    static const char* const excludedGroups[] = {
        "SettingsProfiles/", "Library/", "LibraryPanel/", "Home/", "HomeHidden/",
        "RecentsMRL/", "sortCriteria/", "sortOrder/",
    };
    for (const char* group : excludedGroups)
        if (key.startsWith(QLatin1String(group)))
            return false;
    return !key.endsWith(QLatin1String("RecoveryFilePath"))
        && !key.contains(QLatin1String("geometry"), Qt::CaseInsensitive)
        && !key.contains(QLatin1String("windowState"), Qt::CaseInsensitive);
}

QString profileFile(const QString& name)
{
    char* dir = config_GetUserDir(VLC_USERDATA_DIR);
    const QString base = qfu(dir ? dir : "");
    free(dir);
    QDir().mkpath(base + QStringLiteral("/profiles"));
    // keep file names simple whatever the profile name is
    return base + QStringLiteral("/profiles/") + QString::fromLatin1(name.toUtf8().toHex()) + QStringLiteral(".ini");
}

template<typename F>
void forEachOption(F&& f)
{
    size_t count = 0;
    module_t** modules = module_list_get(&count);
    for (size_t m = 0; m < count; ++m)
    {
        unsigned n = 0;
        module_config_t* items = module_config_get(modules[m], &n);
        for (unsigned i = 0; i < n; ++i)
        {
            const module_config_t& item = items[i];
            // skip hints, obsolete and private options
            if (!CONFIG_ITEM(item.i_type) || item.psz_name == nullptr || item.psz_text == nullptr)
                continue;
            f(item);
        }
        module_config_free(items);
    }
    module_list_free(modules);
}

/* writes every option that differs from its default value, and the
 * interface settings */
void saveProfile(qt_intf_t* intf, const QString& name)
{
    QSettings file(profileFile(name), QSettings::IniFormat);
    file.clear();

    if (intf->p_mi)
        intf->p_mi->controlbarProfileModel()->save(false);
    QSettings& settings = *intf->mainSettings;
    file.beginGroup(kInterfaceGroup);
    for (const QString& key : settings.allKeys())
        if (isProfileKey(key))
            file.setValue(key, settings.value(key));
    file.endGroup();

    forEachOption([&file](const module_config_t& item) {
        const char* option = item.psz_name;
        if (IsConfigIntegerType(item.i_type))
        {
            const int64_t value = config_GetInt(option);
            if (value != item.orig.i)
                file.setValue(QString::fromUtf8(option), QVariant::fromValue<qint64>(value));
        }
        else if (IsConfigFloatType(item.i_type))
        {
            const float value = config_GetFloat(option);
            if (value != item.orig.f)
                file.setValue(QString::fromUtf8(option), value);
        }
        else if (IsConfigStringType(item.i_type))
        {
            char* value = config_GetPsz(option);
            const QString str = qfu(value ? value : "");
            free(value);
            if (str != qfu(item.orig.psz ? item.orig.psz : ""))
                file.setValue(QString::fromUtf8(option), str);
        }
    });
    file.sync();
}

/* resets all options, then applies the saved ones */
void loadProfile(qt_intf_t* intf, const QString& name)
{
    QSettings file(profileFile(name), QSettings::IniFormat);

    // profiles saved before they kept the interface settings leave them as they are
    if (file.childGroups().contains(kInterfaceGroup))
    {
        QSettings& settings = *intf->mainSettings;
        for (const QString& key : settings.allKeys())
            if (isProfileKey(key))
                settings.remove(key);
        file.beginGroup(kInterfaceGroup);
        for (const QString& key : file.allKeys())
            if (isProfileKey(key))
                settings.setValue(key, file.value(key));
        file.endGroup();
        settings.sync();
    }

    config_ResetAll();
    forEachOption([&file](const module_config_t& item) {
        const QString key = QString::fromUtf8(item.psz_name);
        if (!file.contains(key))
            return;
        const QVariant value = file.value(key);
        if (IsConfigIntegerType(item.i_type))
            config_PutInt(item.psz_name, value.toLongLong());
        else if (IsConfigFloatType(item.i_type))
            config_PutFloat(item.psz_name, value.toFloat());
        else if (IsConfigStringType(item.i_type))
        {
            const QByteArray str = value.toString().toUtf8();
            config_PutPsz(item.psz_name, str.isEmpty() ? nullptr : str.constData());
        }
    });
}

void ensureDefaults(qt_intf_t* intf)
{
    QSettings& settings = *intf->mainSettings;
    settings.beginGroup(kGroup);
    const bool exists = settings.contains(QStringLiteral("names"));
    settings.endGroup();
    if (exists)
        return;

    // the profiles of the design, all starting from the current settings
    const QStringList defaults { qtr("Movies"), qtr("Shows"), qtr("Music"), qtr("Work") };
    for (const QString& name : defaults)
        saveProfile(intf, name);
    settings.beginGroup(kGroup);
    settings.setValue(QStringLiteral("names"), defaults);
    settings.setValue(QStringLiteral("current"), defaults.first());
    settings.endGroup();
}

} // namespace

QStringList SettingsProfiles::names(qt_intf_t* intf)
{
    ensureDefaults(intf);
    QSettings& settings = *intf->mainSettings;
    return settings.value(QStringLiteral("%1/names").arg(kGroup)).toStringList();
}

QString SettingsProfiles::current(qt_intf_t* intf)
{
    ensureDefaults(intf);
    return intf->mainSettings->value(QStringLiteral("%1/current").arg(kGroup)).toString();
}

bool SettingsProfiles::switchTo(qt_intf_t* intf, const QString& name)
{
    const QString previous = current(intf);
    if (name == previous || !names(intf).contains(name))
        return false;

    saveProfile(intf, previous);
    loadProfile(intf, name);
    config_SaveConfigFile(intf);
    intf->mainSettings->setValue(QStringLiteral("%1/current").arg(kGroup), name);
    msg_Info(intf, "settings profile changed to %s", qtu(name));

    // apply the profile to the open interface
    if (MainCtx* const mainCtx = intf->p_mi)
    {
        mainCtx->reloadPrefs();
        mainCtx->reloadFromSettings();
        mainCtx->controlbarProfileModel()->reload();
        emit mainCtx->settingsProfileChanged();
    }
    return true;
}

bool SettingsProfiles::create(qt_intf_t* intf, const QString& name)
{
    QStringList list = names(intf);
    if (name.trimmed().isEmpty() || list.contains(name))
        return false;

    saveProfile(intf, current(intf));
    saveProfile(intf, name);
    list.append(name);
    QSettings& settings = *intf->mainSettings;
    settings.setValue(QStringLiteral("%1/names").arg(kGroup), list);
    settings.setValue(QStringLiteral("%1/current").arg(kGroup), name);
    return true;
}
