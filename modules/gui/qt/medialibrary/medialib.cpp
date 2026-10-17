/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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

#include "medialib.hpp"

#include <QDateTime>
#include <QDir>
#include <QImage>
#include <QSet>
#include <QSettings>
#include <QTimer>
#include <QFile>
#include <QFileDialog>
#include <QTextStream>
#include <vlc_url.h>
#include <vlc_configuration.h>
#include "mlhelper.hpp"
#include "mlcustomcover.hpp"
#include "playlist/playlist_controller.hpp"
#include "player/player_controller.hpp"
#include "util/shared_input_item.hpp"

#include <utility>
#include <cstring>

#include <QQmlEngine>

static QString homeHiddenKey(const QString& list)
{
    return QStringLiteral("HomeHidden/") + list;
}

QSet<int64_t> MediaLib::homeHidden(const QString& list) const
{
    if (list.isEmpty())
        return {};
    auto it = m_homeHidden.find(list);
    if (it == m_homeHidden.end())
    {
        QSet<int64_t> ids;
        const QStringList saved = m_intf->mainSettings->value(homeHiddenKey(list)).toStringList();
        for (const QString& id : saved)
        {
            bool ok = false;
            const qlonglong value = id.toLongLong(&ok);
            if (ok)
                ids.insert(value);
        }
        it = m_homeHidden.insert(list, ids);
    }
    return *it;
}

void MediaLib::hideOnHome(const QString& list, const QVector<int64_t>& ids)
{
    if (list.isEmpty() || ids.isEmpty())
        return;
    QSet<int64_t> hidden = homeHidden(list);
    for (const int64_t id : ids)
        hidden.insert(id);
    m_homeHidden[list] = hidden;

    QStringList saved;
    for (const int64_t id : hidden)
        saved.append(QString::number(id));
    m_intf->mainSettings->setValue(homeHiddenKey(list), saved);

    emit homeHiddenChanged(list);
}

MediaLib::MediaLib(qt_intf_t *_intf, vlc::playlist::PlaylistController* playlistController, QObject *_parent)
    : QObject( _parent )
    , m_intf( _intf )
    , m_playlistController(playlistController)
    , m_ml( vlc_ml_instance_get( _intf ) )
    , m_event_cb( nullptr, [this](vlc_ml_event_callback_t* cb ) {
        vlc_ml_event_unregister_callback( m_ml, cb );
      })
{
    m_event_cb.reset( vlc_ml_event_register_callback( m_ml, MediaLib::onMediaLibraryEvent,
                                                      this ) );
    m_runner = new ThreadRunner();

    // music played outside the library folders (or a track the library
    // found no picture for) gets the artwork the player found for it, so
    // that Home (Listen Again) and the music views show it
    if (PlayerController* player = m_intf->p_mainPlayerController)
    {
        connect(player, &PlayerController::currentMetaChanged, this, &MediaLib::storePlayerArtwork);
        connect(player, &PlayerController::playingStateChanged, this, [this](PlayerController::PlayingState state) {
            if (state == PlayerController::PLAYING_STATE_STOPPED)
                flushPlayerArtwork();
        });
    }

    // "Playlist Name" item of the player bar
    connect(m_playlistController, &vlc::playlist::PlaylistController::currentItemChanged,
            this, &MediaLib::updateCurrentPlaylistName);
    connect(m_playlistController, &vlc::playlist::PlaylistController::itemsReset,
            this, [this](const QVector<PlaylistItem>& items) {
        QSet<const void*> queued;
        for (const auto& item : items)
            queued.insert(item.inputItem());
        for (auto it = m_queuedOrigins.begin(); it != m_queuedOrigins.end();)
            it = queued.contains(it.key()) ? std::next(it) : m_queuedOrigins.erase(it);
        updateCurrentPlaylistName();
    });
}

MediaLib::~MediaLib()
{
    m_runner->destroy();
}

static void convertMLItemToPlaylistMedias(vlc_medialibrary_t* ml, const MLItemId & itemId, const QStringList &options, QVector<vlc::playlist::Media>& medias)
{
    //invalid item
    if (itemId.id == 0)
        return;

    if (itemId.type == VLC_ML_PARENT_UNKNOWN)
    {
        SharedInputItem item( vlc_ml_get_input_item( ml, itemId.id ), false );
        if (item)
            medias.push_back(vlc::playlist::Media(item.get(), options));
    }
    else
    {
        vlc_ml_query_params_t query = vlc_ml_query_params_create();
        ml_unique_ptr<vlc_ml_media_list_t> media_list(vlc_ml_list_media_of( ml, &query, itemId.type, itemId.id));
        if (media_list == nullptr || media_list->i_nb_items == 0)
            return;

        auto mediaRange = ml_range_iterate<vlc_ml_media_t>( media_list );
        std::transform(mediaRange.begin(), mediaRange.end(), std::back_inserter(medias), [&](vlc_ml_media_t& m) {
            SharedInputItem item(vlc_ml_get_input_item( ml, m.i_id ), false);
            return vlc::playlist::Media(item.get(), options);
        });
    }
}

static void convertQUrlToPlaylistMedias(QUrl mrl, const QStringList& options, QVector<vlc::playlist::Media>& medias)
{
    vlc::playlist::Media media{ mrl.toString(QUrl::FullyEncoded), mrl.fileName(), options };
    medias.push_back(media);
}

