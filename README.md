# MECCHA CHAMELEON on Mac (Wine 11 + DXMT)

Free setup for **MECCHA CHAMELEON** (Steam AppID `4704690`) on Apple Silicon using **Wine 11 + DXMT** — no CrossOver, no Whisky.

## Reproduce on another Mac (from GitHub)

```bash
git clone https://github.com/spdoub/meccha-chameleon-mac.git ~/Games/meccha-chameleon-gptk
cd ~/Games/meccha-chameleon-gptk
bash install.sh
```

**First run takes ~45–90 minutes** (LLVM + DXMT fork compile). Re-runs are fast.

Then:
1. Open **Steam on M1 Wine** from `~/Applications` (or Dock)
2. Log in and install **MECCHA CHAMELEON**
3. Click **MECCHA CHAMELEON** in the Dock to play

### Install options

| Variable | Effect |
|----------|--------|
| `SKIP_DXMT_FORK=1` | Skip long graphics build (Steam works; game won't render yet) |
| `SKIP_STEAM=1` | Wine + prefix only; install Steam yourself |
| `SKIP_DOCK=1` | Don't auto-pin Dock icons |

```bash
# Steam UI first, graphics later:
SKIP_DXMT_FORK=1 bash install.sh
bash scripts/build-dxmt-fork.sh
```

## What `install.sh` does

1. Clones [notpop/steam-on-m1-wine](https://github.com/notpop/steam-on-m1-wine) → Wine 11, Steam, CEF wrapper
2. `scripts/patch-winemac.sh` → exports Metal APIs for DXMT
3. `scripts/build-dxmt-fork.sh` → UE5-compatible DXMT fork (with macOS 26 workarounds)
4. `scripts/install-prefix-deps.sh` → VC++ 2022 via winetricks
5. Creates **Steam on M1 Wine.app** + **MECCHA CHAMELEON.app** and pins both to Dock

## Why two launchers?

| App | Purpose |
|-----|---------|
| **Steam on M1 Wine** | Install/update games, log in |
| **MECCHA CHAMELEON** | `steam.exe -applaunch 4704690` — keeps online auth working |

**Do not** set Steam launch options to `PenguinHotel-Win64-Shipping.exe` (breaks EOS multiplayer).

## Scripts

| Script | Purpose |
|--------|---------|
| `install.sh` | **Full one-shot setup** for a new Mac |
| `scripts/build-dxmt-fork.sh` | Build/install UE5 DXMT fork (included in install.sh) |
| `scripts/patch-winemac.sh` | Patch Wine 11 `winemac.so` for DXMT |
| `scripts/launch-meccha.sh` | Launch game via Steam applaunch |
| `scripts/launch-steam.sh` | Open Steam (Wine 11) |
| `scripts/install-meccha-app.sh` | Create `~/Applications/MECCHA CHAMELEON.app` |
| `scripts/add-meccha-to-dock.sh` | Pin game icon to Dock |
| `scripts/install-prefix-deps.sh` | VC++ / fonts in Wine prefix |
| `scripts/clear-launch-options.sh` | Remove Shipping.exe bypass in Steam VDF |
| `scripts/preflight-launch.sh` | Idle-week recovery (locks, wrapper, DXMT, WoW64) |
| `scripts/fix-wow64-steam.sh` | Diagnose/repair empty `syswow64` (Steam `kernel32.dll` errors) |
| `scripts/legacy-install-gptk.sh` | Old GPTK 7.7 path (deprecated) |

## Requirements

- Apple Silicon Mac (M-series)
- macOS 14+ (Sonoma or later)
- Rosetta 2, Homebrew (`/opt/homebrew`)
- ~20 GB free disk (LLVM build + Steam + game)
- Steam account owning MECCHA CHAMELEON

## Environment

| Variable | Default |
|----------|---------|
| `WINEPREFIX` | `~/.wine-steam` |
| `WINE_APP` | `~/Applications/Wine Stable.app` |
| `NOTPOP` | `~/Games/steam-on-m1-wine` |
| `GAME_FLAGS` | `-dx11 -force-d3d11-no-singlethreaded -screen-fullscreen 0` |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `kernel32.dll` / empty `syswow64` / SteamSetup fails | `bash scripts/fix-wow64-steam.sh` then `--fix` if needed |
| Icon flashes and exits | Run `bash scripts/build-dxmt-fork.sh` |
| D3D11 GPU required | Run `bash scripts/patch-winemac.sh` then `build-dxmt-fork.sh` |
| VC++ redistributable error | `bash scripts/install-prefix-deps.sh` |
| Auth token error | Use Dock app / `launch-meccha.sh`, not direct `.exe` |
| No Dock icon | `bash scripts/add-meccha-to-dock.sh` |
| Broken after a week idle / Wine upgrade | Just click the Dock app — preflight runs automatically; or `bash scripts/preflight-launch.sh` |

Logs: `~/Games/meccha-chameleon-gptk/logs/`

## Credits

- [notpop/steam-on-m1-wine](https://github.com/notpop/steam-on-m1-wine) — Wine 11 Steam stack
- [notpop/dxmt](https://github.com/notpop/dxmt) — DXMT fork for UE5 on Mac
- [3Shain/dxmt](https://github.com/3Shain/dxmt) — D3D11→Metal

## License

Scripts: MIT. Wine/DXMT/Steam: upstream licenses.
