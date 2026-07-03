unit cedarkmode;

{
  SirCabby fork addition — dark mode palette for running under Wine/Proton.

  Cheat Engine already ships a full dark-mode rendering engine (the bundled
  betterControls unit + its New* custom-drawn controls). It only activates when
  betterControls.ShouldAppsUseDarkMode returns true, and it pulls its colour
  palette from the Windows theme API (OpenThemeData 'ItemsView').

  Under Wine there is no active visual style, so OpenThemeData returns 0 and the
  palette is never populated: betterControls' initialization leaves ColorSet at
  the light defaults (FontColor ~= black) while newForm.pas still hardcodes the
  form background to $242424 -> unreadable black-on-dark text.

  This unit fills that gap. Compiled with -dFORCEDDARKMODE (see the Release
  64-Bit build mode in cheatengine.lpi), ShouldAppsUseDarkMode is forced true,
  so here we overwrite betterControls' colour globals with an explicit dark
  palette that does NOT depend on Wine's (missing) theme support.

  Runs from the initialization section, which — because this unit uses
  betterControls — executes AFTER betterControls' own initialization and, like
  every unit init, BEFORE cheatengine.lpr creates the first form. So the New*
  controls read the values set here when they first paint.
}

{$mode objfpc}{$H+}

interface

uses
  betterControls, windows;

implementation

{ Darken the GDI system colours. Wine draws several elements itself using these
  (the scrollbars *inside* list/tree/memo controls, disabled edit fields, native
  combo-box buttons) and ignores per-window dark theming — SetWindowTheme with
  'DarkMode_Explorer' is a no-op under Wine — so overriding the system colours is
  the only way to make those OS-drawn parts dark. Applied once at startup; scope
  is this Wine session (not persisted). }
procedure SetDarkSysColors;
const
  cSCROLLBAR    = 0;
  cMENU         = 4;
  cWINDOW       = 5;
  cWINDOWFRAME  = 6;
  cMENUTEXT     = 7;
  cWINDOWTEXT   = 8;
  cAPPWORKSPACE = 12;
  cBTNFACE      = 15;
  cBTNSHADOW    = 16;
  cGRAYTEXT     = 17;
  cBTNTEXT      = 18;
  cBTNHIGHLIGHT = 20;
  c3DDKSHADOW   = 21;
  c3DLIGHT      = 22;
  cINFOTEXT     = 23;
  cINFOBK       = 24;
  N = 16;
var
  elems: array[0..N-1] of longint;
  cols:  array[0..N-1] of DWORD;
begin
  elems[0]:=cSCROLLBAR;     cols[0]:=$002B2B2B;   // scrollbar track
  elems[1]:=cMENU;          cols[1]:=$002B2B2B;
  elems[2]:=cWINDOW;        cols[2]:=$002B2B2B;
  elems[3]:=cWINDOWFRAME;   cols[3]:=$00555555;
  elems[4]:=cMENUTEXT;      cols[4]:=$00E0E0E0;
  elems[5]:=cWINDOWTEXT;    cols[5]:=$00E0E0E0;
  elems[6]:=cAPPWORKSPACE;  cols[6]:=$00202020;
  elems[7]:=cBTNFACE;       cols[7]:=$002D2D2D;   // scrollbar thumb / disabled-edit bg
  elems[8]:=cBTNSHADOW;     cols[8]:=$001F1F1F;
  elems[9]:=cGRAYTEXT;      cols[9]:=$00909090;
  elems[10]:=cBTNTEXT;      cols[10]:=$00E0E0E0;
  elems[11]:=cBTNHIGHLIGHT; cols[11]:=$003A3A3A;
  elems[12]:=c3DDKSHADOW;   cols[12]:=$00151515;
  elems[13]:=c3DLIGHT;      cols[13]:=$003A3A3A;
  elems[14]:=cINFOTEXT;     cols[14]:=$00E0E0E0;  // tooltip text
  elems[15]:=cINFOBK;       cols[15]:=$002B2B2B;  // tooltip bg
  SetSysColors(N, elems[0], cols[0]);
end;

initialization
  if betterControls.ShouldAppsUseDarkMode then
  begin
    // ---- palette read by the New* controls at draw time ----
    betterControls.ColorSet.FontColor                     := $00E0E0E0; // near-white text (fixes black-on-dark)
    betterControls.ColorSet.TextBackground                := $002B2B2B; // list/edit/tree background (not pure black)
    betterControls.ColorSet.EditBackground                := $00262626;
    betterControls.ColorSet.InactiveFontColor             := $00808080;

    betterControls.ColorSet.ButtonFaceColorDefault        := $002D2D2D;
    betterControls.ColorSet.ButtonFaceColorHover          := $003A3A3A;
    betterControls.ColorSet.ButtonFaceColorDown           := $00272727;
    betterControls.ColorSet.ButtonFaceColorDisabled       := $002A2A2A;
    betterControls.ColorSet.ButtonBorderColor             := $00555555;
    betterControls.ColorSet.ButtonBorderColorHover        := $00777777;
    betterControls.ColorSet.ButtonInactiveBorderColor     := $003A3A3A;

    betterControls.ColorSet.CheckboxFillColor             := $00E8E8E8;
    betterControls.ColorSet.InactiveCheckboxFillColor     := $00999999;
    betterControls.ColorSet.CheckboxCheckMarkColor        := $00202020; // dark mark on the light fill
    betterControls.ColorSet.InactiveCheckboxCheckMarkColor:= $00202020;

    betterControls.currentColorSet := betterControls.ColorSet;

    // ---- override globals (TColor = $00BBGGRR) used by Pascal code paths ----
    betterControls.clWindowText := $00E0E0E0;
    betterControls.clWindow     := $002B2B2B;
    betterControls.clBtnFace    := $002D2D2D;
    betterControls.clBtnText    := $00E0E0E0;
    betterControls.clBtnBorder  := $00555555;
    betterControls.clHighlight  := $00885A2D; // muted blue selection (RGB 45,90,136)

    // syntax highlighters load their '<name> dark' registry profiles when this is set
    betterControls.darkmodestring := ' dark';

    // darken Wine's OS-drawn parts (scrollbars inside lists, disabled edits, ...)
    SetDarkSysColors;
  end;
end.