static void convertQStringToPlaylistMedias(const QString &mrl, const QStringList& options, QVector<vlc::playlist::Media>& medias)
{
    vlc::playlist::Media media{ mrl, mrl, options };
    medias.push_back(media);
}


static void notePlaylistOrigin(vlc_medialibrary_t* ml, const MLItemId& itemId,
                               const QVector<vlc::playlist::Media>& medias,
                               MLPlaylistOrigins* origins)
{
    if (!origins)
        return;
    const int64_t id = itemId.type == VLC_ML_PARENT_PLAYLIST ? itemId.id : 0;
    while (origins->ids.size() < medias.size())
        origins->ids.push_back(id);
    if (id && !origins->names.contains(id))
    {
        ml_unique_ptr<vlc_ml_playlist_t> playlist { vlc_ml_get_playlist(ml, id) };
        origins->names.insert(id, playlist ? qfu(playlist->psz_name) : QString {});
    }
}

static void convertQVariantListToPlaylistMedias(vlc_medialibrary_t* ml, QVariantList itemIdList, const QStringList& options, QVector<vlc::playlist::Media>& medias,
                                                MLPlaylistOrigins* origins = nullptr)
{
    for (const QVariant& varValue: itemIdList)
    {
        if (varValue.canConvert<QUrl>())
        {
            auto mrl = varValue.value<QUrl>();
            convertQUrlToPlaylistMedias(mrl, options, medias);
        }
        else if (varValue.canConvert<QString>())
        {
            auto mrl = varValue.value<QString>();
            convertQStringToPlaylistMedias(mrl, options, medias);
        }
        else if (varValue.canConvert<MLItemId>())
        {
            MLItemId itemId = varValue.value<MLItemId>();
            convertMLItemToPlaylistMedias(ml, itemId, options, medias);
            notePlaylistOrigin(ml, itemId, medias, origins);
            continue;
        }
        // else ignore
        notePlaylistOrigin(ml, MLItemId {}, medias, origins);
    }
    notePlaylistOrigin(ml, MLItemId {}, medias, origins);
}

MLItemId MediaLib::deserializeMlItemIdFromString(const QString& serialized_id) {
    return MLItemId::fromString(serialized_id);
}

void MediaLib::addToPlaylist(const QString& mrl, const QStringList &options)
{
    QVector<vlc::playlist::Media> medias;
    convertQStringToPlaylistMedias(mrl, options, medias);
    m_playlistController->append(medias, false);
}

void MediaLib::addToPlaylist(const QUrl& mrl, const QStringList &options)
{
    QVector<vlc::playlist::Media> medias;
    convertQUrlToPlaylistMedias(mrl, options, medias);
    m_playlistController->append(medias, false);
}

// A specific item has been asked to be added to the playlist
void MediaLib::addToPlaylist(const MLItemId & itemId, const QStringList &options)
{
    struct Context {
        QVector<vlc::playlist::Media> medias;
        MLPlaylistOrigins origins;
    };
    runOnMLThread<Context>(this,
    //ML thread
    [itemId, options]
    (vlc_medialibrary_t* ml, Context& ctx){
        convertMLItemToPlaylistMedias(ml, itemId, options, ctx.medias);
        notePlaylistOrigin(ml, itemId, ctx.medias, &ctx.origins);
    },
    //UI thread
    [this](quint64, Context& ctx){
        if (!ctx.medias.empty())
        {
            rememberPlaylistOrigins(ctx.medias, ctx.origins);
            m_playlistController->append(ctx.medias, false);
        }
    });
}

void MediaLib::addToPlaylist(const QVariantList& itemIdList, const QStringList &options)
{
    struct Context {
        QVector<vlc::playlist::Media> medias;
        MLPlaylistOrigins origins;
    };
    runOnMLThread<Context>(this,
    //ML thread
    [itemIdList, options]
    (vlc_medialibrary_t* ml, Context& ctx)
    {
        convertQVariantListToPlaylistMedias(ml, itemIdList, options, ctx.medias, &ctx.origins);
    },
    //UI thread
    [this](quint64, Context& ctx){
        if (!ctx.medias.empty())
        {
            rememberPlaylistOrigins(ctx.medias, ctx.origins);
            m_playlistController->append(ctx.medias, false);
        }
    });
}

// A specific item has been asked to be played,
// so it's added to the playlist and played
void MediaLib::addAndPlay(const MLItemId & itemId, const QStringList &options )
{
    struct Context {
        QVector<vlc::playlist::Media> medias;
        MLPlaylistOrigins origins;
    };
    runOnMLThread<Context>(this,
    //ML thread
    [itemId, options]
    (vlc_medialibrary_t* ml, Context& ctx)
    {
        convertMLItemToPlaylistMedias(ml, itemId, options, ctx.medias);
        notePlaylistOrigin(ml, itemId, ctx.medias, &ctx.origins);
    },
    //UI thread
    [this](quint64, Context& ctx){
        if (!ctx.medias.empty())
        {
            rememberPlaylistOrigins(ctx.medias, ctx.origins);
            m_playlistController->append(ctx.medias, true);
        }
    });


}

