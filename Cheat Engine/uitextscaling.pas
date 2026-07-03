unit uitextscaling;

{
  Central UI text-scaling machinery for Cheat Engine.

  The scale factor lives in globals.uitextscale (1.0 = 100%). Each form is scaled
  once, on its first show, from its design PPI to design PPI * uitextscale using
  LCL's AutoAdjustLayout (which scales fonts AND control bounds, including
  ParentFont=False controls). ApplyUITextScale re-scales all already-scaled forms
  live so the user does not have to restart.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Forms;

// Register the screen hooks so forms scale to the current uitextscale as they show.
procedure InitUITextScale;

// Live-apply a new scale (percent, e.g. 150) to every open form and to future ones.
procedure ApplyUITextScale(newPercent: integer);

implementation

uses
  SysUtils, Menus, StdCtrls, Buttons, Graphics, LCLType, Dialogs, InterfaceBase,
  SynCompletion, LCLIntf, globals, newButton{$ifdef windows}, win32proc{$endif};

type
  TUIScaler = class
  public
    scaledForms: TList;
    constructor Create;
    destructor Destroy; override;
    procedure onFormVisibleChanged(Sender: TObject; Form: TCustomForm);
    procedure onFormRemove(Sender: TObject; Form: TCustomForm);
  end;

var
  uiscaler: TUIScaler = nil;

function baseFormPPI(Form: TCustomForm): integer;
begin
  Result := Form.DesignTimePPI; // 96 for almost every form; 120 for a couple; 0 for dynamically-built forms
  if Result <= 0 then Result := 96;
end;

// Rescale a single form from one scale factor to another via AutoAdjustLayout.
procedure scaleFormBetween(Form: TCustomForm; fromScale, toScale: single);
var
  base, frompp, topp: integer;
begin
  if (Form = nil) or (Form is TsynCompletionForm) then exit;
  base := baseFormPPI(Form);
  frompp := round(base * fromScale);
  topp := round(base * toScale);
  if frompp = topp then exit;
  Form.AutoAdjustLayout(lapAutoAdjustForDPI, frompp, topp, Form.Width,
                        round(Form.Width * topp / frompp));
end;

constructor TUIScaler.Create;
begin
  scaledForms := TList.Create;
end;

destructor TUIScaler.Destroy;
begin
  scaledForms.Free;
  inherited Destroy;
end;

procedure TUIScaler.onFormVisibleChanged(Sender: TObject; Form: TCustomForm);
begin
  if (Form = nil) or (uitextscale = 1.0) or (Form is TsynCompletionForm) then exit;
  if not Form.Visible then exit;                // snFormVisibleChanged also fires on hide
  if scaledForms.IndexOf(Form) >= 0 then exit;  // AutoAdjustLayout is not idempotent - scale each form once
  scaledForms.Add(Form);
  scaleFormBetween(Form, 1.0, uitextscale);
end;

procedure TUIScaler.onFormRemove(Sender: TObject; Form: TCustomForm);
begin
  scaledForms.Remove(Form); // prevent stale-pointer reuse if a freed form's address is recycled
end;

// A control-based replacement for LCL's MessageDlg/ShowMessage dialog. LCL's TPromptDialog
// custom-paints its text (measured with the canvas default font) and re-syncs its font to the
// screen DPI at handle creation, so it can't be scaled from outside. This builds an ordinary form
// with a real TLabel + TBitBtns at the scaled size instead. Falls back to the stock dialog on any
// problem, so the worst case is an unscaled (but working) dialog.
function scaledPromptDialog(const DialogCaption, DialogMessage: String;
  DialogType: longint; Buttons: PLongint; ButtonCount, DefaultIndex, EscapeResult: Longint;
  UseDefaultPos: boolean; X, Y: Longint): Longint;
var
  f: TForm;
  lbl: TLabel;
  btn: TNewButton;
  i, m, bw, bh, gap, bx, by, cw: integer;
  kind: TBitBtnKind;
  measure: TBitmap;
  tr: TRect;
  lblw, lblh, maxw: integer;
