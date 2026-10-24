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
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QCollator>
#include <QUrl>
#include <QSettings>
#include <QStringList>
#include <QKeyEvent>

#include <cfloat>
#include <cstdint>
#include <cstring>
#include <algorithm>
#include <map>
#include <set>

#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_modules.h>
#include <vlc_plugin.h>
#include <vlc_actions.h>
#include <vlc_config_cat.h>

#include "qt.hpp"
#include "util/vlchotkeyconverter.hpp"
#include "network/networkmediamodel.hpp"
#include "maininterface/mainctx.hpp"
#include "medialibrary/medialib.hpp"
#include "medialibrary/mlfoldersmodel.hpp"
#include "dialogs/preferences/simple_preferences.hpp"

#include <QApplication>
#include <QStyle>
#include <QStyleFactory>
#include <cmath>

#include <vlc_aout.h>
#include <vlc_media_library.h>

#include <vlc_media_source.h>
#include <vlc_input_item.h>

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


// Config items of a module; frees them when going out of scope
struct ModuleConfig
{
    explicit ModuleConfig(const module_t* module)
        : items(module_config_get(module, &count)) {}
    ~ModuleConfig() { module_config_free(items); }
    ModuleConfig(const ModuleConfig&) = delete;
    ModuleConfig& operator=(const ModuleConfig&) = delete;

    const module_config_t* begin() const { return items; }
    const module_config_t* end() const { return items + count; }

    // count first: it is filled while `items` is initialized
    unsigned count = 0;
    module_config_t* items = nullptr;
};

// Every module, freed when going out of scope
struct ModuleList
{
    ModuleList() : modules(module_list_get(&count)) {}
    ~ModuleList() { module_list_free(modules); }
    ModuleList(const ModuleList&) = delete;
    ModuleList& operator=(const ModuleList&) = delete;

    module_t* const* begin() const { return modules; }
    module_t* const* end() const { return modules + count; }

    // count first: it is filled while `modules` is initialized
    size_t count = 0;
    module_t** modules = nullptr;
};

// Where the classic preferences show a module: its first subcategory
// followed by an option; SUBCAT_UNKNOWN when it has no options
enum vlc_config_subcat modulePlace(const module_t* module)
{
    enum vlc_config_subcat subcat = SUBCAT_UNKNOWN;
    bool hasOptions = false;
    for (const module_config_t& item : ModuleConfig(module))
    {
        if (item.i_type == CONFIG_SUBCATEGORY)
        {
            subcat = static_cast<enum vlc_config_subcat>(item.value.i);
            continue;
        }
        if (CONFIG_ITEM(item.i_type))
        {
            hasOptions = true;
            if (subcat != SUBCAT_UNKNOWN)
                break;
        }
    }
    if (!hasOptions)
        return SUBCAT_UNKNOWN;
    const enum vlc_config_cat cat = vlc_config_cat_FromSubcat(subcat);
    if (cat == CAT_UNKNOWN || cat == CAT_HIDDEN)
        return SUBCAT_UNKNOWN;
    return subcat;
}

bool moduleInSubcat(const module_t* module, int subcat)
{
    for (const module_config_t& item : ModuleConfig(module))
        if (item.i_type == CONFIG_SUBCATEGORY && item.value.i == subcat)
            return true;
    return false;
}

QString moduleText(const module_t* module)
{
    return qfut(module_GetLongName(module));
}

// Options from `begin` on, split at the sections; stops at the next
// subcategory when `onePage` (the core's options of one page)
QVariantList optionSections(const module_config_t* begin, const module_config_t* end, bool onePage)
{
    QVariantList sections;
    QString title;
    QStringList options;
    bool hotkeys = false;

    const auto flush = [&]() {
        if (!options.isEmpty())
            sections.append(QVariantMap {
                { QStringLiteral("title"), title },
                { QStringLiteral("options"), options },
            });
        options.clear();
    };

    for (const module_config_t* item = begin; item < end; ++item)
    {
        if (item->i_type == CONFIG_SUBCATEGORY)
        {
            if (onePage)
                break;
            continue;
        }
        if (item->i_type == CONFIG_SECTION)
        {
            flush();
            title = item->psz_text ? qfut(item->psz_text) : QString {};
            continue;
        }
        // obsolete options have no description
        if (!CONFIG_ITEM(item->i_type) || item->psz_text == nullptr)
            continue;
        // the hotkeys are edited together, in one dialog
        if (item->i_type == CONFIG_ITEM_KEY)
        {
            if (!hotkeys)
                options.append(QStringLiteral("#hotkeys"));
            hotkeys = true;
            continue;
        }
        options.append(qfu(item->psz_name));
    }
    flush();
    return sections;
}

