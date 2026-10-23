/******************************************************************************
 * Copyright (C) 2024 VLC authors and VideoLAN
 *
 * Author: Ash <ashutoshv191@gmail.com>
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
 ******************************************************************************/
#include "util/vlctick.hpp"

#include "mlmediamodel.hpp"
#include "mlhelper.hpp"
#include <QFile>

#include <vector>

MLMediaModel::MLMediaModel(QObject *par)
    : MLBaseModel(par)
{
    connect(this, &MLBaseModel::mlChanged, this, [this]() {
        if (!m_mediaLib)
            return;
        connect(m_mediaLib, &MediaLib::homeHiddenChanged, this, [this](const QString &list) {
            // a full reset: the loader keeps the hidden media it was made with
            if (!m_homeList.isEmpty() && list == m_homeList)
                resetCache();
        });
    });
}

void MLMediaModel::setHomeList(const QString &list)
{
    if (m_homeList == list)
        return;
    m_homeList = list;
    emit homeListChanged();
    resetCache();
}

void MLMediaModel::hideOnHome(const QModelIndexList &indexes)
{
    assert(m_mediaLib != nullptr);

    QVector<int64_t> ids;
    for (const QModelIndex &index : indexes)
    {
        const auto media = static_cast<MLMedia *>(item(index.row()));
        if (media)
            ids.push_back(media->getId().id);
    }
    m_mediaLib->hideOnHome(m_homeList, ids);
}

namespace {

// Loads through another loader and drops the hidden media. Home rows load
// from the start (offset 0): one more item is asked for every hidden one.
struct WithoutHiddenOp : public MLListCacheLoader::MLOp
{
    WithoutHiddenOp(const MLBaseModel &model, std::shared_ptr<MLListCacheLoader::MLOp> op,
                    QSet<int64_t> hidden)
        : MLOp(model), m_op(std::move(op)), m_hidden(std::move(hidden))
    {}

    size_t count(vlc_medialibrary_t *ml, const vlc_ml_query_params_t *queryParams) const override
    {
        const size_t count = m_op->count(ml, queryParams);
        return count > size_t(m_hidden.size()) ? count - m_hidden.size() : 0;
    }

    std::vector<std::unique_ptr<MLItem>> load(vlc_medialibrary_t *ml, const vlc_ml_query_params_t *queryParams) const override
    {
        vlc_ml_query_params_t params = queryParams ? *queryParams : vlc_ml_query_params_create();
        const uint32_t wanted = params.i_nbResults;
        if (wanted > 0)
            params.i_nbResults = wanted + m_hidden.size();

        std::vector<std::unique_ptr<MLItem>> items = m_op->load(ml, &params);
        std::vector<std::unique_ptr<MLItem>> res;
        for (auto &item : items)
        {
            if (m_hidden.contains(item->getId().id))
                continue;
            if (wanted > 0 && res.size() >= wanted)
                break;
            res.push_back(std::move(item));
        }
        return res;
    }

    std::unique_ptr<MLItem> loadItemById(vlc_medialibrary_t *ml, MLItemId itemId) const override
    {
        if (m_hidden.contains(itemId.id))
            return nullptr;
        return m_op->loadItemById(ml, itemId);
    }

    std::shared_ptr<MLListCacheLoader::MLOp> m_op;
    QSet<int64_t> m_hidden;
};

} // namespace

std::shared_ptr<MLListCacheLoader::MLOp>
MLMediaModel::withoutHidden(std::shared_ptr<MLListCacheLoader::MLOp> op) const
{
    if (m_homeList.isEmpty() || !m_mediaLib)
        return op;
    QSet<int64_t> hidden = m_mediaLib->homeHidden(m_homeList);
    if (hidden.isEmpty())
        return op;
    return std::make_shared<WithoutHiddenOp>(*this, std::move(op), std::move(hidden));
}

