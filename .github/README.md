# VLC Redesign (Qt interface)

An unofficial implementation of the community "VLC Redesign" in VLC 4.0's Qt/QML
interface. It is not affiliated with or endorsed by VideoLAN.

- Design: "VLC Redesign" by **Juxtopposed** (https://www.juxtopposed.com/):
  the [Figma Community file](https://www.figma.com/community/file/1691465999134370980/vlc-redesign)
  and the [video](https://www.youtube.com/watch?v=ERFeOgqk324).
  The design is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/);
  this repository adapts it to VLC's Qt interface, with changes. All credit for
  the design goes to Juxtopposed; any mistakes in this implementation are ours.
- Code: GPLv2 or later, like the rest of VLC's Qt interface (see `COPYING`).
- Base: VLC master `1176b56`. All changes are in `modules/gui/qt`, plus two small
  hooks in `modules/misc/medialibrary/entities.cpp` and `src/libvlc-module.c`.

## What it changes

- Theme, palette and icon set from the design; top bars and a slimmer player bar
- Player bar: play controls on the left, a thick seek bar, the cone-shaped volume,
  then Audio, Subtitles, Playback settings and Queue
- Audio / subtitle track popover; Queue / Bookmarks / Chapters popover
- Playback settings side panel with Playback, Video, Audio and Subtitles tabs
  (effects, presets, sleep timer, reverse)
- Seek preview thumbnails and a subtitle timeline on the seek bar with delay and
  zoom buttons
- Compact library inside the player, opened from the folder name in the top bar
- Library: side navigation (Home, Videos, Music, Network, Playlists, Recent, pins),
  Home rows (Continue Watching, Listen Again, Frequently Visited Folders), videos
  grouped by folder, a video card with the play queue
- Restyled menus, dialogs, settings window with profiles, keyboard shortcuts,
  Customize Player and onboarding

Existing users keep their saved player bar layout: use
Customize Player › Restore Default to get the new one.

## Building

Windows (x86_64), from the repository root:

```
docker run --rm -it --user root -v "$PWD":/vlc -w /vlc \
  registry.videolan.org/vlc-debian-win64-posix:20260611225331 \
  bash -c 'git config --global --add safe.directory /vlc && extras/package/win32/build.sh -a x86_64 -p -r -i r'
```

The result is `win64/vlc-4.0.0-dev/vlc.exe`.

Linux: a normal meson build with Qt 6.8 and medialibrary enabled
(`meson setup build -Dqt=enabled -Dmedialibrary=enabled`, then `ninja -C build`).

## Status

Work in progress. Tested mostly on Linux (Qt 6.8.3); several parts have not been
tested on Windows yet. Known gaps: no OpenSubtitles search, no waveform seek bar,
no breadcrumb / nested folders in Videos yet.

Known upstream issue: closing VLC on Windows can hang in UPnP discovery; deleting
`plugins\services_discovery\libupnp_plugin.dll` works around it.
