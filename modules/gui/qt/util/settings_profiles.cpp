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

#include <QDir>
#include <QSettings>

#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_modules.h>
#include <vlc_plugin.h>

namespace {

const char* const kGroup = "SettingsProfiles";

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

/* writes every option that differs from its default value */
void saveProfile(const QString& name)
{
    QSettings file(profileFile(name), QSettings::IniFormat);
    file.clear();
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
void loadProfile(const QString& name)
{
    QSettings file(profileFile(name), QSettings::IniFormat);
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
        saveProfile(name);
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

    saveProfile(previous);
    loadProfile(name);
    config_SaveConfigFile(intf);
    intf->mainSettings->setValue(QStringLiteral("%1/current").arg(kGroup), name);
    msg_Info(intf, "settings profile changed to %s", qtu(name));
    return true;
}

bool SettingsProfiles::create(qt_intf_t* intf, const QString& name)
{
    QStringList list = names(intf);
    if (name.trimmed().isEmpty() || list.contains(name))
        return false;

    saveProfile(current(intf));
    saveProfile(name);
    list.append(name);
    QSettings& settings = *intf->mainSettings;
    settings.setValue(QStringLiteral("%1/names").arg(kGroup), list);
    settings.setValue(QStringLiteral("%1/current").arg(kGroup), name);
    return true;
}
