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

#include "audio_waveform.hpp"

#include <QMutex>
#include <QMutexLocker>

#include <algorithm>
#include <cmath>
#include <vector>

#include <vlc_common.h>
#include <vlc_input_item.h>
#include <vlc_player.h>

namespace {
// loudness is kept for every 50 ms of audio
constexpr qint64 BUCKET_MS = 50;
// the audio is decoded as mono 16 bit at this rate: enough for the levels
constexpr unsigned DECODE_RATE = 8000;
constexpr unsigned SAMPLES_PER_BUCKET = DECODE_RATE * BUCKET_MS / 1000;
}

struct AudioWaveform::Job
{
    AudioWaveform *owner = nullptr;
    vlc_player_t *player = nullptr;
    vlc_player_listener_id *listener = nullptr;

    // written by the stream output thread
    QMutex lock;
    std::vector<double> sumSquares;    // per bucket
    std::vector<uint32_t> counts;      // samples per bucket
    uint64_t samples = 0;
    std::vector<uint8_t> buffer;       // given to smem

    static void prerender(void *data, uint8_t **buffer, size_t size)
    {
        auto *job = static_cast<Job *>(data);
        job->buffer.resize(size);
        *buffer = job->buffer.data();
    }

    static void postrender(void *data, uint8_t *pcm, unsigned channels, unsigned rate,
                           unsigned nbSamples, unsigned bitsPerSample, size_t, vlc_tick_t)
    {
        auto *job = static_cast<Job *>(data);
        if (bitsPerSample != 16 || channels == 0 || rate == 0)
            return;
        const auto *samples = reinterpret_cast<const int16_t *>(pcm);
        const uint64_t perBucket = std::max<uint64_t>(1, uint64_t(rate) * BUCKET_MS / 1000);

        QMutexLocker locker(&job->lock);
        for (unsigned i = 0; i < nbSamples; ++i)
        {
            const size_t bucket = (job->samples + i) / perBucket;
            if (bucket >= job->sumSquares.size())
            {
                job->sumSquares.resize(bucket + 1, 0.);
                job->counts.resize(bucket + 1, 0);
            }
            const double v = samples[i * channels] / 32768.;
            job->sumSquares[bucket] += v * v;
            job->counts[bucket]++;
        }
        job->samples += nbSamples;
    }

    // RMS of every bucket
    QVector<float> levels()
    {
        QMutexLocker locker(&lock);
        QVector<float> result(sumSquares.size());
        for (size_t i = 0; i < sumSquares.size(); ++i)
            result[i] = counts[i] ? float(std::sqrt(sumSquares[i] / counts[i])) : 0.f;
        return result;
    }
};

AudioWaveform::AudioWaveform(qt_intf_t *intf, QObject *parent)
    : QObject(parent)
    , m_intf(intf)
{
    m_refresh.setInterval(250);
    connect(&m_refresh, &QTimer::timeout, this, [this]() {
        if (!m_job)
            return;
        m_levels = m_job->levels();
        emit levelsChanged();
    });
}

AudioWaveform::~AudioWaveform()
{
    stop();
}

