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

#include "mlrecentaudiomodel.hpp"
#include "mlhelper.hpp"
#include "mlaudio.hpp"

#include <cstring>

// Ctor / dtor

MLRecentAudioModel::MLRecentAudioModel(QObject * parent) : MLAudioModel(parent) {}

// Protected MLBaseModel implementation

std::unique_ptr<MLListCacheLoader>
MLRecentAudioModel::createMLLoader() const
/* override */
{
    return std::make_unique<MLListCacheLoader>(m_mediaLib, std::make_shared<MLRecentAudioModel::Loader>(*this));
}

// Private MLAudioModel reimplementation

void MLRecentAudioModel::onVlcMlEvent(const MLEvent & event) /* override */
{
    switch (event.i_type)
    {
        case VLC_ML_EVENT_HISTORY_CHANGED:
            emit resetRequested();
            return;
        default:
            break;
    }

    MLAudioModel::onVlcMlEvent(event);
}

// Loader

namespace {

// "Listen Again" lists local audio files only: played radio stations and
// other streams are in the history too, named after their stream URL
bool isLocalFile(const vlc_ml_media_t &media)
{
    if (media.p_files == nullptr || media.p_files->i_nb_items == 0)
        return false;
    const char *mrl = media.p_files->p_items[0].psz_mrl;
    return mrl != nullptr && strncmp(mrl, "file://", 7) == 0;
}

// the whole audio history, without paging (the filter comes first)
std::vector<const vlc_ml_media_t *> localMedia(const vlc_ml_media_list_t *list)
{
    std::vector<const vlc_ml_media_t *> res;
    for (size_t i = 0; list != nullptr && i < list->i_nb_items; ++i)
        if (isLocalFile(list->p_items[i]))
            res.push_back(&list->p_items[i]);
    return res;
}

vlc_ml_query_params_t withoutPaging(const vlc_ml_query_params_t *queryParams)
{
    vlc_ml_query_params_t params = queryParams ? *queryParams : vlc_ml_query_params_create();
    params.i_nbResults = 0;
    params.i_offset = 0;
    return params;
}

} // namespace

size_t MLRecentAudioModel::Loader::count(vlc_medialibrary_t* ml, const vlc_ml_query_params_t* queryParams) const /* override */
{
    const vlc_ml_query_params_t params = withoutPaging(queryParams);
    ml_unique_ptr<vlc_ml_media_list_t> media_list { vlc_ml_list_audio_history(ml, &params) };
    // like vlc_ml_count_audio_history(): the model applies its limit itself
    return localMedia(media_list.get()).size();
}

std::vector<std::unique_ptr<MLItem>>
MLRecentAudioModel::Loader::load(vlc_medialibrary_t* ml, const vlc_ml_query_params_t* queryParams) const /* override */
{
    const vlc_ml_query_params_t params = withoutPaging(queryParams);
    ml_unique_ptr<vlc_ml_media_list_t> media_list { vlc_ml_list_audio_history(ml, &params) };

    const std::vector<const vlc_ml_media_t *> local = localMedia(media_list.get());

    const size_t offset = queryParams ? queryParams->i_offset : 0;
    const size_t limit = (queryParams && queryParams->i_nbResults > 0) ? queryParams->i_nbResults : local.size();

    std::vector<std::unique_ptr<MLItem>> res;
    for (size_t i = offset; i < local.size() && res.size() < limit; ++i)
        res.emplace_back( std::make_unique<MLAudio>(ml, local[i]));

    return res;
}

std::unique_ptr<MLItem>
MLRecentAudioModel::Loader::loadItemById(vlc_medialibrary_t* ml, MLItemId itemId) const
{
    assert(itemId.type == VLC_ML_PARENT_UNKNOWN);
    ml_unique_ptr<vlc_ml_media_t> media(vlc_ml_get_media(ml, itemId.id));
    if (!media)
        return nullptr;
    return std::make_unique<MLAudio>(ml, media.get());
}
