#!/bin/bash
# Ableton Live Font Replacement Script
# Replaces UI fonts with accessibility-friendly alternatives (good for astigmatism)
# Supports: Atkinson Hyperlegible, Inter, or custom fonts
#
# @author madebycm
# @license MIT

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.ableton-font-backup"
VENV_DIR="$SCRIPT_DIR/.font-venv"
TEMP_DIR=$(mktemp -d)

# Find Ableton installation
find_ableton() {
    local ableton_path=""

    # Check common locations
    for app in "/Applications/Ableton Live"*".app"; do
        if [[ -d "$app" ]]; then
            ableton_path="$app"
            break
        fi
    done

    if [[ -z "$ableton_path" ]]; then
        # Try Spotlight
        ableton_path=$(mdfind "kMDItemKind == 'Application' && kMDItemFSName == 'Ableton Live*'" 2>/dev/null | head -1)
    fi

    echo "$ableton_path"
}

ABLETON_APP=$(find_ableton)
FONTS_DIR="$ABLETON_APP/Contents/App-Resources/Fonts"

# Font files to replace (main UI fonts)
FONT_FILES=(
    "AbletonSans-Light.ttf"
    "AbletonSansSmall-Bold.ttf"
    "AbletonSansSmall-Regular.ttf"
    "AbletonSansSmall-RegularItalic.ttf"
)

# Atkinson Hyperlegible download URLs (from official Braille Institute release)
ATKINSON_BASE_URL="https://github.com/googlefonts/atkinson-hyperlegible/raw/main/fonts/ttf"
ATKINSON_FILES=(
    "AtkinsonHyperlegible-Regular.ttf"
    "AtkinsonHyperlegible-Bold.ttf"
    "AtkinsonHyperlegible-Italic.ttf"
    "AtkinsonHyperlegible-BoldItalic.ttf"
)

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║        Ableton Live Font Replacement Tool                    ║"
    echo "║        For improved readability (astigmatism-friendly)       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

check_requirements() {
    log_info "Checking requirements..."

    if [[ -z "$ABLETON_APP" || ! -d "$ABLETON_APP" ]]; then
        log_error "Ableton Live not found!"
        echo "Please ensure Ableton Live is installed in /Applications"
        exit 1
    fi

    log_info "Found: $ABLETON_APP"

    if [[ ! -d "$FONTS_DIR" ]]; then
        log_error "Fonts directory not found at: $FONTS_DIR"
        exit 1
    fi

    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is required but not found"
        exit 1
    fi

    if ! command -v curl &> /dev/null; then
        log_error "curl is required but not found"
        exit 1
    fi
}

setup_venv() {
    log_info "Setting up Python virtual environment..."

    if [[ ! -d "$VENV_DIR" ]]; then
        python3 -m venv "$VENV_DIR"
    fi

    source "$VENV_DIR/bin/activate"
    pip install --quiet --upgrade pip
    pip install --quiet fonttools

    log_info "fonttools installed successfully"
}

download_atkinson() {
    log_info "Downloading Atkinson Hyperlegible font..."

    local download_dir="$TEMP_DIR/atkinson"
    mkdir -p "$download_dir"

    for font in "${ATKINSON_FILES[@]}"; do
        local url="$ATKINSON_BASE_URL/$font"
        local dest="$download_dir/$font"

        if curl -sL "$url" -o "$dest"; then
            log_info "Downloaded: $font"
        else
            log_error "Failed to download: $font"
            exit 1
        fi
    done

    echo "$download_dir"
}

backup_fonts() {
    log_info "Creating backup of original fonts..."

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/$timestamp"

    mkdir -p "$backup_path"

    # Copy original fonts
    for font in "${FONT_FILES[@]}"; do
        local src="$FONTS_DIR/$font"
        if [[ -f "$src" ]]; then
            cp "$src" "$backup_path/"
            log_info "Backed up: $font"
        fi
    done

    # Save metadata
    echo "$ABLETON_APP" > "$backup_path/.ableton_path"
    echo "$timestamp" > "$backup_path/.timestamp"

    # Create latest symlink
    ln -sf "$backup_path" "$BACKUP_DIR/latest"

    log_info "Backup saved to: $backup_path"
}

