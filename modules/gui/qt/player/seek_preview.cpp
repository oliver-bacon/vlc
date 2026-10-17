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

#include "seek_preview.hpp"

#include <QByteArray>
#include <QMutexLocker>

#include <vlc_common.h>
#include <vlc_block.h>
#include <vlc_input_item.h>
#include <vlc_picture.h>
#include <vlc_preparser.h>

namespace {
// width of the exported frame (the preview shows it at 252 px, so this is
// enough for 2x screens)
constexpr int PREVIEW_WIDTH = 504;
constexpr int CACHE_SIZE = 64;
}

QMutex SeekPreview::s_imagesLock;
QHash<QString, QImage> SeekPreview::s_images;

QImage SeekPreviewImageProvider::requestImage(const QString &id, QSize *size, const QSize &)
{
    QImage image;
    {
        QMutexLocker locker(&SeekPreview::s_imagesLock);
        image = SeekPreview::s_images.value(id);
    }
    if (size)
        *size = image.size();
    return image;
}

struct SeekPreview::Request
{
    SeekPreview *self;
    QString key;
    qint64 timeMs;
};

SeekPreview::SeekPreview(qt_intf_t *intf, QObject *parent)
    : QObject(parent)
    , m_intf(intf)
{
}

SeekPreview::~SeekPreview()
{
    m_closing = true;

    vlc_preparser_req *pending;
    {
        QMutexLocker locker(&m_lock);
        pending = m_pending;
        m_pending = nullptr;
    }
    if (pending)
    {
        // the callback may run synchronously here: no lock held
        vlc_preparser_Cancel(m_preparser, pending);
        vlc_preparser_req_Release(pending);
    }
    if (m_preparser)
        vlc_preparser_Delete(m_preparser); // waits for running callbacks
}

bool SeekPreview::available() const
{
    return true;
}

bool SeekPreview::ensurePreparser()
{
    if (m_preparser)
        return true;

    struct vlc_preparser_cfg cfg{};
    cfg.types = VLC_PREPARSER_TYPE_THUMBNAIL;
    cfg.max_thumbnailer_threads = 1;
    cfg.timeout = VLC_TICK_FROM_SEC(5);
    cfg.external_process = false;
    m_preparser = vlc_preparser_New(VLC_OBJECT(m_intf), &cfg);
    return m_preparser != nullptr;
}

void SeekPreview::clear()
{
    vlc_preparser_req *pending;
    {
        QMutexLocker locker(&m_lock);
        pending = m_pending;
        m_pending = nullptr;
    }
    if (pending)
    {
        vlc_preparser_Cancel(m_preparser, pending);
        vlc_preparser_req_Release(pending);
    }
    m_cache.clear();
    m_cacheOrder.clear();
    {
        QMutexLocker locker(&s_imagesLock);
        s_images.clear();
    }
    m_wanted.clear();
    if (!m_source.isEmpty())
    {
        m_source.clear();
        m_time = -1;
        emit sourceChanged();
    }
}

void SeekPreview::request(const QString &mrl, qint64 timeMs)
{
    if (mrl.isEmpty() || timeMs < 0)
        return;

    const QString key = mrl + QLatin1Char('#') + QString::number(timeMs);
    if (key == m_wanted)
        return;
    m_wanted = key;

    // the previous request is no longer wanted
    vlc_preparser_req *pending;
    {
        QMutexLocker locker(&m_lock);
        pending = m_pending;
        m_pending = nullptr;
    }
    if (pending)
    {
        vlc_preparser_Cancel(m_preparser, pending);
        vlc_preparser_req_Release(pending);
    }

    const auto cached = m_cache.constFind(key);
    if (cached != m_cache.constEnd())
    {
        setSource(cached.value(), timeMs);
        return;
    }

    if (!ensurePreparser())
        return;

    input_item_t *item = input_item_New(qtu(mrl), nullptr);
    if (!item)
        return;

    struct vlc_thumbnailer_arg arg{};
    arg.seek.type = vlc_thumbnailer_arg::seek::VLC_THUMBNAILER_SEEK_TIME;
    arg.seek.time = VLC_TICK_FROM_MS(timeMs);
    arg.seek.speed = vlc_thumbnailer_arg::seek::VLC_THUMBNAILER_SEEK_FAST;
    arg.hw_dec = false;

    static const struct vlc_thumbnailer_cbs cbs = { &SeekPreview::onEnded };

    auto *data = new Request{ this, key, timeMs };
    vlc_preparser_req *req = vlc_preparser_req_NewThumbnail(m_preparser, item, &arg, &cbs, data);
    input_item_Release(item);
    if (!req)
    {
        delete data;
        return;
    }

    {
        QMutexLocker locker(&m_lock);
        m_pending = req;
    }

    if (vlc_preparser_Submit(m_preparser, req) != VLC_SUCCESS)
    {
        {
            QMutexLocker locker(&m_lock);
            if (m_pending == req)
                m_pending = nullptr;
        }
        vlc_preparser_req_Release(req);
        delete data;
    }
}

// preparser thread (or the thread calling vlc_preparser_Cancel)
void SeekPreview::onEnded(vlc_preparser_req *req, int status, picture_t *pic, void *opaque)
{
    auto *data = static_cast<Request *>(opaque);
    SeekPreview *self = data->self;

    // the handle is released by whoever takes it out of m_pending
    bool release = false;
    {
        QMutexLocker locker(&self->m_lock);
        if (self->m_pending == req)
        {
            self->m_pending = nullptr;
            release = true;
        }
    }

    if (status == VLC_SUCCESS && pic && !self->m_closing)
    {
        block_t *block = nullptr;
        if (picture_Export(VLC_OBJECT(self->m_intf), &block, nullptr, pic,
                           VLC_CODEC_PNG, PREVIEW_WIDTH, 0, false) == VLC_SUCCESS && block)
        {
            const QImage image = QImage::fromData(reinterpret_cast<const uchar *>(block->p_buffer),
                                                  static_cast<int>(block->i_buffer), "PNG");
            block_Release(block);

            if (image.isNull())
            {
                msg_Warn(self->m_intf, "seek preview: the frame could not be read");
            }
            else
            {
                const QString key = data->key;
                const qint64 timeMs = data->timeMs;
                QMetaObject::invokeMethod(self, [self, key, timeMs, image]() {
                    self->publish(key, timeMs, image);
                }, Qt::QueuedConnection);
            }
        }
        else
        {
            msg_Warn(self->m_intf, "seek preview: the frame could not be exported");
        }
    }

    if (release)
        vlc_preparser_req_Release(req);
    delete data;
}

void SeekPreview::publish(const QString &key, qint64 timeMs, const QImage &image)
{
    if (!m_cache.contains(key))
    {
        const QString id = QString::number(++m_serial);
        {
            QMutexLocker locker(&s_imagesLock);
            s_images.insert(id, image);
        }
        m_cache.insert(key, id);
        m_cacheOrder.append(key);
        while (m_cacheOrder.size() > CACHE_SIZE)
        {
            const QString oldId = m_cache.take(m_cacheOrder.takeFirst());
            QMutexLocker locker(&s_imagesLock);
            s_images.remove(oldId);
        }
    }

    if (key != m_wanted)
        return;

    setSource(m_cache.value(key), timeMs);
}

void SeekPreview::setSource(const QString &id, qint64 timeMs)
{
    m_source = QStringLiteral("image://%1/%2").arg(QLatin1String(SeekPreviewImageProvider::providerId), id);
    m_time = timeMs;
    emit sourceChanged();
}
