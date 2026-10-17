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
#ifndef SEEK_PREVIEW_HPP
#define SEEK_PREVIEW_HPP

#include <QObject>
#include <QImage>
#include <QQuickImageProvider>
#include <QString>
#include <QHash>
#include <QList>
#include <QMutex>
#include <atomic>

#include "qt.hpp"

struct vlc_preparser_t;
struct vlc_preparser_req;

/**
 * Seek preview thumbnails of the VLC Redesign seek bar.
 *
 * request() asks VLC's thumbnailer for a frame of a media at a given time.
 * Only the latest request is kept: a new request cancels the previous one.
 * The result is published as an "image://seekpreview/<id>" URL in `source`
 * (for a QML Image), with the time it shows in `time`. Recent results are
 * cached. (A data: URL showed nothing on Windows, where VLC's Qt is built
 * without its network module.)
 */
class SeekPreview : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString source READ source NOTIFY sourceChanged FINAL)
    Q_PROPERTY(qint64 time READ time NOTIFY sourceChanged FINAL)
    Q_PROPERTY(bool available READ available CONSTANT FINAL)

public:
    explicit SeekPreview(qt_intf_t *intf, QObject *parent = nullptr);
    ~SeekPreview() override;

    /// @param mrl media to read
    /// @param timeMs time of the frame, in milliseconds
    Q_INVOKABLE void request(const QString &mrl, qint64 timeMs);
    /// drop the cache and the pending request
    Q_INVOKABLE void clear();

    QString source() const { return m_source; }
    qint64 time() const { return m_time; }
    bool available() const;

signals:
    void sourceChanged();

private:
    struct Request;
    static void onEnded(vlc_preparser_req *req, int status, struct picture_t *pic, void *data);
    void publish(const QString &key, qint64 timeMs, const QImage &image);
    void setSource(const QString &id, qint64 timeMs);
    bool ensurePreparser();

    qt_intf_t *m_intf;
    vlc_preparser_t *m_preparser = nullptr;
    QMutex m_lock;                      // protects m_pending
    vlc_preparser_req *m_pending = nullptr;
    std::atomic<bool> m_closing { false };

    QString m_source;
    qint64 m_time = -1;
    QString m_wanted;                   // cache key of the latest request
    QHash<QString, QString> m_cache;    // key -> image id
    QList<QString> m_cacheOrder;
    quint64 m_serial = 0;

    friend class SeekPreviewImageProvider;
    // images of the cache, read by the image provider (QML threads)
    static QMutex s_imagesLock;
    static QHash<QString, QImage> s_images;
};

/// "image://seekpreview/<id>": the frames of SeekPreview
class SeekPreviewImageProvider : public QQuickImageProvider
{
public:
    SeekPreviewImageProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
    static constexpr const char *providerId = "seekpreview";
};

#endif // SEEK_PREVIEW_HPP
