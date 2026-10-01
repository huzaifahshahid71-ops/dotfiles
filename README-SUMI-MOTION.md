# Sumi Deck launch and scrolling update

The classic switcher now waits for the saved theme before mapping its window.
Selecting Sumi Deck therefore launches the carousel without a purple window flash.
Original, Midnight Cyan, and the forced THEMES picker retain their existing UI.

The carousel wraps in both directions, including its mouse wheel and arrow/Tab navigation.
The neighboring cards use their shortest distance around the circular catalog;
the darkest far card is recycled without sweeping across the focused card.
Names, ACTIVE badges, geometry, colors, switching commands, and the installed catalog
remain unchanged.

Before revealing the carousel, its screenshots are decoded asynchronously and
primed in the scene graph. The image objects stay alive for the session.
Decoded previews use 880 × 480 rather than 1320 × 720, reducing their pixel memory
by about 56% while leaving the original screenshot files untouched.
Missing or unreadable images finish warmup and use the existing icon fallback.
There may be a brief loading message on a cold launch.

## Install

Close the switcher and run in Fish as your normal user:

```fish
curl -fL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/v6.0-tahoe-dev/v6/tools/install-switcher-themes.sh -o /tmp/huzaifah-switcher-themes.sh
bash /tmp/huzaifah-switcher-themes.sh --install
```

At the existing installer prompt, type `INSTALL SWITCHER THEMES`.
Then reopen the switcher with Super+Shift+D.
The installer backs up the classic QML, backend, and locally installed Sumi QML.
It preserves the theme preference and all screenshot files.
No rice configs, compositor processes, keybinds, or services are changed.
Upstream QML is fetched at the existing pinned revision and patched locally.

## Roll back

```fish
bash /tmp/huzaifah-switcher-themes.sh --rollback
```

At the prompt, type `ROLLBACK SWITCHER THEMES`. Close and reopen the switcher.

## Validation

The generated QML is parsed with qmlformat. Headless Qt runtime checks exercise
the actual UI and artwork while replacing external Quickshell process/window
plumbing. They verify classic-window visibility before and after theme resolution,
the THEMES escape hatch, both wrap directions, odd/even dynamic catalogs,
preview warmup, missing-image fallback, and unchanged profile-switch commands.
Wayland rendering and first-scroll frame pacing still require a live laptop check.

Test launch repeatedly, then scroll immediately in both directions across the
first/last cards. If there is still a pause, inspect:

```fish
tail -n 80 ~/.local/state/huzaifah-switcher/sumi-deck.log
```

Per-rice Super+Shift+D bindings are a separate live diagnostic; this update does
not replace or rewrite them.