void MLMediaModel::setMediaIsFavorite(const QModelIndex &index, bool isFavorite)
{
    assert(m_mediaLib != nullptr);

    const auto media = static_cast<MLMedia *>(item(index.row()));
    assert(media != nullptr);

    // on ML thread
    m_mediaLib->runOnMLThread(this, [id = media->getId().id, isFavorite](vlc_medialibrary_t *ml)
    {
        vlc_ml_media_set_favorite(ml, id, isFavorite);
    });

    media->setIsFavorite(isFavorite);

    emit dataChanged(index, index, { MEDIA_IS_FAVORITE });
}

void MLMediaModel::removeFromHistory(const QModelIndexList &indexes)
{
    assert(m_mediaLib != nullptr);

    std::vector<int64_t> ids;
    for (const QModelIndex &index : indexes)
    {
        const auto media = static_cast<MLMedia *>(item(index.row()));
        if (media)
            ids.push_back(media->getId().id);
    }
    if (ids.empty())
        return;

    // on ML thread; the history models reload on VLC_ML_EVENT_HISTORY_CHANGED
    m_mediaLib->runOnMLThread(this, [ids](vlc_medialibrary_t *ml)
    {
        for (const int64_t id : ids)
            vlc_ml_media_remove_from_history(ml, id);
    });
}

QUrl MLMediaModel::getParentURL(const QModelIndex &index) {
    const auto media = static_cast<MLMedia *>(item(index.row()));
    assert(media != nullptr);
    return getParentURL(media);
}

QUrl MLMediaModel::getParentURL(const MLMedia *media) const{
    assert(media != nullptr);
    return getParentURLFromURL(media->mrl());
}

bool MLMediaModel::getPermissions(const MLMedia* media) const
{
    QString mrl = media->mrl();

    QUrl fileUrl(mrl);
    QString localPath = fileUrl.toLocalFile();

    if (localPath.isEmpty())
        return false;

    QFileDevice::Permissions filePermissions = QFile::permissions(localPath);

    if (!(filePermissions & QFileDevice::WriteUser))
        return false;

    QUrl parentUrl = getParentURL(media);
    QString parentPath = parentUrl.toLocalFile();

    if (parentPath.isEmpty())
        return false;

    QFileDevice::Permissions folderPermissions = QFile::permissions(parentPath);

    return folderPermissions & QFileDevice::WriteUser;
}

void MLMediaModel::deleteFileFromSource(const QModelIndex &index)
{
    const auto media = static_cast<MLMedia *>(item(index.row()));
    QString mrl = media->mrl();

    QUrl fileUrl(mrl);
    QString localPath = fileUrl.toLocalFile();

    QFile file(localPath);
    bool removed = file.remove();
    if (!removed)
        return;

    QUrl parentUrl = getParentURL(index);
    QString parentUrlString = parentUrl.toString();

    m_mediaLib->runOnMLThread(this,
                              [parentUrlString](vlc_medialibrary_t *ml)
                              {
                                  vlc_ml_reload_folder(ml, qtu(parentUrlString));
                              });
}

vlc_ml_sorting_criteria_t MLMediaModel::nameToCriteria(QByteArray name) const
{
    return QHash<QByteArray, vlc_ml_sorting_criteria_t> {
        {QByteArrayLiteral("title"), VLC_ML_SORTING_ALPHA},
        {QByteArrayLiteral("duration"), VLC_ML_SORTING_DURATION},
        {QByteArrayLiteral("insertion"), VLC_ML_SORTING_INSERTIONDATE},
    }.value(name, VLC_ML_SORTING_DEFAULT);
}