QString subcatName(enum vlc_config_subcat subcat)
{
    return qfu(vlc_config_subcat_GetName(subcat));
}

// "Video › Output modules", or "Video" for a category's own page
QString pagePath(enum vlc_config_subcat subcat)
{
    const enum vlc_config_cat cat = vlc_config_cat_FromSubcat(subcat);
    if (vlc_config_subcat_IsGeneral(subcat))
        return qfu(vlc_config_cat_GetName(cat));
    return qfu(vlc_config_cat_GetName(cat)) + QStringLiteral(" › ") + subcatName(subcat);
}

QString catIcon(enum vlc_config_cat cat)
{
    switch (cat)
    {
    case CAT_INTERFACE: return QStringLiteral("interface");
    case CAT_AUDIO:     return QStringLiteral("audio");
    case CAT_VIDEO:     return QStringLiteral("video");
    case CAT_INPUT:     return QStringLiteral("input");
    case CAT_SOUT:      return QStringLiteral("sout");
    case CAT_PLAYLIST:  return QStringLiteral("playlist");
    case CAT_ADVANCED:  return QStringLiteral("advanced");
    default:            return {};
    }
}

// sorted as the classic preferences tree (QTreeWidget: case-insensitive,
// not numeric, so "Direct3D11" comes before "Direct3D9")
void sortByText(QVariantList& list, const QString& key)
{
    QCollator collator;
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::sort(list.begin(), list.end(), [&](const QVariant& a, const QVariant& b) {
        return collator.compare(a.toMap().value(key).toString(), b.toMap().value(key).toString()) < 0;
    });
}

} // namespace

