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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "openmedia.hpp"

#include <QDir>
#include <QRegularExpression>
#include <QUrl>

#include <vlc_common.h>
#include <vlc_url.h>

#include "dialogs/dialogs_provider.hpp"
#include "playlist/playlist_controller.hpp"
#include "util/qt_dirs.hpp"

#include "../../../eject.c"

OpenMediaHelper::OpenMediaHelper(qt_intf_t* intf, QObject* parent)
    : QObject(parent)
    , p_intf(intf)
{
}

QVariantList OpenMediaHelper::discDevices() const
{
    QVariantList ret;
    const auto add = [&](const QString& text, const QString& value) {
        ret.append(QVariantMap {
            { QStringLiteral("text"), text },
            { QStringLiteral("value"), value },
        });
    };

#ifdef _WIN32
    // as the classic dialog: the CD/DVD drives, with the disc name
    wchar_t drives[512];
    drives[0] = L'\0';
    if (GetLogicalDriveStringsW(ARRAY_SIZE(drives) - 1, drives))
    {
        DWORD oldMode;
        SetThreadErrorMode(SEM_FAILCRITICALERRORS, &oldMode);
        for (wchar_t* drive = drives; *drive; drive += wcslen(drive) + 1)
        {
            if (GetDriveTypeW(drive) != DRIVE_CDROM)
                continue;
            wchar_t name[512] = L"";
            GetVolumeInformationW(drive, name, ARRAY_SIZE(name) - 1, NULL, NULL, NULL, NULL, 0);
            const QString path = QString::fromWCharArray(drive);
            const QString title = QString::fromWCharArray(name);
            add(title.isEmpty() ? path : path + QStringLiteral(" - ") + title, path);
        }
        SetThreadErrorMode(oldMode, NULL);
    }
#elif !defined(__OS2__)
    const QStringList patterns { "sr*", "sg*", "scd*", "dvd*", "cd*" };
    for (const QString& node : QDir(QStringLiteral("/dev/")).entryList(patterns, QDir::System))
        add(QStringLiteral("/dev/") + node, QStringLiteral("/dev/") + node);
#endif
    return ret;
}

QString OpenMediaHelper::discMrl(const QString& device, const QString& scheme) const
{
    char* mrl = vlc_path2uri(qtu(device), qtu(scheme));
    if (!mrl)
        return {};
    const QString ret = qfu(mrl);
    free(mrl);
    return ret;
}

void OpenMediaHelper::eject(const QString& device) const
{
    intf_Eject(p_intf, qtu(device));
}

QStringList OpenMediaHelper::videoDevices() const
{
#ifdef _WIN32
    return {};
#else
    return QDir(QStringLiteral("/dev/")).entryList({ QStringLiteral("video*") }, QDir::System)
            .replaceInStrings(QRegularExpression(QStringLiteral("^")), QStringLiteral("/dev/"));
#endif
}

QStringList OpenMediaHelper::alsaDevices() const
{
#ifdef _WIN32
    return {};
#else
    // capture nodes pcmC<card>D<device>c, as "hw:<card>,<device>"
    QStringList nodes = QDir(QStringLiteral("/dev/snd")).entryList({ QStringLiteral("pcmC*D*c") }, QDir::System);
    return nodes.replaceInStrings(QRegularExpression(QStringLiteral("^pcmC")), QStringLiteral("hw:"))
                .replaceInStrings(QRegularExpression(QStringLiteral("c$")), QString {})
                .replaceInStrings(QRegularExpression(QStringLiteral("D")), QStringLiteral(","));
#endif
}

QString OpenMediaHelper::fixupUrl(const QString& url) const
{
    if (!url.contains(QLatin1String("://")))
        return url;
    char* uri = vlc_uri_fixup(qtu(url));
    if (!uri)
        return {};
    const QString ret = qfu(uri);
    free(uri);
    return ret;
}

QString OpenMediaHelper::displayPath(const QString& url) const
{
    const QUrl u(url);
    return u.isLocalFile() ? toNativeSeparators(u.toLocalFile()) : url;
}

QString OpenMediaHelper::optionPath(const QString& url) const
{
    return colon_escape(displayPath(url));
}

void OpenMediaHelper::open(const QStringList& mrls, const QStringList& options, bool play) const
{
    QStringList sorted = mrls;
    sorted.sort();

    QVector<vlc::playlist::Media> medias;
    for (const QString& mrl : sorted)
        medias.push_back(vlc::playlist::Media { mrl, QString {}, options });
    if (!medias.empty())
        THEMPL->append(medias, play);
}

void OpenMediaHelper::stream(const QStringList& mrls, const QStringList& options, bool convert) const
{
    if (mrls.isEmpty())
        return;
    THEDP->streamingDialog(nullptr, mrls, convert, options);
}