QHash<int, QByteArray> MLMediaModel::roleNames() const
{
    return {
        {MEDIA_ID, QByteArrayLiteral("id")},
        {MEDIA_TITLE, QByteArrayLiteral("title")},
        {MEDIA_TITLE_FIRST_SYMBOL, QByteArrayLiteral("title_first_symbol")},
        {MEDIA_FILENAME, QByteArrayLiteral("fileName")},
        {MEDIA_SMALL_COVER, QByteArrayLiteral("small_cover")},
        {MEDIA_DURATION, QByteArrayLiteral("duration")},
        {MEDIA_MRL, QByteArrayLiteral("mrl")},
        {MEDIA_IS_VIDEO, QByteArrayLiteral("isVideo")},
        {MEDIA_IS_FAVORITE, QByteArrayLiteral("isFavorite")},
        {MEDIA_IS_LOCAL, QByteArrayLiteral("isLocal")},
        {MEDIA_PROGRESS, QByteArrayLiteral("progress")},
        {MEDIA_PLAYCOUNT, QByteArrayLiteral("playcount")},
        {MEDIA_LAST_PLAYED_DATE, QByteArrayLiteral("last_played_date")},
        {MEDIA_IS_DELETABLE_FILE, QByteArrayLiteral("isDeletableFile")},
    };
}

QVariant MLMediaModel::itemRoleData(const MLItem *item, int role) const
{
    const auto media = static_cast<const MLMedia *>(item);
    assert(media != nullptr);

    switch(role)
    {
    case MEDIA_ID:
        return QVariant::fromValue(media->getId());
    case MEDIA_TITLE:
        return QVariant::fromValue(media->title());
    case MEDIA_TITLE_FIRST_SYMBOL:
        return QVariant::fromValue(getFirstSymbol(media->title()));
    case MEDIA_FILENAME:
        return QVariant::fromValue(media->fileName());
    case MEDIA_SMALL_COVER: // depends on the type of media
        if (const auto video = dynamic_cast<const MLVideo *>(media))
        {
            vlc_ml_thumbnail_status_t status;
            const QString thumbnail(video->smallCover(&status));
            // also retry "persistent" failures: they are often only a timeout
            // on a slow drive or a large file, which may work the next time
            if (status == VLC_ML_THUMBNAIL_STATUS_MISSING || status == VLC_ML_THUMBNAIL_STATUS_FAILURE
                || status == VLC_ML_THUMBNAIL_STATUS_PERSISTENT_FAILURE)
                generateThumbnail(video);
            return QVariant::fromValue(thumbnail);
        }
        else if (const auto audio = dynamic_cast<const MLAudio *>(media))
            return QVariant::fromValue(audio->smallCover());
        else
            Q_UNREACHABLE();
    case MEDIA_DURATION:
        return QVariant::fromValue(media->duration());
    case MEDIA_MRL:
        return QVariant::fromValue(media->mrl());
    case MEDIA_IS_VIDEO:
        return QVariant::fromValue(media->type() != VLC_ML_MEDIA_TYPE_AUDIO);
    case MEDIA_IS_FAVORITE:
        return QVariant::fromValue(media->isFavorite());
    case MEDIA_IS_LOCAL:
    {
        QUrl mediaUrl(media->mrl());
        return QVariant::fromValue(mediaUrl.isLocalFile());
    }
    case MEDIA_PROGRESS:
        return QVariant::fromValue(media->progress());
    case MEDIA_PLAYCOUNT:
        return QVariant::fromValue(media->playCount());
    case MEDIA_LAST_PLAYED_DATE:
        return QVariant::fromValue( media->lastPlayedDate().toString( QLocale::system().dateFormat( QLocale::ShortFormat ) ) );
    case MEDIA_IS_DELETABLE_FILE:
        return QVariant::fromValue(getPermissions(media));
    }
    return {};
}