void MediaLib::addAndPlay(const QString& mrl, const QStringList &options)
{
    vlc::playlist::Media media{ mrl, mrl, options };
    m_playlistController->append( QVector<vlc::playlist::Media>{media}, true );
}

void MediaLib::addAndPlay(const QUrl& mrl, const QStringList &options)
{
    vlc::playlist::Media media{ mrl.toString(QUrl::FullyEncoded), mrl.fileName(), options };
    m_playlistController->append( QVector<vlc::playlist::Media>{media}, true );
}


void MediaLib::addAndPlay(const QVariantList& itemIdList, const QStringList &options)
{
    struct Context {
        QVector<vlc::playlist::Media> medias;
        MLPlaylistOrigins origins;
    };
    runOnMLThread<Context>(this,
    //ML thread
    [itemIdList, options]
    (vlc_medialibrary_t* ml, Context& ctx)
    {
        convertQVariantListToPlaylistMedias(ml, itemIdList, options, ctx.medias, &ctx.origins);
    },
    //UI thread
    [this](quint64, Context& ctx){
        if (!ctx.medias.empty())
        {
            rememberPlaylistOrigins(ctx.medias, ctx.origins);
            m_playlistController->append(ctx.medias, true);
        }
    });
}

void MediaLib::insertIntoPlaylist(const size_t index, const QVariantList &itemIdList, const QStringList &options)
{
    struct Context {
        QVector<vlc::playlist::Media> medias;
        MLPlaylistOrigins origins;
    };
    runOnMLThread<Context>(this,
    //ML thread
    [itemIdList, options]
    (vlc_medialibrary_t* ml, Context& ctx )
    {
        convertQVariantListToPlaylistMedias(ml, itemIdList, options, ctx.medias, &ctx.origins);
    },
    //UI thread
    [this, index]
    (quint64, Context& ctx) {
        if (!ctx.medias.isEmpty())
        {
            rememberPlaylistOrigins(ctx.medias, ctx.origins);
            m_playlistController->insert( index, ctx.medias );
        }
    });
}

void MediaLib::reload()
{
    runOnMLThread(this,
    //ML thread
    [](vlc_medialibrary_t* ml){
        vlc_ml_reload_folder(ml, nullptr);
    });
}

void MediaLib::queryMediaFavorite(const QUrl& mrl)
{
    if (mrl.isEmpty())
        return;

    struct Ctx {
        bool known = false;
        bool favorite = false;
    };

    runOnMLThread<Ctx>(this,
    //ML thread
    [mrl = mrl.toString(QUrl::FullyEncoded).toUtf8()](vlc_medialibrary_t* ml, Ctx& ctx){
        ml_unique_ptr<vlc_ml_media_t> media { vlc_ml_get_media_by_mrl(ml, mrl.constData()) };
        if (media)
        {
            ctx.known = true;
            ctx.favorite = media->b_is_favorite;
        }
    },
    //UI thread
    [this, mrl](quint64, Ctx& ctx){
        emit mediaFavoriteState(mrl, ctx.known, ctx.favorite);
    });
}

void MediaLib::queryMediaProgress(const QUrl& mrl)
{
    if (mrl.isEmpty())
        return;

    struct Ctx {
        double progress = -1;
    };

    runOnMLThread<Ctx>(this,
    //ML thread
    [mrl = mrl.toString(QUrl::FullyEncoded).toUtf8()](vlc_medialibrary_t* ml, Ctx& ctx){
        ml_unique_ptr<vlc_ml_media_t> media { vlc_ml_get_media_by_mrl(ml, mrl.constData()) };
        if (media && media->f_progress > 0)
            ctx.progress = media->f_progress;
    },
    //UI thread
    [this, mrl](quint64, Ctx& ctx){
        emit mediaProgressState(mrl, ctx.progress);
    });
}

namespace {
QString folderCoverKey(const QUrl& mrl)
{
    return mrl.adjusted(QUrl::StripTrailingSlash | QUrl::NormalizePathSegments)
              .toString(QUrl::FullyEncoded);
}
}

