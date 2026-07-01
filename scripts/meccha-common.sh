#!/usr/bin/env bash
# Shared helpers for MECCHA launch, doctor, and bootstrap scripts.

meccha_notify() {
  /usr/bin/osascript -e "display notification \"$2\" with title \"$1\"" 2>/dev/null || true
}

meccha_detect_display_size() {
  local bounds width height
  bounds=$(/usr/bin/osascript -e 'tell application "Finder" to get bounds of window of desktop' 2>/dev/null || true)
  if [[ "$bounds" =~ ,[[:space:]]*([0-9]+),[[:space:]]*([0-9]+)$ ]]; then
    width="${BASH_REMATCH[1]}"
    height="${BASH_REMATCH[2]}"
    if [[ "$width" -gt 0 && "$height" -gt 0 ]]; then
      echo "${width}x${height}"
      return 0
    fi
  fi
  echo "1440x900"
}

meccha_kill_prefix() {
  local prefix="${1:-$WINEPREFIX}"
  local wineserver="${2:-$WINESERVER}"
  if [[ -x "$wineserver" ]]; then
    WINEPREFIX="$prefix" "$wineserver" -k 2>/dev/null || true
    sleep 2
  fi
  local patterns='steam\.exe|steamwebhelper|steamservice|wineserver|wine64-preloader|winedevice|explorer\.exe'
  local to_kill
  to_kill=$(/usr/bin/pgrep -f "$patterns" 2>/dev/null || true)
  if [[ -n "$to_kill" ]]; then
    # shellcheck disable=SC2086
    /bin/kill -9 $to_kill 2>/dev/null || true
    sleep 2
  fi
}

meccha_kill_stale_launchers() {
  local self="${1:-$$}"
  local pid
  while IFS= read -r pid; do
    [[ -z "$pid" || "$pid" == "$self" ]] && continue
    /bin/kill -9 "$pid" 2>/dev/null || true
  done < <(/usr/bin/pgrep -f 'scripts/launch-meccha\.sh' 2>/dev/null || true)
}

meccha_purge_steam_locks() {
  local htmlcache="${1:-}"
  [[ -n "$htmlcache" && -d "$htmlcache" ]] || return 0
  find "$htmlcache" -maxdepth 3 \
    \( -name 'Singleton*' -o -name '*.lock' -o -name 'CrashpadMetrics*.pma' -o -name 'lockfile' \) \
    -delete 2>/dev/null || true
}

# macOS has no flock(1) — use an atomic mkdir lock directory.
meccha_acquire_launch_lock() {
  local lock_dir="${1:-}"
  [[ -n "$lock_dir" ]] || return 1
  if mkdir "$lock_dir" 2>/dev/null; then
    echo "$$" >"$lock_dir/pid"
    return 0
  fi
  if [[ -f "$lock_dir/pid" ]]; then
    local old_pid
    old_pid=$(/bin/cat "$lock_dir/pid" 2>/dev/null || true)
    if [[ -n "$old_pid" ]] && ! /bin/kill -0 "$old_pid" 2>/dev/null; then
      /bin/rm -rf "$lock_dir"
      mkdir "$lock_dir" 2>/dev/null || return 1
      echo "$$" >"$lock_dir/pid"
      return 0
    fi
  fi
  return 1
}

meccha_release_launch_lock() {
  local lock_dir="${1:-}"
  [[ -n "$lock_dir" ]] && /bin/rm -rf "$lock_dir"
}

meccha_build_game_flags() {
  local flags="${GAME_FLAGS:--dx11 -force-d3d11-no-singlethreaded}"
  if [[ "${MECCHA_FULLSCREEN:-0}" == "1" ]]; then
    flags="$flags -screen-fullscreen 1"
  else
    flags="$flags -screen-fullscreen 0"
  fi
  echo "$flags"
}

meccha_focus_wine() {
  /usr/bin/osascript <<'APPLESCRIPT' 2>/dev/null || true
tell application "System Events"
  repeat with p in (every process whose name contains "wine")
    try
      set frontmost of p to true
      repeat with w in (every window of p)
        try
          perform action "AXRaise" of w
        end try
      end repeat
    end try
  end repeat
end tell
APPLESCRIPT
}

