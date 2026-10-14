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
#ifndef SUBTITLE_CUES_HPP
#define SUBTITLE_CUES_HPP

#include <QObject>
#include <QString>
#include <QVariantMap>

#include "qt.hpp"

/**
 * Cue times for the subtitle timeline of the VLC Redesign seek bar.
 *
 * VLC does not expose the times of subtitle lines, so they are read from
 * the subtitle file itself: a subtitle slave of the current media, or a
 * file next to the media named like it (as VLC's autodetection finds
 * them). SubRip (.srt), WebVTT (.vtt) and SubStation (.ass, .ssa) files are
 * read. Embedded subtitle tracks have no file, so they give no cues.
 */
class SubtitleCues : public QObject
{
    Q_OBJECT

public:
    explicit SubtitleCues(qt_intf_t *intf, QObject *parent = nullptr);

    /// Reads the cues of the selected subtitle track of the current media.
    /// @return { "file": path read or "", "cues": [start0, end0, start1, ...] (ms) }
    Q_INVOKABLE QVariantMap load() const;

    /// Cues of a given subtitle file (same format as load()'s "cues").
    static QVariantList parseFile(const QString &path);

private:
    qt_intf_t *m_intf;
};

#endif // SUBTITLE_CUES_HPP
