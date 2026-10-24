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

#ifndef VIDEOFOLDERFILTER_HPP
#define VIDEOFOLDERFILTER_HPP

#include <QSet>
#include <QSortFilterProxyModel>
#include <QStringList>

// Keeps the folders and the video files of a NetworkMediaModel, for the
// "Videos" folder view of the VLC Redesign (VideoFoldersDisplay.qml).
class VideoFolderFilter : public QSortFilterProxyModel
{
    Q_OBJECT

    Q_PROPERTY(int count READ rowCount NOTIFY countChanged FINAL)

public:
    explicit VideoFolderFilter(QObject *parent = nullptr);

    // row of the source model, for its addAndPlay() / addToPlaylist()
    Q_INVOKABLE int sourceRow(int row) const;

    Q_INVOKABLE QVariantMap getDataAt(int row) const;

signals:
    void countChanged();

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const override;
};

// Leaves the music folders (VLCConfig.musicFolders) out of the library
// folders (MLFolderModel), for "Videos": folders added from Music stay in Music.
class VideoLibraryFolderFilter : public QSortFilterProxyModel
{
    Q_OBJECT

    Q_PROPERTY(QStringList hiddenUrls READ hiddenUrls WRITE setHiddenUrls NOTIFY hiddenUrlsChanged FINAL)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged FINAL)

public:
    explicit VideoLibraryFolderFilter(QObject *parent = nullptr);

    QStringList hiddenUrls() const { return m_hiddenUrls; }
    void setHiddenUrls(const QStringList &urls);

signals:
    void hiddenUrlsChanged();
    void countChanged();

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const override;

private:
    QStringList m_hiddenUrls;
    QSet<QString> m_hiddenKeys;
};

#endif // VIDEOFOLDERFILTER_HPP