# Python script for font name rewriting
create_font_renamer() {
    cat > "$TEMP_DIR/rename_font.py" << 'PYTHON_SCRIPT'
#!/usr/bin/env python3
"""
Font name rewriter - changes internal font names to match target names.
This is necessary because applications look up fonts by internal name, not filename.
"""

import sys
from fontTools.ttLib import TTFont

def rename_font(input_path, output_path, target_family, target_subfamily):
    """
    Rename a font's internal names to match a target.

    Name IDs in the name table:
    0 - Copyright
    1 - Font Family
    2 - Font Subfamily (style)
    3 - Unique Identifier
    4 - Full Name
    5 - Version
    6 - PostScript Name
    7 - Trademark
    16 - Typographic Family
    17 - Typographic Subfamily
    """
    font = TTFont(input_path)
    name_table = font['name']

    # Build new names
    full_name = f"{target_family} {target_subfamily}".strip()
    ps_name = f"{target_family}-{target_subfamily}".replace(" ", "")

    # Update name records for all platforms/encodings
    for record in name_table.names:
        try:
            if record.nameID == 1:  # Family
                record.string = target_family
            elif record.nameID == 2:  # Subfamily
                record.string = target_subfamily
            elif record.nameID == 4:  # Full name
                record.string = full_name
            elif record.nameID == 6:  # PostScript name
                record.string = ps_name
            elif record.nameID == 16:  # Typographic Family
                record.string = target_family
            elif record.nameID == 17:  # Typographic Subfamily
                record.string = target_subfamily
        except Exception as e:
            # Some records may be in different encodings
            pass

    font.save(output_path)
    print(f"Renamed font saved to: {output_path}")

def scale_font(input_path, output_path, scale_factor):
    """
    Scale a font by reducing unitsPerEm.

    This makes the font render larger at any given point size.
    We only modify the unitsPerEm value - fontTools handles the rest.
    """
    from fontTools.ttLib.tables._g_l_y_f import GlyphCoordinates

    font = TTFont(input_path)

    # Original unitsPerEm (typically 1000 or 2048)
    original_upm = font['head'].unitsPerEm

    # Calculate new UPM - lower UPM = larger rendered size
    new_upm = int(original_upm / scale_factor)

    # Scale factor for coordinate transformation
    coord_scale = new_upm / original_upm

    # Update head table
    font['head'].unitsPerEm = new_upm

    # Update hhea (horizontal metrics)
    if 'hhea' in font:
        font['hhea'].ascent = int(font['hhea'].ascent * coord_scale)
        font['hhea'].descent = int(font['hhea'].descent * coord_scale)
        font['hhea'].lineGap = int(font['hhea'].lineGap * coord_scale)

    # Update OS/2 table metrics
    if 'OS/2' in font:
        os2 = font['OS/2']
        os2.sTypoAscender = int(os2.sTypoAscender * coord_scale)
        os2.sTypoDescender = int(os2.sTypoDescender * coord_scale)
        os2.sTypoLineGap = int(os2.sTypoLineGap * coord_scale)
        os2.usWinAscent = int(os2.usWinAscent * coord_scale)
        os2.usWinDescent = abs(int(os2.usWinDescent * coord_scale))
        os2.sxHeight = int(os2.sxHeight * coord_scale)
        os2.sCapHeight = int(os2.sCapHeight * coord_scale)

    # Update post table
    if 'post' in font:
        font['post'].underlinePosition = int(font['post'].underlinePosition * coord_scale)
        font['post'].underlineThickness = int(font['post'].underlineThickness * coord_scale)

    # Scale all glyph widths in hmtx
    if 'hmtx' in font:
        for glyph_name in font['hmtx'].metrics:
            width, lsb = font['hmtx'].metrics[glyph_name]
            font['hmtx'].metrics[glyph_name] = (int(width * coord_scale), int(lsb * coord_scale))

    # Scale glyph outlines using proper GlyphCoordinates
    if 'glyf' in font:
        glyf = font['glyf']
        for glyph_name in glyf.keys():
            glyph = glyf[glyph_name]
            if glyph.numberOfContours > 0 and hasattr(glyph, 'coordinates') and glyph.coordinates:
                # Scale coordinates properly
                scaled = [(int(x * coord_scale), int(y * coord_scale))
                          for x, y in glyph.coordinates]
                glyph.coordinates = GlyphCoordinates(scaled)

                # Recalculate bounds
                if scaled:
                    xs = [p[0] for p in scaled]
                    ys = [p[1] for p in scaled]
                    glyph.xMin = min(xs)
                    glyph.yMin = min(ys)
                    glyph.xMax = max(xs)
                    glyph.yMax = max(ys)
            elif glyph.numberOfContours == -1:  # Composite glyph
                if hasattr(glyph, 'components'):
                    for comp in glyph.components:
                        if hasattr(comp, 'x'):
                            comp.x = int(comp.x * coord_scale)
                        if hasattr(comp, 'y'):
                            comp.y = int(comp.y * coord_scale)

    font.save(output_path)
    print(f"Scaled font ({scale_factor}x) saved to: {output_path}")

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: rename_font.py <input.ttf> <output.ttf> <family> <subfamily> [scale]")
        sys.exit(1)

    scale = float(sys.argv[5]) if len(sys.argv) > 5 else 1.0

    rename_font(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])

    if scale != 1.0:
        scale_font(sys.argv[2], sys.argv[2], scale)
