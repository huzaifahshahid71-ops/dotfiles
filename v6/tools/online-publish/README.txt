Sumi v6.0.0: publish the VM-tested fast online installer

Run on the HOST, as gamer, using the retained build/test directories:

  unzip -o ~/Downloads/sumi-v6-online-publish-v1.zip -d ~/Downloads
  python3 ~/Downloads/sumi-v6-online-publish-v1/publish.py

GitHub CLI must already be signed in as huzaifahshahid71-ops.
No VM bridge or new AppImage build is needed.

The publisher checks the accepted GUI against its recorded runtime hashes,
checks the existing twelve public release assets, and adds five new online-r1
assets. Existing assets are retained. Verified partial uploads are reused.
The source update goes only to v6.0-tahoe-dev, using a non-forced update.
Release instructions are added only after all new asset hashes are verified.

Wait for UPDATED ONLINE INSTALLER. Then run this single command in a graphical
terminal on the machine where you want to install (for example, inside the VM):

  curl -fsSL https://github.com/huzaifahshahid71-ops/dotfiles/releases/download/v6.0.0/ONLINE-INSTALL-v6.sh | bash

Run without sudo. The launcher downloads and verifies the small online GUI and
the public payload manifest, then opens setup. Choose the full collection for
631 wallpapers; it downloads the three ZIP packs in parallel and verifies the
images locally. Setup still asks for installation choices and authentication.
The online GUI uses the existing verified v6.0.0 AppImage payload.

The original offline AppImage contains its original GUI. This publication adds
the tested fast online GUI separately; the one-command launcher selects it.

If publication stops, rerun the same command to resume. Changed existing assets
are preserved and cause a stop. Diagnostic report:
  ~/Downloads/sumi-v6-online-publication-report.zip

Checks:
  python3 ~/Downloads/sumi-v6-online-publish-v1/test_publish.py
