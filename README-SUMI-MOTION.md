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
The image objects stay alive for the session.
Decoded previews use 880 × 480 rather than 1320 × 720, reducing their pixel memory
by about 56% while leaving the original screenshot files untouched.
Missing or unreadable images finish warmup and use the existing icon fallback.
There may be a brief loading message on a cold launch. Warmup waits for decoding and then three
rendered frames per profile, plus three frames to restore the active selection.
The live no-layer test did not improve the startup hitch, so card layers remain.
This corrects a reproduced preload bug; laptop GPU performance still needs validation.

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

## Temporary same-process reopen test

The normal launcher still starts a new deck process for each opening. Silent mode
can therefore repeat the first-use cost. This diagnostic prepares a temporary
copy of the installed v3 deck: Escape hides it, while an IPC call reopens the same
QML instance and retains its decoded image objects. GPU resource retention when
hiding a window is platform-dependent; this is a live experiment, not a guaranteed fix.
No installed QML, shortcuts, theme setting, services, or rice files are edited.

Close the normal switcher, stay in Silent mode, then run:

```fish
curl -fL https://raw.githubusercontent.com/huzaifahshahid71-ops/dotfiles/v6.0-tahoe-dev/v6/tools/test-sumi-resident.py -o /tmp/test-sumi-resident.py
python /tmp/test-sumi-resident.py
quickshell -p /tmp/huzaifah-sumi-resident-test.qml > /tmp/huzaifah-sumi-resident-test.log 2>&1 &
```

Scroll until smooth, press Escape, then reopen using this command:

```fish
quickshell ipc --path /tmp/huzaifah-sumi-resident-test.qml call huzaifahSumiTest reopenDeck
```

Compare the first scroll after each reopening. For this experiment use the IPC
command to reopen, since Super+Shift+D still uses the installed launcher.
Finish by stopping only the temporary instance:

```fish
quickshell ipc --path /tmp/huzaifah-sumi-resident-test.qml call huzaifahSumiTest quit
```

Headless Qt checks verify repeated hide/show retains the same QML instance and
warmed image state. Wayland, IPC transport, keyboard focus and Silent-mode frame
pacing require the laptop test.
