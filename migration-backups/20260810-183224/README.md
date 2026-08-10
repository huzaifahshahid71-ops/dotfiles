CachyOS + Hyprland Dotfiles

My personal CachyOS / Hyprland desktop configuration, built around DIM Caelestia, with custom display scaling, automatic refresh-rate switching, background music, floating lyrics, a desktop audio visualizer, and other quality-of-life tweaks.

[!WARNING]These dotfiles are tuned for my own laptop and display.Read the configuration before enabling the monitor, refresh-rate, ASUS, or systemd-related parts on another machine.

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

Power state

Refresh rate

Battery

~119.97 Hz

AC power

240 Hz

The custom battery mode currently uses this modeline:

modeline 1125.275 2560 2568 2600 2640 1600 3534 3542 3552 -hsync -vsync

[!CAUTION]Do not copy this modeline blindly to another display.It was created specifically for my laptop panel.

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