PYTHON_SCRIPT
}

prepare_replacement_fonts() {
    local source_dir="$1"
    local scale="${2:-1.0}"
    local output_dir="$TEMP_DIR/prepared"
    mkdir -p "$output_dir"

    log_info "Preparing replacement fonts with correct internal names..."
    if [[ "$scale" != "1.0" ]]; then
        log_info "Applying scale factor: ${scale}x"
    fi

    create_font_renamer

    # Map Atkinson fonts to Ableton font names
    # AbletonSans-Light.ttf <- AtkinsonHyperlegible-Regular.ttf
    # AbletonSansSmall-Bold.ttf <- AtkinsonHyperlegible-Bold.ttf
    # AbletonSansSmall-Regular.ttf <- AtkinsonHyperlegible-Regular.ttf
    # AbletonSansSmall-RegularItalic.ttf <- AtkinsonHyperlegible-Italic.ttf

    # Map Atkinson fonts to Ableton font slots
    # AbletonSans-Light <- Regular (main UI)
    # AbletonSansSmall-Regular <- Regular
    # AbletonSansSmall-Bold <- Bold
    # AbletonSansSmall-RegularItalic <- Italic

    python3 "$TEMP_DIR/rename_font.py" \
        "$source_dir/AtkinsonHyperlegible-Regular.ttf" \
        "$output_dir/AbletonSans-Light.ttf" \
        "AbletonSans" "Light" "$scale" >&2

    python3 "$TEMP_DIR/rename_font.py" \
        "$source_dir/AtkinsonHyperlegible-Bold.ttf" \
        "$output_dir/AbletonSansSmall-Bold.ttf" \
        "AbletonSans Small" "Bold" "$scale" >&2

    python3 "$TEMP_DIR/rename_font.py" \
        "$source_dir/AtkinsonHyperlegible-Regular.ttf" \
        "$output_dir/AbletonSansSmall-Regular.ttf" \
        "AbletonSans Small" "Regular" "$scale" >&2

    python3 "$TEMP_DIR/rename_font.py" \
        "$source_dir/AtkinsonHyperlegible-Italic.ttf" \
        "$output_dir/AbletonSansSmall-RegularItalic.ttf" \
        "AbletonSans Small" "Regular Italic" "$scale" >&2

    echo "$output_dir"
}

