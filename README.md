# MECCHA CHAMELEON on Mac (GPTK + Wine + DXMT)

Free, self-hosted fix for **MECCHA CHAMELEON** (Steam AppID `4704690`) on Apple Silicon using **vanilla Wine + Apple's Game Porting Toolkit + DXMT** — no CrossOver, no Whisky, no paid software.

## The problem

There are two separate issues when running MECCHA CHAMELEON on Mac:

### 1. Graphics: "A D3D11-compatible GPU is required"
MECCHA CHAMELEON is Unreal Engine 5 and needs D3D11. GPTK's default **D3DMetal** doesn't properly expose D3D11 feature levels to UE5. The fix is **DXMT** — an open-source D3D11→Metal translation layer that UE5 accepts.

### 2. Auth: "Failed due to invalid or missing authentication token"
Community guides bypass the game's launcher by setting Steam launch options to point directly at `PenguinHotel-Win64-Shipping.exe`. This skips the Visual C++ prerequisite check but **breaks the Steam / Epic Online Services (EOS) auth handshake**. Online multiplayer dies.

## The fix

**Graphics (Wine 11 stack)**: Run `bash ~/Games/steam-on-m1-wine/scripts/04-install-dxmt.sh`, then `bash scripts/patch-winemac.sh`. UE5 may still crash until the **DXMT fork** is built (~30–60 min once):

```bash
bash ~/Games/steam-on-m1-wine/scripts/07-build-dxmt-fork.sh
```

**Auth**: Launch through **Steam's process chain**, not the .exe:

```bash
steam.exe -applaunch 4704690
```

Steam stays parent of the game process, injects `steam_api64.dll`, and EOS receives a valid session token.

## Requirements

- Apple Silicon Mac (M-series)
- macOS 14+ (Sonoma or later)
- Rosetta 2 (installed automatically)
- Homebrew (`/opt/homebrew`)
- ~15 GB free disk (GPTK + Steam + game)
- Windows Steam account that owns MECCHA CHAMELEON

## Quick start

**Steam uses Wine 11** (GPTK Wine 7.7 cannot boot the 2026 Steam client). Game auth still uses `steam.exe -applaunch`.

```bash
cd ~/Games/meccha-chameleon-gptk
git clone https://github.com/spdoub/meccha-chameleon-mac.git .  # if fresh

# One-time: Wine 11 + Steam wrapper (auto-clones notpop/steam-on-m1-wine)
bash scripts/launch-steam.sh

# Or click: ~/Applications/Steam on M1 Wine.app
# Log in, install MECCHA CHAMELEON from your library

bash scripts/clear-launch-options.sh --fix --set "-dx11"
bash scripts/install-meccha-app.sh   # Dock icon for one-click play
bash scripts/launch-meccha.sh        # or click the Dock icon
```

## Play from the Dock

After installing the game in Steam:

| Dock app | What it does |
|----------|----------------|
| **Steam on M1 Wine** | Opens Steam (install games, log in) |
| **MECCHA CHAMELEON** | Launches the game via `steam.exe -applaunch 4704690` (keeps online auth working) |

Install the game launcher:

```bash
bash scripts/install-meccha-app.sh
```

Then drag **MECCHA CHAMELEON** from `~/Applications` onto your Dock. First launch can take ~3 minutes.

You can also click **Play** inside Steam's library — just don't set launch options to `PenguinHotel-Win64-Shipping.exe`.

## Scripts

| Script | Purpose |
|--------|---------|
| `install.sh` | Full setup: GPTK 3.0-3, DXMT v0.80, Wine prefix, VC++/DirectX deps |
| `scripts/launch-meccha.sh` | **Primary fix** — Steam applaunch with DXMT + winemac checks |
| `scripts/patch-winemac.sh` | Rebuild Wine 11 `winemac.so` for DXMT Metal views |
| `scripts/install-meccha-app.sh` | Create `~/Applications/MECCHA CHAMELEON.app` for Dock |
| `scripts/launch-steam.sh` | Open Windows Steam for install / updates |
| `scripts/setup-dxmt.sh` | Install/revert DXMT (D3D11→Metal) in GPTK |
| `scripts/clear-launch-options.sh` | Detect/remove Shipping.exe bypass in Steam VDF |
| `scripts/fix-steam-wine-overrides.sh` | Steam CEF + libglesv2 Wine registry fixes |
| `scripts/fix-steam-api-overrides.sh` | Set `steam_api64=n,b` DLL override |
| `scripts/debug-auth.sh` | Wine debug log for auth/EOS failures |
| `cleanup.sh` | Remove everything this project installed |

