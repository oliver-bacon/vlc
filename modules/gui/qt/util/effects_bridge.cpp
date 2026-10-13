/*****************************************************************************
 * Copyright (C) 2026 the VideoLAN team
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

#include "effects_bridge.hpp"

#include <QStringList>

#include <vlc_common.h>
#include <vlc_aout.h>
#include <vlc_configuration.h>
#include <vlc_player.h>
#include <vlc_vout.h>

#include "player/player_controller.hpp"
#include "../../../audio_filter/equalizer_presets.h"

namespace {

QStringList chainOf(const char* option)
{
    char* psz = config_GetPsz(option);
    const QStringList list = qfu(psz ? psz : "").split(':', Qt::SkipEmptyParts);
    free(psz);
    return list;
}

/* sets a variable on a live object, with the type of the variable (or of
 * the config option when the object does not have it yet) */
void setVar(vlc_object_t* obj, const char* name, const QVariant& value)
{
    int type = var_Type(obj, name);
    if (type == 0)
        type = config_GetType(name);
    switch (type & VLC_VAR_CLASS)
    {
    case VLC_VAR_BOOL:    var_Create(obj, name, VLC_VAR_BOOL);    var_SetBool(obj, name, value.toBool()); break;
    case VLC_VAR_INTEGER: var_Create(obj, name, VLC_VAR_INTEGER); var_SetInteger(obj, name, value.toLongLong()); break;
    case VLC_VAR_FLOAT:   var_Create(obj, name, VLC_VAR_FLOAT);   var_SetFloat(obj, name, value.toFloat()); break;
    case VLC_VAR_STRING:  var_Create(obj, name, VLC_VAR_STRING);  var_SetString(obj, name, qtu(value.toString())); break;
    default: break;
    }
}

QVariant getVar(vlc_object_t* obj, const char* name)
{
    switch (var_Type(obj, name) & VLC_VAR_CLASS)
    {
    case VLC_VAR_BOOL:    return var_GetBool(obj, name);
    case VLC_VAR_INTEGER: return QVariant::fromValue<qint64>(var_GetInteger(obj, name));
    case VLC_VAR_FLOAT:   return var_GetFloat(obj, name);
    case VLC_VAR_STRING:
    {
        char* psz = var_GetString(obj, name);
        const QString str = qfu(psz ? psz : "");
        free(psz);
        return str;
    }
    default: return {};
    }
}

QVariant getConfig(const char* name)
{
    switch (config_GetType(name) & VLC_VAR_CLASS)
    {
    case VLC_VAR_BOOL:    return config_GetInt(name) != 0;
    case VLC_VAR_INTEGER: return QVariant::fromValue<qint64>(config_GetInt(name));
    case VLC_VAR_FLOAT:   return config_GetFloat(name);
    case VLC_VAR_STRING:
    {
        char* psz = config_GetPsz(name);
        const QString str = qfu(psz ? psz : "");
        free(psz);
        return str;
    }
    default: return {};
    }
}

} // namespace

EffectsBridge::EffectsBridge(qt_intf_t* intf, QObject* parent)
    : QObject(parent)
    , m_intf(intf)
{
    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(800);
    connect(&m_saveTimer, &QTimer::timeout, this, [this]() {
        config_SaveConfigFile(m_intf);
    });
}

void EffectsBridge::scheduleSave()
{
    m_saveTimer.start();
    emit changed();
}

void EffectsBridge::putConfig(const QString& option, const QVariant& value)
{
    const QByteArray name = option.toUtf8();
    switch (config_GetType(name.constData()) & VLC_VAR_CLASS)
    {
    case VLC_VAR_BOOL:    config_PutInt(name.constData(), value.toBool() ? 1 : 0); break;
    case VLC_VAR_INTEGER: config_PutInt(name.constData(), value.toLongLong()); break;
    case VLC_VAR_FLOAT:   config_PutFloat(name.constData(), value.toFloat()); break;
    case VLC_VAR_STRING:  config_PutPsz(name.constData(), qtu(value.toString())); break;
    default: return;
    }
    scheduleSave();
}

bool EffectsBridge::audioFilterEnabled(const QString& module) const
{
    return chainOf("audio-filter").contains(module);
}

void EffectsBridge::setAudioFilterEnabled(const QString& module, bool enabled)
{
    QStringList list = chainOf("audio-filter");
    if (enabled == list.contains(module))
        return;
    if (enabled)
        list.append(module);
    else
        list.removeAll(module);
    putConfig(QStringLiteral("audio-filter"), list.join(':'));
    vlc_player_aout_EnableFilter(m_intf->p_player, qtu(module), enabled);
}

