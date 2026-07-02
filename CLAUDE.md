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

### Runtime context (outside this repo)  — SOURCE BUILD IS NOW LIVE (2026-07-02)
The prebuilt CE 7.4 "Lite" **and** the old CE 6.3 have been **removed**. The machine now runs our
**source-built 7.5.1** exe:
- Launcher `~/.local/bin/cheatengine` runs the exe **in-place from the repo build dir**
  (`Cheat Engine/bin/cheatengine-x86_64.exe`) — so a rebuild is picked up with no reinstall. Still
  auto-attaches to a running Steam/Proton game via `protontricks-launch`, else standalone; opens `.CT`.
- `~/.local/bin/cheatengine-rebuild` — one-command rebuild helper (wraps the lazbuild line below).
- Wine prefix `~/.local/share/wineprefixes/cheatengine7` is **reused** as the exe's Wine environment
  (its old `Program Files/Cheat Engine 7.4` install dir was deleted; the prefix itself stays).
- Menu/desktop entry: `~/.local/share/applications/cheatengine.desktop` (replaced the misnamed
  `cheatengine-63.desktop`); it is the Kickoff favorite (KActivities DB row updated accordingly).
- Removed: the whole `~/.local/share/wineprefixes/cheatengine` (6.3) prefix, `cheatengine63` launcher,
  and stale `wine-extension-{ct,cetrainer}.desktop` handlers that pointed at the deleted 6.3 prefix.

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

## Build — target win64 exe, run under Wine  (VERIFIED working 2026-07-02 — just run `cheatengine-rebuild`)
Toolchain (installed): **FPC 3.2.2** (Arch pkg `fpc`) + **Lazarus 4.8** (`lazarus`) + `fpc-src`.
Cross-compiles on Linux → win64; no Wine needed to build. **Day-to-day: just run `cheatengine-rebuild`**
(it wraps the lazbuild line below and the launcher runs the output in-place). Full recipe if setting up
fresh:
1. `sudo pacman -S --needed fpc fpc-src lazarus`  *(needs your password — Claude can't run sudo)*
2. Build the FPC **win64 cross-RTL** (FPC uses its **internal linker** → no mingw/binutils needed):
   `cd /usr/lib/fpc/src && sudo make crossinstall CPU_TARGET=x86_64 OS_TARGET=win64 INSTALL_PREFIX=/usr`
   → verify `/usr/lib/fpc/3.2.2/units/x86_64-win64/rtl/system.ppu` exists.
3. Register the bundled VirtualTreeView pkg (once), then build the **Release 64-Bit** mode:
   `lazbuild --lazarusdir=/usr/lib/lazarus --add-package-link /usr/lib/lazarus/components/virtualtreeview/laz.virtualtreeview_package.lpk`
   `lazbuild --lazarusdir=/usr/lib/lazarus --build-mode="Release 64-Bit" --cpu=x86_64 --os=win64 --ws=win32 "Cheat Engine/cheatengine.lpi"`
   → output `Cheat Engine/bin/cheatengine-x86_64.exe` (17 MB PE32+). `bin/`, `lib/`, `*.dbg` are gitignored.
   **GOTCHAS (all handled):** `--lazarusdir` is required (fresh lazbuild has no LazarusDirectory set).
   Lazarus 4.8 ≠ CE's expected 2.2.2, so two source fixes were needed — see "Changes made". The win64
   LCL/pkg units compile on demand into a writable per-user dir (system `/usr/lib/lazarus` stays read-only).
4. No install/copy step — the launcher runs the exe straight from `Cheat Engine/bin/` (exe↔Lua API are
   version-coupled and the repo's own `bin/` IS the matching runtime). Telemetry is already stripped in
   the tree (see "Changes made"), so a rebuild is instantly live.

Alternative (matches README exactly, slower): install **Lazarus 2.2.2 win64** into a Wine prefix
(`lazarus-2.2.2-fpc-3.2.2-win64.exe` then the `cross-i386-win32-win64` add-on) and run
`wine lazbuild.exe "cheatengine.lpi"` — avoids the 4.8 source patches. Secondary projects (speedhack.lpr,
luaclient.lpr, monodatacollector.sln, tcclib.sln, …) only if you modify them — see upstream `README.md`.

## Nag / annoyance map (for removal)
- **Celebration popups** — `MainUnit.pas` ~8560: birthday (`if month=7 and day=1 then
  ShowMessage(strhappybirthday)` — fires *every* July 1, **no "already shown" guard**), new-year,
  "future" (year≥2030), april-fools ("chEAt Engine" rename). **Already commented out in this fork.**
- **Trainer ad** — `supportCheatEngine` (LuaHandler.pas) + `trainergenerator.pas`: ad window embedded
  in GENERATED trainers, forced on. Only affects trainers you build.
- **Update nag / telemetry** — `bin/autorun/versioncheck.lua`, `bin/autorun/ceshare*`. **Already
  neutralized in this fork** via a `do return end` guard (see "Changes made"). No deploy-time step needed.
- **Audio "laughter" nag** — `eatme.lua` + `soundextension.lua` + `dnd.dat` (renamed mp3). **BINARY-ONLY
  in 7.6/7.7 releases; NOT in this source.** Building from source, you never get it.
- **Lite nag** — `limited.lua` (startup "stripped down installation" popup + random "Baby/Neutered
  Cheat Engine" window title). Only in the prebuilt "Lite" packaging, not in source.

## Changes made in this fork
- `Cheat Engine/MainUnit.pas`: commented out the birthday / new-year / future / april-fools nag popups
  (search for `Celebration nag popups`).
- **Lazarus 4.8 build compat** (needed because system Lazarus is 4.8, not CE's 2.2.2):
  - `Cheat Engine/cheatengine.lpi`: added `-dlaztrunk` to the **Release 64-Bit** build mode's
    CustomOptions. CE's `{$ifdef laztrunk}` branches switch to modern units (e.g. `AVL_Tree` instead of
    the removed `laz_avl_Tree`).
  - `Cheat Engine/cesupport.pas`: added `LazFileUtils` to the `uses` clause (`ExtractFileNameWithoutExt`
    moved there in modern Lazarus).
- **Telemetry stripped in-tree** (safe: versioncheck has no other refs; ceshare only referenced by
  `.po` translations): `bin/autorun/versioncheck.lua` and `bin/autorun/ceshare.lua` each start with a
  `do return end` guard, so they load as no-ops (no update/online-sharing phone-home). The `ceshare/`
  subdir is never loaded once `ceshare.lua` early-returns. Minimal one-line diffs = easy upstream rebase.

## Conventions / gotchas
- Lua is **5.3**. Build target is **win64**; build only the app and reuse the committed DLLs.
- Never build `DBKKernel/` or `dbvm/` for a Wine setup.
- Sync upstream later with: `git fetch upstream && git rebase upstream/master`.
