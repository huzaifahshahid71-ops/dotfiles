# SDDM Frieren Theme

A beautiful SDDM login screen theme inspired by **Frieren: Beyond Journey's End**.

![Theme Preview](Backgrounds/frieren.jpg)

## Copyright & License

**Copyright (c) 2026 moau-prog**  
Licensed under [GPL-3.0-or-later](LICENSE)

🔒 **ATTRIBUTION REQUIRED**: This theme is protected under GPL-3.0. Anyone who uses, modifies, or redistributes this theme MUST:
- Keep this copyright notice intact
- Give appropriate credit to **moau-prog** (the original author)
- Link back to the original repository
- Clearly state if changes were made
- License derivative works under GPL-3.0

---

## Features

- Frieren anime-themed login screen
- Customized color scheme matching the Frieren aesthetic
- Blur effects for enhanced visual appeal
- Clean and modern interface
- Easy installation script
- Fully customizable configuration

## Requirements

- SDDM (Simple Desktop Display Manager)
- Qt6
- Linux system (Arch, Fedora, Ubuntu, etc.)

## Installation

### Method 1: Automatic Installation (Recommended)

1. Clone this repository:
```bash
git clone https://github.com/moau-prog/sddm-frieren-theme.git
cd sddm-frieren-theme
```

2. Run the installation script:
```bash
sudo ./install.sh
```

3. The theme will be installed and configured automatically!

### Method 2: Manual Installation

1. Clone the repository:
```bash
git clone https://github.com/moau-prog/sddm-frieren-theme.git
```

2. Copy the theme to SDDM themes directory:
```bash
sudo cp -r sddm-frieren-theme /usr/share/sddm/themes/
```

3. Edit SDDM configuration:
```bash
sudo nano /etc/sddm.conf.d/sddm.conf
```

4. Add or modify the following:
```ini
[Theme]
Current=sddm-frieren-theme
```

5. Save and restart SDDM:
```bash
sudo systemctl restart sddm
```
**WARNING**: This will log you out!

## Customization

You can customize various aspects of the theme by editing the configuration file:

```bash
sudo nano /usr/share/sddm/themes/sddm-frieren-theme/Themes/theme.conf
```

### What You Can Customize:

- **Colors**: Text colors, background colors, button colors
- **Background**: Change the background image or use videos/GIFs
- **Layout**: Form position (left, center, right)
- **Blur Effects**: Adjust blur intensity and style
- **Text**: Header text, date/time format
- **Fonts**: Font family and size
- **Interface**: Hide/show elements like virtual keyboard, system buttons

### Example Customizations:

**Change Header Text:**
```ini
HeaderText="Welcome Back!"
```

**Change Background Image:**
```ini
Background="Backgrounds/your-image.jpg"
```

**Adjust Colors:**
```ini
LoginButtonTextColor="#ffffff"
LoginButtonBackgroundColor="#5533ff"
```

## Screenshots

The theme features:
- Frieren-themed background
- Smooth blur effects
- Clean login form
- Responsive design

## Credits

**Created by**: [moau-prog](https://github.com/moau-prog)  
**Based on**: [sddm-astronaut-theme](https://github.com/Keyitdev/sddm-astronaut-theme) by Keyitdev

This theme is a customized derivative work based on the excellent sddm-astronaut-theme framework.

## Troubleshooting

### Theme not showing up?
```bash
sudo systemctl restart sddm
```

### SDDM not starting?
Check logs:
```bash
journalctl -u sddm -b
```

### Want to revert to default theme?
```bash
sudo nano /etc/sddm.conf.d/sddm.conf
```
Change `Current=` to your previous theme name.

## License

This project is licensed under the **GNU General Public License v3.0 or later**.

See [LICENSE](LICENSE) file for full license text.

### What this means:

✅ You CAN:
- Use this theme freely
- Modify it for your own use
- Share it with others
- Create derivative works

❌ You CANNOT:
- Remove the copyright notice
- Claim you made it
- Distribute it without giving credit to moau-prog
- Relicense it under different terms
- **Remove or modify the "by moau-prog" watermark**

Any modifications or redistributions MUST:
- Include this copyright notice
- Be licensed under GPL-3.0
- Give appropriate credit to the original author
- **Keep the author watermark intact**

### ⚠️ IMPORTANT: Author Watermark Protection

This theme includes a **protected author watermark** ("by moau-prog") that appears for 5 seconds at the bottom of the login screen. This watermark:
- **MUST NOT be removed or modified** - it's required by the GPL-3.0 license
- Is protected by copyright law
- Includes technical protection against removal
- Logs violations to system console

See [COPYRIGHT_NOTICE.txt](COPYRIGHT_NOTICE.txt) for full details.

---

## Support

If you encounter any issues or have questions:
- Open an issue on GitHub
- Check the [SDDM documentation](https://github.com/sddm/sddm)

---

## Star This Repository ⭐

If you like this theme, please give it a star on GitHub!

---

**Made with ❤️ by [moau-prog](https://github.com/moau-prog)**  
**Copyright © 2026 moau-prog. All rights reserved.**