meccha_latest_crash() {
  find "$WINEPREFIX/drive_c/users" -path '*/Chameleon/Saved/Crashes/*/*.xml' 2>/dev/null \
    | /usr/bin/xargs /bin/ls -t 2>/dev/null | head -n1
}

meccha_report_crash() {
  local log="${1:-$LOG_DIR/meccha-launch.log}"
  local crash
  crash=$(meccha_latest_crash)
  if [[ -n "$crash" && -f "$crash" ]]; then
    {
      echo ""
      echo "=== Latest crash report: $crash ==="
      /usr/bin/head -80 "$crash"
    } >>"$log"
    meccha_notify "MECCHA CHAMELEON" "Game crashed — see logs/meccha-launch.log"
  fi
}

meccha_remove_steam_from_dock() {
  /usr/bin/python3 <<'PY'
import plistlib, os, subprocess

plist_path = os.path.expanduser("~/Library/Preferences/com.apple.dock.plist")
steam_markers = ("Steam on M1 Wine", "Wine Stable", "wine-stable")

with open(plist_path, "rb") as f:
    dock = plistlib.load(f)

apps = dock.get("persistent-apps", [])
filtered = []
removed = 0
for tile in apps:
    data = tile.get("tile-data", {})
    fd = data.get("file-data", {})
    url = fd.get("_CFURLString", "")
    label = str(data.get("file-label", ""))
    if any(m in url or m in label for m in steam_markers):
        removed += 1
        continue
    filtered.append(tile)

if removed:
    dock["persistent-apps"] = filtered
    with open(plist_path, "wb") as f:
        plistlib.dump(dock, f)
    subprocess.run(["killall", "Dock"], check=False)
PY
}

meccha_wine_version() {
  /usr/bin/arch -x86_64 "$WINE_BIN" --version 2>/dev/null | /usr/bin/head -n1 || echo "unknown"
}

meccha_check_wine_version() {
  local current known_file="$PROJECT_ROOT/.known-wine-version"
  current=$(meccha_wine_version)
  if [[ ! -f "$known_file" ]]; then
    echo "$current" >"$known_file"
    return 0
  fi
  local known
  known=$(/bin/cat "$known_file")
  if [[ "$current" != "$known" ]]; then
    echo "WARN: Wine changed ($known -> $current). Run: bash scripts/preflight-launch.sh" >&2
    echo "      To pin: brew pin wine-stable  (after install)" >&2
    return 1
  fi
  return 0
}

meccha_has_xcode() {
  [[ -d /Applications/Xcode.app ]] && /usr/bin/xcodebuild -version >/dev/null 2>&1
}

meccha_dxmt_fork_ready() {
  local root="${1:-$PROJECT_ROOT}"
  local wine_app="${2:-$WINE_APP}"
  local d3d="$wine_app/Contents/Resources/wine/lib/wine/x86_64-windows/d3d11.dll"
  local winemac="$wine_app/Contents/Resources/wine/lib/wine/x86_64-unix/winemac.so"
  [[ -f "$root/.dxmt-fork-built" ]] || return 1
  local sz
  sz=$(stat -f%z "$d3d" 2>/dev/null || echo 0)
  (( sz >= 15000000 )) || return 1
  nm -gU "$winemac" 2>/dev/null | grep -q macdrv_view_create_metal_view
}

meccha_require_dxmt_for_play() {
  local root="${1:-$PROJECT_ROOT}"
  local game_exe="${2:-}"
  [[ -n "$game_exe" && -f "$game_exe" ]] || return 0
  if meccha_dxmt_fork_ready "$root" "$WINE_APP"; then
    return 0
  fi
  if meccha_has_xcode; then
    echo "DXMT fork not built — UE5 will crash on launch." >&2
    echo "Run: bash scripts/build-dxmt-fork.sh  (~30–60 min, one time)" >&2
  else
    echo "Cannot play yet — the DXMT graphics fork must be compiled on this Mac." >&2
    echo "Install full Xcode from the App Store (Command Line Tools alone is not enough)," >&2
    echo "then run: bash scripts/build-dxmt-fork.sh" >&2
  fi
  return 1
}
