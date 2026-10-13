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

#include "config_bridge.hpp"

#include <QColor>
#include <QFileDialog>
#include <QFileInfo>
#include <QStringList>

#include <cfloat>
#include <cstdint>

#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_modules.h>
#include <vlc_plugin.h>

namespace {

const module_config_t* findItem(const QString& name)
{
    const QByteArray utf8 = name.toUtf8();
    const module_config_t* item = config_FindConfig(utf8.constData());
    // Obsolete options are still registered, but without any description;
    // they must not be shown nor edited.
    if (item == nullptr || item->psz_text == nullptr)
        return nullptr;
    return item;
}

QString typeName(const module_config_t* item)
{
    switch (item->i_type)
    {
    case CONFIG_ITEM_BOOL:              return QStringLiteral("bool");
    case CONFIG_ITEM_INTEGER:           return QStringLiteral("int");
    case CONFIG_ITEM_RGB:               return QStringLiteral("rgb");
    case CONFIG_ITEM_FLOAT:             return QStringLiteral("float");
    case CONFIG_ITEM_PASSWORD:          return QStringLiteral("password");
    case CONFIG_ITEM_KEY:               return QStringLiteral("key");
    case CONFIG_ITEM_MODULE:
    case CONFIG_ITEM_MODULE_CAT:        return QStringLiteral("module");
    case CONFIG_ITEM_MODULE_LIST:
    case CONFIG_ITEM_MODULE_LIST_CAT:   return QStringLiteral("modulelist");
    case CONFIG_ITEM_LOADFILE:
    case CONFIG_ITEM_SAVEFILE:          return QStringLiteral("file");
    case CONFIG_ITEM_DIRECTORY:         return QStringLiteral("directory");
    case CONFIG_ITEM_FONT:              return QStringLiteral("font");
    default:
        return IsConfigStringType(item->i_type) ? QStringLiteral("string") : QString {};
    }
}

QString rgbToString(int64_t rgb)
{
    return QColor::fromRgb(static_cast<QRgb>(rgb & 0xFFFFFF)).name();
}

} // namespace

ConfigBridge::ConfigBridge(qt_intf_t* intf, QObject* parent)
    : QObject(parent)
    , m_intf(intf)
{
    assert(m_intf);
}

bool ConfigBridge::exists(const QString& name) const
{
    return findItem(name) != nullptr;
}

QString ConfigBridge::type(const QString& name) const
{
    const module_config_t* item = findItem(name);
    return item ? typeName(item) : QString {};
}

QVariant ConfigBridge::value(const QString& name) const
{
    const module_config_t* item = findItem(name);
    if (!item)
        return {};

    const QByteArray utf8 = name.toUtf8();
    const char* psz_name = utf8.constData();

    if (item->i_type == CONFIG_ITEM_BOOL)
        return config_GetInt(psz_name) != 0;
    if (item->i_type == CONFIG_ITEM_RGB)
        return rgbToString(config_GetInt(psz_name));
    if (IsConfigIntegerType(item->i_type))
        return QVariant::fromValue<qint64>(config_GetInt(psz_name));
    if (IsConfigFloatType(item->i_type))
        return config_GetFloat(psz_name);
    if (IsConfigStringType(item->i_type))
    {
        char* psz = config_GetPsz(psz_name);
        QString ret = qfu(psz ? psz : "");
        free(psz);
        return ret;
    }
    return {};
}

QVariant ConfigBridge::defaultValue(const QString& name) const
{
    const module_config_t* item = findItem(name);
    if (!item)
        return {};

    if (item->i_type == CONFIG_ITEM_BOOL)
        return item->orig.i != 0;
    if (item->i_type == CONFIG_ITEM_RGB)
        return rgbToString(item->orig.i);
    if (IsConfigIntegerType(item->i_type))
        return QVariant::fromValue<qint64>(item->orig.i);
    if (IsConfigFloatType(item->i_type))
        return item->orig.f;
    if (IsConfigStringType(item->i_type))
        return qfu(item->orig.psz ? item->orig.psz : "");
    return {};
}

void ConfigBridge::setValue(const QString& name, const QVariant& value)
{
    const module_config_t* item = findItem(name);
    if (!item)
        return;

    const QByteArray utf8 = name.toUtf8();
    const char* psz_name = utf8.constData();

    if (item->i_type == CONFIG_ITEM_BOOL)
        config_PutInt(psz_name, value.toBool() ? 1 : 0);
    else if (item->i_type == CONFIG_ITEM_RGB)
    {
        const QColor color = (value.typeId() == QMetaType::QString)
                ? QColor(value.toString())
                : QColor::fromRgb(static_cast<QRgb>(value.toLongLong() & 0xFFFFFF));
        if (!color.isValid())
            return;
        config_PutInt(psz_name, color.rgb() & 0xFFFFFF);
    }
    else if (IsConfigIntegerType(item->i_type))
    {
        bool ok = false;
        int64_t val = value.toLongLong(&ok);
        if (!ok)
            return;
        if (item->min.i != INT64_MIN || item->max.i != INT64_MAX)
            val = qBound<int64_t>(item->min.i, val, item->max.i);
        config_PutInt(psz_name, val);
    }
    else if (IsConfigFloatType(item->i_type))
    {
        bool ok = false;
        float val = value.toFloat(&ok);
        if (!ok)
            return;
        config_PutFloat(psz_name, val);
    }
    else if (IsConfigStringType(item->i_type))
    {
        const QByteArray str = value.toString().toUtf8();
        config_PutPsz(psz_name, str.isEmpty() ? nullptr : str.constData());
    }
    else
        return;

    save();
    emit valueChanged(name);
}