void MediaLib::loadFolderCovers()
{
    struct Folder {
        int64_t id;
        QString mrl;
        unsigned videoCount;
        QString audioCover; // first music cover of an audio-only folder
    };
    struct Ctx {
        QVector<Folder> folders;
    };

    runOnMLThread<Ctx>(this,
    //ML thread
    [](vlc_medialibrary_t* ml, Ctx& ctx){
        vlc_ml_query_params_t params = vlc_ml_query_params_create();
        ml_unique_ptr<vlc_ml_folder_list_t> list { vlc_ml_list_folders(ml, &params) };
        if (!list)
            return;
        for (const vlc_ml_folder_t& f : ml_range_iterate<vlc_ml_folder_t>(list))
        {
            if (!f.psz_mrl || f.b_banned || (f.i_nb_video == 0 && f.i_nb_audio == 0))
                continue;
            Folder folder { f.i_id, QString::fromUtf8(f.psz_mrl), f.i_nb_video, {} };
            if (folder.videoCount == 0)
            {
                vlc_ml_query_params_t mediaParams = vlc_ml_query_params_create();
                mediaParams.i_nbResults = 10;
                ml_unique_ptr<vlc_ml_media_list_t> media {
                    vlc_ml_list_folder_media(ml, &mediaParams, f.i_id) };
                if (media)
                {
                    for (const vlc_ml_media_t& m : ml_range_iterate<vlc_ml_media_t>(media))
                    {
                        const vlc_ml_thumbnail_t& t = m.thumbnails[VLC_ML_THUMBNAIL_SMALL];
                        if (t.i_status == VLC_ML_THUMBNAIL_STATUS_AVAILABLE && t.psz_mrl)
                        {
                            folder.audioCover = QString::fromUtf8(t.psz_mrl);
                            break;
                        }
                    }
                }
                if (folder.audioCover.isEmpty())
                    continue;
            }
            ctx.folders.push_back(std::move(folder));
        }
    },
    //UI thread
    [this](quint64, Ctx& ctx){
        // same size as the video folders of the library (MLVideoFoldersModel)
        const QSize size(260 * 3, 162 * 3);
        m_folderCovers.clear();
        for (const Folder& f : ctx.folders)
        {
            // 2x2 mosaic from 4 videos on, else one thumbnail (a smaller
            // mosaic leaves empty tiles)
            const int count = f.videoCount >= 4 ? 2 : 1;
            m_folderCovers.insert(folderCoverKey(QUrl(f.mrl)),
                                  f.videoCount > 0
                                  ? MLCustomCover::url(MLItemId(f.id, VLC_ML_PARENT_FOLDER), size,
                                                       QStringLiteral(":/placeholder/noart_videoCover.svg"),
                                                       count, count)
                                  : f.audioCover);
        }
        emit folderCoversChanged();
    });
}

QString MediaLib::folderCover(const QUrl& mrl) const
{
    const QString key = folderCoverKey(mrl);
    if (key.isEmpty())
        return {};
    const auto it = m_folderCovers.constFind(key);
    if (it != m_folderCovers.cend())
        return it.value();
    // first subfolder with media (keys are sorted)
    const QString prefix = key + QLatin1Char('/');
    const auto sub = m_folderCovers.lowerBound(prefix);
    if (sub != m_folderCovers.cend() && sub.key().startsWith(prefix))
        return sub.value();
    return {};
}

void MediaLib::addBookmark(const QUrl& mrl, qint64 timeMs)
{
    const QByteArray uri = mrl.toString(QUrl::FullyEncoded).toUtf8();
    if (uri.isEmpty())
        return;
    runOnMLThread(this,
    //ML thread
    [uri, timeMs](vlc_medialibrary_t* ml){
        ml_unique_ptr<vlc_ml_media_t> media { vlc_ml_get_media_by_mrl(ml, uri.constData()) };
        if (media)
            vlc_ml_media_add_bookmark(ml, media->i_id, timeMs);
    });
}

void MediaLib::reloadFolder(const QUrl& folder)
{
    const QByteArray mrl = folder.toString(QUrl::FullyEncoded).toUtf8();
    if (mrl.isEmpty())
        return;
    runOnMLThread(this,
    //ML thread
    [mrl](vlc_medialibrary_t* ml){
        vlc_ml_reload_folder(ml, mrl.constData());
    });
}

void MediaLib::mediaMrls(const QVariantList& ids, std::function<void(QStringList)> callback)
{
    struct Ctx {
        QStringList mrls;
    };

    std::vector<MLItemId> itemIds;
    for (const QVariant& id : ids)
        if (id.canConvert<MLItemId>())
            itemIds.push_back(id.value<MLItemId>());

    runOnMLThread<Ctx>(this,
    //ML thread
    [itemIds](vlc_medialibrary_t* ml, Ctx& ctx){
        const auto addMedia = [&ctx](const vlc_ml_media_t& media) {
            for (const vlc_ml_file_t& file : ml_range_iterate<vlc_ml_file_t>(media.p_files))
            {
                if (file.i_type == VLC_ML_FILE_TYPE_MAIN && file.psz_mrl)
                {
                    ctx.mrls.append(qfu(file.psz_mrl));
                    break;
                }
            }
        };
        for (const MLItemId& id : itemIds)
        {
            if (id.type == VLC_ML_PARENT_UNKNOWN)
            {
                ml_unique_ptr<vlc_ml_media_t> media { vlc_ml_get_media(ml, id.id) };
                if (media)
                    addMedia(*media);
                continue;
            }
            vlc_ml_query_params_t query = vlc_ml_query_params_create();
            ml_unique_ptr<vlc_ml_media_list_t> list { vlc_ml_list_media_of(ml, &query, id.type, id.id) };
            if (!list)
                continue;
            for (const vlc_ml_media_t& media : ml_range_iterate<vlc_ml_media_t>(list))
                addMedia(media);
        }
    },
    //UI thread
    [callback](quint64, Ctx& ctx){
        callback(ctx.mrls);
    });
}

void MediaLib::exportPlaylists(const QVariantList& ids, const QString& name)
{
    mediaMrls(ids, [name](QStringList mrls) {
        if (mrls.isEmpty())
            return;
        QString path = QFileDialog::getSaveFileName(nullptr, qtr("Export Playlist"),
                                                    QDir::homePath() + QStringLiteral("/") + name + QStringLiteral(".m3u8"),
                                                    qtr("M3U playlist (*.m3u8 *.m3u)"));
        if (path.isEmpty())
            return;
        QFile file(path);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text))
            return;
        QTextStream out(&file);
        out << "#EXTM3U\n";
        for (const QString& mrl : mrls)
        {
            const QUrl url(mrl);
            out << (url.isLocalFile() ? QDir::toNativeSeparators(url.toLocalFile()) : mrl) << "\n";
        }
    });
}

