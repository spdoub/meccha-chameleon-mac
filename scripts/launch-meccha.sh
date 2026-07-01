#!/usr/bin/env bash
#
# Launch MECCHA CHAMELEON via Steam applaunch inside one virtual-desktop window.

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

mkdir -p "$LOG_DIR"
exec >>"$LOG_FILE" 2>&1

meccha_notify "MECCHA CHAMELEON" "Starting…"

bash "$ROOT/scripts/preflight-launch.sh"

GAME_FLAGS="$(meccha_build_game_flags)"
export WINEESYNC=0 WINEFSYNC=0
export WINEDLLOVERRIDES="dxgi,d3d11,d3d10core=n,b;bcrypt=b;ncrypt=b;gameoverlayrenderer,gameoverlayrenderer64=d;steam_api64=n,b"
export MTL_HUD_ENABLED="${MECCHA_HUD:-${MTL_HUD_ENABLED:-0}}"
export WINE_VIRTUAL_DESKTOP_NAME="${WINE_VIRTUAL_DESKTOP_NAME:-MECCHA CHAMELEON}"

if [[ ! -f "$GAME_EXE" ]]; then
  meccha_notify "MECCHA CHAMELEON" "Install the game in Steam first"
  open "$INSTALL_APP_DIR/Steam on M1 Wine.app" 2>/dev/null || bash "$ROOT/scripts/launch-steam.sh" --detach
  exit 1
fi

steam_main_running() {
  /usr/bin/pgrep -f 'Steam\.exe.*(-no-cef-sandbox|-noverifyfiles)' >/dev/null 2>&1
}

game_up() {
  /usr/bin/pgrep -f 'PenguinHotel-Win64-Shipping' >/dev/null 2>&1
}

wait_for_steam_ready() {
  echo "Waiting for Steam to finish booting…"
  local i
  for i in $(seq 1 90); do
    if steam_main_running; then
      echo "Steam main process up (${i}s)"
      sleep 12
      return 0
    fi
    sleep 2
  done
  echo "ERROR: Steam main process never appeared"
  return 1
}

launch_game() {
  echo "Launching via steam.exe -applaunch $APP_ID ($GAME_FLAGS)"
  cd "$STEAM_DIR"
  /usr/bin/arch -x86_64 env \
    WINEPREFIX="$WINEPREFIX" \
    WINEESYNC=0 \
    WINEFSYNC=0 \
    WINEDEBUG="${WINEDEBUG:--all}" \
    WINEDLLOVERRIDES="$WINEDLLOVERRIDES" \
    MTL_HUD_ENABLED="$MTL_HUD_ENABLED" \
    "$WINE_BIN" "C:\\Program Files (x86)\\Steam\\Steam.exe" \
    -applaunch "$APP_ID" $GAME_FLAGS
}

start_steam_session() {
  if [[ "${MECCHA_NO_KILL:-0}" != "1" ]]; then
    echo "Stopping stale Wine/Steam processes…"
    meccha_kill_prefix "$WINEPREFIX" "$WINESERVER"
  fi
  bash "$NOTPOP/scripts/06-install-wrapper.sh" >/dev/null 2>&1 || true
  echo "Starting Steam (virtual desktop: $WINE_VIRTUAL_DESKTOP_NAME)…"
  meccha_notify "MECCHA CHAMELEON" "Starting Steam…"
  bash "$ROOT/scripts/launch-steam.sh" --detach
  wait_for_steam_ready
}

for attempt in 1 2; do
  start_steam_session || exit 1
  meccha_notify "MECCHA CHAMELEON" "Launching game…"
  launch_game || true

  for _ in $(seq 1 90); do
    game_up && break
    sleep 1
  done

  if game_up; then
    meccha_focus_wine
    meccha_notify "MECCHA CHAMELEON" "Ready"
    echo "Game running."
    exit 0
  fi

  if [[ "$attempt" == 1 ]]; then
    echo "Game did not appear — retrying (attempt 2)…"
    meccha_notify "MECCHA CHAMELEON" "Retrying…"
    meccha_kill_prefix "$WINEPREFIX" "$WINESERVER"
    sleep 3
  fi
done

echo "ERROR: Game did not start within timeout"
meccha_report_crash "$LOG_FILE"
meccha_notify "MECCHA CHAMELEON" "Launch failed — run: bash scripts/doctor.sh"
exit 1
