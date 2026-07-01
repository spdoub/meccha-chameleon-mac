#!/usr/bin/env bash
#
# Apply Wine registry overrides required for Steam on macOS/GPTK.
# Run once after install, or if Steam UI (steamwebhelper) misbehaves.

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_ROOT="$ROOT"
# shellcheck source=common.sh
source "$ROOT/scripts/common.sh"

echo "==> Applying Steam Wine overrides"
echo "    Prefix: $WINEPREFIX"
echo ""

require_prefix

# steam_api64 for game auth (see fix-steam-api-overrides.sh — kept here for one-shot setup).
run_wine reg add 'HKCU\Software\Wine\DllOverrides' /v steam_api64 /t REG_SZ /d native,builtin /f >/dev/null 2>&1 || true
run_wine reg add 'HKCU\Software\Wine\DllOverrides' /v steam_api /t REG_SZ /d native,builtin /f >/dev/null 2>&1 || true

# Wine bug 44985: libglesv2 breaks Steam Store/Library on macOS.
run_wine reg add 'HKCU\Software\Wine\AppDefaults\steamwebhelper.exe\DllOverrides' /v libglesv2 /t REG_SZ /d disabled /f >/dev/null 2>&1 || true

# Reduce crash dialogs on macOS (winetricks nocrashdialog).
run_wine reg add 'HKCU\Software\Wine\WineDbg' /v ShowCrashDialog /t REG_DWORD /d 0 /f >/dev/null 2>&1 || true

echo "Applied:"
echo "  steam_api64 = native,builtin"
echo "  steamwebhelper.exe → libglesv2 = disabled"
echo "  ShowCrashDialog = 0"
echo ""
echo "Steam launch flags (in common.sh): $STEAM_CEF_ARGS"
echo ""
echo "If Steam UI still won't appear, GPTK's Wine 7.7 may be too old for the"
echo "current Steam client. Options:"
echo "  1. Wait 3–5 min and check the Dock for a Steam/Wine icon"
echo "  2. Avoid display mirroring (known to crash Steam on Wine)"
echo "  3. Use Sikarugir/Whisky to install Steam, then copy the prefix game files"
echo "  4. See README 'Steam UI troubleshooting' section"