void MediaLib::addFolder(const QUrl& folder)
{
    const QByteArray mrl = folder.toString(QUrl::FullyEncoded).toUtf8();
    if (mrl.isEmpty())
        return;
    runOnMLThread(this,
    //ML thread
    [mrl](vlc_medialibrary_t* ml){
        vlc_ml_add_folder(ml, mrl.constData());
    });
}

void MediaLib::addExternalSubtitles(const QVariantList& pairs)
{
    struct Pair { QByteArray media; QByteArray file; bool audio; };
    std::vector<Pair> list;
    for (const QVariant& pair : pairs)
    {
        const QVariantMap map = pair.toMap();
        // encode the MRLs the way the media library does (vlc_path2uri)
        const auto toMrl = [](const QVariant& value) -> QByteArray {
            const QUrl url(value.toString());
            if (!url.isLocalFile())
                return url.toString(QUrl::FullyEncoded).toUtf8();
            char* uri = vlc_path2uri(qtu(QDir::toNativeSeparators(url.toLocalFile())), "file");
            const QByteArray ret(uri ? uri : "");
            free(uri);
            return ret;
        };
        const QByteArray media = toMrl(map.value("media"));
        const QByteArray subtitle = toMrl(map.value("subtitle"));
        if (!media.isEmpty() && !subtitle.isEmpty())
            list.push_back({ media, subtitle, map.value("audio").toBool() });

        // the media that is playing gets the track at once
        PlayerController* player = m_intf->p_mainPlayerController;
        if (player && !media.isEmpty() && !subtitle.isEmpty()
            && toMrl(player->getUrl().toString()) == media)
        {
            player->AddAssociatedMedia(map.value("audio").toBool() ? AUDIO_ES : SPU_ES,
                                       QString::fromUtf8(subtitle), true, true, false);
        }
    }
    if (list.empty())
        return;

    runOnMLThread(this,
    //ML thread
    [list](vlc_medialibrary_t* ml){
        for (const Pair& pair : list)
        {
            ml_unique_ptr<vlc_ml_media_t> item { vlc_ml_get_media_by_mrl(ml, pair.media.constData()) };
            if (item)
                vlc_ml_media_add_external_mrl(ml, item->i_id, pair.file.constData(),
                                              pair.audio ? VLC_ML_FILE_TYPE_SOUNDTRACK : VLC_ML_FILE_TYPE_SUBTITLE);
        }
    });
}

void MediaLib::storePlayerArtwork(input_item_t* item)
{
    if (!item)
        return;
    // the URL and the artwork of the same item (the player's own getters
    // change at different moments when the next media starts)
    QUrl url;
    QUrl artwork;
    {
        char* uri = input_item_GetURI(item);
        char* art = input_item_GetArtworkURL(item);
        url = QUrl(qfu(uri));
        artwork = QUrl(qfu(art));
        free(uri);
        free(art);
    }

    // the previous media is in the media library now if it was played from
    // outside the library folders (it is added when its playback ends)
    if (!m_pendingArtwork.first.isEmpty() && m_pendingArtwork.first != url)
        flushPlayerArtwork();

    // only pictures that stay: VLC's art cache or a cover file
    if (url.isEmpty() || !artwork.isLocalFile())
        return;
    const QString key = url.toString() + QLatin1Char('\n') + artwork.toString();
    if (key == m_storedArtwork)
        return;
    m_storedArtwork = key;
    m_pendingArtwork = { url, artwork };
    storeArtwork(url, artwork, -1);
}

void MediaLib::flushPlayerArtwork()
{
    if (m_pendingArtwork.first.isEmpty())
        return;
    storeArtwork(m_pendingArtwork.first, m_pendingArtwork.second, 0);
    m_pendingArtwork = {};
}

void MediaLib::storeArtwork(const QUrl& url, const QUrl& artwork, int attempt)
{
    struct Ctx {
        bool found = false;
        bool stored = false;
    };

    runOnMLThread<Ctx>(this,
    //ML thread
    [mrl = url.toString(QUrl::FullyEncoded).toUtf8(),
     art = artwork.toString(QUrl::FullyEncoded).toUtf8()](vlc_medialibrary_t* ml, Ctx& ctx){
        ml_unique_ptr<vlc_ml_media_t> media { vlc_ml_get_media_by_mrl(ml, mrl.constData()) };
        if (!media)
            return;
        ctx.found = true;
        if (media->i_type != VLC_ML_MEDIA_TYPE_AUDIO)
            return;
        if (media->thumbnails[VLC_ML_THUMBNAIL_SMALL].i_status == VLC_ML_THUMBNAIL_STATUS_AVAILABLE)
            return;
        ctx.stored = vlc_ml_media_set_thumbnail(ml, media->i_id, art.constData(),
                                                VLC_ML_THUMBNAIL_SMALL) == VLC_SUCCESS;
    },
    //UI thread
    [this, url, artwork, attempt](quint64, Ctx& ctx){
        if (ctx.stored)
            emit mediaArtworkStored();
        if (ctx.found && m_pendingArtwork.first == url)
            m_pendingArtwork = {};
        // attempt -1: while it plays (flushPlayerArtwork() tries again when
        // it ends); then a few more times while the media library adds it
        if (!ctx.found && attempt >= 0 && attempt < 5)
            QTimer::singleShot(2000, this, [this, url, artwork, attempt]() {
                storeArtwork(url, artwork, attempt + 1);
            });
    });
}

