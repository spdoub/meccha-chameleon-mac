#!/usr/bin/env bash
#
# Launch MECCHA CHAMELEON — one virtual-desktop window, silent Steam, game via applaunch.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=wine11-env.sh
source "$ROOT/scripts/wine11-env.sh"
# shellcheck source=meccha-common.sh
source "$ROOT/scripts/meccha-common.sh"

APP_ID="${APP_ID:-4704690}"
NOTPOP="$NOTPOP"
STEAM_DIR="$WINEPREFIX/drive_c/Program Files (x86)/Steam"
GAME_EXE="$STEAM_DIR/steamapps/common/MECCHA CHAMELEON/Chameleon/Binaries/Win64/PenguinHotel-Win64-Shipping.exe"
LOG_FILE="${LOG_DIR}/meccha-launch.log"
VD_NAME="${WINE_VIRTUAL_DESKTOP_NAME:-MECCHA CHAMELEON}"

mkdir -p "$LOG_DIR"
exec >>"$LOG_FILE" 2>&1

meccha_notify "MECCHA CHAMELEON" "Starting…"

bash "$ROOT/scripts/preflight-launch.sh"

GAME_FLAGS="$(meccha_build_game_flags)"
export WINEESYNC=0 WINEFSYNC=0
export WINEDLLOVERRIDES="dxgi,d3d11,d3d10core=n,b;bcrypt=b;ncrypt=b;gameoverlayrenderer,gameoverlayrenderer64=d;steam_api64=n,b"
export MTL_HUD_ENABLED="${MECCHA_HUD:-${MTL_HUD_ENABLED:-0}}"

# Game not installed — open Steam UI once (only path that needs a second app).
if [[ ! -f "$GAME_EXE" ]]; then
  meccha_notify "MECCHA CHAMELEON" "Install the game in Steam first"
  open "$INSTALL_APP_DIR/Steam on M1 Wine.app" 2>/dev/null || bash "$ROOT/scripts/launch-steam.sh"
  exit 1
fi

# Prefix-scoped shutdown (does not touch other Wine installs).
if [[ "${MECCHA_NO_KILL:-0}" != "1" ]]; then
  echo "Stopping previous session for $WINEPREFIX..."
  meccha_kill_prefix "$WINEPREFIX" "$WINESERVER"
fi

# Deploy wrapper + scrub locks (launch-steam does this too; keep in sync).
bash "$NOTPOP/scripts/06-install-wrapper.sh" >/dev/null 2>&1 || true

VD_SIZE="$(meccha_detect_display_size)"
STEAM_ARGS=(-no-cef-sandbox -cef-single-process -noverifyfiles -silent)

echo "Launching single-window session ($VD_NAME @ $VD_SIZE)"
meccha_notify "MECCHA CHAMELEON" "Launching game…"

cd "$STEAM_DIR"
/usr/bin/arch -x86_64 env \
  WINEPREFIX="$WINEPREFIX" \
  WINEESYNC=0 \
  WINEFSYNC=0 \
  WINEDEBUG="${WINEDEBUG:--all}" \
  WINEDLLOVERRIDES="$WINEDLLOVERRIDES" \
  MTL_HUD_ENABLED="$MTL_HUD_ENABLED" \
  "$WINE_BIN" explorer.exe \
  "/desktop=${VD_NAME},${VD_SIZE}" \
  "C:\\Program Files (x86)\\Steam\\Steam.exe" \
  "${STEAM_ARGS[@]}" \
  -applaunch "$APP_ID" $GAME_FLAGS &

LAUNCH_PID=$!

# Wait for game process (retry once on failure).
game_up() { /usr/bin/pgrep -f 'PenguinHotel-Win64-Shipping' >/dev/null 2>&1; }

for attempt in 1 2; do
  for _ in $(seq 1 45); do
    game_up && break
    sleep 1
  done
  game_up && break
  if [[ "$attempt" == 1 ]]; then
    echo "Game did not appear — retrying launch (attempt 2)..."
    meccha_notify "MECCHA CHAMELEON" "Retrying launch…"
    meccha_kill_prefix "$WINEPREFIX" "$WINESERVER"
    sleep 2
    /usr/bin/arch -x86_64 env \
      WINEPREFIX="$WINEPREFIX" WINEESYNC=0 WINEFSYNC=0 \
      WINEDEBUG="${WINEDEBUG:--all}" WINEDLLOVERRIDES="$WINEDLLOVERRIDES" \
      MTL_HUD_ENABLED="$MTL_HUD_ENABLED" \
      "$WINE_BIN" explorer.exe \
      "/desktop=${VD_NAME},${VD_SIZE}" \
      "C:\\Program Files (x86)\\Steam\\Steam.exe" \
      "${STEAM_ARGS[@]}" \
      -applaunch "$APP_ID" $GAME_FLAGS &
    LAUNCH_PID=$!
  fi
done

if game_up; then
  meccha_focus_wine
  meccha_notify "MECCHA CHAMELEON" "Ready — check the game window"
  echo "Game running (pid $LAUNCH_PID)"
  exit 0
fi

echo "ERROR: Game did not start within timeout"
meccha_report_crash "$LOG_FILE"
meccha_notify "MECCHA CHAMELEON" "Launch failed — run: bash scripts/doctor.sh"
exit 1
