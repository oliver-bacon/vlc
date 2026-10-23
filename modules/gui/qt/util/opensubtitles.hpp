/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
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
#ifndef VLC_QT_OPENSUBTITLES_HPP
#define VLC_QT_OPENSUBTITLES_HPP

#include <QObject>
#include <QVariant>
#include <QThreadPool>
#include <QTimer>
#include <QMutex>

#include <functional>
#include <memory>
#include <vector>

#include "qt.hpp"

/**
 * Subtitle search and download on opensubtitles.com ("From OpenSubtitles"
 * in the Add Subtitles dialog, account in Settings > Network).
 *
 * The requests run on worker threads, over VLC's own TLS client (the Qt
 * build of VLC has no network module). The app key is set at build time
 * (meson option opensubtitles_api_key); without it `available` is false.
 *
 * Signing in is optional: without an account, opensubtitles.com allows a
 * few downloads a day per IP address. The password is kept in VLC's
 * keystore, the user name in the interface settings.
 */
class OpenSubtitles : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool available READ available CONSTANT FINAL)
    Q_PROPERTY(QString username READ username NOTIFY accountChanged FINAL)
    Q_PROPERTY(bool signedIn READ signedIn NOTIFY accountChanged FINAL)
    Q_PROPERTY(bool signingIn READ signingIn NOTIFY accountChanged FINAL)
    Q_PROPERTY(QString accountError READ accountError NOTIFY accountChanged FINAL)
    /// downloads left today, -1 while unknown
    Q_PROPERTY(int remaining READ remaining NOTIFY remainingChanged FINAL)
    Q_PROPERTY(int allowedDownloads READ allowedDownloads NOTIFY accountChanged FINAL)
    /// [{ code, name }], sorted by name
    Q_PROPERTY(QVariantList languages READ languages NOTIFY languagesChanged FINAL)

public:
    explicit OpenSubtitles(qt_intf_t* intf, QObject* parent = nullptr);
    ~OpenSubtitles() override;

    bool available() const;
    QString username() const { return m_username; }
    bool signedIn() const { return !m_token.isEmpty(); }
    bool signingIn() const { return m_signingIn; }
    QString accountError() const { return m_accountError; }
    int remaining() const { return m_remaining; }
    int allowedDownloads() const { return m_allowed; }
    QVariantList languages();

    /// Language code for a new search: the last one used, else the UI language
    Q_INVOKABLE QString defaultLanguage() const;
    Q_INVOKABLE void setDefaultLanguage(const QString& code);

    /// Searches subtitles for a video (URL). `query` is the text typed by the
    /// user, or empty to search by the video's file name and hash.
    /// Returns a request id; the answer comes with searchFinished().
    /// A result: { fileId, fileName, release, language, downloads,
    ///   hashMatch, episodeMatch, hearingImpaired, trusted, machine, title }
    Q_INVOKABLE int search(const QString& mediaUrl, const QString& query, const QString& language);

    /// Downloads subtitles next to their videos. items: [{ media, fileId,
    /// language, fileName }]. Returns a request id; progress with
    /// downloadProgress(), the end with downloadFinished(id, saved, error)
    /// where saved is [{ media, subtitle }] (URLs)
    Q_INVOKABLE int download(const QVariantList& items);

    /// Forget the results of pending requests (dialog closed)
    Q_INVOKABLE void cancel(int id);

    Q_INVOKABLE void signIn(const QString& username, const QString& password);
    Q_INVOKABLE void signOut();

signals:
    void accountChanged();
    void remainingChanged();
    void languagesChanged();
    void searchFinished(int id, const QVariantList& results, const QString& error);
    void downloadProgress(int id, int done, int total);
    void downloadFinished(int id, const QVariantList& saved, const QString& error);

private:
    struct Job;
    struct Session { QByteArray host; QByteArray token; };

    int start(std::function<void(Job&)> work);
    void loadAccount();
    void fetchLanguages();
    void setRemaining(int remaining);
    Session session() const;
    // worker side: signs in again with the stored password (token expired)
    bool relogin(Job& job, QString* error);

    qt_intf_t* m_intf;
    QThreadPool m_pool;
    QTimer m_watchdog;

    // jobs that are running, to stop them on timeout or exit
    mutable QMutex m_lock;
    std::vector<std::shared_ptr<Job>> m_jobs;
    int m_lastId = 0;

    QString m_username;
    QByteArray m_token;           // JWT of the session
    QByteArray m_host = "api.opensubtitles.com";
    bool m_signingIn = false;
    QString m_accountError;
    int m_remaining = -1;
    int m_allowed = 0;
    QVariantList m_languages;
    bool m_languagesRequested = false;
};

#endif // VLC_QT_OPENSUBTITLES_HPP
