#!/usr/bin/env bash
#
# Launch MECCHA CHAMELEON — one Wine session, Steam flags + applaunch together.

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
HTMLCACHE="$WINEPREFIX/drive_c/users/$USER/AppData/Local/Steam/htmlcache"
GAME_WAIT_SEC="${MECCHA_GAME_WAIT_SEC:-240}"
LOCK_DIR="${LOG_DIR}/.launch.lock.d"

mkdir -p "$LOG_DIR"
exec >>"$LOG_FILE" 2>&1

meccha_notify "MECCHA CHAMELEON" "Starting…"

if ! meccha_acquire_launch_lock "$LOCK_DIR"; then
  meccha_notify "MECCHA CHAMELEON" "Already launching — please wait"
  exit 0
fi
trap 'meccha_release_launch_lock "$LOCK_DIR"' EXIT

echo "Stopping stale Wine/Steam processes…"
meccha_kill_stale_launchers "$$"
meccha_kill_prefix "$WINEPREFIX" "$WINESERVER"
meccha_purge_steam_locks "$HTMLCACHE"

bash "$ROOT/scripts/preflight-launch.sh"

GAME_FLAGS="$(meccha_build_game_flags)"
export WINEESYNC=0 WINEFSYNC=0
export WINEDLLOVERRIDES="dxgi,d3d11,d3d10core=n,b;bcrypt=b;ncrypt=b;gameoverlayrenderer,gameoverlayrenderer64=d;steam_api64=n,b"
export MTL_HUD_ENABLED="${MECCHA_HUD:-${MTL_HUD_ENABLED:-0}}"

if [[ ! -f "$GAME_EXE" ]]; then
  meccha_notify "MECCHA CHAMELEON" "Install the game in Steam first"
  open "$INSTALL_APP_DIR/Steam on M1 Wine.app" 2>/dev/null || bash "$ROOT/scripts/launch-steam.sh" --detach
  exit 1
fi

game_up() {
  /usr/bin/pgrep -f 'PenguinHotel-Win64-Shipping' >/dev/null 2>&1
}

steam_explorer_up() {
  /usr/bin/pgrep -f "desktop=${VD_NAME}" >/dev/null 2>&1 \
    && /usr/bin/pgrep -f 'Steam\.exe.*-noverifyfiles' >/dev/null 2>&1
}

launch_session() {
  local vd_size
  vd_size="$(meccha_detect_display_size)"
  echo "Starting session: $VD_NAME @ $vd_size"
  echo "  steam.exe -no-cef-sandbox -cef-single-process -noverifyfiles -applaunch $APP_ID $GAME_FLAGS"
  cd "$STEAM_DIR"
  /usr/bin/nohup /usr/bin/arch -x86_64 env \
    WINEPREFIX="$WINEPREFIX" \
    WINEESYNC=0 \
    WINEFSYNC=0 \
    WINEDEBUG="${WINEDEBUG:--all}" \
    WINEDLLOVERRIDES="$WINEDLLOVERRIDES" \
    MTL_HUD_ENABLED="$MTL_HUD_ENABLED" \
    "$WINE_BIN" explorer.exe \
    "/desktop=${VD_NAME},${vd_size}" \
    "C:\\Program Files (x86)\\Steam\\Steam.exe" \
    -no-cef-sandbox -cef-single-process -noverifyfiles \
    -applaunch "$APP_ID" $GAME_FLAGS \
    >>"$LOG_FILE" 2>&1 &
}

for attempt in 1 2; do
  if [[ "$attempt" -gt 1 ]]; then
    echo "Retrying launch (attempt $attempt)…"
    meccha_kill_prefix "$WINEPREFIX" "$WINESERVER"
    meccha_purge_steam_locks "$HTMLCACHE"
    sleep 3
  fi
  bash "$NOTPOP/scripts/06-install-wrapper.sh" >/dev/null 2>&1 || true
  meccha_notify "MECCHA CHAMELEON" "Launching…"
  launch_session

  for ((i = 1; i <= GAME_WAIT_SEC; i++)); do
    if game_up; then
      sleep 2
      meccha_focus_wine
      meccha_notify "MECCHA CHAMELEON" "Ready"
      echo "Game running."
      exit 0
    fi
    if (( i % 15 == 0 )); then
      meccha_focus_wine
      bash "$NOTPOP/scripts/06-install-wrapper.sh" >/dev/null 2>&1 || true
    fi
    sleep 1
  done
done

echo "ERROR: Game did not start within ${GAME_WAIT_SEC}s"
meccha_report_crash "$LOG_FILE"
meccha_notify "MECCHA CHAMELEON" "Launch failed — run: bash scripts/doctor.sh"
exit 1
