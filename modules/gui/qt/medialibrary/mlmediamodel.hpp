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
#pragma once

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "mlbasemodel.hpp"
#include "mlmedia.hpp"
#include "mlvideo.hpp"
#include "mlaudio.hpp"

class MLMediaModel : public MLBaseModel
{
    Q_OBJECT
    /// name of a Home row: leaves out the media hidden from it
    /// (MediaLib::homeHidden), used by New Videos and New Music
    Q_PROPERTY(QString homeList READ homeList WRITE setHomeList NOTIFY homeListChanged FINAL)
public:
    enum Roles
    {
        MEDIA_ID = Qt::UserRole,
        MEDIA_TITLE,
        MEDIA_TITLE_FIRST_SYMBOL,
        MEDIA_FILENAME,
        MEDIA_SMALL_COVER,
        MEDIA_DURATION,
        MEDIA_MRL,
        MEDIA_IS_VIDEO,
        MEDIA_IS_FAVORITE,
        MEDIA_IS_LOCAL,
        MEDIA_PROGRESS,
        MEDIA_PLAYCOUNT,
        MEDIA_LAST_PLAYED_DATE,
        MEDIA_IS_DELETABLE_FILE,
        MEDIA_ROLES_COUNT,
    };

    explicit MLMediaModel(QObject *par = nullptr);
    virtual ~MLMediaModel() = default;

    Q_INVOKABLE void setMediaIsFavorite(const QModelIndex &index, bool isFavorite);
    // as if the media were never played: leaves the history (Home, Recent),
    // loses its play count and progress
    Q_INVOKABLE void removeFromHistory(const QModelIndexList &indexes);
    // "Remove from Home" on a row with homeList
    Q_INVOKABLE void hideOnHome(const QModelIndexList &indexes);

    QString homeList() const { return m_homeList; }
    void setHomeList(const QString &list);

signals:
    void homeListChanged();

public:
    Q_INVOKABLE QUrl getParentURL(const QModelIndex &index);
    Q_INVOKABLE QUrl getParentURL(const MLMedia *media) const;
    Q_INVOKABLE bool getPermissions(const MLMedia* media) const;
    Q_INVOKABLE void deleteFileFromSource(const QModelIndex &index);

protected:
    QHash<int, QByteArray> roleNames() const override;
    QVariant itemRoleData(const MLItem *item, int role) const override;
    void onVlcMlEvent(const MLEvent &event) override;
    std::unique_ptr<MLListCacheLoader> createMLLoader() const override;

    // `op` without the media hidden from homeList (op itself without one)
    std::shared_ptr<MLListCacheLoader::MLOp> withoutHidden(std::shared_ptr<MLListCacheLoader::MLOp> op) const;

private:
    QString m_homeList;

    vlc_ml_sorting_criteria_t nameToCriteria(QByteArray name) const override;
    void generateThumbnail(const MLVideo *video) const;

    struct Loader : public MLListCacheLoader::MLOp
    {
        using MLListCacheLoader::MLOp::MLOp;
        size_t count(vlc_medialibrary_t *ml, const vlc_ml_query_params_t *queryParams) const override;
        std::vector<std::unique_ptr<MLItem>> load(vlc_medialibrary_t *ml, const vlc_ml_query_params_t *queryParams) const override;
        std::unique_ptr<MLItem> loadItemById(vlc_medialibrary_t *ml, MLItemId itemId) const override;
    };
};
