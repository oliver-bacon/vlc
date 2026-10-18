# Changelog

All notable changes of the VLC Redesign (unofficial). Versions use the tag scheme
`redesign-vX.Y.Z`, so they cannot clash with VLC's own tags.

## redesign-v0.2.6 (beta)

### Fixed
- Quitting no longer crashes at exit: medialibrary kept a logger from a plugin that VLC
  had already unloaded (patch in `contrib/src/medialibrary`)

### Changed
- Linux build instructions in the README: Arch Linux packages, building medialibrary,
  running from the build folder

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