ConfigBridge::ConfigBridge(qt_intf_t* intf, QObject* parent)
    : QObject(parent)
    , m_intf(intf)
{
    assert(m_intf);
    // a settings profile changes any option: "" = all of them
    if (m_intf->p_mi)
        connect(m_intf->p_mi, &MainCtx::settingsProfileChanged, this, [this]() {
            emit valueChanged({});
            emit uiValueChanged({});
        });
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

    // the interface colors follow the accent at once
    if (name == QLatin1String("qt-accent-color") && m_intf->p_mi)
        emit m_intf->p_mi->accentColorChanged();
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

    // Modules of a subcategory or with a capability (the core lists only
    // the CONFIG_ITEM_MODULE ones), as the classic preferences do
    if (item->i_type == CONFIG_ITEM_MODULE_CAT || item->i_type == CONFIG_ITEM_MODULE_LIST_CAT
     || item->i_type == CONFIG_ITEM_MODULE_LIST)
    {
        std::set<QString> seen;
        const auto add = [&](const QString& value, const QString& text) {
            if (seen.insert(value).second)
                ret.append(QVariantMap {
                    { QStringLiteral("value"), value },
                    { QStringLiteral("text"), text },
                });
        };

        for (module_t* module : ModuleList())
        {
            if (module_is_main(module))
                continue;
            const bool match = (item->i_type == CONFIG_ITEM_MODULE_LIST)
                    ? (item->psz_type && module_provides(module, item->psz_type))
                    : moduleInSubcat(module, item->min.i);
            if (!match)
                continue;
            add(qfu(module_get_object(module)), moduleText(module));

            // the web, telnet and console interfaces are all the lua module
            if (!strcmp(module_get_object(module), "lua") && !strcmp(item->psz_name, "extraintf"))
            {
                add(QStringLiteral("http"), QStringLiteral("Web"));
                add(QStringLiteral("telnet"), QStringLiteral("Telnet"));
#ifndef _WIN32
                add(QStringLiteral("cli"), QStringLiteral("Console"));
#endif
            }
        }
        // in module list order, as the classic preferences
        if (item->i_type == CONFIG_ITEM_MODULE_CAT)
            ret.prepend(QVariantMap {
                { QStringLiteral("value"), QString {} },
                { QStringLiteral("text"), qtr("Default") },
            });
        return ret;
    }

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

QVariantList ConfigBridge::browseFiles(const QString& title, const QString& filter) const
{
    QVariantList ret;
    for (const QUrl& url : QFileDialog::getOpenFileUrls(nullptr, title, {}, filter))
        ret.append(url);
    return ret;
}

QString ConfigBridge::browseFolder(const QString& title) const
{
    const QUrl url = QFileDialog::getExistingDirectoryUrl(nullptr, title);
    return url.isEmpty() ? QString {} : url.toString();
}

QVariantList ConfigBridge::hotkeys() const
{
    QVariantList ret;
    module_t* main = module_get_main();
    unsigned count = 0;
    module_config_t* items = module_config_get(main, &count);
    if (!items)
        return ret;

    QStringList globals;
    for (unsigned i = 0; i < count; ++i)
    {
        const module_config_t& item = items[i];
        if (item.i_type == CONFIG_ITEM_KEY && item.psz_text && strncmp(item.psz_name, "global-", 7) == 0)
            globals.append(qfu(item.psz_name));
    }
    for (unsigned i = 0; i < count; ++i)
    {
        const module_config_t& item = items[i];
        if (item.i_type != CONFIG_ITEM_KEY || !item.psz_text || strncmp(item.psz_name, "global-", 7) == 0)
            continue;
        const QString name = qfu(item.psz_name);
        const QString global = QStringLiteral("global-") + name;
        ret.append(QVariantMap {
            { QStringLiteral("name"), name },
            { QStringLiteral("text"), qfut(item.psz_text) },
            { QStringLiteral("global"), globals.contains(global) ? global : QString {} },
        });
    }
    module_config_free(items);
    return ret;
}

QString ConfigBridge::keyFromEvent(int key, int modifiers, const QString& text) const
{
    switch (key)
    {
    case Qt::Key_Control: case Qt::Key_Shift: case Qt::Key_Alt:
    case Qt::Key_Meta: case Qt::Key_AltGr: case Qt::Key_unknown:
        return {};
    default:
        break;
    }
    QKeyEvent event(QEvent::KeyPress, key, Qt::KeyboardModifiers(modifiers), text);
    const int code = qtEventToVLCKey(&event);
    char* str = vlc_keycode2str(code, false);
    QString ret = qfu(str ? str : "");
    free(str);
    return ret;
}

QString ConfigBridge::keyDisplayText(const QString& key) const
{
    QStringList keys;
    for (const QString& one : key.split('\t', Qt::SkipEmptyParts))
    {
        QStringList parts = one.split('+', Qt::SkipEmptyParts);
        for (QString& part : parts)
            part = (part.size() == 1) ? part.toUpper() : part;
        keys.append(parts.join(QStringLiteral(" + ")));
    }
    return keys.join(QStringLiteral(", "));
}

QStringList ConfigBridge::listFiles(const QString& folderUrl, const QStringList& extensions) const
{
    const QString path = QUrl(folderUrl).toLocalFile();
    if (path.isEmpty())
        return {};
    QStringList filters;
    for (const QString& ext : extensions)
        filters.append(QStringLiteral("*.") + ext);
    QStringList files = QDir(path).entryList(filters, QDir::Files | QDir::Readable);
    QCollator collator;
    collator.setNumericMode(true);
    std::sort(files.begin(), files.end(), collator);
    return files;
}

bool ConfigBridge::isDeletableFile(const QString& fileUrl) const
{
    const QString path = QUrl(fileUrl).toLocalFile();
    if (path.isEmpty())
        return false;
    const QFileInfo info(path);
    if (!info.isFile())
        return false;
    // like File Explorer, a read-only file can be deleted: only its folder
    // has to be writable (deleteFile() clears the read-only flag)
    return QFile::permissions(info.absolutePath()) & QFileDevice::WriteUser;
}

bool ConfigBridge::deleteFile(const QString& fileUrl) const
{
    if (!isDeletableFile(fileUrl))
        return false;
    const QString path = QUrl(fileUrl).toLocalFile();
    const QFileDevice::Permissions perms = QFile::permissions(path);
    if (!(perms & QFileDevice::WriteUser))
        QFile::setPermissions(path, perms | QFileDevice::WriteUser | QFileDevice::WriteOwner);
    return QFile::remove(path);
}

QVariant ConfigBridge::browseNode(const QString& folderUrl) const
{
    // same construction as the "Folders" of the Browse view (StandardPathModel)
    const QUrl url(folderUrl);
    if (!url.isValid())
        return {};
    const QString name = url.fileName().isEmpty() ? url.toString() : url.fileName();
    input_item_t* inputItem = input_item_NewDirectory(qtu(url.toString()), qtu(name), ITEM_LOCAL);
    if (!inputItem)
        return {};
    SharedInputItem item(inputItem, false);
    MediaTreePtr tree(vlc_media_tree_New(), false);
    {
        MediaTreeLocker lock{tree};
        vlc_media_tree_Add(tree.get(), &(tree->root), inputItem);
    }
    return QVariant::fromValue(NetworkTreeItem(tree, item));
}

QVariantList ConfigBridge::settingsTree() const
{
    std::map<int, QVariantList> subcats; // by category
    std::set<int> seen;

    const auto addSubcat = [&](enum vlc_config_subcat subcat) {
        const enum vlc_config_cat cat = vlc_config_cat_FromSubcat(subcat);
        if (cat == CAT_UNKNOWN || cat == CAT_HIDDEN)
            return;
        subcats[cat]; // the category exists even without other pages
        // a category's general subcategory is the category's own page
        if (vlc_config_subcat_IsGeneral(subcat) || !seen.insert(subcat).second)
            return;
        subcats[cat].append(QVariantMap {
            { QStringLiteral("subcat"), static_cast<int>(subcat) },
            { QStringLiteral("name"), subcatName(subcat) },
        });
    };

    for (const module_config_t& item : ModuleConfig(module_get_main()))
        if (item.i_type == CONFIG_SUBCATEGORY)
            addSubcat(static_cast<enum vlc_config_subcat>(item.value.i));

    // pages that only modules use
    for (module_t* module : ModuleList())
    {
        if (module_is_main(module))
            continue;
        const enum vlc_config_subcat subcat = modulePlace(module);
        if (subcat != SUBCAT_UNKNOWN)
            addSubcat(subcat);
    }

    QVariantList ret;
    for (size_t i = 0; i < vlc_config_cat_Count(); ++i)
    {
        const enum vlc_config_cat cat = vlc_config_cat_GetAt(i)->id;
        const auto it = subcats.find(cat);
        if (it == subcats.end())
            continue;
        QVariantList pages = it->second;
        sortByText(pages, QStringLiteral("name"));
        ret.append(QVariantMap {
            { QStringLiteral("cat"), static_cast<int>(cat) },
            { QStringLiteral("name"), qfu(vlc_config_cat_GetName(cat)) },
            { QStringLiteral("icon"), catIcon(cat) },
            { QStringLiteral("subcat"), static_cast<int>(vlc_config_cat_GetGeneralSubcat(cat)) },
            { QStringLiteral("subcats"), pages },
        });
    }
    return ret;
}

QVariantMap ConfigBridge::settingsPage(int subcat) const
{
    const auto id = static_cast<enum vlc_config_subcat>(subcat);

    QVariantList sections;
    {
        const ModuleConfig core(module_get_main());
        for (const module_config_t* item = core.begin(); item < core.end(); ++item)
        {
            if (item->i_type == CONFIG_SUBCATEGORY && item->value.i == subcat)
            {
                sections = optionSections(item + 1, core.end(), true);
                break;
            }
        }
    }

    QVariantList modules;
    for (module_t* module : ModuleList())
    {
        if (module_is_main(module) || modulePlace(module) != id)
            continue;
        // the short name, as in the classic preferences tree
        modules.append(QVariantMap {
            { QStringLiteral("name"), qfu(module_get_object(module)) },
            { QStringLiteral("text"), qfut(module_get_name(module, false)) },
        });
    }
    sortByText(modules, QStringLiteral("text"));

    const char* help = vlc_config_subcat_GetHelp(id);
    return {
        { QStringLiteral("title"), subcatName(id) },
        { QStringLiteral("path"), pagePath(id) },
        { QStringLiteral("help"), help ? qfu(help) : QString {} },
        { QStringLiteral("sections"), sections },
        { QStringLiteral("modules"), modules },
    };
}

QVariantMap ConfigBridge::moduleSettings(const QString& name) const
{
    const module_t* module = module_find(name.toUtf8().constData());
    if (!module)
        return {};

    const ModuleConfig config(module);
    // as the classic preferences: the HTML help when there is one
    const char* helpHtml = module_get_help_html(module);
    const char* help = module_get_help(module);
    return {
        { QStringLiteral("name"), name },
        { QStringLiteral("title"), moduleText(module) },
        { QStringLiteral("help"), helpHtml ? qfut(helpHtml) : (help ? qfut(help) : QString {}) },
        { QStringLiteral("helpIsHtml"), helpHtml != nullptr },
        { QStringLiteral("sections"), optionSections(config.begin(), config.end(), false) },
    };
}

QVariantList ConfigBridge::searchSettings(const QString& text, int limit) const
{
    QVariantList ret;
    const QString needle = text.trimmed();
    if (needle.isEmpty())
        return ret;

    const auto matches = [&](const module_config_t& item) {
        if (!CONFIG_ITEM(item.i_type) || item.i_type == CONFIG_ITEM_KEY || item.psz_text == nullptr)
            return false;
        return qfu(item.psz_name).contains(needle, Qt::CaseInsensitive)
            || qfut(item.psz_text).contains(needle, Qt::CaseInsensitive)
            || (item.psz_longtext && qfut(item.psz_longtext).contains(needle, Qt::CaseInsensitive));
    };
    const auto add = [&](const module_config_t& item, const QString& place) {
        ret.append(QVariantMap {
            { QStringLiteral("option"), qfu(item.psz_name) },
            { QStringLiteral("place"), place },
        });
        return ret.size() < limit;
    };

    // the core's options, by page
    enum vlc_config_subcat subcat = SUBCAT_UNKNOWN;
    for (const module_config_t& item : ModuleConfig(module_get_main()))
    {
        if (item.i_type == CONFIG_SUBCATEGORY)
            subcat = static_cast<enum vlc_config_subcat>(item.value.i);
        const enum vlc_config_cat cat = vlc_config_cat_FromSubcat(subcat);
        if (cat == CAT_UNKNOWN || cat == CAT_HIDDEN || !matches(item))
            continue;
        if (!add(item, pagePath(subcat)))
            return ret;
    }

    // then the modules' options
    for (module_t* module : ModuleList())
    {
        if (module_is_main(module))
            continue;
        const enum vlc_config_subcat place = modulePlace(module);
        if (place == SUBCAT_UNKNOWN)
            continue;
        const QString where = pagePath(place) + QStringLiteral(" › ") + moduleText(module);
        for (const module_config_t& item : ModuleConfig(module))
            if (matches(item) && !add(item, where))
                return ret;
    }
    return ret;
}

bool ConfigBridge::hasIntf(const QString& module) const
{
    return config_ExistIntf(module.toUtf8().constData());
}

void ConfigBridge::setIntf(const QString& module, bool enabled)
{
    const QByteArray name = module.toUtf8();
    if (enabled)
        config_AddIntf(name.constData());
    else
        config_RemoveIntf(name.constData());
    save();
    emit valueChanged(QStringLiteral("control"));
    emit valueChanged(QStringLiteral("extraintf"));
}

// as the classic simple preferences (getDefaultAudioVolume)
int ConfigBridge::startVolume() const
{
    const QByteArray aout = value(QStringLiteral("aout")).toString().toUtf8();
    const char* name = aout.constData();

    if (!strcmp(name, "") || !strcmp(name, "any"))
#ifdef _WIN32
        // every Windows output that can be chosen automatically keeps its
        // volume; they all share it, so mmdevice's stands for them
        return config_GetFloat("mmdevice-volume") * 100.f + .5f;
#else
        return -1;
#endif

    if (!strcmp(name, "pulse"))
        return -1;
#ifdef __linux__
    if (!strcmp(name, "alsa") && module_exists("alsa"))
        return cbrtf(config_GetFloat("alsa-gain")) * 100.f + .5f;
#endif
#ifdef _WIN32
    if (!strcmp(name, "mmdevice"))
        return config_GetFloat("mmdevice-volume") * 100.f + .5f;
#endif
#ifdef __APPLE__
    if (!strcmp(name, "auhal") && module_exists("auhal"))
        return (config_GetFloat("auhal-volume") * 100.f + .5f) / AOUT_VOLUME_DEFAULT;
#endif
    if (!strcmp(name, "jack"))
        return cbrtf(config_GetFloat("jack-gain")) * 100.f + .5f;
#ifdef __OS2__
    if (!strcmp(name, "kai"))
        return cbrtf(config_GetFloat("kai-gain")) * 100.f + .5f;
#endif
#ifdef _WIN32
    if (!strcmp(name, "waveout"))
        return config_GetFloat("waveout-volume") * 100.f + .5f;
#endif
    return -1;
}

// as the classic simple preferences (SPrefsPanel::apply)
void ConfigBridge::setStartVolume(int percent)
{
    const QByteArray aout = value(QStringLiteral("aout")).toString().toUtf8();
    const char* current = aout.isEmpty() ? nullptr : aout.constData();
    const auto applies = [current](const char* name) {
        return module_exists(name) && (!current || !strcmp(current, name) || !strcmp(current, "any"));
    };
    const float gain = powf(percent / 100.f, 3);
    VLC_UNUSED(gain);

#if defined(_WIN32)
    if (applies("mmdevice"))
        config_PutFloat("mmdevice-volume", percent / 100.f);
    if (applies("waveout"))
        config_PutFloat("waveout-volume", percent / 100.f);
#elif defined(__APPLE__)
    if (applies("auhal"))
        config_PutFloat("auhal-volume", percent / 100.f * AOUT_VOLUME_DEFAULT);
#elif defined(__OS2__)
    if (applies("kai"))
        config_PutFloat("kai-gain", gain);
#else
    if (applies("alsa"))
        config_PutFloat("alsa-gain", gain);
    if (applies("jack"))
        config_PutFloat("jack-gain", gain);
#endif
    save();
    emit valueChanged(QStringLiteral("#startVolume"));
}

QVariantList ConfigBridge::languages() const
{
#ifdef _WIN32
    return SPrefsPanel::languageChoices();
#else
    return {};
#endif
}

QString ConfigBridge::language() const
{
#ifdef _WIN32
    return SPrefsPanel::savedLanguage();
#else
    return {};
#endif
}

void ConfigBridge::setLanguage(const QString& iso)
{
#ifdef _WIN32
    SPrefsPanel::saveLanguage(iso);
    emit valueChanged(QStringLiteral("#language"));
#else
    VLC_UNUSED(iso);
#endif
}

static const QString styleSettingsKey = QStringLiteral("MainWindow/QtStyle");

QVariantList ConfigBridge::qtStyles() const
{
    const QString initialStyle = qApp->property("initialStyle").toString();
    QVariantList ret {
        QVariantMap {
            { QStringLiteral("value"), QString {} },
            { QStringLiteral("text"), qtr("System's default (%1)").arg(initialStyle) },
        }
    };
    for (const QString& style : QStyleFactory::keys())
        ret.append(QVariantMap {
            { QStringLiteral("value"), style },
            { QStringLiteral("text"), style },
        });
    return ret;
}

QString ConfigBridge::qtStyle() const
{
    QSettings* const settings = m_intf->mainSettings;
    return settings ? settings->value(styleSettingsKey).toString() : QString {};
}

// as the classic simple preferences: applied at once, and kept for the
// next start (qt.cpp reads the same key)
void ConfigBridge::setQtStyle(const QString& style)
{
    if (QSettings* const settings = m_intf->mainSettings)
    {
        if (style.isEmpty())
            settings->remove(styleSettingsKey);
        else
            settings->setValue(styleSettingsKey, style);
    }
    const QString applied = style.isEmpty() ? qApp->property("initialStyle").toString() : style;
    QMetaObject::invokeMethod(qApp, [applied]() {
        QApplication::setStyle(applied);
    }, Qt::QueuedConnection);
    emit valueChanged(QStringLiteral("#qtStyle"));
}

// as PrefsDialog::reset()
void ConfigBridge::resetPreferences()
{
    config_ResetAll();
    save();
    if (QSettings* const settings = m_intf->mainSettings)
        settings->clear();
    m_intf->preferencesResetPending = true;
    if (m_intf->p_mi)
    {
        m_intf->p_mi->reloadPrefs();
        m_intf->p_mi->reloadFromSettings();
    }
#ifdef _WIN32
    SPrefsPanel::cleanLanguage();
#endif
    emit valueChanged(QString {});
}

void ConfigBridge::fileAssociations() const
{
#ifdef _WIN32
    SPrefsPanel::showFileAssociations(nullptr);
#endif
}

void ConfigBridge::clearRecentMedia() const
{
    MediaLib* const mediaLib = m_intf->p_mi ? m_intf->p_mi->getMediaLibrary() : nullptr;
    if (!mediaLib)
        return;
    mediaLib->runOnMLThread(this, [](vlc_medialibrary_t* ml) {
        vlc_ml_clear_history(ml, VLC_ML_HISTORY_TYPE_GLOBAL);
    });
}

QObject* ConfigBridge::mediaFolders(bool banned)
{
    if (!m_intf->p_mi || !m_intf->p_mi->hasMediaLibrary())
        return nullptr;
    QObject*& model = banned ? m_bannedFolders : m_mediaFolders;
    if (!model)
    {
        MLFoldersBaseModel* folders = banned ? static_cast<MLFoldersBaseModel*>(new MLBannedFoldersModel(this))
                                             : static_cast<MLFoldersBaseModel*>(new MLFoldersModel(this));
        folders->setCtx(m_intf->p_mi);
        model = folders;
    }
    return model;
}

void ConfigBridge::reloadMediaLibrary() const
{
    MediaLib* const mediaLib = m_intf->p_mi ? m_intf->p_mi->getMediaLibrary() : nullptr;
    if (mediaLib)
        mediaLib->reload();
}

void ConfigBridge::save()
{
    config_SaveConfigFile(m_intf);
}

QVariant ConfigBridge::uiValue(const QString& key, const QVariant& defaultValue) const
{
    QSettings* const settings = m_intf->mainSettings;
    return settings ? settings->value(key, defaultValue) : defaultValue;
}

void ConfigBridge::setUiValue(const QString& key, const QVariant& value)
{
    QSettings* const settings = m_intf->mainSettings;
    if (!settings)
        return;
    settings->setValue(key, value);
    emit uiValueChanged(key);
}

QStringList ConfigBridge::musicFolders() const
{
    return uiValue(QStringLiteral("Library/MusicFolders")).toStringList();
}

void ConfigBridge::setMusicFolder(const QString& url, bool music)
{
    const QString key = QUrl(url).adjusted(QUrl::StripTrailingSlash | QUrl::NormalizePathSegments)
                            .toString(QUrl::FullyEncoded);
    if (key.isEmpty())
        return;
    QStringList list = musicFolders();
    if (music == list.contains(key))
        return;
    if (music)
        list.append(key);
    else
        list.removeAll(key);
    setUiValue(QStringLiteral("Library/MusicFolders"), list);
}
