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

#include "menustyle.hpp"

#include <QApplication>
#include <QMenu>
#include <QPainter>
#include <QPainterPath>
#include <QPointer>
#include <QStyleOptionMenuItem>

#include <algorithm>

namespace {

// Figma "VLC Redesign": context menu / option components
constexpr int kShadow = 12;       // transparent margin holding the drop shadow
constexpr int kPadding = 4;       // panel padding around the rows
constexpr int kPanelRadius = 10;
constexpr int kRowHeight = 48;
constexpr int kRowRadius = 6;
constexpr int kRowMinWidth = 257; // 265px wide panel
constexpr int kIconLeft = 14;
constexpr int kIconSize = 24;
constexpr int kTextLeft = 48;
constexpr int kTextLeftNoIcon = 14; // menus without any icon ("Sorting Options")
constexpr int kRightPadding = 16;
constexpr int kArrowSpace = 28;   // submenu chevron / check mark column
constexpr int kFontPixelSize = 14;

struct MenuColors
{
    QColor panel, hover, text, shortcut, disabled, divider, mark;
};

bool s_dark = true;

MenuColors colors()
{
    if (s_dark)
        return { QColor(0x19, 0x19, 0x19, 242), QColor(0x1F, 0x1F, 0x1F), QColor(0x8F, 0x8F, 0x8F),
                 QColor(0x6B, 0x6B, 0x6B), QColor(0x40, 0x40, 0x40), QColor(0x22, 0x22, 0x22),
                 QColor(0xD3, 0x79, 0x18) };
    // the design has no light menus: use the light tokens of the palette
    return { QColor(0xE7, 0xE7, 0xE7, 242), QColor(0xDE, 0xDE, 0xDE), QColor(0x2E, 0x2E, 0x2E),
             QColor(0x6B, 0x6B, 0x6B), QColor(0x9B, 0x9B, 0x9B), QColor(0xAC, 0xAC, 0xAC),
             QColor(0xD3, 0x79, 0x18) };
}

QFont menuFont(const QFont& base)
{
    QFont f = base;
    f.setPixelSize(kFontPixelSize);
    return f;
}

bool isMenu(const QWidget* widget)
{
    return qobject_cast<const QMenu*>(widget) != nullptr;
}

MenuStyle* sharedStyle()
{
    static QPointer<MenuStyle> style;
    if (!style)
        style = new MenuStyle(); // proxies the application style
    return style;
}

class MenuStyler : public QObject
{
public:
    using QObject::QObject;

    bool eventFilter(QObject* obj, QEvent* event) override
    {
        if (event->type() == QEvent::Polish || event->type() == QEvent::Show)
            if (auto menu = qobject_cast<QMenu*>(obj))
                MenuStyle::apply(menu);
        return false;
    }
};

} // namespace

void MenuStyle::setDark(bool dark)
{
    s_dark = dark;
}

void MenuStyle::install()
{
    static QPointer<MenuStyler> styler;
    if (styler)
        return;
    styler = new MenuStyler(qApp);
    qApp->installEventFilter(styler);
}

void MenuStyle::apply(QMenu* menu)
{
    MenuStyle* style = sharedStyle();
    if (menu->style() == style)
        return;
    menu->setStyle(style);
}

void MenuStyle::polish(QWidget* widget)
{
    QProxyStyle::polish(widget);
    if (!isMenu(widget))
        return;
    widget->setAttribute(Qt::WA_TranslucentBackground);
    widget->setWindowFlag(Qt::FramelessWindowHint);
    widget->setWindowFlag(Qt::NoDropShadowWindowHint);
}

int MenuStyle::pixelMetric(PixelMetric metric, const QStyleOption* option, const QWidget* widget) const
{
    if (isMenu(widget))
    {
        switch (metric)
        {
        case PM_MenuPanelWidth: return kShadow;
        case PM_MenuHMargin:
        case PM_MenuVMargin: return kPadding;
        case PM_MenuDesktopFrameWidth: return 0;
        case PM_SubMenuOverlap: return 2 * kShadow - kPadding;
        case PM_SmallIconSize: return kIconSize;
        default: break;
        }
    }
    return QProxyStyle::pixelMetric(metric, option, widget);
}

int MenuStyle::styleHint(StyleHint hint, const QStyleOption* option, const QWidget* widget,
                         QStyleHintReturn* returnData) const
{
    if (isMenu(widget))
    {
        switch (hint)
        {
        case SH_Menu_Mask: return 0;
        case SH_Menu_AllowActiveAndDisabled: return 0;
        default: break;
        }
    }
    return QProxyStyle::styleHint(hint, option, widget, returnData);
}

QSize MenuStyle::sizeFromContents(ContentsType type, const QStyleOption* option,
                                  const QSize& size, const QWidget* widget) const
{
    if (type != CT_MenuItem || !isMenu(widget))
        return QProxyStyle::sizeFromContents(type, option, size, widget);

    const auto item = qstyleoption_cast<const QStyleOptionMenuItem*>(option);
    if (!item)
        return QProxyStyle::sizeFromContents(type, option, size, widget);
    if (item->menuItemType == QStyleOptionMenuItem::Separator)
        return { kRowMinWidth, 1 };

    const QFontMetrics fm(menuFont(item->font));
    QString text = item->text;
    QString shortcut;
    if (const int tab = text.indexOf('\t'); tab >= 0)
    {
        shortcut = text.mid(tab + 1);
        text = text.left(tab);
    }
    text.remove('&');
    const int textLeft = item->maxIconWidth > 0 ? kTextLeft : kTextLeftNoIcon;
    int width = textLeft + fm.horizontalAdvance(text) + kRightPadding;
    if (!shortcut.isEmpty())
        width += kRightPadding + fm.horizontalAdvance(shortcut);
    if (item->menuItemType == QStyleOptionMenuItem::SubMenu || item->checkType != QStyleOptionMenuItem::NotCheckable)
        width += kArrowSpace;
    return { std::max(width, kRowMinWidth), kRowHeight };
}