begin
  f := TForm.CreateNew(nil);
  try
    if uiscaler <> nil then
      uiscaler.scaledForms.Add(f); //built already-scaled; keep the show hook from scaling it again

    m := round(16 * uitextscale);
    bw := round(85 * uitextscale);
    bh := round(27 * uitextscale);
    gap := round(8 * uitextscale);

    f.BorderStyle := bsDialog;
    f.BorderIcons := [biSystemMenu];
    if DialogCaption <> '' then f.Caption := DialogCaption else f.Caption := 'Cheat Engine';
    f.Font.Height := round(-12 * uitextscale);
    if UseDefaultPos then f.Position := poScreenCenter
    else begin f.Position := poDesigned; f.Left := X; f.Top := Y; end;

    // Measure the word-wrapped message with the scaled font up front. A WordWrap+AutoSize TLabel's
    // Width/Height can't be read reliably during construction (the wrapped extent isn't computed
    // until it has a handle), which left the form too narrow and clipped the text. DT_CALCRECT gives
    // the exact wrapped box; we then size the label and form to it.
    maxw := round(560 * uitextscale);
    measure := TBitmap.Create;
    try
      measure.SetSize(1, 1);
      measure.Canvas.Font.Assign(f.Font);
      measure.Canvas.TextWidth('W'); //force LCL to select the font into the DC before the raw DrawText
      tr := Rect(0, 0, maxw, 0);
      LCLIntf.DrawText(measure.Canvas.Handle, PChar(DialogMessage), Length(DialogMessage), tr,
                       DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX);
      lblw := tr.Right - tr.Left;
      lblh := tr.Bottom - tr.Top;
    finally
      measure.Free;
    end;
    if lblw < 1 then lblw := 1;
    if lblh < 1 then lblh := 1;

    lbl := TLabel.Create(f);
    lbl.Parent := f;
    lbl.WordWrap := True;
    lbl.AutoSize := False;
    lbl.SetBounds(m, m, lblw, lblh);
    lbl.Caption := DialogMessage;

    by := m + lblh + m;
    cw := m + lblw + m;
    if cw < 2*m + ButtonCount*bw + (ButtonCount-1)*gap then
      cw := 2*m + ButtonCount*bw + (ButtonCount-1)*gap;
    f.ClientWidth := cw;
    f.ClientHeight := by + bh + m;

    bx := cw - m - (ButtonCount*bw + (ButtonCount-1)*gap);
    for i := 0 to ButtonCount-1 do
    begin
      case Buttons[i] of
        idButtonOk:       kind := bkOK;
        idButtonCancel:   kind := bkCancel;
        idButtonYes:      kind := bkYes;
        idButtonNo:       kind := bkNo;
        idButtonHelp:     kind := bkHelp;
        idButtonClose:    kind := bkClose;
        idButtonAbort:    kind := bkAbort;
        idButtonRetry:    kind := bkRetry;
        idButtonIgnore:   kind := bkIgnore;
        idButtonAll:      kind := bkAll;
        idButtonYesToAll: kind := bkYesToAll;
        idButtonNoToAll:  kind := bkNoToAll;
        else raise Exception.Create('unhandled dialog button'); //-> fall back to the stock dialog
      end;
      // Build the buttons as betterControls' custom-drawn TNewButton (aliased to TButton
      // in the rest of the UI), not a native TBitBtn. Under Wine the native button face
      // renders white regardless of the dark syscolors, whereas TNewButton paints its own
      // dark face when ShouldAppsUseDarkMode is set (forced on via -dFORCEDDARKMODE). It has
      // no Kind property, so set the caption/ModalResult the way the kind would have, reusing
      // LCL's own id->caption and kind->ModalResult tables so the labels/results are identical.
      btn := TNewButton.Create(f);
      btn.Parent := f;
      btn.Caption := GetButtonCaption(Buttons[i]);
      btn.ModalResult := BitBtnModalResults[kind];
      btn.AutoSize := False;
      btn.SetBounds(bx, by, bw, bh);
      if i = DefaultIndex then btn.Default := True;
      inc(bx, bw + gap);
    end;

    // PromptUser indexes DialogResults[] with our return value, so it must be an idButtonXXX
    // (like LCL's DefaultPromptDialog), NOT the raw mrXXX that ShowModal/the TBitBtn kinds give.
    case f.ShowModal of
      mrOk:       Result := idButtonOK;
      mrCancel:   Result := idButtonCancel;
      mrYes:      Result := idButtonYes;
      mrNo:       Result := idButtonNo;
      mrAbort:    Result := idButtonAbort;
      mrRetry:    Result := idButtonRetry;
      mrIgnore:   Result := idButtonIgnore;
      mrAll:      Result := idButtonAll;
      mrYesToAll: Result := idButtonYesToAll;
      mrNoToAll:  Result := idButtonNoToAll;
      mrClose:    Result := idButtonClose;
    else
      Result := EscapeResult;
    end;
  finally
    f.Free;
  end;