void MediaLib::setMediaFavorite(const QUrl& mrl, bool favorite)
{
    if (mrl.isEmpty())
        return;

    struct Ctx {
        bool known = false;
    };

    runOnMLThread<Ctx>(this,
    //ML thread
    [mrl = mrl.toString(QUrl::FullyEncoded).toUtf8(), favorite](vlc_medialibrary_t* ml, Ctx& ctx){
        ml_unique_ptr<vlc_ml_media_t> media { vlc_ml_get_media_by_mrl(ml, mrl.constData()) };
        // a file played from outside the library folders (or a stream) is
        // added to the media library when its playback ends: add it now
        if (!media && favorite)
        {
            if (strncmp(mrl.constData(), "file://", 7) == 0)
                media.reset(vlc_ml_new_external_media(ml, mrl.constData()));
            else
                media.reset(vlc_ml_new_stream(ml, mrl.constData()));
        }
        if (media && vlc_ml_media_set_favorite(ml, media->i_id, favorite) == VLC_SUCCESS)
            ctx.known = true;
    },
    //UI thread
    [this, mrl, favorite](quint64, Ctx& ctx){
        if (ctx.known)
            emit mediaFavoriteState(mrl, true, favorite);
    });
}

void MediaLib::setPlaylistFavorite(const MLItemId& playlistId, bool favorite)
{
    if (playlistId.id == 0)
        return;

    struct Ctx {
        bool done = false;
    };

    runOnMLThread<Ctx>(this,
    //ML thread
    [id = playlistId.id, favorite](vlc_medialibrary_t* ml, Ctx& ctx){
        ctx.done = vlc_ml_playlist_set_favorite(ml, id, favorite) == VLC_SUCCESS;
    },
    //UI thread
    [this, playlistId](quint64, Ctx& ctx){
        if (ctx.done)
            emit playlistChanged(MLItemId(playlistId.id, VLC_ML_PARENT_PLAYLIST));
    });
}

void MediaLib::renamePlaylist(const MLItemId& playlistId, const QString& name)
{
    const QString trimmed = name.trimmed();
    if (playlistId.id == 0 || trimmed.isEmpty())
        return;

    struct Ctx {
        bool done = false;
    };

    runOnMLThread<Ctx>(this,
    //ML thread
    [id = playlistId.id, utf8 = trimmed.toUtf8()](vlc_medialibrary_t* ml, Ctx& ctx){
        ctx.done = vlc_ml_playlist_rename(ml, id, utf8.constData()) == VLC_SUCCESS;
    },
    //UI thread
    [this, playlistId, trimmed](quint64, Ctx& ctx){
        if (!ctx.done)
            return;
        if (m_playlistNames.contains(playlistId.id))
        {
            m_playlistNames[playlistId.id] = trimmed;
            updateCurrentPlaylistName();
        }
        emit playlistChanged(MLItemId(playlistId.id, VLC_ML_PARENT_PLAYLIST));
    });
}

// Playlist pictures: "<user data>/playlist-thumbnails/<id>-<time>.png"; the
// time in the name changes the URL, so that views do not show a cached
// picture after a change
static QString playlistThumbnailDir()
{
    char* dir = config_GetUserDir(VLC_USERDATA_DIR);
    if (!dir)
        return {};
    const QString ret = qfu(dir) + QStringLiteral("/playlist-thumbnails");
    free(dir);
    return ret;
}

static QHash<int64_t, QString>& playlistThumbnailFiles()
{
    static QHash<int64_t, QString> files;
    static bool loaded = false;
    if (!loaded)
    {
        loaded = true;
        const QDir dir(playlistThumbnailDir());
        const QStringList names = dir.entryList({ QStringLiteral("*.png") }, QDir::Files, QDir::Name);
        for (const QString& name : names)
        {
            bool ok = false;
            const int64_t id = name.section(QLatin1Char('-'), 0, 0).toLongLong(&ok);
            if (ok && id > 0)
                files.insert(id, dir.filePath(name)); // sorted by name: the newest wins
        }
    }
    return files;
}

QString MediaLib::playlistThumbnail(int64_t playlistId)
{
    const QString file = playlistThumbnailFiles().value(playlistId);
    return file.isEmpty() ? QString {} : QUrl::fromLocalFile(file).toString();
}

QString MediaLib::playlistThumbnail(const MLItemId& playlistId)
{
    return playlistThumbnail(playlistId.id);
}

