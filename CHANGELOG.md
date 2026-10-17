# Changelog

All notable changes of the VLC Redesign (unofficial). Versions use the tag scheme
`redesign-vX.Y.Z`, so they cannot clash with VLC's own tags.

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
