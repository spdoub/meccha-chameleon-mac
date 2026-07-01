# MECCHA CHAMELEON on Mac (Wine 11 + DXMT)

Free setup for **MECCHA CHAMELEON** (Steam AppID `4704690`) on Apple Silicon using **Wine 11 + DXMT** — no CrossOver, no Whisky.

**One Dock icon.** Click **MECCHA CHAMELEON** to play. Steam runs silently in the background inside a single window — no extra Steam/Wine icons cluttering the Dock.

## Quick start

```bash
git clone https://github.com/spdoub/meccha-chameleon-mac.git ~/Games/meccha-chameleon-gptk
cd ~/Games/meccha-chameleon-gptk
bash install.sh
```

First run takes ~45–90 minutes (DXMT fork compile). Re-runs are fast.

Then click **MECCHA CHAMELEON** in the Dock. First time only: install the game from Steam when prompted.

## Another Mac (fast path)

On the working Mac:

```bash
bash scripts/export-prefix.sh ~/Desktop/wine-steam.tgz
```

AirDrop the file, then on the new Mac:

```bash
git clone https://github.com/spdoub/meccha-chameleon-mac.git ~/Games/meccha-chameleon-gptk
cd ~/Games/meccha-chameleon-gptk
bash scripts/bootstrap-mac.sh ~/Downloads/wine-steam.tgz
```

## Install options

| Variable | Effect |
|----------|--------|
| `SKIP_DXMT_FORK=1` | Skip long graphics build |
| `SKIP_STEAM=1` | Wine + prefix only |
| `SKIP_DOCK=1` | Don't auto-pin Dock icon |

## Launch options

| Variable | Effect |
|----------|--------|
| `MECCHA_HUD=1` | Metal FPS overlay (debug) |
| `MECCHA_FULLSCREEN=1` | Fullscreen game |
| `MECCHA_NO_KILL=1` | Don't stop existing Wine session |

```bash
MECCHA_HUD=1 bash scripts/launch-meccha.sh
```

## Scripts

| Script | Purpose |
|--------|---------|
| `install.sh` | Full one-shot setup |
| `scripts/bootstrap-mac.sh` | New Mac: restore prefix tarball or fresh install |
| `scripts/export-prefix.sh` | Create `wine-steam.tgz` for another Mac |
| `scripts/doctor.sh` | One-screen health check |
| `scripts/launch-meccha.sh` | Play (single window, silent Steam) |
| `scripts/preflight-launch.sh` | Idle-week recovery (auto on launch) |
| `scripts/fix-wow64-steam.sh` | Repair broken 32-bit Steam |
| `scripts/install-meccha-app.sh` | Create Dock app with game icon |
| `scripts/launch-steam.sh` | Steam UI only (install/update games) |

## Is it working?

```bash
bash scripts/doctor.sh
```

All green ✓ = good to play.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Nothing happens when clicking Dock icon | Wait 30s; check `logs/meccha-launch.log`; run `bash scripts/doctor.sh` |
| `kernel32.dll` / empty `syswow64` | `bash scripts/fix-wow64-steam.sh --fix` |
| Broken after a week idle / Wine upgrade | Click Dock app (preflight auto-runs) or `bash scripts/preflight-launch.sh` |
| Icon flashes and exits | `bash scripts/build-dxmt-fork.sh` |
| D3D11 GPU required | `bash scripts/patch-winemac.sh` then `build-dxmt-fork.sh` |
| Extra Steam icons in Dock | `bash scripts/add-meccha-to-dock.sh` (removes Steam tile) |

**Do not** set Steam launch options to `PenguinHotel-Win64-Shipping.exe` (breaks EOS multiplayer).

## vs a normal PC

Same game, same Steam auth. Differences: ~30s cold start, runs in one Wine window, graphics via DXMT (D3D11→Metal), windowed by default. See commit history for technical details.

## Credits

- [notpop/steam-on-m1-wine](https://github.com/notpop/steam-on-m1-wine)
- [notpop/dxmt](https://github.com/notpop/dxmt)
- [3Shain/dxmt](https://github.com/3Shain/dxmt)

## License

Scripts: MIT. Wine/DXMT/Steam: upstream licenses.
