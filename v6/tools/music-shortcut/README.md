# Shared Lumina Music shortcut

Target: Super+Shift+M opens the same installed Lumina Music player in all twelve
profiles. Preserve the current theme, playlist/settings and Cipher's private
decoration/Genie route. Resolve conflicts in the effective binding sources,
not just an unused copy of a profile config.

The repository's base profile catalog still has ten entries. Tsugumori,
Eclipse and the installed music launcher must be collected from the host before
creating the final twelve-profile release payload.

`collect.py` is a read-only desktop-user source collector. It gathers profile
Lua/KDL/conf files, selected session/music launchers and music QML/JS sources
into `~/Downloads/multi-rice-music-sources.zip`. It does not collect playlists,
user JSON settings, caches, journals, process environment or window titles.
Paths outside the desktop user's home and backup files are excluded. The report
records present profiles, symlink aliases and source hashes. It never executes
collected launchers or restarts a session. Existing output files are preserved;
use `--output` to choose a different filename when repeating a collection.

Run without sudo, then attach the resulting ZIP for integration:

```sh
python3 collect.py
```

The binding patch, live twelve-profile verification and new v6 installer/build
are still pending. This collector does not install the shortcut or publish a
release.