void ConfigBridge::resetValue(const QString& name)
{
    setValue(name, defaultValue(name));
}

QVariantList ConfigBridge::choices(const QString& name) const
{
    QVariantList ret;
    const module_config_t* item = findItem(name);
    if (!item)
        return ret;

    const QByteArray utf8 = name.toUtf8();

    if (IsConfigIntegerType(item->i_type) && item->i_type != CONFIG_ITEM_RGB)
    {
        int64_t* values = nullptr;
        char** texts = nullptr;
        const ssize_t count = config_GetIntChoices(utf8.constData(), &values, &texts);
        for (ssize_t i = 0; i < count; ++i)
        {
            ret.append(QVariantMap {
                { QStringLiteral("value"), QVariant::fromValue<qint64>(values[i]) },
                { QStringLiteral("text"), qfu(texts[i]) },
            });
            free(texts[i]);
        }
        free(values);
        free(texts);
    }
    else if (IsConfigStringType(item->i_type))
    {
        char** values = nullptr;
        char** texts = nullptr;
        const ssize_t count = config_GetPszChoices(utf8.constData(), &values, &texts);
        for (ssize_t i = 0; i < count; ++i)
        {
            const QString value = qfu(values[i] ? values[i] : "");
            const QString text = (texts[i] && texts[i][0]) ? qfu(texts[i]) : value;
            ret.append(QVariantMap {
                { QStringLiteral("value"), value },
                { QStringLiteral("text"), text },
            });
            free(values[i]);
            free(texts[i]);
        }
        free(values);
        free(texts);
    }
    return ret;
}

QVariantMap ConfigBridge::range(const QString& name) const
{
    const module_config_t* item = findItem(name);
    if (!item || item->i_type == CONFIG_ITEM_BOOL || item->i_type == CONFIG_ITEM_RGB)
        return {};

    if (IsConfigIntegerType(item->i_type))
    {
        if (item->min.i == INT64_MIN && item->max.i == INT64_MAX)
            return {};
        return {
            { QStringLiteral("min"), QVariant::fromValue<qint64>(item->min.i) },
            { QStringLiteral("max"), QVariant::fromValue<qint64>(item->max.i) },
        };
    }
    if (IsConfigFloatType(item->i_type))
    {
        if (item->min.f == -FLT_MAX && item->max.f == FLT_MAX)
            return {};
        return {
            { QStringLiteral("min"), item->min.f },
            { QStringLiteral("max"), item->max.f },
        };
    }
    return {};
}

QString ConfigBridge::text(const QString& name) const
{
    const module_config_t* item = findItem(name);
    return item ? qfut(item->psz_text) : QString {};
}

QString ConfigBridge::longText(const QString& name) const
{
    const module_config_t* item = findItem(name);
    if (!item)
        return {};
    return qfut(item->psz_longtext ? item->psz_longtext : item->psz_text);
}

bool ConfigBridge::hasModule(const QString& listName, const QString& module) const
{
    return value(listName).toString().split(':', Qt::SkipEmptyParts).contains(module);
}

void ConfigBridge::setModule(const QString& listName, const QString& module, bool enabled)
{
    QStringList modules = value(listName).toString().split(':', Qt::SkipEmptyParts);
    if (enabled == modules.contains(module))
        return;
    if (enabled)
        modules.append(module);
    else
        modules.removeAll(module);
    setValue(listName, modules.join(':'));
}

bool ConfigBridge::moduleExists(const QString& module) const
{
    return module_exists(module.toUtf8().constData());
}

QString ConfigBridge::browse(const QString& title, const QString& current,
                             bool directory, bool save) const
{
    if (directory)
        return QFileDialog::getExistingDirectory(nullptr, title, current);

    const QString dir = current.isEmpty() ? QString {} : QFileInfo(current).absolutePath();
    if (save)
        return QFileDialog::getSaveFileName(nullptr, title, current.isEmpty() ? dir : current);
    return QFileDialog::getOpenFileName(nullptr, title, dir);
}

void ConfigBridge::save()
{
    config_SaveConfigFile(m_intf);
}