end;

function scaledPromptDialogSafe(const DialogCaption, DialogMessage: String;
  DialogType: longint; Buttons: PLongint; ButtonCount, DefaultIndex, EscapeResult: Longint;
  UseDefaultPos: boolean; X, Y: Longint): Longint;
begin
  try
    Result := scaledPromptDialog(DialogCaption, DialogMessage, DialogType, Buttons,
                                 ButtonCount, DefaultIndex, EscapeResult, UseDefaultPos, X, Y);
  except
    Result := DefaultPromptDialog(DialogCaption, DialogMessage, DialogType, Buttons,
                                  ButtonCount, DefaultIndex, EscapeResult, UseDefaultPos, X, Y);
  end;
end;

procedure InitUITextScale;
begin
  if uiscaler = nil then
    uiscaler := TUIScaler.Create;
  Screen.AddHandlerFormVisibleChanged(@uiscaler.onFormVisibleChanged);
  Screen.AddHandlerRemoveForm(@uiscaler.onFormRemove);
  //route MessageDlg/ShowMessage through our scalable dialog while a scale is active
  PromptDialogFunction := @scaledPromptDialogSafe;
  {$ifdef windows}
  //...but on the win32/64 widgetset MessageDlg/ShowMessage call the native (Wine-drawn, unscalable)
  //TaskDialogIndirect whenever WindowsVersion>=Vista, which bypasses PromptDialogFunction entirely.
  //Drop the detected version just below Vista so the widgetset falls back to our scalable dialog.
  //This is a Wine-only fork and only runs when a scale is active; the other sub-Vista code paths it
  //flips are cosmetic or no-ops under Wine (edit-box margin fallback; native taskbar/UIPI calls Wine
  //ignores). getDPIScaleFactor keys off screen.PixelsPerInch, not this, so scaling is unaffected.
  if WindowsVersion >= wvVista then
    WindowsVersion := wvServer2003;
  {$endif}
end;

procedure ApplyUITextScale(newPercent: integer);
var
  newscale: single;
  i: integer;
  f: TCustomForm;
begin
  newscale := newPercent / 100;
  if newscale < 1.0 then newscale := 1.0;
  if newscale > 4.0 then newscale := 4.0;

  // Make sure the hooks exist even if we started at 100% (so future forms scale too).
  if uiscaler = nil then
    InitUITextScale;

  if newscale = uitextscale then exit;

  // 1. Rescale every form we have already scaled, from the current global scale to the new one.
  for i := 0 to uiscaler.scaledForms.Count - 1 do
    scaleFormBetween(TCustomForm(uiscaler.scaledForms[i]), uitextscale, newscale);

  // 2. Scale any currently-VISIBLE form we have not scaled yet - i.e. windows that were opened
  //    while the scale was still 100%, so onFormVisibleChanged skipped them. This is what makes a
  //    live scale change actually resize the windows already on screen (the Settings window you are
  //    editing, the main window, an open memory viewer...) instead of only future ones. Hidden
  //    untracked forms are left alone; they get scaled from 1.0 by the show hook when next opened.
  for i := 0 to Screen.CustomFormCount - 1 do
  begin
    f := Screen.CustomForms[i];
    if (f = nil) or (not f.Visible) or (f is TsynCompletionForm) then continue;
    if uiscaler.scaledForms.IndexOf(f) >= 0 then continue; // already handled in step 1
    uiscaler.scaledForms.Add(f);
    scaleFormBetween(f, 1.0, newscale);
  end;

  uitextscale := newscale;

  // Re-measure menus: menu item boxes are sized at handle creation via WM_MEASUREITEM (which reads
  // uitextscale); the owner-draw already reads it live, but the box sizes need a handle rebuild.
  for i := 0 to uiscaler.scaledForms.Count - 1 do
  begin
    f := TCustomForm(uiscaler.scaledForms[i]);
    if (f <> nil) and (f.Menu <> nil) then
      try f.Menu.Items.RecreateHandle; except end;
  end;
end;

end.
