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
#ifndef VLC_QT_MENUSTYLE_HPP
#define VLC_QT_MENUSTYLE_HPP

#include <QProxyStyle>

class QMenu;

/**
 * Draws every QMenu of the interface (context menus, player right-click
 * menu, sort menus...) the way the "VLC Redesign" Figma file does:
 * rounded translucent panel with a soft shadow, 48px rows, 24px icons,
 * shortcuts in a dimmer color, accent check marks and thin dividers.
 *
 * Only menu elements are handled here, everything else is forwarded to
 * the application style.
 */
class MenuStyle : public QProxyStyle
{
    Q_OBJECT

public:
    using QProxyStyle::QProxyStyle;

    /// Applies the style to all menus of the application (current and future)
    static void install();
    /// Applies the style to one menu, before it is shown
    static void apply(QMenu* menu);
    /// Follows the interface color scheme (set by SystemPalette)
    static void setDark(bool dark);

    int pixelMetric(PixelMetric metric, const QStyleOption* option = nullptr,
                    const QWidget* widget = nullptr) const override;
    int styleHint(StyleHint hint, const QStyleOption* option = nullptr,
                  const QWidget* widget = nullptr, QStyleHintReturn* returnData = nullptr) const override;
    QSize sizeFromContents(ContentsType type, const QStyleOption* option,
                           const QSize& size, const QWidget* widget) const override;
    void drawPrimitive(PrimitiveElement element, const QStyleOption* option,
                       QPainter* painter, const QWidget* widget = nullptr) const override;
    void drawControl(ControlElement element, const QStyleOption* option,
                     QPainter* painter, const QWidget* widget = nullptr) const override;
    void polish(QWidget* widget) override;
    using QProxyStyle::polish;
};

#endif // VLC_QT_MENUSTYLE_HPP