install_fonts() {
    local prepared_dir="$1"

    log_info "Installing replacement fonts..."

    # Check if we need sudo
    if [[ ! -w "$FONTS_DIR" ]]; then
        log_warn "Need administrator privileges to modify Ableton fonts"

        for font in "${FONT_FILES[@]}"; do
            sudo cp "$prepared_dir/$font" "$FONTS_DIR/$font"
        done
    else
        for font in "${FONT_FILES[@]}"; do
            cp "$prepared_dir/$font" "$FONTS_DIR/$font"
        done
    fi

    log_info "Fonts installed successfully"
}

handle_codesign() {
    log_info "Handling code signature..."

    # Check current signature
    if codesign -dv "$ABLETON_APP" 2>&1 | grep -q "Signature"; then
        log_warn "App is code-signed. Modifications will invalidate signature."
        echo ""
        echo "Options:"
        echo "  1) Remove signature (app will show 'unidentified developer' warning)"
        echo "  2) Re-sign with ad-hoc signature (recommended)"
        echo "  3) Skip (app may not launch on some systems)"
        echo ""
        read -p "Choose option [2]: " choice
        choice=${choice:-2}

        case $choice in
            1)
                log_info "Removing code signature..."
                sudo codesign --remove-signature "$ABLETON_APP"
                ;;
            2)
                log_info "Re-signing with ad-hoc signature..."
                sudo codesign --force --deep --sign - "$ABLETON_APP"
                ;;
            3)
                log_warn "Skipping code signature handling"
                ;;
        esac
    fi

    # Clear quarantine if present
    sudo xattr -rd com.apple.quarantine "$ABLETON_APP" 2>/dev/null || true
}

revert_fonts() {
    log_info "Reverting to original fonts..."

    if [[ ! -d "$BACKUP_DIR/latest" ]]; then
        log_error "No backup found!"
        echo "Backup directory: $BACKUP_DIR"
        exit 1
    fi

    local backup_path=$(readlink -f "$BACKUP_DIR/latest")

    if [[ ! -f "$backup_path/.ableton_path" ]]; then
        log_error "Invalid backup - missing metadata"
        exit 1
    fi

    local saved_ableton_path=$(cat "$backup_path/.ableton_path")

    log_info "Restoring from: $backup_path"
    log_info "Target: $saved_ableton_path"

    local target_fonts="$saved_ableton_path/Contents/App-Resources/Fonts"

    if [[ ! -d "$target_fonts" ]]; then
        log_error "Target fonts directory not found: $target_fonts"
        exit 1
    fi

    # Restore fonts
    for font in "${FONT_FILES[@]}"; do
        local src="$backup_path/$font"
        local dest="$target_fonts/$font"

        if [[ -f "$src" ]]; then
            if [[ ! -w "$target_fonts" ]]; then
                sudo cp "$src" "$dest"
            else
                cp "$src" "$dest"
            fi
            log_info "Restored: $font"
        else
            log_warn "Backup file not found: $font"
        fi
    done

    # Re-sign after restore
    ABLETON_APP="$saved_ableton_path"
    handle_codesign

    log_info "Fonts reverted successfully!"
}

