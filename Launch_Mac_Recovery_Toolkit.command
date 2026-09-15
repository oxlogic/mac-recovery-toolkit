#!/bin/bash
# ==============================================================================
# OxLogic Mac Recovery Toolkit (MRTK) v1.0.0
# Lead Developer: Md Tazmir (@mdtazmir1 | https://www.facebook.com/muhammadtazmir) | OxLogic Team
# Official Repository: https://github.com/oxlogic/mac-recovery-toolkit
# One-Click Double-Clickable Launcher for macOS Finder
# ==============================================================================

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "================================================================="
echo "       OxLogic Mac Recovery Toolkit (MRTK) v1.0.0       "
echo "       Developed by Md Tazmir (@mdtazmir1) | OxLogic Team       "
echo "================================================================="
echo "Initializing environment..."

if [ -f "$DIR/mac_recovery_toolkit.sh" ]; then
    bash "$DIR/mac_recovery_toolkit.sh"
elif [ -f "$DIR/universal_mac.sh" ]; then
    bash "$DIR/universal_mac.sh"
elif [ -f "$DIR/mac.sh" ]; then
    bash "$DIR/mac.sh"
else
    echo "Error: mac_recovery_toolkit.sh not found in $DIR"
    read -rp "Press [Enter] to exit..."
fi