bool MediaLib::setPlaylistThumbnail(const MLItemId& playlistId, const QUrl& image)
{
    if (playlistId.id == 0)
        return false;

    auto& files = playlistThumbnailFiles();
    const QString previous = files.value(playlistId.id);

    if (image.isEmpty())
    {
        if (previous.isEmpty())
            return true;
        QFile::remove(previous);
        files.remove(playlistId.id);
        emit playlistChanged(MLItemId(playlistId.id, VLC_ML_PARENT_PLAYLIST));
        return true;
    }

    QImage picture(image.isLocalFile() ? image.toLocalFile() : image.toString());
    if (picture.isNull())
    {
        msg_Warn(m_intf, "cannot read the playlist picture %s", qtu(image.toString()));
        return false;
    }
    if (picture.width() > 1024 || picture.height() > 1024)
        picture = picture.scaled(1024, 1024, Qt::KeepAspectRatio, Qt::SmoothTransformation);

    const QString dirPath = playlistThumbnailDir();
    if (dirPath.isEmpty() || !QDir().mkpath(dirPath))
        return false;

    const QString file = QDir(dirPath).filePath(QStringLiteral("%1-%2.png")
                                                .arg(playlistId.id)
                                                .arg(QDateTime::currentMSecsSinceEpoch()));
    if (!picture.save(file, "PNG"))
    {
        msg_Warn(m_intf, "cannot save the playlist picture %s", qtu(file));
        return false;
    }

    if (!previous.isEmpty())
        QFile::remove(previous);
    files.insert(playlistId.id, file);
    emit playlistChanged(MLItemId(playlistId.id, VLC_ML_PARENT_PLAYLIST));
    return true;
}

void MediaLib::rememberPlaylistOrigins(const QVector<vlc::playlist::Media>& medias,
                                       const MLPlaylistOrigins& origins)
{
    if (origins.names.isEmpty())
        return;

    // the play queue was cleared many times without a reset: start over
    if (m_queuedOrigins.size() > 20000)
        m_queuedOrigins.clear();

    for (int i = 0; i < medias.size() && i < origins.ids.size(); ++i)
    {
        if (origins.ids[i] == 0)
            continue;
        auto media = std::make_shared<vlc::playlist::Media>(medias[i]);
        m_queuedOrigins.insert(media->raw(), QueuedOrigin { media, origins.ids[i] });
    }
    for (auto it = origins.names.cbegin(); it != origins.names.cend(); ++it)
        m_playlistNames.insert(it.key(), it.value());

    updateCurrentPlaylistName();
}

void MediaLib::updateCurrentPlaylistName()
{
    QString name;
    const PlaylistItem item = m_playlistController->getCurrentItem();
    if (item)
    {
        const auto it = m_queuedOrigins.constFind(item.inputItem());
        if (it != m_queuedOrigins.cend())
            name = m_playlistNames.value(it->playlistId);
    }
    if (name == m_currentPlaylistName)
        return;
    m_currentPlaylistName = name;
    emit currentPlaylistNameChanged();
}

void MediaLib::mlInputItem(const QVector<MLItemId>& itemIdVector, QJSValue callback)
{
    if (!callback.isCallable()) // invalid argument
    {
        msg_Warn(m_intf, "callback is not callbable");
        return;
    }

    struct Ctx {
        std::vector<SharedInputItem> items;
    };

    if (itemIdVector.empty())
    {
        //call the callback with and empty list
        auto jsEngine = qjsEngine(this);
        if (!jsEngine)
            return;
        auto jsArray = jsEngine->newArray(0);
        callback.call({jsArray});
        return;
    }

    auto it = m_inputItemQuery.find(itemIdVector);

    if (it == m_inputItemQuery.end())
    {
        it = m_inputItemQuery.insert(itemIdVector, {callback});
    }
    else
    {
        // be patient

        for (const auto& it2 : it.value())
        {
            if (callback.strictlyEquals(it2))
                return;
        }

        it.value().push_back(callback); // FIXME: Use an ordered set
        return;
    }

    runOnMLThread<Ctx>(this,
    //ML thread
    [itemIdVector](vlc_medialibrary_t* ml, Ctx& ctx){
        for (auto mlId : itemIdVector)
        {
            // NOTE: When we have a parent it's a collection of media(s).
            if (mlId.type == VLC_ML_PARENT_UNKNOWN)
            {
                ctx.items.emplace_back(vlc_ml_get_input_item(ml, mlId.id), false);
            }
            else
            {
                ml_unique_ptr<vlc_ml_media_list_t> list;

                vlc_ml_query_params_t query = vlc_ml_query_params_create();

                list.reset(vlc_ml_list_media_of(ml, &query, mlId.type, mlId.id));

                if (list == nullptr)
                    continue;

                for (const vlc_ml_media_t & media : ml_range_iterate<vlc_ml_media_t>(list))
                    ctx.items.emplace_back(vlc_ml_get_input_item(ml, media.i_id), false);
            }
        }
    },
    //UI thread
    [this, it](quint64, Ctx& ctx) mutable
    {
        auto jsEngine = qjsEngine(this);
        if (!jsEngine)
            return;

        auto jsArray = jsEngine->newArray(ctx.items.size());

        int i  = 0;
        for (const auto& inputItem : ctx.items)
        {
            jsArray.setProperty(i, jsEngine->toScriptValue(inputItem));
            i++;
        }

        for (const auto& cb : std::as_const(it.value()))
        {
            cb.call({jsArray});
        }

        m_inputItemQuery.erase(it);
    });
}