list_backups() {
    log_info "Available backups:"

    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "No backups found"
        return
    fi

    for backup in "$BACKUP_DIR"/*/; do
        if [[ -f "$backup/.timestamp" ]]; then
            local ts=$(cat "$backup/.timestamp")
            local path=$(cat "$backup/.ableton_path" 2>/dev/null || echo "unknown")
            echo "  - $ts ($(basename "$path"))"
        fi
    done
}

replace_fonts() {
    local scale="${FONT_SCALE:-1.0}"

    check_requirements
    setup_venv

    # Download replacement font
    local atkinson_dir
    atkinson_dir=$(download_atkinson)

    # Backup original fonts
    backup_fonts

    # Prepare fonts with correct names and optional scaling
    local prepared_dir
    prepared_dir=$(prepare_replacement_fonts "$atkinson_dir" "$scale")

    # Install fonts
    install_fonts "$prepared_dir"

    # Handle code signing
    handle_codesign

    # Cleanup
    rm -rf "$TEMP_DIR"

    echo ""
    log_info "Font replacement complete!"
    echo ""
    echo -e "${GREEN}Atkinson Hyperlegible${NC} is now installed in Ableton Live."
    echo "This font was designed by the Braille Institute for improved readability."
    echo ""
    echo "To revert: $0 --revert"
    echo ""
    log_warn "Please restart Ableton Live for changes to take effect."
}

use_custom_font() {
    local font_path="$1"

    if [[ ! -f "$font_path" ]]; then
        log_error "Font file not found: $font_path"
        exit 1
    fi

    check_requirements
    setup_venv

    # Create temp directory with the custom font
    local custom_dir="$TEMP_DIR/custom"
    mkdir -p "$custom_dir"

    # Copy the custom font for all variants
    cp "$font_path" "$custom_dir/AtkinsonHyperlegible-Regular.ttf"
    cp "$font_path" "$custom_dir/AtkinsonHyperlegible-Bold.ttf"
    cp "$font_path" "$custom_dir/AtkinsonHyperlegible-Italic.ttf"
    cp "$font_path" "$custom_dir/AtkinsonHyperlegible-BoldItalic.ttf"

    # Backup original fonts
    backup_fonts

    # Prepare fonts with correct names
    local prepared_dir=$(prepare_replacement_fonts "$custom_dir")

    # Install fonts
    install_fonts "$prepared_dir"

    # Handle code signing
    handle_codesign

    # Cleanup
    rm -rf "$TEMP_DIR"

    echo ""
    log_info "Custom font installed successfully!"
    echo "To revert: $0 --revert"
}

show_help() {
    print_header
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --install, -i       Install Atkinson Hyperlegible font (default)"
    echo "  --revert, -r        Revert to original Ableton fonts"
    echo "  --list, -l          List available backups"
    echo "  --custom <font>     Use a custom TTF font file"
    echo "  --help, -h          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                          # Install Atkinson Hyperlegible"
    echo "  $0 --revert                 # Restore original fonts"
    echo "  $0 --custom ~/my-font.ttf   # Use custom font"
    echo ""
    echo "Recommended fonts for astigmatism:"
    echo "  - Atkinson Hyperlegible (default, by Braille Institute)"
    echo "  - Inter"
    echo "  - OpenDyslexic"
    echo "  - Lexie Readable"
}

cleanup() {
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    deactivate 2>/dev/null || true
}

trap cleanup EXIT

# Main
print_header

# Parse arguments
FONT_SCALE="1.0"
ACTION=""
CUSTOM_FONT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --revert|-r)
            ACTION="revert"
            shift
            ;;
        --list|-l)
            ACTION="list"
            shift
            ;;
        --scale|-s)
            if [[ -z "${2:-}" ]]; then
                log_error "Please provide a scale factor (e.g., 1.15)"
                exit 1
            fi
            FONT_SCALE="$2"
            shift 2
            ;;
        --custom|-c)
            if [[ -z "${2:-}" ]]; then
                log_error "Please provide a font file path"
                exit 1
            fi
            ACTION="custom"
            CUSTOM_FONT="$2"
            shift 2
            ;;
        --help|-h)
            ACTION="help"
            shift
            ;;
        --install|-i)
            ACTION="install"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Execute action
case "${ACTION:-install}" in
    revert)
        revert_fonts
        ;;
    list)
        list_backups
        ;;
    custom)
        use_custom_font "$CUSTOM_FONT"
        ;;
    help)
        show_help
        ;;
    install|"")
        replace_fonts
        ;;
esac
