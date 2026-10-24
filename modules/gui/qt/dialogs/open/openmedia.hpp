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
#ifndef VLC_QT_OPENMEDIA_HPP
#define VLC_QT_OPENMEDIA_HPP

#include <QObject>
#include <QStringList>
#include <QVariant>

#include "qt.hpp"

/**
 * What the Open Media window of the redesign (OpenMediaDialog.qml) needs
 * from VLC: the disc drives and capture devices, the MRL of a disc, and
 * adding the result to the queue (or handing it to Stream / Convert).
 * The MRLs and options are the ones of the classic Open Media dialog.
 */
class OpenMediaHelper : public QObject
{
    Q_OBJECT

public:
    explicit OpenMediaHelper(qt_intf_t* intf, QObject* parent = nullptr);

    /// optical drives: [{ text, value }] (value = device path)
    Q_INVOKABLE QVariantList discDevices() const;
    /// MRL of a disc: scheme "dvd", "dvdsimple", "dvda", "bluray", "vcd", "cdda"
    Q_INVOKABLE QString discMrl(const QString& device, const QString& scheme) const;
    Q_INVOKABLE void eject(const QString& device) const;

    /// video capture devices (/dev/video*), Linux only
    Q_INVOKABLE QStringList videoDevices() const;
    /// ALSA capture devices ("hw:0,0"), Linux only
    Q_INVOKABLE QStringList alsaDevices() const;

    /// a typed network URL with the invalid characters escaped
    Q_INVOKABLE QString fixupUrl(const QString& url) const;

    /// local path of a file URL, or the URL itself when it is not a file
    Q_INVOKABLE QString displayPath(const QString& url) const;
    /// value of a ":name=value" option: the file path for a file URL, with
    /// the colons escaped
    Q_INVOKABLE QString optionPath(const QString& url) const;

    /// adds the MRLs, each with the options (":name=value"), to the queue
    Q_INVOKABLE void open(const QStringList& mrls, const QStringList& options, bool play) const;
    /// the classic Stream wizard or Convert dialog for the MRLs
    Q_INVOKABLE void stream(const QStringList& mrls, const QStringList& options, bool convert) const;

private:
    qt_intf_t* p_intf;
};

#endif
