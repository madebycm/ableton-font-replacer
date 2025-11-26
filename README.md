# Ableton Live Font Replacer

Replace Ableton Live's UI fonts with accessibility-friendly alternatives. Perfect for users with astigmatism, dyslexia, or anyone who wants improved readability.

![macOS](https://img.shields.io/badge/macOS-000000?style=flat&logo=apple&logoColor=white)
![Ableton Live](https://img.shields.io/badge/Ableton%20Live-000000?style=flat&logo=abletonlive&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green)

## Why?

Ableton Live uses a custom "AbletonSans" font that can be difficult to read for people with:
- **Astigmatism** - blurry/distorted vision that makes thin fonts hard to read
- **Dyslexia** - difficulty distinguishing similar letterforms
- **Low vision** - need for higher contrast and distinct characters

This tool replaces Ableton's fonts with **Atkinson Hyperlegible**, a font designed by the Braille Institute specifically for maximum legibility.

## Features

- One-command font replacement
- Automatic backup of original fonts
- Easy revert to original fonts
- Support for custom fonts
- Handles macOS code signing automatically

## Quick Start

```bash
# Clone the repo
git clone https://github.com/madebycm/ableton-font-replacer.git
cd ableton-font-replacer

# Run the installer
./ableton-font-replace.sh

# Enter your password when prompted for code signing
```

That's it! Restart Ableton Live to see the new fonts.

## Usage

```bash
# Install Atkinson Hyperlegible (default)
./ableton-font-replace.sh

# Revert to original Ableton fonts
./ableton-font-replace.sh --revert

# Use a custom font
./ableton-font-replace.sh --custom /path/to/your-font.ttf

# List available backups
./ableton-font-replace.sh --list

# Show help
./ableton-font-replace.sh --help
```

## About Atkinson Hyperlegible

[Atkinson Hyperlegible](https://brailleinstitute.org/freefont) was developed by the Braille Institute and named after its founder, J. Robert Atkinson. It features:

- **Distinct letterforms** - Characters like I, l, 1 and O, 0 are clearly different
- **Open apertures** - More space inside letters for better recognition
- **Unambiguous design** - Every character is uniquely identifiable
- **Free and open source** - Available under the SIL Open Font License

## How It Works

1. **Locates** your Ableton Live installation
2. **Downloads** Atkinson Hyperlegible font files
3. **Backs up** original fonts to `~/.ableton-font-backup/`
4. **Rewrites** font metadata to match Ableton's expected font names
5. **Replaces** the fonts in the app bundle
6. **Re-signs** the application with an ad-hoc signature

## Requirements

- macOS
- Ableton Live 11 or 12
- Python 3 (comes with macOS)
- Administrator privileges (for code signing)

## Troubleshooting

### "Ableton Live is damaged and can't be opened"

Run the code signing command manually:
```bash
sudo codesign --force --deep --sign - "/Applications/Ableton Live 12 Suite.app"
```

### Fonts don't appear to change

1. Fully quit Ableton Live (Cmd+Q)
2. Clear font caches: `sudo atsutil databases -remove`
3. Restart your Mac
4. Reopen Ableton

### Want to try a different font?

```bash
# First revert to original
./ableton-font-replace.sh --revert

# Then install your custom font
./ableton-font-replace.sh --custom ~/Downloads/Inter-Regular.ttf
```

## Other Recommended Fonts

- [Inter](https://rsms.me/inter/) - Clean, highly legible sans-serif
- [OpenDyslexic](https://opendyslexic.org/) - Designed specifically for dyslexia
- [Lexie Readable](http://www.intototype.com/) - Another dyslexia-friendly option

## License

MIT License - See [LICENSE](LICENSE) for details.

Atkinson Hyperlegible is licensed under the [SIL Open Font License](https://scripts.sil.org/OFL).

## Contributing

Contributions welcome! Feel free to open issues or submit PRs.

---

Made with care for the accessibility community.
