# Sumi Deck launch and scrolling update

The classic switcher now waits for the saved theme before mapping its window.
Selecting Sumi Deck therefore launches the carousel without a purple window flash.
Original, Midnight Cyan, and the forced THEMES picker retain their existing UI.

The carousel wraps in both directions, including its mouse wheel and arrow/Tab navigation.
A continuous position drives the whole fan. A fixed pool of cards recycles beyond
the fading visible edges, keeping each card's identity while crossing the center.
High-resolution wheel deltas accumulate into full steps rather than treating
every tiny input event as a whole profile change.
The heading is now Japanese: フザイファ · 墨デッキ (Huzaifah · Sumi Deck),
using Noto Sans CJK JP with system font fallback. Profile names, ACTIVE badges,
geometry, colors, switching commands, and the installed catalog remain unchanged.

Before revealing the carousel, its screenshots are decoded asynchronously using
the same PreserveAspectCrop setting and source size as the actual cards. Qt includes
the crop option in its pixmap cache key; the previous default Stretch preload
created a second cache entry for every screenshot instead of keeping the card
entry resident. Warmup now also checks the actual pooled card images after each
selection and when restoring the active profile. Only settled images (Ready,
Error, or empty source) let the focused scene finish its warmup.
The actual card scene is rendered in every focused profile state at negligible
opacity. This exercises focused text, borders, card layers, and image textures.
Card contents are cached in Qt layers; their movement uses a single animation.
The image objects stay alive between ordinary openings of the deck. Escape and
backdrop clicks hide the window; the normal launcher uses IPC to reopen it. The
hidden window has no ongoing warmup animation once ready.
Decoded previews use 880 × 480 rather than 1320 × 720, reducing their pixel memory
by about 56% while leaving the original screenshot files untouched.
Missing or unreadable images finish warmup and use the existing icon fallback.
There may be a brief loading message on a cold launch. Warmup waits for decoding and then three
rendered frames per profile, plus three frames to restore the active selection.
The live no-layer test did not improve the startup hitch, so card layers remain.
The user also confirmed that reopening a temporary same-process deck removes
the repeated Silent-mode initial scroll hitch. Normal launches now use that reuse
path. The first cold opening after login, a profile switch, or leaving for THEMES
can still incur initialization cost. Reuse retains the decoded preview memory
while hidden; it does not change the selected power profile.

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
No rice configs, compositor processes, keybinds, or services are changed. The
installer stops only an existing Sumi resident instance before install or rollback
to avoid hot-reloading a hidden deck into view.
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
Production tests verify retained warm state on ordinary reopenings, refreshed
ACTIVE state, immediate selection restore, fresh warmup when catalog IDs/order
change, and exit after handing off a profile switch. The actual launcher shell
is tested for IPC reuse, absent-instance startup, path quoting, and missing files.
The normal shortcut route still requires the live laptop check.
An isolated Qt cache test reproduces two entries with mismatched crop modes and
one shared entry with matching modes. A delayed-card test verifies the deck cannot
reveal while its card-image barrier is pending, and restores selection after it clears.

Test launch repeatedly, then scroll immediately in both directions across the
first/last cards. If there is still a pause, inspect:

```fish
tail -n 80 ~/.local/state/huzaifah-switcher/sumi-deck.log
```

Per-rice Super+Shift+D bindings are a separate live diagnostic; this update does
not replace or rewrite them.

## Resident lifecycle

The normal launcher first calls `huzaifahSumiDeck reopenDeck` on the installed
file. If no handler exists, it starts Quickshell with `--no-duplicate`.
On reopening a hidden deck, the backend catalog and colors refresh before the
window maps. The active profile is restored without animating from an old selection.
Matching catalog IDs/order reuse the warm state; changed catalogs warm again.

Selecting a profile preserves the existing detached `multi-rice-control switch`
command and exits the deck process. Opening THEMES also exits the deck process.
This avoids keeping old desktop or theme state resident across those handoffs.

To stop only the resident deck manually:

```fish
quickshell ipc --path ~/.local/share/desktop-switcher/themes/sumi-deck/DotsBrowser.qml call huzaifahSumiDeck shutdownDeck
```

The earlier `/tmp` diagnostic used `huzaifahSumiTest reopenDeck`. Stop any remaining
instance of that test before installing this update:

```fish
quickshell ipc --path /tmp/huzaifah-sumi-resident-test.qml call huzaifahSumiTest quit
```
