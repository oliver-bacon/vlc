# VLC Redesign (unofficial)

A new interface for VLC media player 4.0, built on VLC's own Qt/QML interface and
following the community design "VLC Redesign" by Juxtopposed.

[![License: GPL-2.0-or-later](https://img.shields.io/badge/license-GPL--2.0--or--later-blue)](COPYING)
[![Design: CC BY 4.0](https://img.shields.io/badge/design-CC%20BY%204.0-lightgrey)](https://creativecommons.org/licenses/by/4.0/)
[![Platform: Windows](https://img.shields.io/badge/platform-Windows%2010%2F11%20x64-0078D6)](#download-and-install)

> [!IMPORTANT]
> This is an **unofficial fan project**. It is not made, affiliated with, or endorsed
> by VideoLAN. "VLC", "VLC media player" and the cone logo are trademarks of
> VideoLAN. This is a modified version of VLC, redistributed under the GNU GPL like
> VLC itself; the original software comes from
> [videolan.org](https://www.videolan.org/) and
> [code.videolan.org/videolan/vlc](https://code.videolan.org/videolan/vlc).
> Please do not report problems with this build to VideoLAN.

It is based on VLC master (4.0 development version, commit `1176b56`). The work is in
the Qt interface (`modules/gui/qt`), plus a few small changes elsewhere listed in
[CHANGELOG.md](CHANGELOG.md). The original VLC README is in
[README.upstream.md](README.upstream.md).

## Screenshots

![Player](docs/screenshots/player.png)

| Library home | Seek bar preview |
|---|---|
| ![Library home with Continue Watching and the mini player](docs/screenshots/library-home.png) | ![Preview thumbnail while hovering the seek bar](docs/screenshots/seek-preview.png) |

## Features

What is in the code today.

**Look and feel**
- Colours, accent (#D37918, user-selectable), icon set and two-tone menu icons from the design
- Restyled menus, dialogs and top bars; new placeholder pictures for media without artwork
- Onboarding on first start: media folder, theme and accent colour, basic shortcuts

**Player**
- One-row player bar: playback controls on the left, a thick seek bar in the middle
- On the right: Favorite, the cone-shaped volume, fullscreen, Audio, Subtitles, Playback
  settings and Queue
- Rounded frame around the video
- Top bar with the media title, the folder name (opens the library at that folder) and a
  library button; with VLC's own title bar: minimize, maximize, close
- Favorite button for every media, also for files outside the library
- Audio / subtitle track popover; Queue / Bookmarks / Chapters popover with sort,
  repeat, shuffle, add and remove
- "Continue watching" prompt with the time already watched; error messages in the same style
- Right-click menu reorganized like the design, with "Hide UI"
- Default hotkeys changed: Record is `R` (Random has no key), Hide UI is `Ctrl+\`

**Seek bar**
- Preview thumbnails while hovering (local video files)
- Subtitle timeline on the seek bar with delay and zoom buttons (external .srt, .vtt,
  .ass, .ssa files; turned on in the Playback tab)
- Waveform for local audio files

**Playback settings panel** (gear button)
- Playback, Video, Audio and Subtitles tabs: speed, reverse, sleep timer; video effects
  (essential, crop, colours); equalizer with preset icons, compressor, spatializer,
  stereo widener; audio and subtitle delays
- Subtitle appearance: font, colours, offset, size as named steps or as a percentage,
  outline thickness, background opacity, and saved subtitle presets
- "Open Advanced Settings" opens the matching page of the settings window

**Library**
- Side navigation: Home, Videos, Music, Network, Playlists, Recent, pins and "Add item";
  icon-only rail with side panels on narrow windows; back and forward in the page headers
- Home: Continue Watching, Listen Again, Frequently Visited Folders; "Remove from Home"
  in the context menu; music covers from the files' artwork
- Videos browsed by library folder with previews of what is inside; Music with Songs,
  Albums, Artists and Genres
- Network: Add Network Stream, Podcasts, Radio (bundled country flags), saved streams
- Folder and file context menus (play, queue, stream, convert, subtitle and audio tracks,
  resync, show in folder, pin, remove from library)
- Compact library panel inside the player (resizable); mini player card with the play queue

**Dialogs and settings**
- New settings window (App / Media / System, search, advanced options), backed by VLC's
  own options; equalizer with 10 bands and audio effects applied while playing
- Settings profiles (Movies, Shows, Music, Work, …): each keeps all settings, including
  the player bars, theme and subtitle presets
- Theme and accent colour change at once, also over a playing video
- Open Network Stream, New Playlist (with picture), Playlist Properties, Keyboard Shortcuts
- Add Subtitles / Add Audio Tracks: to this file, folder or playlist; from the computer
  or from a link. Tracks are saved in the media library and loaded every time
- Customize Player edits the bars in place, for the video and the music player, with new
  bar items (Favorite, PiP, ±15 s, Chapters, Bookmark, Zoom, …)

## Download and install

### Windows (10 or 11, 64-bit)

Download from the [Releases](https://github.com/oliver-bacon/vlc/releases) page. You can
check a download against `SHA256SUMS.txt` from the same release:
`certutil -hashfile <file> SHA256`.

**Portable (recommended):** `vlc-4.0.0-dev-win64.zip` or `.7z`. Extract it anywhere and run
`vlc.exe`. Nothing is installed.

**Installer:** `vlc-4.0.0-dev-win64.exe`. This is VLC's own installer, unchanged: it calls
itself "VLC media player" and installs into the same folder as official VLC
(`C:\Program Files\VideoLAN\VLC`), **replacing an installed VLC** and its file
associations. Use it only if you do not need official VLC on the same PC; reinstall
official VLC from [videolan.org](https://www.videolan.org/) to go back.

Notes:
- The build is not code-signed, so Windows SmartScreen may warn before the first start.
- It uses the same settings folder as an installed VLC (`%APPDATA%\vlc`). If you also use
  official VLC 4 builds, back that folder up first.
- If you used an earlier build: open **Customize Player** and click **Restore Default**
  to get the new player bar.

### Linux

No Linux packages. Linux: build from source (experimental), see below.

## Known issues

- **Testing:** tested by the author only; no independent tester yet.
- **Light theme:** not reviewed screen by screen.
- **Accent colour:** the library side panel and the cone logo keep the default orange.
- **Subtitle timeline:** works with external .srt / .vtt / .ass / .ssa files; embedded
  subtitle tracks get no timeline.
- **Not implemented:** subtitles from OpenSubtitles (shown but disabled); the key that was
  pressed in on-screen messages; picture-in-picture outside the main window; moving the
  seek bar in Customize Player.
- **UPnP shutdown hang on Windows:** VLC's UPnP plugin could keep `vlc.exe` running after
  closing, and the next start had no media library. This build includes a fix (libupnp
  miscompiled with MinGW). If it still happens: end `vlc.exe` in Task Manager and delete
  `plugins\services_discovery\libupnp_plugin.dll` (you lose UPnP discovery).
- **Linux (built from source):** quitting can crash on exit; unmodified upstream VLC does the same
  with Qt 6.8.3.

Please report problems in the [issue tracker](https://github.com/oliver-bacon/vlc/issues) of this repository.

## Building from source

### Windows (Docker, recommended)

From the repository root, with Docker (on Linux or in WSL):

```sh
docker run --rm -it --user root -v "$PWD":/vlc -w /vlc \
  registry.videolan.org/vlc-debian-win64-posix:20260611225331 \
  bash -c 'git config --global --add safe.directory /vlc && extras/package/win32/build.sh -a x86_64 -p -r -i r'
```

This uses VideoLAN's own build image. The first run takes long because it also builds
VLC's dependencies. Output: `win64/vlc-4.0.0-dev/vlc.exe` and the packages
`win64/vlc-4.0.0-dev-win64.zip` / `.7z` / `.exe`; debug symbols in
`win64/symbols-4.0.0-dev/`.

### Linux (experimental)

Known to build on Ubuntu with Qt 6.8.3 (installed with
[aqtinstall](https://github.com/miurahr/aqtinstall)) and libmedialibrary 0.13:

```sh
aqt install-qt linux desktop 6.8.3 linux_gcc_64 -O ~/Qt -m qtshadertools
PATH=~/Qt/6.8.3/gcc_64/bin:$PATH PKG_CONFIG_PATH=~/Qt/6.8.3/gcc_64/lib/pkgconfig \
  meson setup build-linux -Dmedialibrary=enabled -Dqt=enabled -Dlua=disabled
ninja -C build-linux
./build-linux/bin/vlc-static -I qt
```

Running from the build folder may need `VLC_LIB_PATH=build-linux/modules` so that
helpers such as the preparser are found.

You need VLC's usual build dependencies (meson, ninja, ffmpeg, libmedialibrary, X11/xcb,
freetype, libass, …). See [README.upstream.md](README.upstream.md) and VLC's
documentation for the full list.

## Credits and attribution

**Design:** ["VLC Redesign"](https://www.figma.com/community/file/1691465999134370980/vlc-redesign)
by [Juxtopposed](https://www.juxtopposed.com/), licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). See also the designer's
[redesign video](https://www.youtube.com/watch?v=ERFeOgqk324).

**Changes were made:** this repository is an independent implementation of that design
in VLC's Qt/QML interface. Some parts differ from the design, and some are not
implemented yet. Icons and pictures from the Figma file were used, converted or adapted
(see [CREDITS.md](CREDITS.md)). Juxtopposed is not involved in this project and has not
endorsed it.

**VLC:** the [VideoLAN team and VLC contributors](THANKS), who make VLC and its Qt interface.

**Redesign implementation:** Oliver Bacon ([@oliver-bacon](https://github.com/oliver-bacon)).

**Third-party assets:** country flags from [flag-icons](https://github.com/lipis/flag-icons)
(MIT). Details in [CREDITS.md](CREDITS.md).

## License

- **VLC**, including the Qt interface and this project's code changes, is under the
  [GNU GPL, version 2 or later](COPYING). **libVLC** (the engine in `src/` and `lib/`)
  is under the [GNU LGPL, version 2.1 or later](COPYING.LIB). The Windows builds contain
  GPL modules, so the program as a whole is distributed under the GPL.
- **The design** (and the icons and pictures taken from the Figma file, see
  [CREDITS.md](CREDITS.md)) is by Juxtopposed and licensed under
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), not the GPL.
- Country flags: MIT, see `modules/gui/qt/pixmaps/flags/LICENSE`.
