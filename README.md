i need all these bottom icons removed too and also after pressing the linux it takes me to systemd where as systemd shouldnt exist at all

The bottom 4 icons still exist

Lesgoo

Is this customizable? 

Pasted text(3).txt
Document

It hasbeen stuck at this screen since half an hr



It did something 

Done 

Music files show their icons but how do i play them

It still says no media here 

it looks horrible the mac os one is in the second image

how can this music windo not be here and the music just plays in the background and is controlled from above

i am changing from hybrid to integrated

Pasted text(4).txt
Document


Also i dont want this text to be displayed when booting into linux

now what is this cat and how do i get rid of it 

all done hell yeahh !!!!!!!!!! now the very last problem is that the wallpapers i add in the wallpapers folder do not show up

there should also be an option to edit the order 

The first photo is my apple music playlist and the second one is the songs on the laptop i want the playlist on the laptop in the same was as in apple music 

Yes — the Dolphin Music folder is only displaying files alphabetically. To preserve the exact Apple Music order, you need a playlist file such as:

~/Music/Favorites.m3u8

mpv will follow the entries in that playlist from top to bottom, and Caelestia will continue controlling mpv normally.

Because several filenames in the screenshot are shortened with ..., export the exact filenames first:

find "$HOME/Music" -maxdepth 1 -type f \
    \( -iname '*.mp3' -o -iname '*.flac' -o -iname '*.m4a' -o -iname '*.opus' -o -iname '*.wav' \) \
    -printf '%f\n' | sort > "$HOME/Music/song-files.txt"

Confirm it contains all 128 songs:

wc -l "$HOME/Music/song-files.txt"

Upload song-files.txt here. I’ll return a ready-to-use Favorites.m3u8 arranged in the exact order shown in your Apple Music screenshots.

Once created, start it with:

mpv --playlist="$HOME/Music/Favorites.m3u8"


song-files.txt
Document

it is playing in my preffered order but not in the music tab above but in a seperate player which i dont want

i want it to be in this menu in the place of the || icon

the service isnt even running now

both the fans should run even if the gpu is disabled 

For your dotfiles repo, create a fine-grained Personal Access Token. GitHub recommends fine-grained tokens over classic tokens when possible.

On GitHub:

    Click your profile picture → Settings

    Scroll down → Developer settings

    Personal access tokens → Fine-grained tokens

    Click Generate new token

    Set:

        Token name: CachyOS Git

        Expiration: e.g. 90 days, or whatever you prefer

        Resource owner: huzaifahshahid71-ops

        Repository access: Only select repositories

        Select your dotfiles repository

    Under Repository permissions, set:

        Contents → Read and write

    Click Generate token.

It will give you something beginning roughly like:

github_pat_...

Copy it immediately and never paste it here or put it in your dotfiles repository. Treat it like a password.

Then on CachyOS:

cd ~/dotfiles
git push -u origin main

When Git asks:

Username for 'https://github.com':

enter:

huzaifahshahid71-ops

When it asks:

Password for 'https://huzaifahshahid71-ops@github.com':

paste the token, not your GitHub password.

Nothing will appear on screen while you paste/type the token—that's normal.

One important thing: your earlier git commit still failed because Git didn't have an identity configured. Before pushing, make sure you've done:

git config --global user.name "Huzaifah Shahid"
git config --global user.email "YOUR_GITHUB_EMAIL"

cd ~/dotfiles
git add .
git commit -m "Initial CachyOS Hyprland dotfiles"
git branch -M main
git remote set-url origin https://github.com/huzaifahshahid71-ops/dotfiles.git
git push -u origin main

GitHub supports PATs as the password replacement for HTTPS command-line authentication.

Repository access

Repository access

Public repositoriesRead-only access to public repositories.

All repositoriesThis applies to all current and future repositories you own. Also includes public repositories (read-only).

Only select repositoriesSelect at least one repository. Max 50 repositories. Also includes public repositories (read-only).

Choose Only select repositories.

Then select:

dotfiles

That gives the token access only to your dotfiles repository, which is much safer than granting access to every repository.

Do not choose Public repositories, because that option is read-only and you won't be able to git push.