void MLMediaModel::onVlcMlEvent(const MLEvent &event)
{
    switch(event.i_type)
    {
    // common
    case VLC_ML_EVENT_MEDIA_ADDED:
        emit resetRequested();
        return;
    case VLC_ML_EVENT_MEDIA_UPDATED:
    {
        MLItemId itemId(event.modification.i_entity_id, VLC_ML_PARENT_UNKNOWN);
        updateItemInCache(itemId);
        return;
    }
    case VLC_ML_EVENT_MEDIA_DELETED:
    {
        MLItemId itemId(event.modification.i_entity_id, VLC_ML_PARENT_UNKNOWN);
        deleteItemInCache(itemId);
        return;
    }
    // audio specific
    case VLC_ML_EVENT_ALBUM_UPDATED:
        if (m_parent.id != 0 && m_parent.type == VLC_ML_PARENT_ALBUM && m_parent.id == event.modification.i_entity_id)
            emit resetRequested();
        return;
    case VLC_ML_EVENT_ALBUM_DELETED:
        if (m_parent.id != 0 && m_parent.type == VLC_ML_PARENT_ALBUM && m_parent.id == event.deletion.i_entity_id)
            emit resetRequested();
        return;
    case VLC_ML_EVENT_GENRE_DELETED:
        if (m_parent.id != 0 && m_parent.type == VLC_ML_PARENT_GENRE && m_parent.id == event.deletion.i_entity_id)
            emit resetRequested();
        return;
    default:
        MLBaseModel::onVlcMlEvent(event);
    }
}

void MLMediaModel::generateThumbnail(const MLVideo *video) const
{
    assert(video != nullptr);

    // on ML thread
    m_mediaLib->runOnMLThread(this, [id = video->getId().id](vlc_medialibrary_t *ml)
    {
        vlc_ml_media_generate_thumbnail(ml, id, VLC_ML_THUMBNAIL_SMALL, 512, 320, .15);
    });
}

// Loader related member functions
std::unique_ptr<MLListCacheLoader>
MLMediaModel::createMLLoader() const
{
    return std::make_unique<MLListCacheLoader>(m_mediaLib, std::make_shared<MLMediaModel::Loader>(*this));
}

size_t MLMediaModel::Loader::count(vlc_medialibrary_t *ml, const vlc_ml_query_params_t *queryParams) const
{
    if (m_parent.id <= 0)
        return vlc_ml_count_media(ml, queryParams);
    return vlc_ml_count_media_of(ml, queryParams, m_parent.type, m_parent.id);
}

std::vector<std::unique_ptr<MLItem>>
MLMediaModel::Loader::load(vlc_medialibrary_t *ml, const vlc_ml_query_params_t *queryParams) const
{
    ml_unique_ptr<vlc_ml_media_list_t> mediaList;

    if (m_parent.id <= 0)
        mediaList.reset(vlc_ml_list_media(ml, queryParams));
    else
        mediaList.reset(vlc_ml_list_media_of(ml, queryParams, m_parent.type, m_parent.id));

    if (mediaList == nullptr)
        return {};

    std::vector<std::unique_ptr<MLItem>> res;

    for (vlc_ml_media_t &media : ml_range_iterate<vlc_ml_media_t>(mediaList))
        if (media.i_type != VLC_ML_MEDIA_TYPE_AUDIO)
            res.emplace_back(std::make_unique<MLVideo>(&media));
        else if (media.i_type == VLC_ML_MEDIA_TYPE_AUDIO)
            res.emplace_back(std::make_unique<MLAudio>(ml, &media));
        else
            Q_UNREACHABLE();
    return res;
}

std::unique_ptr<MLItem>
MLMediaModel::Loader::loadItemById(vlc_medialibrary_t *ml, MLItemId itemId) const
{
    assert(itemId.type == VLC_ML_PARENT_UNKNOWN);
    ml_unique_ptr<vlc_ml_media_t> media(vlc_ml_get_media(ml, itemId.id));

    if (media == nullptr)
        return nullptr;

    if (media->i_type != VLC_ML_MEDIA_TYPE_AUDIO)
        return std::make_unique<MLVideo>(media.get());
    else if (media->i_type == VLC_ML_MEDIA_TYPE_AUDIO)
        return std::make_unique<MLAudio>(ml, media.get());
    else
        Q_UNREACHABLE();
    return nullptr;
}
