# Music UI source provenance

The payload preserves the existing user's Lumina Music QML sources supplied in
`multi-rice-music-sources.zip` on 2026-10-04:

- Overlay: `dotfiles/shared/lumina-music/quickshell/lumina-music`.
- Native Cipher: `.local/share/desktop-profiles/clavis/native/buttons/lumina-music`.

The three player theme files are unchanged. Each shell gains a small
`Quickshell.Io.IpcHandler` which shows the existing player on repeated requests.
No music files, playlist metadata, lyrics cache or playback backend are bundled.
Source hashes for the installer payload are in `payload-manifest.json`.
This notice records source provenance; it does not assign a new license to
third-party assets or music.
