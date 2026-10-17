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
#ifndef AUDIO_WAVEFORM_HPP
#define AUDIO_WAVEFORM_HPP

#include <QObject>
#include <QString>
#include <QTimer>
#include <QVariantList>

#include "qt.hpp"

/**
 * Waveform of the VLC Redesign seek bar, for audio files.
 *
 * load() decodes the audio of a media in the background with a private
 * player and the "#transcode{s16l, mono}:smem" stream output, faster than
 * real time, and keeps the loudness (RMS) of every 50 ms. levels() turns it
 * into the bars of the seek bar. The waveform fills in while it is decoded
 * (levelsChanged() a few times per second).
 */
class AudioWaveform : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString mrl READ mrl NOTIFY mrlChanged FINAL)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged FINAL)

public:
    explicit AudioWaveform(qt_intf_t *intf, QObject *parent = nullptr);
    ~AudioWaveform() override;

    /// decode @p mrl (nothing when it is already the current one)
    Q_INVOKABLE void load(const QString &mrl);
    /// stop decoding and forget the waveform
    Q_INVOKABLE void clear();
    /// @p count bars over @p lengthMs: values 0..1, or -1 where the audio is
    /// not decoded yet
    Q_INVOKABLE QVariantList levels(int count, qint64 lengthMs) const;

    QString mrl() const { return m_mrl; }
    bool loading() const { return m_job != nullptr; }

signals:
    void mrlChanged();
    void loadingChanged();
    void levelsChanged();

private:
    struct Job;
    void stop();
    void finished(Job *job);

    qt_intf_t *m_intf;
    QString m_mrl;
    Job *m_job = nullptr;
    // RMS of every bucket of the finished (or running) job
    QVector<float> m_levels;
    QTimer m_refresh;
};

#endif // AUDIO_WAVEFORM_HPP
