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
#ifndef VLC_QT_SETTINGS_PROFILES_HPP
#define VLC_QT_SETTINGS_PROFILES_HPP

#include <QStringList>

#include "qt.hpp"

/**
 * Settings profiles ("Profile (Movies) > Movies / Shows / Music / Work /
 * New" in the main menu of the VLC Redesign Figma file).
 *
 * A profile is a complete set of VLC settings: every option that differs
 * from its default value, saved in its own file of the user config folder.
 * The profile also keeps the Qt interface settings (look, player bars,
 * subtitle presets...), see isProfileKey(). Switching profile saves the
 * current settings into the current profile, then resets all options and
 * applies the other profile to the open interface.
 */
namespace SettingsProfiles
{
    /// Profile names; the default profiles are created on first use
    QStringList names(qt_intf_t* intf);
    QString current(qt_intf_t* intf);

    /// Saves the current settings into the current profile, then switches
    bool switchTo(qt_intf_t* intf, const QString& name);
    /// Creates a profile from the current settings and switches to it
    bool create(qt_intf_t* intf, const QString& name);
}

#endif // VLC_QT_SETTINGS_PROFILES_HPP
