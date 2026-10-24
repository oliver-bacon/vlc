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

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "videofolderfilter.hpp"
#include "networkbasemodel.hpp"

#include <vlc_common.h>
#include <vlc_interface.h>

#include <QSet>
#include <QUrl>

namespace {

const QSet<QString> &videoExtensions()
{
    static const QSet<QString> extensions { EXTENSIONS_VIDEO_CSV };
    return extensions;
}

int roleId(const QAbstractItemModel *model, const QByteArray &name)
{
    return model ? model->roleNames().key(name, -1) : -1;
}

} // namespace

VideoFolderFilter::VideoFolderFilter(QObject *parent)
    : QSortFilterProxyModel(parent)
{
    connect(this, &QAbstractItemModel::rowsInserted, this, &VideoFolderFilter::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &VideoFolderFilter::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &VideoFolderFilter::countChanged);
    connect(this, &QAbstractItemModel::layoutChanged, this, &VideoFolderFilter::countChanged);
}

int VideoFolderFilter::sourceRow(int row) const
{
    return mapToSource(index(row, 0)).row();
}

QVariantMap VideoFolderFilter::getDataAt(int row) const
{
    QVariantMap result;
    const QModelIndex idx = index(row, 0);
    if (!idx.isValid())
        return result;
    const QHash<int, QByteArray> names = roleNames();
    for (auto it = names.cbegin(); it != names.cend(); ++it)
        result.insert(QString::fromUtf8(it.value()), data(idx, it.key()));
    return result;
}

bool VideoFolderFilter::filterAcceptsRow(int row, const QModelIndex &parent) const
{
    const QAbstractItemModel *model = sourceModel();
    if (!model)
        return false;
    const QModelIndex idx = model->index(row, 0, parent);

    const int type = model->data(idx, roleId(model, "type")).toInt();
    if (type == NetworkBaseModel::TYPE_DIRECTORY || type == NetworkBaseModel::TYPE_NODE)
        return true;
    if (type != NetworkBaseModel::TYPE_FILE)
        return false;

    const QString path = model->data(idx, roleId(model, "mrl")).toUrl().path();
    const qsizetype dot = path.lastIndexOf(QLatin1Char('.'));
    return dot >= 0 && videoExtensions().contains(path.mid(dot + 1).toLower());
}

VideoLibraryFolderFilter::VideoLibraryFolderFilter(QObject *parent)
    : QSortFilterProxyModel(parent)
{
    connect(this, &QAbstractItemModel::rowsInserted, this, &VideoLibraryFolderFilter::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &VideoLibraryFolderFilter::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &VideoLibraryFolderFilter::countChanged);
    connect(this, &QAbstractItemModel::layoutChanged, this, &VideoLibraryFolderFilter::countChanged);
}

namespace {

QString folderKey(const QUrl &url)
{
    return url.adjusted(QUrl::StripTrailingSlash | QUrl::NormalizePathSegments)
              .toString(QUrl::FullyEncoded);
}

} // namespace

void VideoLibraryFolderFilter::setHiddenUrls(const QStringList &urls)
{
    if (m_hiddenUrls == urls)
        return;
    m_hiddenUrls = urls;
    m_hiddenKeys.clear();
    for (const QString &url : urls)
        m_hiddenKeys.insert(folderKey(QUrl(url)));
    invalidateFilter();
    emit hiddenUrlsChanged();
}

bool VideoLibraryFolderFilter::filterAcceptsRow(int row, const QModelIndex &parent) const
{
    const QAbstractItemModel *model = sourceModel();
    if (!model)
        return false;
    const QModelIndex idx = model->index(row, 0, parent);
    return !m_hiddenKeys.contains(folderKey(model->data(idx, roleId(model, "url")).toUrl()));
}
