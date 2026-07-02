#!/usr/bin/env bash
#
# build-mingw-dll.sh — Cross-compile MonoDataCollector{64,32}.dll from source on Linux.
#
# WHY THIS EXISTS
#   CE's Mono features (dissector, "Activate" on Mono scripts) inject
#   bin/autorun/dlls/MonoDataCollector64.dll into the target game. Upstream STOPPED
#   committing the prebuilt collector DLLs to git back in 2021 (commit 09654220);
#   they now ship only inside the compiled installer. A from-source build therefore has
#   NO collector DLL, so monoscript.lua prints:
#       "DLL Injection failed or invalid DLL version"
#   (bin/autorun/monoscript.lua:557) and every Mono script fails.
#
#   This script builds the DLL straight from the in-tree C++ source
#   (MonoDataCollector/MonoDataCollector/), which is #define MONO_DATACOLLECTORVERSION
#   20240511 — the exact version bin/autorun/monoscript.lua expects — and drops it into
#   bin/autorun/dlls/ where CE looks. No CE (exe) rebuild is needed: the collector DLL is
#   a runtime file, not linked into cheatengine-x86_64.exe.
#
# REQUIREMENTS
#   sudo pacman -S --needed mingw-w64-gcc     # provides x86_64-w64-mingw32-g++ (and i686-)
#
# USAGE
#   bash "Cheat Engine/MonoDataCollector/build-mingw-dll.sh"
#   then restart Cheat Engine and re-run the Mono script.
#
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/MonoDataCollector" && pwd)"
COMMON_DIR="$(cd "$SRC_DIR/../../Common" && pwd)"
DEST_DIR="$(cd "$SRC_DIR/../../bin/autorun/dlls" && pwd)"

# Windows source set, taken verbatim from MonoDataCollector.vcxproj <ClCompile> entries.
SOURCES=(MonoDataCollector.cpp PipeServer.cpp CMemStream.cpp dllmain.cpp stdafx.cpp "$COMMON_DIR/Pipe.cpp")

# The Windows code is gated behind #ifdef _WINDOWS (NOT _WIN32), which mingw does not
# auto-define — so pass it explicitly, plus the vcxproj Release defines.
# (WIN32_LEAN_AND_MEAN is left to stdafx.h, which already defines it.)
DEFINES=(-DWIN32 -DNDEBUG -D_WINDOWS -D_USRDLL -DMONODATACOLLECTOR_EXPORTS)

# MSVC-origin source: allow string-literal->char* and narrowing (portability, not logic).
CXXFLAGS=(-O2 -std=gnu++17 -fpermissive -Wno-write-strings -Wno-narrowing)

# The source uses MSVC's case-insensitive #includes (<Windows.h>, <TlHelp32.h>, "StdAfx.h"),
# but mingw's headers on Linux are case-sensitive (windows.h, tlhelp32.h) and the local file is
# stdafx.h. Provide case-alias shim headers in a temp dir searched first, rather than editing the
# committed upstream source (keeps future `git rebase upstream/master` clean).
SHIM_DIR="$(mktemp -d)"
printf '#include <windows.h>\n'  > "$SHIM_DIR/Windows.h"
printf '#include <tlhelp32.h>\n' > "$SHIM_DIR/TlHelp32.h"
printf '#include "stdafx.h"\n'   > "$SHIM_DIR/StdAfx.h"

# Force-included into every TU to bridge two more MSVC-isms mingw doesn't provide:
#   - <cstdint>: MSVC pulls uintNN_t in transitively; mingw doesn't, so QWORD/uint32_t/
#     the MONO_METHOD_GET_FLAGS typedef would all fail to name a type.
#   - __in / __in_bcount: old-style SAL annotations in the ZwSetInformationThread typedef.
cat > "$SHIM_DIR/mingw_compat.h" <<'EOF'
#pragma once
#include <cstdint>
#ifndef __in
#define __in
#endif
#ifndef __in_bcount
#define __in_bcount(x)
#endif
EOF
FORCEINC=(-include "$SHIM_DIR/mingw_compat.h")

INCLUDES=(-I"$SHIM_DIR" -I"$SRC_DIR" -I"$COMMON_DIR")

# CE reads/writes the pipe HANDLE at the ADDRESS of the MDC_ServerPipe export
# (monoscript.lua:565/573), so it must be exported as DATA, not as a code thunk.
# The in-tree exports.def has no DATA keyword (fine for MSVC, wrong for GNU ld), so
# generate a correct one here instead of editing the committed file.
DEF_FILE="$(mktemp --suffix=.def)"
printf 'EXPORTS\n    MDC_ServerPipe @1 DATA\n' > "$DEF_FILE"
trap 'rm -f "$DEF_FILE"; rm -rf "$SHIM_DIR"' EXIT

# -static* so the injected DLL carries no libgcc/libstdc++/winpthread runtime dependency
# (those DLLs are not present in the target game process).
LINK=(-shared -static -static-libgcc -static-libstdc++ "$DEF_FILE" -lkernel32)

build() { # $1 = mingw triple, $2 = output dll name
  local cxx="$1-g++"
  if ! command -v "$cxx" >/dev/null 2>&1; then
    echo "!! $cxx not found — skipping $2  (install with: sudo pacman -S --needed mingw-w64-gcc)"
    return 1
  fi
  echo ">> Building $2 with $cxx ..."
  ( cd "$SRC_DIR" && "$cxx" "${CXXFLAGS[@]}" "${DEFINES[@]}" "${FORCEINC[@]}" "${INCLUDES[@]}" \
      "${SOURCES[@]}" "${LINK[@]}" -o "$DEST_DIR/$2" )
  echo ">> Wrote $DEST_DIR/$2"
}

# 64-bit is what Blasphemous (and other 64-bit Unity/Mono games) needs.
build x86_64-w64-mingw32 MonoDataCollector64.dll
# 32-bit only if the i686 cross-compiler is installed (not needed for 64-bit games).
if command -v i686-w64-mingw32-g++ >/dev/null 2>&1; then
  build i686-w64-mingw32 MonoDataCollector32.dll || true
fi

echo
echo "Done. Restart Cheat Engine, attach to the game, and re-run the Mono script."
echo "If sprintf_s errors during compile, tell Claude — mingw-w64's secure API just needs a small tweak."