bool EffectsBridge::videoFilterEnabled(const QString& module) const
{
    return chainOf("video-filter").contains(module);
}

void EffectsBridge::setVideoFilterEnabled(const QString& module, bool enabled)
{
    QStringList list = chainOf("video-filter");
    if (enabled == list.contains(module))
        return;
    if (enabled)
        list.append(module);
    else
        list.removeAll(module);
    const QString chain = list.join(':');
    putConfig(QStringLiteral("video-filter"), chain);
    for (const auto& vout : m_intf->p_mainPlayerController->getVouts())
        var_SetString(vout.get(), "video-filter", qtu(chain));
}

QVariant EffectsBridge::audioValue(const QString& option) const
{
    const QByteArray name = option.toUtf8();
    if (SharedAOut aout = m_intf->p_mainPlayerController->getAout())
        if (var_Type(aout.get(), name.constData()) != 0)
            return getVar(VLC_OBJECT(aout.get()), name.constData());
    return getConfig(name.constData());
}

void EffectsBridge::setAudioValue(const QString& option, const QVariant& value)
{
    const QByteArray name = option.toUtf8();
    if (SharedAOut aout = m_intf->p_mainPlayerController->getAout())
        setVar(VLC_OBJECT(aout.get()), name.constData(), value);
    putConfig(option, value);
}

QVariant EffectsBridge::videoValue(const QString& option) const
{
    const QByteArray name = option.toUtf8();
    if (SharedVOutThread vout = m_intf->p_mainPlayerController->getVout())
        if (var_Type(vout.get(), name.constData()) != 0)
            return getVar(VLC_OBJECT(vout.get()), name.constData());
    return getConfig(name.constData());
}

void EffectsBridge::setVideoValue(const QString& option, const QVariant& value)
{
    const QByteArray name = option.toUtf8();
    for (const auto& vout : m_intf->p_mainPlayerController->getVouts())
        setVar(VLC_OBJECT(vout.get()), name.constData(), value);
    putConfig(option, value);
}

QVariantList EffectsBridge::equalizerPresets() const
{
    QVariantList ret;
    for (int i = 0; i < NB_PRESETS; ++i)
        ret.append(QVariantMap {
            { QStringLiteral("name"), qfu(preset_list[i]) },
            { QStringLiteral("text"), qfut(preset_list_text[i]) },
        });
    return ret;
}

QVariantMap EffectsBridge::applyEqualizerPreset(const QString& name)
{
    for (int i = 0; i < NB_PRESETS; ++i)
    {
        if (name != qfu(preset_list[i]))
            continue;
        const eqz_preset_t& preset = eqz_preset_10b[i];
        QVariantList bands;
        QStringList text;
        for (int b = 0; b < preset.i_band && b < EQZ_BANDS_MAX; ++b)
        {
            bands.append(preset.f_amp[b]);
            text.append(QString::number(preset.f_amp[b], 'f', 1));
        }
        setAudioValue(QStringLiteral("equalizer-preamp"), preset.f_preamp);
        setAudioValue(QStringLiteral("equalizer-bands"), text.join(' '));
        setAudioValue(QStringLiteral("equalizer-preset"), name);
        return { { QStringLiteral("preamp"), preset.f_preamp }, { QStringLiteral("bands"), bands } };
    }
    return {};
}

QVariantList EffectsBridge::equalizerBands() const
{
    QVariantList ret;
    const QStringList bands = audioValue(QStringLiteral("equalizer-bands")).toString()
                                  .split(' ', Qt::SkipEmptyParts);
    for (int b = 0; b < EQZ_BANDS_MAX; ++b)
        ret.append(b < bands.size() ? bands[b].toDouble() : 0.0);
    return ret;
}

void EffectsBridge::setEqualizerBand(int band, double gain)
{
    if (band < 0 || band >= EQZ_BANDS_MAX)
        return;
    QStringList text;
    const QVariantList bands = equalizerBands();
    for (int b = 0; b < EQZ_BANDS_MAX; ++b)
        text.append(QString::number(b == band ? gain : bands[b].toDouble(), 'f', 1));
    setAudioValue(QStringLiteral("equalizer-bands"), text.join(' '));
}

void EffectsBridge::setCrop(int top, int bottom, int left, int right)
{
    for (const auto& vout : m_intf->p_mainPlayerController->getVouts())
    {
        var_SetInteger(vout.get(), "crop-top", top);
        var_SetInteger(vout.get(), "crop-bottom", bottom);
        var_SetInteger(vout.get(), "crop-left", left);
        var_SetInteger(vout.get(), "crop-right", right);
    }
}