vlc_ml_event_callback_t* MediaLib::registerEventListener( void (*callback)(void*, const vlc_ml_event_t*), void* data)
{
    return vlc_ml_event_register_callback( m_ml , callback , data ) ;
}

void MediaLib::unregisterEventListener(vlc_ml_event_callback_t* cb)
{
    vlc_ml_event_unregister_callback( m_ml , cb );
}

void MediaLib::onMediaLibraryEvent( void* data, const vlc_ml_event_t* event )
{
    MediaLib* self = static_cast<MediaLib*>( data );
    switch ( event->i_type )
    {
        case VLC_ML_EVENT_PARSING_PROGRESS_UPDATED:
        {
            int percent =  event->parsing_progress.i_percent;
            QMetaObject::invokeMethod(self, [self, percent]() {
                self->m_parsingProgress = percent;
                self->emit parsingProgressChanged(percent);
            });
            break;
        }
        case VLC_ML_EVENT_DISCOVERY_STARTED:
        {
            QMetaObject::invokeMethod(self, [self]() {
                self->m_discoveryPending = true;
                self->emit discoveryPendingChanged(self->m_discoveryPending);
                self->emit discoveryStarted();
            });
            break;
        }
        case VLC_ML_EVENT_DISCOVERY_PROGRESS:
        {
            const QUrl entryPoint{ event->discovery_progress.psz_entry_point };
            const QString entryPointStr = entryPoint.isLocalFile()
                                              ? entryPoint.toLocalFile()
                                              : entryPoint.toDisplayString();

            QMetaObject::invokeMethod(self, [self, entryPointStr]() {
                self->m_discoveryEntryPoint = entryPointStr;
                self->emit discoveryEntryPointChanged(entryPointStr);
            });
            break;
        }
        case VLC_ML_EVENT_DISCOVERY_COMPLETED:
        {
            QMetaObject::invokeMethod(self, [self]() {
                self->m_discoveryPending = false;
                self->emit discoveryPendingChanged(self->m_discoveryPending);
                self->emit discoveryCompleted();
            });
            break;
        }
        case VLC_ML_EVENT_PLAYLIST_UPDATED:
        {
            const int64_t id = event->modification.i_entity_id;
            QMetaObject::invokeMethod(self, [self, id]() {
                if (!self->m_playlistNames.contains(id))
                    return;
                struct Ctx {
                    QString name;
                    bool found = false;
                };
                self->runOnMLThread<Ctx>(self,
                [id](vlc_medialibrary_t* ml, Ctx& ctx) {
                    ml_unique_ptr<vlc_ml_playlist_t> playlist { vlc_ml_get_playlist(ml, id) };
                    if (playlist)
                    {
                        ctx.found = true;
                        ctx.name = qfu(playlist->psz_name);
                    }
                },
                [self, id](quint64, Ctx& ctx) {
                    if (!ctx.found)
                        return;
                    self->m_playlistNames[id] = ctx.name;
                    self->updateCurrentPlaylistName();
                });
            });
            break;
        }
        case VLC_ML_EVENT_PLAYLIST_DELETED:
        {
            const int64_t id = event->deletion.i_entity_id;
            QMetaObject::invokeMethod(self, [self, id]() {
                self->setPlaylistThumbnail(MLItemId(id, VLC_ML_PARENT_PLAYLIST), QUrl {});
            });
            break;
        }
        case VLC_ML_EVENT_BACKGROUND_IDLE_CHANGED:
        {
            bool idle = event->background_idle_changed.b_idle;
            QMetaObject::invokeMethod(self, [self, idle]() {
                self->m_idle = idle;
                self->emit idleChanged();
            });
            break;
        }
        default:
            break;
    }
}

quint64 MediaLib::runOnMLThread(const QObject* obj,
                std::function< void(vlc_medialibrary_t* ml)> mlCb,
                std::function< void()> uiCb,
                const char* queue)
{
    struct NoCtx{};
    return m_runner->runOnThread<NoCtx>(obj,
    [mlCb, ml=m_ml](NoCtx&){
        mlCb(ml);
    },
    [uiCb](quint64, NoCtx&){
        uiCb();
    },
    queue);
}

quint64 MediaLib::runOnMLThread(const QObject* obj,
                std::function< void(vlc_medialibrary_t* ml)> mlCb,
                std::function< void(quint64)> uiCb, const char* queue)
{
    struct NoCtx{};
    return m_runner->runOnThread<NoCtx>(obj,
    [mlCb, ml=m_ml](NoCtx&){
        mlCb(ml);
    },
    [uiCb](quint64 requestId, NoCtx&){
        uiCb(requestId);
    },
    queue);
}

quint64 MediaLib::runOnMLThread(const QObject* obj,
                std::function< void(vlc_medialibrary_t* ml)> mlCb,
                const char* queue)
{
    struct NoCtx{};
    return m_runner->runOnThread<NoCtx>(obj,
    [mlCb, ml=m_ml](NoCtx&){
        mlCb(ml);
    },
    [](quint64, NoCtx&){
    },
    queue);
}

void MediaLib::cancelMLTask(const QObject* object, quint64 taskId)
{
    m_runner->cancelTask(object, taskId);
}