After selecting dotfiles, scroll down to Repository permissions and set:

Contents → Read and write

Everything else can usually stay at No access.

If dotfiles is not available in the list yet, create the dotfiles repository on GitHub first, then come back and generate the token.

generate me a readme for this repo 
huzaifahshahid71-ops/dotfiles


Also these are the files that it posted

Perfect — that screenshot helps. Your repo already has the right main folders for the setup:

    caelestia

    fish

    hypr

    mpv

    scripts

    systemd

    .gitignore

So I tailored the README to that exact structure, including your 125% scaling, 120/240 Hz switching, DIM Caelestia visualizer/lyrics, headless mpv music service, Favorites.m3u8, Night Light, and the hardware-specific warnings.

Put it in the root of your repo:

cp ~/Downloads/README.md ~/dotfiles/README.md

Or move it there from wherever your browser saved it.

Then upload it:

cd ~/dotfiles
git add README.md
git commit -m "Add README"
git push

One important note: your public repo currently exposes the configuration folders themselves, which is what we want for dotfiles. Before adding more files later, keep checking with:

git status
git diff --cached

so tokens, passwords, SSH keys, Wi-Fi credentials, or other private data never get committed. GitHub’s public search had not indexed your new repo yet, so I used the folder structure visible in your screenshot as the source of truth for this README.


README.md
CachyOS + Hyprland Dotfiles

My personal CachyOS / Hyprland desktop configuration, built around DIM Caelestia, with custom display scaling, automatic refresh-rate switching, background music, floating lyrics, a desktop audio visualizer, and other quality-of-life tweaks.

    [!WARNING]
    These dotfiles are tuned for my own laptop and display.
    Read the configuration before enabling the monitor, refresh-rate, ASUS, or systemd-related parts on another machine.

Features

    Hyprland with Lua configuration

    125% display scaling

    Automatic internal-display refresh-rate switching:

        ~120 Hz on battery

        240 Hz on AC power

    DIM Caelestia Shell

        desktop audio visualizer

        floating desktop lyrics

        weather in Celsius

        custom wallpaper directory

        Shimeji desktop pet disabled

    Fish shell

    Headless mpv background music

    Caelestia/MPRIS media controls

    Persistent custom .m3u8 playlist support

    Automatic music startup and playback resume

    User systemd services

    Custom helper scripts

    hyprsunset support for a Windows-style Night Light

    ASUS ROG utilities used separately through asusctl / ROG Control Center

Repository Structure

dotfiles/
├── caelestia/
│   └── .config/caelestia/
├── fish/
│   └── .config/fish/
├── hypr/
│   └── .config/hypr/
├── mpv/
│   └── .config/mpv/
├── scripts/
│   └── .local/bin/
├── systemd/
│   └── .config/systemd/user/
└── .gitignore

The folders are arranged in a GNU Stow-friendly layout.
Screenshots

Add screenshots of the desktop here:

![Desktop](assets/desktop.png)
![Caelestia](assets/caelestia.png)

Requirements

This setup is primarily intended for Arch Linux / CachyOS.

Core packages:

sudo pacman -S git stow hyprland fish mpv jq hyprsunset

For AUR packages, install an AUR helper such as paru, then:

paru -S dim-caelestia-shell-git

Depending on your existing CachyOS installation, you may already have many of the required Hyprland/Wayland packages.
Installation
1. Clone the repository

git clone https://github.com/huzaifahshahid71-ops/dotfiles.git ~/dotfiles
cd ~/dotfiles

2. Back up your current configuration

Do this before applying anything:

mkdir -p ~/dotfiles-backup

cp -a ~/.config/hypr ~/dotfiles-backup/ 2>/dev/null || true
cp -a ~/.config/caelestia ~/dotfiles-backup/ 2>/dev/null || true
cp -a ~/.config/fish ~/dotfiles-backup/ 2>/dev/null || true
cp -a ~/.config/mpv ~/dotfiles-backup/ 2>/dev/null || true
cp -a ~/.config/systemd/user ~/dotfiles-backup/systemd-user 2>/dev/null || true
cp -a ~/.local/bin ~/dotfiles-backup/local-bin 2>/dev/null || true

