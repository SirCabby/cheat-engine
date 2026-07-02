# CLAUDE.md — Cheat Engine (SirCabby personal fork)

Guidance for future Claude Code sessions working in this repo.

## What this repo is
A **personal fork** of Cheat Engine (upstream: `github.com/cheat-engine/cheat-engine`), cloned to
build our **own clean `win64` CE from source** and customize it. Motivation: remove nag/adware
behaviors and (later) improve Mono-under-Proton behavior. Runs under **Wine/Proton on Linux**
(CachyOS, KDE Plasma 6 Wayland) to cheat in **single-player** games (e.g. *Blasphemous*, a
Unity/Mono game).

Upstream source currently sits at **7.5.1** (the public source lags the released binaries; 7.6/7.7
are binary-only). `git remote`: `origin` = this fork, `upstream` = cheat-engine/cheat-engine.

### Runtime context (outside this repo)
A prebuilt clean **CE 7.4 "Lite"** is already installed & wired on this machine:
- Launcher `~/.local/bin/cheatengine` (auto-attaches to a running Steam/Proton game via
  `protontricks-launch`, else standalone; opens `.CT` tables; `cheatengine63` = the old 6.3 build).
- Wine prefix `~/.local/share/wineprefixes/cheatengine7`.
This fork exists to eventually replace that prebuilt exe with our **source-built** one.

## Repo layout (what matters)
- **`Cheat Engine/`** — the main **Lazarus / Object Pascal** GUI app (this is what you build).
  - `cheatengine.lpi` / `.lpr` — main project (**target: win64**, widgetset win32). `cecore.lpi` = core.
  - `MainUnit.pas` — main form + app startup (`FormShow`). **Celebration nag popups live ~line 8560.**
  - `LuaHandler.pas` — huge; registers the CE Lua API (incl. `supportCheatEngine` = the trainer ad).
  - `trainergenerator.pas` — the "make a trainer" feature (embeds the ad; forces "support CE" on).
  - **`bin/`** — the RUNTIME shipped next to the exe:
    - `main.lua` (tiny bootstrap), `defines.lua`, `celua.txt` (Lua API docs).
    - `autorun/*.lua` — Lua-scripted features loaded at startup, **editable without recompiling**:
      `monoscript.lua` (Mono dissector + `LaunchMonoDataCollector`), `dotnetinfo.lua`/`DotNet*` (.NET),
      `versioncheck.lua` (update nag, phones home), `ceshare*` (online sharing, phones home).
    - `autorun/dlls/MonoDataCollector{32,64}.dll` and other **committed prebuilt DLLs** (speedhack,
      lua53, d3dhook, luaclient…) — so you usually only need to build the **exe**, not the C projects.
  - `MonoDataCollector/` — C++ source for the injected Mono DLL (rebuild only if changing Mono internals).
- `DBKKernel/` — Windows kernel driver (C). **Do NOT build for Wine** (no driver loads under Wine;
  CE falls back to user-mode `ReadProcessMemory`/VEH).
- `dbvm/`, `DBVM UEFI/` — Dark Byte's hypervisor (advanced; irrelevant under Wine).
- `lua/` — Lua 5.3 sources. Language mix: Pascal ~51% (app), C ~40% (driver/DLLs), Lua ~4%.

## Build — target win64 exe, run under Wine  (INTENDED PLAN — not yet verified end-to-end)
Toolchain: **FPC 3.2.2** (Arch pkg `fpc`; the exact version CE's README wants) + **Lazarus** (for the
LCL) + `fpc-src`. Approach: cross-compile the main exe on Linux → win64 (no Wine needed to build).
1. `sudo pacman -S --needed fpc fpc-src lazarus`
2. Build the FPC **win64 cross-compiler + RTL** from `fpc-src` (FPC uses its **internal linker** for
   Windows targets → no external mingw/binutils needed):
   `cd /usr/lib/fpc/src && sudo make crossinstall CPU_TARGET=x86_64 OS_TARGET=win64 INSTALL_PREFIX=/usr`
   → verify `/usr/lib/fpc/3.2.2/units/x86_64-win64/` exists; ensure `fpc.cfg` sees it.
3. Build CE (lazbuild compiles the LCL for the target on demand):
   `lazbuild --cpu=x86_64 --os=win64 --ws=win32 "Cheat Engine/cheatengine.lpi"`
4. Assemble runtime: put the built `cheatengine-x86_64.exe` next to `Cheat Engine/bin/` (**same
   version** — exe↔Lua API are version-coupled), strip `autorun/versioncheck.lua` + `autorun/ceshare*`,
   install into a Wine prefix, point `~/.local/bin/cheatengine` at it.

Alternative (matches README exactly, slower): install **Lazarus 2.2.2 win64** into a Wine prefix
(`lazarus-2.2.2-fpc-3.2.2-win64.exe` then the `cross-i386-win32-win64` add-on) and run
`wine lazbuild.exe "cheatengine.lpi"`. Secondary projects (speedhack.lpr, luaclient.lpr,
monodatacollector.sln, tcclib.sln, …) only if you modify them — see upstream `README.md`.

## Nag / annoyance map (for removal)
- **Celebration popups** — `MainUnit.pas` ~8560: birthday (`if month=7 and day=1 then
  ShowMessage(strhappybirthday)` — fires *every* July 1, **no "already shown" guard**), new-year,
  "future" (year≥2030), april-fools ("chEAt Engine" rename). **Already commented out in this fork.**
- **Trainer ad** — `supportCheatEngine` (LuaHandler.pas) + `trainergenerator.pas`: ad window embedded
  in GENERATED trainers, forced on. Only affects trainers you build.
- **Update nag / telemetry** — `bin/autorun/versioncheck.lua`, `bin/autorun/ceshare*` (strip at deploy).
- **Audio "laughter" nag** — `eatme.lua` + `soundextension.lua` + `dnd.dat` (renamed mp3). **BINARY-ONLY
  in 7.6/7.7 releases; NOT in this source.** Building from source, you never get it.
- **Lite nag** — `limited.lua` (startup "stripped down installation" popup + random "Baby/Neutered
  Cheat Engine" window title). Only in the prebuilt "Lite" packaging, not in source.

## Changes made in this fork
- `Cheat Engine/MainUnit.pas`: commented out the birthday / new-year / future / april-fools nag popups
  (search for `Celebration nag popups`).

## Conventions / gotchas
- Lua is **5.3**. Build target is **win64**; build only the app and reuse the committed DLLs.
- Never build `DBKKernel/` or `dbvm/` for a Wine setup.
- Sync upstream later with: `git fetch upstream && git rebase upstream/master`.
