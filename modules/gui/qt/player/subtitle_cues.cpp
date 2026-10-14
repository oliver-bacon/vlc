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

#include "subtitle_cues.hpp"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QStringList>
#include <QUrl>

#include <algorithm>
#include <utility>
#include <vector>

#include <vlc_common.h>
#include <vlc_input_item.h>
#include <vlc_player.h>
#include <vlc_url.h>

#include "player/player_controller.hpp"

namespace {

const QStringList SUB_EXTENSIONS = { "srt", "vtt", "ass", "ssa" };
// folders VLC looks into by default (option sub-autodetect-path)
const QStringList SUB_FOLDERS = { ".", "Subtitles", "subtitles", "Subs", "subs" };

qint64 toMs(const QString &h, const QString &m, const QString &s, const QString &frac)
{
    // the fraction has 1 to 3 digits: "5" = 500 ms, "05" = 50 ms
    QString f = frac.left(3);
    while (f.size() < 3)
        f.append(QLatin1Char('0'));
    return ((h.isEmpty() ? 0 : h.toLongLong()) * 3600 + m.toLongLong() * 60 + s.toLongLong()) * 1000
           + f.toLongLong();
}

QString localPath(const char *uri)
{
    char *path = vlc_uri2path(uri);
    if (!path)
        return {};
    const QString result = QString::fromUtf8(path);
    free(path);
    return result;
}

} // namespace

SubtitleCues::SubtitleCues(qt_intf_t *intf, QObject *parent)
    : QObject(parent)
    , m_intf(intf)
{
}

QVariantList SubtitleCues::parseFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    // only the times are read, which are plain ASCII in any encoding
    const QString text = QString::fromLatin1(file.read(16 * 1024 * 1024));

    std::vector<std::pair<qint64, qint64>> cues;

    // SubRip and WebVTT: "00:01:02,345 --> 00:01:04,000" (hours optional in WebVTT)
    static const QRegularExpression timing(
        QStringLiteral("(?:(\\d+):)?(\\d{1,2}):(\\d{2})[,.](\\d{1,3})\\s*-->\\s*"
                       "(?:(\\d+):)?(\\d{1,2}):(\\d{2})[,.](\\d{1,3})"));
    // SubStation: "Dialogue: 0,0:01:02.34,0:01:04.00,..."
    static const QRegularExpression dialogue(
        QStringLiteral("^Dialogue:\\s*[^,]*,(\\d+):(\\d{2}):(\\d{2})\\.(\\d{1,3}),"
                       "(\\d+):(\\d{2}):(\\d{2})\\.(\\d{1,3})"),
        QRegularExpression::MultilineOption);

    const QString suffix = QFileInfo(path).suffix().toLower();
    const QRegularExpression &re = (suffix == QLatin1String("ass") || suffix == QLatin1String("ssa"))
                                   ? dialogue : timing;

    auto it = re.globalMatch(text);
    while (it.hasNext())
    {
        const QRegularExpressionMatch m = it.next();
        const qint64 start = toMs(m.captured(1), m.captured(2), m.captured(3), m.captured(4));
        const qint64 end = toMs(m.captured(5), m.captured(6), m.captured(7), m.captured(8));
        if (end > start)
            cues.emplace_back(start, end);
    }

    std::sort(cues.begin(), cues.end());

    QVariantList result;
    result.reserve(static_cast<qsizetype>(cues.size() * 2));
    for (const auto &cue : cues)
    {
        result.append(cue.first);
        result.append(cue.second);
    }
    return result;
}

QVariantMap SubtitleCues::load() const
{
    QVariantMap result { { "file", QString() }, { "cues", QVariantList() } };

    vlc_player_t *player = m_intf->p_mainPlayerController->getPlayer();

    QString mediaPath;
    QString trackName;
    QStringList slaves;
    {
        vlc_player_locker lock { player };

        input_item_t *item = vlc_player_GetCurrentMedia(player);
        if (!item)
            return result;

        const struct vlc_player_track *track = vlc_player_GetSelectedTrack(player, SPU_ES);
        if (!track)
            return result; // no subtitles shown
        trackName = QString::fromUtf8(track->name);

        vlc_mutex_lock(&item->lock);
        if (item->psz_uri)
            mediaPath = localPath(item->psz_uri);
        for (int i = 0; i < item->i_slaves; ++i)
        {
            const input_item_slave_t *slave = item->pp_slaves[i];
            if (slave->i_type == SLAVE_TYPE_SPU)
            {
                const QString path = localPath(slave->psz_uri);
                if (!path.isEmpty())
                    slaves.append(path);
            }
        }
        vlc_mutex_unlock(&item->lock);
    }

    // files next to the media named like it
    QStringList candidates;
    for (const QString &path : std::as_const(slaves))
        if (SUB_EXTENSIONS.contains(QFileInfo(path).suffix().toLower()))
            candidates.append(path);

    if (!mediaPath.isEmpty())
    {
        const QFileInfo media(mediaPath);
        const QString baseName = media.completeBaseName();
        QStringList filters;
        for (const QString &ext : SUB_EXTENSIONS)
            filters.append(QStringLiteral("*.") + ext);

        for (const QString &folder : SUB_FOLDERS)
        {
            const QDir dir(media.dir().filePath(folder));
            if (!dir.exists())
                continue;
            const QFileInfoList files = dir.entryInfoList(filters, QDir::Files, QDir::Name);
            for (const QFileInfo &file : files)
            {
                if (file.completeBaseName().startsWith(baseName, Qt::CaseInsensitive)
                    && !candidates.contains(file.absoluteFilePath()))
                    candidates.append(file.absoluteFilePath());
            }
        }
    }

    if (candidates.isEmpty())
        return result;

    // VLC names external tracks after the file in some cases; otherwise
    // take the first candidate (slaves come first)
    QString chosen = candidates.first();
    for (const QString &path : std::as_const(candidates))
    {
        const QString name = QFileInfo(path).completeBaseName();
        if (!trackName.isEmpty() && (trackName.contains(name, Qt::CaseInsensitive)
                                     || name.endsWith(QLatin1Char('.') + trackName, Qt::CaseInsensitive)))
        {
            chosen = path;
            break;
        }
    }

    result["file"] = chosen;
    result["cues"] = parseFile(chosen);
    return result;
}