3. Apply with GNU Stow

From ~/dotfiles:

stow -t "$HOME" caelestia
stow -t "$HOME" fish
stow -t "$HOME" hypr
stow -t "$HOME" mpv
stow -t "$HOME" scripts
stow -t "$HOME" systemd

You do not have to use every package. Stow only the parts you want.

If Stow reports that files already exist, move or back them up first instead of forcing the operation blindly.
Configuration Notes
Hyprland Monitor Configuration

My internal display is named:

eDP-1

Check your monitor names with:

hyprctl monitors

If your display has a different name, update the relevant Hyprland files and scripts before using them.
125% scaling

My internal display uses:

scale = 1.25

Check the current scale with:

hyprctl monitors | grep -E 'Monitor|scale'

Automatic 120 / 240 Hz Switching

My laptop automatically changes refresh rate depending on charger state:
Power state	Refresh rate
Battery	~119.97 Hz
AC power	240 Hz

The custom battery mode currently uses this modeline:

modeline 1125.275 2560 2568 2600 2640 1600 3534 3542 3552 -hsync -vsync

    [!CAUTION]
    Do not copy this modeline blindly to another display.
    It was created specifically for my laptop panel.

The helper scripts are located under:

~/.local/bin/

The associated user service is:

auto-refresh-rate.service

Enable it with:

systemctl --user daemon-reload
systemctl --user enable --now auto-refresh-rate.service

Check the current refresh rate:

hyprctl monitors -j | jq -r '.[] | "\(.name): \(.refreshRate) Hz"'

DIM Caelestia

This setup uses the DIM fork of Caelestia:

paru -S dim-caelestia-shell-git

My configuration includes:

    desktop audio visualizer

    floating lyrics

    Celsius weather

    custom wallpaper directory

    Shimeji disabled

Wallpaper directory:

~/Pictures/Wallpapers

Create it if necessary:

mkdir -p ~/Pictures/Wallpapers

Background Music

Music is played by a headless mpv process controlled through Caelestia/MPRIS.

The service:

background-music.service

uses this playlist by default:

~/Music/Favorites.m3u8

Important

The actual music files and my personal playlist are not intended to be part of the dotfiles repo.

Create your own playlist, for example:

#EXTM3U
/home/YOUR_USER/Music/Song One.mp3
/home/YOUR_USER/Music/Song Two.mp3
/home/YOUR_USER/Music/Song Three.mp3

The line order is the playback order.

If you want a different playlist location, edit:

~/.local/bin/background-music

and change:

PLAYLIST="$MUSIC_DIR/Favorites.m3u8"

Enable the service:

systemctl --user daemon-reload
systemctl --user enable --now background-music.service

Check it:

systemctl --user status background-music.service

Restart after changing the playlist:

systemctl --user restart background-music.service

mpv

My mpv configuration keeps background audio playback invisible:

audio-display=no
force-window=no

Caelestia then acts as the visible media interface.
Night Light

I use hyprsunset as the Hyprland equivalent of Windows Night Light.

Enable its user service:

systemctl --user enable --now hyprsunset.service

Set a warm color temperature:

hyprctl hyprsunset temperature 4000

Disable the filter:

hyprctl hyprsunset identity

ASUS ROG Notes

My machine is an ASUS ROG laptop and I also use asusctl / ROG Control Center outside of these dotfiles.

ASUS-specific GPU modes, fan curves, power controls, and firmware behavior vary between models.

Do not assume my ASUS-related settings are appropriate for another laptop.
Useful Commands
Reload Hyprland

hyprctl reload

Check monitor scale and refresh rate

hyprctl monitors

Restart refresh-rate automation

systemctl --user restart auto-refresh-rate.service

Check background music

systemctl --user status background-music.service

Restart background music

systemctl --user restart background-music.service

Check which playlist mpv is using

ps aux | grep '[m]pv'

Updating the Dotfiles

After changing your configuration:

cd ~/dotfiles
git status
git add .
git commit -m "Update dotfiles"
git push

Always inspect what is about to be published:

git diff --cached

Security

