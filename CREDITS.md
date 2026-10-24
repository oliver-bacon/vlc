# Credits

## Design: "VLC Redesign" by Juxtopposed (CC BY 4.0)

- Design: "VLC Redesign" by [Juxtopposed](https://www.juxtopposed.com/)
- Figma file: <https://www.figma.com/community/file/1691465999134370980/vlc-redesign>
- Video: <https://www.youtube.com/watch?v=ERFeOgqk324>
- License: [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/)

This project implements the design in VLC's Qt/QML interface. Changes were made: the
layout was adapted to VLC's existing interface and features, some parts differ from the
design, and some are not implemented. Juxtopposed is not involved in this project and
has not endorsed it.

### Use of the Figma file

The Figma project was used for this implementation: its icons, menu icons, equalizer
icons, sidebar icons, volume cone, onboarding tile and placeholder pictures were taken
from the file (exported, converted to the formats VLC needs, or redrawn from it), and its
colours, sizes and layouts were followed in the QML code. These assets are licensed under
CC BY 4.0 by Juxtopposed, not under the GPL. They are in `modules/gui/qt/pixmaps/`
(mainly `icons/figma/`, `menu/figma/`, `misc/` and `placeholder/`) and in the icon font
`VLCIcons.ttf`. The app icon (`share/icons/*/vlc.png`, `vlc.xpm`, `vlc.ico` and
`share/vlc512x512.png`) is rendered from the Figma file's cone logo.

The VLC cone shown in the interface is a trademark of VideoLAN; `misc/cone_flat.svg` is
VLC's own `cone.svg` without the white stripes.

## Country flags: flag-icons (MIT)

`modules/gui/qt/pixmaps/flags/`: [flag-icons](https://github.com/lipis/flag-icons)
7.6.0 by Panayiotis Lipiridis and contributors, MIT license (see `pixmaps/flags/LICENSE`).
Used unchanged for the radio countries.

## VLC

VLC Gold is based on VLC media player. VLC is made by the VideoLAN team and many
contributors; see [AUTHORS](AUTHORS) and [THANKS](THANKS). "VLC", "VLC media player" and the cone logo are trademarks of
VideoLAN. This project is not affiliated with or endorsed by VideoLAN.

## VLC Gold

Oliver Bacon ([@oliver-bacon](https://github.com/oliver-bacon), commits as thespine1337).
