# Changelog

All notable changes of VLC Gold. Versions use the tag scheme
`redesign-vX.Y.Z`, so they cannot clash with VLC's own tags.

## redesign-v0.3.0 (beta)

### Changed
- Renamed to **VLC Gold**, version 0.3.0: window titles, About, tray, installer, Linux app
  entry and `vlc --version`. VLC's own version (4.0.0-dev) stays for libVLC and plugins
- Windows packages are named `vlc-gold-<version>-win64.zip` / `.7z` / `.exe`, the Linux
  AppImage `VLC_Gold-<version>-x86_64.AppImage`; the repository is now `oliver-bacon/vlc-gold`
- The folder inside the Windows zip / 7z is `vlc-gold-<version>`, and the installer shows
  the VLC Gold version
- README: shorter feature list, beta note, no known issues section
- Linux build instructions moved from the README to `docs/building-linux.md`, with an
  optional install to `/opt/vlc-gold` (`vlc-gold` command, app menu entry, update and
  uninstall steps)

- Yes/no questions use the redesign's dialog: centered, no title bar, outlined frame,
  buttons under the text that light up on hover
- The redesign's cone is the app icon, and a cone shows instead of the music
  placeholder while a video starts
- Playback settings and the queue open as a card on the right side of the player, 20 px
  from the video frame
- The on-screen message shows the pressed key under it

### Removed
- Update check (it compared against VLC releases from VideoLAN)

### Added
- Linux AppImage build script (`extras/package/appimage/build.sh`, Ubuntu 22.04 in Docker)
- README: how to download and run the Linux AppImage
- Delete File From System in the file menu of library folders

### Fixed
- Linux install from source: a launcher script finds VLC's libraries instead of a
  system-wide `ld.so.conf.d` entry, which made the distribution's VLC 3 load the redesign's
  `libvlccore.so.9`
- Submenus open right next to the menu instead of 28 px away
- Videos: subfolder pages keep their folder, and the parent folders in the breadcrumbs
  can be clicked
- HDR videos are tone mapped on SDR screens (Windows, Direct3D 11)

## redesign-v0.2.6 (beta)

### Added
- Linux AppImage (`VLC_Redesign-0.2.6-x86_64.AppImage`), added to the release on 19 Oct;
  same code as the Windows build

### Fixed
- Quitting no longer crashes at exit: medialibrary kept a logger from a plugin that VLC
  had already unloaded (patch in `contrib/src/medialibrary`)

### Changed
- Linux build instructions in the README: Arch Linux packages, dependencies on other
  distributions, Qt 6.8 or newer, meson 1.10, building medialibrary, running without installing

## redesign-v0.2.5 (beta)

### Changed
- Bug reports use a GitHub issue form with fields for the build, package and system

### Fixed
- The chosen accent colour replaces the orange everywhere: the cone logo, the selected
  icons in the library side panel, the player's popovers, side panel and subtitle
  timeline, the dialogs and the equalizer
- Fullscreen always has a way out: F11 and Esc leave it (also the video's fullscreen), and
  the window buttons stay in fullscreen with "exit fullscreen" instead of maximize
- The track, playback settings and queue popovers keep a gap above the player bar
- "Show Preferences" in the track popover opens the settings page of its tab (Video, Audio,
  Subtitles)
- The settings' info tool tips open above the info icon instead of over it
- The queue's sort button shows its icon instead of a magenta square

## redesign-v0.2.0 (beta)

### Added
- Customize Player edits the player bars in place: the top bar and the control bar
  become drop zones, a panel over the video holds the controls not in use, and a
  Video / Music switch chooses which player bar is edited
- Settings window: equalizer with preamp and 10 bands, audio effects applied live,
  spatial audio mode
- Favorite button for every media (also files outside the library)
- Library: back and forward buttons in the page headers (and the mouse's forward
  button), resizable side panel, "Remove from Home" in the Home context menus
- Music covers on Home taken from the player's artwork (embedded pictures, cover files)
- Rounded frame around the video, cut out together with the bars
- Thumbnails for the videos in the folder views

### Changed
- Settings profiles also keep the interface settings: player bars, theme, view
  options, subtitle presets. Window position, library pins and hidden Home items stay
  the same in every profile
- The accent colour changes at once, without restarting VLC
- The player follows the light theme also while a video plays
- Player corner with VLC's own title bar: minimize, maximize, close; fullscreen is on
  the control bar
- Settings window has a title bar like the player's
- The track popover of audio files shows only the output devices
- The seek preview card has the video's aspect ratio
- A visualization stays on only for the media it was turned on for
- The media library can remove a media from the playback history (used by "Remove from Home")

### Fixed
- A minimized settings window comes back when the settings are opened again

## redesign-v0.1.0 (pre-release)

First public pre-release, based on VLC master `1176b56` (4.0 development version).

### Added
- Theme, accent colour, icon set and two-tone menu icons from the "VLC Redesign" design
- One-row player bar, cone-shaped volume, player top bar with library and folder buttons
- Audio / subtitle track popover; Queue / Bookmarks / Chapters popover
- Playback settings panel: playback, video and audio effects, equalizer presets with
  icons, subtitle appearance with size values and presets
- Seek preview thumbnails, subtitle timeline, waveform seek bar for audio files
- Library: side navigation and rail, Home rows, Videos by folder with previews, Music
  sections, Network (podcasts, radio, saved streams), context menus, compact library
  in the player, mini player card with the queue
- Settings window with profiles; Network Stream, New Playlist, Playlist Properties,
  Keyboard Shortcuts, Add Subtitles and Customize Player dialogs; onboarding
- "Continue watching" prompt and error messages in the redesign style

### Changed
- Default hotkeys: Record is `R`, Random has no default key, Hide UI is `Ctrl+\`
- The media library loads subtitle and audio files saved for a media as extra tracks

### Fixed
- Windows: VLC kept running after closing (libupnp built with MinGW looped forever in
  `strncasecmp`), and the UPnP plugin no longer ends libupnp while holding a lock
- The media library no longer ends VLC when a saved subtitle or audio track cannot be read