void MenuStyle::drawPrimitive(PrimitiveElement element, const QStyleOption* option,
                              QPainter* painter, const QWidget* widget) const
{
    if (!isMenu(widget) || (element != PE_PanelMenu && element != PE_FrameMenu))
        return QProxyStyle::drawPrimitive(element, option, painter, widget);
    if (element == PE_FrameMenu)
        return;

    const MenuColors c = colors();
    const QRectF panel = QRectF(option->rect).adjusted(kShadow, kShadow, -kShadow, -kShadow);

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing);
    painter->setPen(Qt::NoPen);
    // soft drop shadow (Figma: y 8, blur 15, black 46%), approximated with
    // stacked translucent rounded rectangles
    const QRectF shadow = panel.translated(0, kShadow / 2.0);
    for (int i = kShadow; i > 0; --i)
    {
        painter->setBrush(QColor(0, 0, 0, s_dark ? 10 : 5));
        painter->drawRoundedRect(shadow.adjusted(-i / 2.0, -i / 2.0, i / 2.0, i / 2.0),
                                 kPanelRadius + i / 2.0, kPanelRadius + i / 2.0);
    }
    painter->setBrush(c.panel);
    painter->drawRoundedRect(panel, kPanelRadius, kPanelRadius);
    painter->restore();
}

void MenuStyle::drawControl(ControlElement element, const QStyleOption* option,
                            QPainter* painter, const QWidget* widget) const
{
    if (!isMenu(widget) || (element != CE_MenuItem && element != CE_MenuEmptyArea))
        return QProxyStyle::drawControl(element, option, painter, widget);
    if (element == CE_MenuEmptyArea)
        return;

    const auto item = qstyleoption_cast<const QStyleOptionMenuItem*>(option);
    if (!item)
        return;

    const MenuColors c = colors();
    const QRect r = item->rect;

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing);

    if (item->menuItemType == QStyleOptionMenuItem::Separator)
    {
        // dividers span the whole panel, padding included
        painter->fillRect(QRect(r.left() - kPadding, r.top(), r.width() + 2 * kPadding, 1), c.divider);
        painter->restore();
        return;
    }

    const bool enabled = item->state & State_Enabled;
    const bool hovered = enabled && (item->state & State_Selected);
    const bool exclusiveChecked = item->checked && item->checkType == QStyleOptionMenuItem::Exclusive;
    if (hovered || exclusiveChecked)
    {
        painter->setPen(Qt::NoPen);
        painter->setBrush(c.hover);
        painter->drawRoundedRect(r, kRowRadius, kRowRadius);
    }

    if (!item->icon.isNull())
    {
        const QRect iconRect(r.left() + kIconLeft, r.top() + (r.height() - kIconSize) / 2, kIconSize, kIconSize);
        item->icon.paint(painter, iconRect, Qt::AlignCenter, enabled ? QIcon::Normal : QIcon::Disabled);
    }

    QString text = item->text;
    QString shortcut;
    if (const int tab = text.indexOf('\t'); tab >= 0)
    {
        shortcut = text.mid(tab + 1);
        text = text.left(tab);
    }

    const bool hasMark = item->menuItemType == QStyleOptionMenuItem::SubMenu || item->checked;
    const int right = r.right() - kRightPadding - (hasMark ? kArrowSpace : 0);

    painter->setFont(menuFont(item->font));
    painter->setPen(enabled ? c.text : c.disabled);
    const int textLeft = item->maxIconWidth > 0 ? kTextLeft : kTextLeftNoIcon;
    const QRect textRect(r.left() + textLeft, r.top(), right - r.left() - textLeft, r.height());
    painter->drawText(textRect, Qt::AlignVCenter | Qt::AlignLeft | Qt::TextShowMnemonic | Qt::TextHideMnemonic,
                      text);
    if (!shortcut.isEmpty())
    {
        painter->setPen(enabled ? c.shortcut : c.disabled);
        painter->drawText(textRect, Qt::AlignVCenter | Qt::AlignRight, shortcut);
    }

    QPen pen(enabled ? c.text : c.disabled, 1.5, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin);
    const qreal cy = r.center().y() + 0.5;
    if (item->menuItemType == QStyleOptionMenuItem::SubMenu)
    {
        // chevron: 5x10, 23px from the right edge of the panel
        const qreal x = r.right() + 1 - 19 - 5;
        QPainterPath path;
        path.moveTo(x, cy - 5);
        path.lineTo(x + 5, cy);
        path.lineTo(x, cy + 5);
        painter->setPen(pen);
        painter->setBrush(Qt::NoBrush);
        painter->drawPath(path);
    }
    else if (item->checked)
    {
        // check mark: 14x11, accent color, 19px from the right edge
        const qreal x = r.right() + 1 - 19 - 14;
        QPainterPath path;
        path.moveTo(x, cy);
        path.lineTo(x + 4.667, cy + 5.5);
        path.lineTo(x + 14, cy - 5.5);
        pen.setColor(enabled ? c.mark : c.disabled);
        painter->setPen(pen);
        painter->setBrush(Qt::NoBrush);
        painter->drawPath(path);
    }
    painter->restore();
}