Never commit:

    GitHub Personal Access Tokens

    passwords

    API keys

    SSH private keys

    Wi-Fi credentials

    browser profiles or cookies

    encryption / BitLocker recovery keys

    private certificates

    other personal secrets

If a secret is ever committed, removing it in a later commit is not enough. Revoke/rotate the secret and remove it from Git history.
Disclaimer

These are my personal dotfiles, not a universal installer.

Some settings—especially display modelines, monitor names, refresh rates, laptop hardware controls, absolute paths, and user services—must be adapted before using them on another system.

Feel free to fork the repo and customize it for your own setup.
License

You are welcome to use and modify these configs.

Consider adding an MIT License to make the reuse terms explicit.
README.md
CachyOS + Hyprland Dotfiles

My personal CachyOS / Hyprland desktop configuration, built around DIM Caelestia, with custom display scaling, automatic refresh-rate switching, background music, floating lyrics, a desktop audio visualizer, and other quality-of-life tweaks.

    [!WARNING]
    These dotfiles are tuned for my own laptop and display.
    Read the configuration before enabling the monitor, refresh-rate, ASUS, or systemd-related parts on another machine.

Features

    Hyprland with Lua configuration

    125% display scaling

    Automatic internal-display refresh-rate switching:

        ~120 Hz on battery

        240 Hz on AC power

    DIM Caelestia Shell

        desktop audio visualizer

        floating desktop lyrics

        weather in Celsius

        custom wallpaper directory

        Shimeji desktop pet disabled

    Fish shell

    Headless mpv background music

    Caelestia/MPRIS media controls

    Persistent custom .m3u8 playlist support

    Automatic music startup and playback resume

    User systemd services

    Custom helper scripts

    hyprsunset support for a Windows-style Night Light

    ASUS ROG utilities used separately through asusctl / ROG Control Center

Repository Structure

dotfiles/
├── caelestia/
│   └── .config/caelestia/
├── fish/
│   └── .config/fish/
├── hypr/
│   └── .config/hypr/
├── mpv/
│   └── .config/mpv/
├── scripts/
│   └── .local/bin/
├── systemd/
│   └── .config/systemd/user/
└── .gitignore

The folders are arranged in a GNU Stow-friendly layout.
Screenshots

Add screenshots of the desktop here:

![Desktop](assets/desktop.png)
![Caelestia](assets/caelestia.png)

Requirements

This setup is primarily intended for Arch Linux / CachyOS.

Core packages:

sudo pacman -S git stow hyprland fish mpv jq hyprsunset

For AUR packages, install an AUR helper such as paru, then:

paru -S dim-caelestia-shell-git

Depending on your existing CachyOS installation, you may already have many of the required Hyprland/Wayland packages.
Installation
1. Clone the repository

git clone https://github.com/huzaifahshahid71-ops/dotfiles.git ~/dotfiles
cd ~/dotfiles

2. Back up your current configuration

Do this before applying anything:

mkdir -p ~/dotfiles-backup

cp -a ~/.config/hypr ~/dotfiles-backup/ 2>/dev/null || true
cp -a ~/.config/caelestia ~/dotfiles-backup/ 2>/dev/null || true
cp -a ~/.config/fish ~/dotfiles-backup/ 2>/dev/null || true
cp -a ~/.config/mpv ~/dotfiles-backup/ 2>/dev/null || true
cp -a ~/.config/systemd/user ~/dotfiles-backup/systemd-user 2>/dev/null || true
cp -a ~/.local/bin ~/dotfiles-backup/local-bin 2>/dev/null || true

3. Apply with GNU Stow

From ~/dotfiles:

stow -t "$HOME" caelestia
stow -t "$HOME" fish
stow -t "$HOME" hypr
stow -t "$HOME" mpv
stow -t "$HOME" scripts
stow -t "$HOME" systemd

You do not have to use every package. Stow only the parts you want.

If Stow reports that files already exist, move or back them up first instead of forcing the operation blindly.
Configuration Notes
Hyprland Monitor Configuration

My internal display is named:

eDP-1

Check your monitor names with:

hyprctl monitors

If your display has a different name, update the relevant Hyprland files and scripts before using them.
125% scaling

