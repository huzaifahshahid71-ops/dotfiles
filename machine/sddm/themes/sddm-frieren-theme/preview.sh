#!/bin/bash
# SDDM Theme Preview Script
# This allows you to preview the theme without applying it

THEME_DIR="$HOME/sddm-frieren-theme"

echo "=========================================="
echo "  SDDM Frieren Theme - Preview Mode"
echo "=========================================="
echo ""

# Check if theme directory exists
if [ ! -d "$THEME_DIR" ]; then
    echo "Error: Theme directory not found at $THEME_DIR"
    exit 1
fi

# Check if sddm-greeter exists
if ! command -v sddm-greeter-qt6 &> /dev/null && ! command -v sddm-greeter &> /dev/null; then
    echo "Error: sddm-greeter not found"
    echo "Please install SDDM first"
    exit 1
fi

# Create temporary config file for preview
TEMP_CONF=$(mktemp)
cat > "$TEMP_CONF" <<EOF
[Theme]
Current=sddm-frieren-theme
ThemeDir=$HOME/sddm-frieren-theme

[General]
InputMethod=
EOF

echo "Starting theme preview..."
echo "Press Ctrl+Alt+F2 (or Ctrl+C in terminal) to exit preview"
echo ""
echo "Note: This is a preview only - your system remains unchanged"
echo ""
sleep 2

# Try Qt6 version first, fallback to regular version
if command -v sddm-greeter-qt6 &> /dev/null; then
    sddm-greeter-qt6 --test-mode --theme "$THEME_DIR"
elif command -v sddm-greeter &> /dev/null; then
    sddm-greeter --test-mode --theme "$THEME_DIR"
fi

# Cleanup
rm -f "$TEMP_CONF"

echo ""
echo "Preview closed."
