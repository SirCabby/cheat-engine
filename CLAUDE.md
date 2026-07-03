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
    - `autorun/dlls/`: `CEJVMTI.dll` (Java) is committed; the injected **`MonoDataCollector{32,64}.dll`
      are NOT** (upstream dropped them from git in 2021, and `bin/` is gitignored here) — **you must build
      them once** (see "Build the Mono collector DLL"). Other prebuilt DLLs (`lua53`, `d3dhook`,
      `luaclient`, speedhack…) sit in `bin/` and are reused as-is, so beyond the Mono DLL you build only the **exe**.
  - `MonoDataCollector/` — C++ source for the injected Mono DLL. **You MUST build this** (the prebuilt DLL
    isn't committed); without it every Mono script fails with "DLL Injection failed or invalid DLL version".
    Build script: `MonoDataCollector/build-mingw-dll.sh` — see "Build the Mono collector DLL".
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
`wine lazbuild.exe "cheatengine.lpi"` — avoids the 4.8 source patches. Other secondary projects
(speedhack.lpr, luaclient.lpr, tcclib.sln, …) only if you modify them — see upstream `README.md`.
(The Mono collector DLL is the exception — you always need it; build it via the subsection below, **not**
its `.sln`.)

### Build the Mono collector DLL  (REQUIRED for Mono/Unity games like *Blasphemous*)  (VERIFIED 2026-07-02)
CE's Mono features inject `bin/autorun/dlls/MonoDataCollector{32,64}.dll` into the target game. Upstream
**stopped committing** these prebuilt DLLs in 2021 (commit `09654220`) — they ship only inside the compiled
installer — and `bin/` is gitignored here, so a from-source build has **no collector DLL** and every Mono
script fails with **"DLL Injection failed or invalid DLL version"** (`bin/autorun/monoscript.lua:557`).
Build them from the in-tree C++ source (which is `MONO_DATACOLLECTORVERSION=20240511`, matching `monoscript.lua`):
1. `sudo pacman -S --needed mingw-w64-gcc`  *(one-time; provides `x86_64-w64-mingw32-g++`. Claude can't sudo.)*
2. `bash "Cheat Engine/MonoDataCollector/build-mingw-dll.sh"`  → writes both DLLs into `bin/autorun/dlls/`.
   No CE-exe rebuild needed (the collector is a runtime file): restart CE and the Mono script works. Only the
   **64-bit** DLL is needed for 64-bit games (Blasphemous is 64-bit); the script also builds 32-bit if the
   `i686-w64-mingw32-g++` cross-compiler is installed.

**Fresh-clone rebuild — yes.** Everything needed is in git *except the toolchain*: `build-mingw-dll.sh` lives
in the tracked `MonoDataCollector/` dir (NOT gitignored `bin/`), and its inputs (`MonoDataCollector/`,
`Common/Pipe.cpp`) are all tracked; only the regenerated `bin/` output is ignored. So on a clean clone:
install `mingw-w64-gcc` once, run the script. (Keep the script committed for this to hold.) The script bridges
the MSVC→mingw gaps **without editing upstream source** (so `git rebase upstream/master` stays clean):
case-alias shim headers (`Windows.h`/`TlHelp32.h`/`StdAfx.h`), `-D_WINDOWS`, force-included `<cstdint>`,
blanked `__in`/`__in_bcount` SAL macros, a generated `.def` exporting `MDC_ServerPipe` as **DATA** (GNU ld
needs the keyword — CE reads/writes the pipe handle at that address), and `-static-lib*` so the injected DLL
carries no libgcc/libstdc++/winpthread dependency.

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
- **"Newer version of CE out" table nag** — `Cheat Engine/OpenSave.pas` ~401: commented out the
  `if (version>CurrentTableVersion) then showmessage(rsOSThereIsANewerVersion…)`. This popup fires when
  loading a `.CT` whose `CheatEngineTableVersion` (>45 for e.g. 7.7 tables) exceeds our 7.5.1 build's
  `_CurrentTableVersion=45`. This is the popup that looks like an update nag "on launch" (it's really
  on table-load). NOTE: this is the compiled exe, so **it only takes effect after `cheatengine-rebuild`**.
- **Mono collector DLL build (added 2026-07-02)** — Mono scripts on Blasphemous failed with "DLL Injection
  failed or invalid DLL version" because the injected `MonoDataCollector64.dll` doesn't exist in a
  from-source build (upstream dropped the prebuilt Mono DLLs in 2021; `bin/` is gitignored). Added
  `Cheat Engine/MonoDataCollector/build-mingw-dll.sh` to cross-compile it from the in-tree C++ source with
  mingw-w64. Built & verified: PE32+ x86-64, `MDC_ServerPipe` DATA export, version 20240511, no runtime
  deps. Full recipe in "Build the Mono collector DLL". (New file, not a source edit → no upstream-rebase risk.)
- **Dark mode (added 2026-07-02)** — CE already ships a full dark-mode engine (the bundled `betterControls`
  unit + its custom-drawn `New*` controls), but it never activated under Wine: it triggers off the Windows
  `AppsUseLightTheme` registry key (absent in our prefix) and pulls its palette from `OpenThemeData('ItemsView')`,
  which returns 0 under Wine (no visual style) — so even when forced on, `newForm.pas` painted forms `$242424`
  with **black text** (`ColorSet.FontColor` left at the light default). Fixed with two edits + one new file:
  (1) added `-dFORCEDDARKMODE` to the **Release 64-Bit** build mode's CustomOptions in `cheatengine.lpi`
  (mirrors the `-dlaztrunk` addition) → `betterControls.ShouldAppsUseDarkMode` returns true unconditionally,
  bypassing every Wine-fragile gate; (2) new `Cheat Engine/cedarkmode.pas` (in the `.lpr` uses clause after
  `betterControls`) whose `initialization` overwrites `betterControls.ColorSet` (`FontColor:=$E0E0E0` near-white
  — the black-on-dark fix — plus dark backgrounds/buttons/checkboxes) and the `clWindow`/`clBtnFace`/`clWindowText`/…
  override globals + `darkmodestring:=' dark'`, guarded by `if ShouldAppsUseDarkMode`. Runs before the first form
  is created (unit inits precede `Application.CreateForm`). **Built & visually verified** (2026-07-02): whole UI
  (main window, scan panel, tables, menus, dialogs) renders dark with readable light text; titlebar dark too
  (KWin deco). The new file avoids editing vendored `betterControls` (clean upstream rebase); the `.lpi`/`.lpr`
  edits are one line each. **Compiled into the exe → only live after `cheatengine-rebuild`.** Out of scope
  (cheap follow-ups): the 7 forms whose `.lfm` hardcodes light colors, and dark syntax-highlighter presets for
  the code editors (they load `…dark` registry profiles keyed off `darkmodestring`).
  - **Polish pass (2026-07-02)** — first-pass feedback fixes. Palette in `cedarkmode.pas`: lifted
    `TextBackground` `$202020`→`$2B2B2B` (lists were near-black). Edits to vendored `betterControls` (small,
    localized): `newlistview.pas` — when `OpenThemeData` fails under Wine (theme=0) fall back to
    `colorset.TextBackground/FontColor` instead of leaving the found-list bg at 0 (pure black);
    `newheadercontrol.pas` — force `canvas.Font.Color:=colorset.FontColor` (header text was unreadable) and a
    slightly-lighter header strip; `newmainmenu.pas` `drawScaled` — extend the last visible top-level bar item to
    fill the bar (the white gap right of "Help" appeared only on the **UI-scaled** menu path). Scrollbars/disabled
    edits are drawn by **Wine using GDI system colours** (per-window `SetWindowTheme('DarkMode_Explorer')` is a
    no-op under Wine), so `cedarkmode.pas` now calls **`SetSysColors`** to darken `COLOR_SCROLLBAR/BTNFACE/WINDOW/
    3DDKSHADOW/…` — this darkens scrollbar **arrow buttons**, disabled-edit backgrounds, native combo buttons and
    tooltips. **Still light: the scrollbar trough/thumb** inside lists — Wine draws those *themed* (via the lists'
    `'Explorer'` window theme), ignoring syscolors; fully darkening them needs forcing **classic (unthemed)**
    scrollbars (`SetWindowTheme(h,'','')` on lists/trees), which also changes row-selection rendering — left as an
    opt-in. Caveat: `SetSysColors` is Wine-session-scoped; in the injected-into-game case CE runs in the game's
    proton prefix, so it also touches that prefix's syscolors (harmless for GPU-rendered games).
  - **Native listview header own-draw (2026-07-02)** — the column headers of every `TListView` (found-list
    "Address/Value/Previous", Advanced Options `lvCodelist`, etc.) rendered **light-on-light / unreadable** under
    Wine: `newlistview.pas`'s `pp` (the listview's `WM_NOTIFY` handler for its header's `NM_CUSTOMDRAW`) set the
    header *text* to `clWindowtext` (light) but never painted the background — on real Windows the `'ItemsView'`
    theme supplies a dark header, but Wine has no such theme so the strip stayed light. Fixed by making `pp`
    **own-draw** header sections when `hwndFrom = ListView_GetHeader(handle)`: fill a dark strip
    (`incColor(TextBackground,10)`) + a `ButtonBorderColor` divider, draw the caption with `colorset.FontColor` via
    `DrawText`, return `CDRF_SKIPDEFAULT` so it wins regardless of the (missing) theme. One edit, covers all
    `TListView` headers app-wide.

### Build gotcha: non-deterministic FPC internal errors (ICE)
FPC sometimes aborts with `Internal error <n>` / `(1026) Compilation raised exception internally` at a
*random* unit (seen at `foundlisthelper.pas`, `SynHighlighterAA.pas`) — not a source bug. A failed
compile can leave stale units in `lib/`, so the next incremental build then fails elsewhere. Fix: wipe
`Cheat Engine/lib/` and build clean. **`cheatengine-rebuild` now auto-does this on any build failure.**

## Conventions / gotchas
- Lua is **5.3**. Build target is **win64**; build the app and reuse the committed DLLs — **except the Mono
  collector DLLs**, which aren't committed and must be built once (see "Build the Mono collector DLL").
- Never build `DBKKernel/` or `dbvm/` for a Wine setup.
- Sync upstream later with: `git fetch upstream && git rebase upstream/master`.