My internal display uses:

scale = 1.25

Check the current scale with:

hyprctl monitors | grep -E 'Monitor|scale'

Automatic 120 / 240 Hz Switching

My laptop automatically changes refresh rate depending on charger state:
Power state	Refresh rate
Battery	~119.97 Hz
AC power	240 Hz

The custom battery mode currently uses this modeline:

modeline 1125.275 2560 2568 2600 2640 1600 3534 3542 3552 -hsync -vsync

    [!CAUTION]
    Do not copy this modeline blindly to another display.
    It was created specifically for my laptop panel.

The helper scripts are located under:

~/.local/bin/

The associated user service is:

auto-refresh-rate.service

Enable it with:

systemctl --user daemon-reload
systemctl --user enable --now auto-refresh-rate.service

Check the current refresh rate:

hyprctl monitors -j | jq -r '.[] | "\(.name): \(.refreshRate) Hz"'

DIM Caelestia

This setup uses the DIM fork of Caelestia:

paru -S dim-caelestia-shell-git

My configuration includes:

    desktop audio visualizer

    floating lyrics

    Celsius weather

    custom wallpaper directory

    Shimeji disabled

Wallpaper directory:

~/Pictures/Wallpapers

Create it if necessary:

mkdir -p ~/Pictures/Wallpapers

Background Music

Music is played by a headless mpv process controlled through Caelestia/MPRIS.

The service:

background-music.service

uses this playlist by default:

~/Music/Favorites.m3u8

Important

The actual music files and my personal playlist are not intended to be part of the dotfiles repo.

Create your own playlist, for example:

#EXTM3U
/home/YOUR_USER/Music/Song One.mp3
/home/YOUR_USER/Music/Song Two.mp3
/home/YOUR_USER/Music/Song Three.mp3

The line order is the playback order.

If you want a different playlist location, edit:

~/.local/bin/background-music

and change:

PLAYLIST="$MUSIC_DIR/Favorites.m3u8"

Enable the service:

systemctl --user daemon-reload
systemctl --user enable --now background-music.service

Check it:

systemctl --user status background-music.service

Restart after changing the playlist:

systemctl --user restart background-music.service

mpv

My mpv configuration keeps background audio playback invisible:

audio-display=no
force-window=no

Caelestia then acts as the visible media interface.
Night Light

I use hyprsunset as the Hyprland equivalent of Windows Night Light.

Enable its user service:

systemctl --user enable --now hyprsunset.service

Set a warm color temperature:

hyprctl hyprsunset temperature 4000

Disable the filter:

hyprctl hyprsunset identity

ASUS ROG Notes

My machine is an ASUS ROG laptop and I also use asusctl / ROG Control Center outside of these dotfiles.

ASUS-specific GPU modes, fan curves, power controls, and firmware behavior vary between models.

Do not assume my ASUS-related settings are appropriate for another laptop.
Useful Commands
Reload Hyprland

hyprctl reload

Check monitor scale and refresh rate

hyprctl monitors

Restart refresh-rate automation

systemctl --user restart auto-refresh-rate.service

Check background music

systemctl --user status background-music.service

Restart background music

systemctl --user restart background-music.service

Check which playlist mpv is using

ps aux | grep '[m]pv'

Updating the Dotfiles

After changing your configuration:

cd ~/dotfiles
git status
git add .
git commit -m "Update dotfiles"
git push

Always inspect what is about to be published:

git diff --cached

Security

Never commit:

    GitHub Personal Access Tokens

    passwords

    API keys

    SSH private keys

    Wi-Fi credentials

    browser profiles or cookies

    encryption / BitLocker recovery keys

    private certificates

    other personal secrets

If a secret is ever committed, removing it in a later commit is not enough. Revoke/rotate the secret and remove it from Git history.
Disclaimer

These are my personal dotfiles, not a universal installer.

Some settings—especially display modelines, monitor names, refresh rates, laptop hardware controls, absolute paths, and user services—must be adapted before using them on another system.

Feel free to fork the repo and customize it for your own setup.
License

You are welcome to use and modify these configs.

Consider adding an MIT License to make the reuse terms explicit.