## Fallback workflow

If applaunch alone doesn't restore multiplayer:

1. **Clear bad launch options** — `bash scripts/clear-launch-options.sh --fix`
2. **DLL overrides** — `bash scripts/fix-steam-api-overrides.sh`
3. **Debug log** — `bash scripts/debug-auth.sh` → inspect `logs/auth-debug-*.log`
4. **Epic link** — Ensure your Epic account is linked to the same Steam account at [epicgames.com](https://www.epicgames.com/account/connections)

## Environment variables

| Variable | Default | Notes |
|----------|---------|-------|
| `WINEPREFIX` | `~/Library/Application Support/MecchaChameleonGPTK` | Isolated prefix |
| `GAME_FLAGS` | `-dx11` | Passed after `-applaunch`; set empty to omit |
| `SKIP_GPTK` | `0` | `1` = skip GPTK download (already installed) |
| `SKIP_DEPS` | `0` | `1` = skip winetricks redistributables |
| `SKIP_DXMT` | `0` | `1` = skip DXMT (use D3DMetal only) |
| `DEBUG_CHANNELS` | see `debug-auth.sh` | WINEDEBUG filters |

## How it works

```
install.sh
  ├── Downloads GPTK 3.0-3 (Gcenx prebuild) → ~/Applications/
  ├── Patches DXMT v0.80 into GPTK's Wine libs (D3D11→Metal)
  ├── Creates isolated Wine prefix with Win10 registry
  ├── Installs VC++ 2010–2022, DirectX, XInput, FAudio via winetricks
  └── Installs Windows Steam + configures steam_api64 DLL override

launch-meccha.sh
  ├── Checks for Shipping.exe launch option bypass → removes if found
  ├── Runs: steam.exe -applaunch 4704690 -dx11
  │         ↑ Steam stays parent process
  │         ↑ steam_api64.dll injected normally
  │         ↑ EOS auth handshake completes
  └── Game launches with working online multiplayer
```

## DXMT management

GPTK 3.0-3 uses Wine 7.7 (Apple's fork). DXMT officially targets Wine 8+, so it may not fully work. GPTK's built-in **D3DMetal 3.0** already supports D3D9–D3D12 and may be sufficient. If you get a crash at launch, revert DXMT and try D3DMetal alone:

```bash
# Revert to D3DMetal
bash scripts/setup-dxmt.sh --undo

# Re-install DXMT
bash scripts/setup-dxmt.sh
```

## Steam UI troubleshooting

If `launch-steam.sh` runs but no window appears (only Wine text in the terminal):

1. **This is normal noise** — Wine debug output is redirected to `logs/steam-launch.log`. Ignore the terminal.
2. **Wait 3–5 minutes** on first launch. Check the **Dock** for a Steam or Wine icon and click it.
3. **Avoid display mirroring** — Steam on Wine crashes when macOS is mirroring to an external display.
4. **Run overrides** — `bash scripts/fix-steam-wine-overrides.sh`
5. **Use Wine 11** — GPTK Wine 7.7 cannot boot the 2026 Steam client. `launch-steam.sh` auto-clones [notpop/steam-on-m1-wine](https://github.com/notpop/steam-on-m1-wine) and installs **Steam on M1 Wine.app**.

## What not to do

- Do **not** set Steam launch options to `PenguinHotel-Win64-Shipping.exe`
- Do **not** use `whisky run … Shipping.exe` or a desktop shortcut to the .exe
- Do **not** launch the game outside of Steam's process tree
- Do **not** expect native macOS Steam to auth the Windows game binary

## Credits

- [Gcenx](https://github.com/Gcenx/game-porting-toolkit) — GPTK prebuilds
- [3Shain/dxmt](https://github.com/3Shain/dxmt) — D3D11→Metal translation
- [feiyuehchen/Meccha-Chameleon-For-MAC](https://github.com/feiyuehchen/Meccha-Chameleon-For-MAC) — Whisky-based setup reference
- [nothinglo/meccha-chameleon-mac](https://github.com/nothinglo/meccha-chameleon-mac) — Sikarugir-based setup reference

## Logs

Install and debug logs: `~/Games/meccha-chameleon-gptk/logs/`

## License

Scripts: MIT. GPTK: Apple license. DXMT: MIT/LGPL. Steam / game: Valve / developer terms.