void AudioWaveform::load(const QString &mrl)
{
    if (mrl == m_mrl)
        return;
    clear();
    if (mrl.isEmpty())
        return;

    m_mrl = mrl;
    emit mrlChanged();

    auto job = new Job;
    job->player = vlc_player_New(VLC_OBJECT(m_intf), VLC_PLAYER_LOCK_NORMAL);
    if (!job->player)
    {
        delete job;
        return;
    }

    input_item_t *item = input_item_New(qtu(mrl), nullptr);
    if (!item)
    {
        vlc_player_Delete(job->player);
        delete job;
        return;
    }

    // decode the audio only, as fast as possible (no time sync), into the
    // callbacks of the job
    const QString sout = QStringLiteral(
        ":sout=#transcode{acodec=s16l,channels=1,samplerate=%1}"
        ":smem{audio-prerender-callback=%2,audio-postrender-callback=%3,audio-data=%4,no-time-sync}")
        .arg(DECODE_RATE)
        .arg(qint64(intptr_t(&Job::prerender)))
        .arg(qint64(intptr_t(&Job::postrender)))
        .arg(qint64(intptr_t(job)));
    input_item_AddOption(item, ":no-video", VLC_INPUT_OPTION_TRUSTED);
    input_item_AddOption(item, ":no-spu", VLC_INPUT_OPTION_TRUSTED);
    input_item_AddOption(item, qtu(sout), VLC_INPUT_OPTION_TRUSTED);

    static const struct vlc_player_cbs cbs = [] {
        struct vlc_player_cbs c = {};
        c.on_state_changed = [](vlc_player_t *, enum vlc_player_state state, void *data) {
            if (state != VLC_PLAYER_STATE_STOPPED)
                return;
            auto *job = static_cast<Job *>(data);
            AudioWaveform *self = job->owner;
            QMetaObject::invokeMethod(self, [self, job]() { self->finished(job); }, Qt::QueuedConnection);
        };
        return c;
    }();

    job->owner = this;
    vlc_player_Lock(job->player);
    job->listener = vlc_player_AddListener(job->player, &cbs, job);
    int ret = vlc_player_SetCurrentMedia(job->player, item);
    if (ret == VLC_SUCCESS)
        ret = vlc_player_Start(job->player);
    vlc_player_Unlock(job->player);
    input_item_Release(item);

    m_job = job;
    if (ret != VLC_SUCCESS)
    {
        stop();
        return;
    }
    m_refresh.start();
    emit loadingChanged();
}

void AudioWaveform::clear()
{
    stop();
    m_levels.clear();
    if (!m_mrl.isEmpty())
    {
        m_mrl.clear();
        emit mrlChanged();
    }
    emit levelsChanged();
}

void AudioWaveform::stop()
{
    m_refresh.stop();
    if (!m_job)
        return;
    Job *job = m_job;
    m_job = nullptr;

    vlc_player_Lock(job->player);
    if (job->listener)
        vlc_player_RemoveListener(job->player, job->listener);
    vlc_player_Unlock(job->player);
    // stops the decoding and waits for it: no callback after this
    vlc_player_Delete(job->player);
    delete job;
    emit loadingChanged();
}

void AudioWaveform::finished(Job *job)
{
    if (job != m_job)
        return;
    m_levels = job->levels();
    stop();
    emit levelsChanged();
}

QVariantList AudioWaveform::levels(int count, qint64 lengthMs) const
{
    QVariantList result;
    if (count <= 0)
        return result;
    result.reserve(count);

    const qsizetype decoded = m_levels.size();
    qsizetype total = decoded;
    if (m_job && lengthMs > 0)
        total = std::max<qsizetype>(decoded, (lengthMs + BUCKET_MS - 1) / BUCKET_MS);
    if (total == 0)
    {
        for (int i = 0; i < count; ++i)
            result.append(-1.);
        return result;
    }

    // louder parts get the full height
    float peak = 0.f;
    for (float v : m_levels)
        peak = std::max(peak, v);
    if (peak <= 0.f)
        peak = 1.f;

    for (int i = 0; i < count; ++i)
    {
        const qsizetype from = total * i / count;
        const qsizetype to = std::max(from + 1, total * (i + 1) / count);
        if (from >= decoded)
        {
            result.append(-1.);
            continue;
        }
        double sum = 0.;
        qsizetype n = 0;
        for (qsizetype b = from; b < std::min(to, decoded); ++b, ++n)
            sum += m_levels[b];
        const double v = n ? sum / n / peak : 0.;
        // a little curve so that quiet parts stay visible
        result.append(std::pow(std::clamp(v, 0., 1.), 0.7));
    }
    return result;
}
