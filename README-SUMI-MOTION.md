# Sumi Deck launch and scrolling update

The classic switcher now waits for the saved theme before mapping its window.
Selecting Sumi Deck therefore launches the carousel without a purple window flash.
Original, Midnight Cyan, and the forced THEMES picker retain their existing UI.

The carousel wraps in both directions, including its mouse wheel and arrow/Tab navigation.
A continuous position drives the whole fan. A fixed pool of cards recycles beyond
the fading visible edges, keeping each card's identity while crossing the center.
High-resolution wheel deltas accumulate into full steps rather than treating
every tiny input event as a whole profile change.
Names, ACTIVE badges, geometry, colors, switching commands, and the installed catalog
remain unchanged.

Before revealing the carousel, its screenshots are decoded asynchronously, then
the actual card scene is rendered in every focused profile state at negligible
opacity. This exercises focused text, borders, card layers, and image textures.
Card contents are cached in Qt layers; their movement uses a single animation.
The image objects stay alive for the session.
Decoded previews use 880 × 480 rather than 1320 × 720, reducing their pixel memory
by about 56% while leaving the original screenshot files untouched.
Missing or unreadable images finish warmup and use the existing icon fallback.
There may be a brief loading message on a cold launch. Warmup adds roughly two
rendered frames per profile plus three frames to restore the active selection.

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
fractional wheel input, invisible slot recycling across many loops, full-card
warmup, missing-image fallback, and unchanged profile-switch commands.
Wayland rendering and first-scroll frame pacing still require a live laptop check.

Test launch repeatedly, then scroll immediately in both directions across the
first/last cards. If there is still a pause, inspect:

```fish
tail -n 80 ~/.local/state/huzaifah-switcher/sumi-deck.log
```

Per-rice Super+Shift+D bindings are a separate live diagnostic; this update does
not replace or rewrite them.
