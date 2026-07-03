unit newMainMenu;

{$mode objfpc}{$H+}

interface

uses
  jwawindows, windows, Classes, SysUtils, Controls, StdCtrls, Menus, Graphics;

type
  TNewMenuItem=class(TMenuItem)
  private
    fCustomFontColor: TColor;
    function drawScaled(ACanvas: TCanvas; ARect: TRect; AState: TOwnerDrawState): Boolean;
  protected
    function DoDrawItem(ACanvas: TCanvas; ARect: TRect; AState: TOwnerDrawState): Boolean; override;
    function DoMeasureItem(ACanvas: TCanvas; var AWidth, AHeight: Integer): Boolean; override;
    procedure setCustomFontColor(newcolor: TColor); virtual;
  public
    constructor Create(TheOwner: TComponent); override;
  published
    property FontColor: TColor read fCustomFontColor write setCustomFontColor;
  end;


  TNewMainMenu=class(TMainMenu)
  private
    procedure firstshow(sender: TObject);
  protected
    procedure SetParentComponent(Value: TComponent); override;
  public
  end;


implementation

uses betterControls, forms, LCLType, LCLProc, ImgList, globals;

procedure TNewMainMenu.firstshow(sender: TObject);
var m: Hmenu;
  mi: windows.MENUINFO;
  c: tcanvas;
  mia: windows.LPCMENUINFO;


 // mbi: ENUBARINFO ;

  b: TBrush;
begin
  if ShouldAppsUseDarkMode then
  begin
    m:=GetMenu(TCustomForm(sender).handle);
   // m:=handle;


    mi.cbSize:=sizeof(mi);
    mi.fMask := MIM_BACKGROUND or MIM_APPLYTOSUBMENUS;

    b:=TBrush.Create;
    b.color:=$2b2b2b;


    b.Style:=bsSolid;

    mi.hbrBack:=b.handle; //GetSysColorBrush(DKGRAY_BRUSH); //b.Handle;
    mia:=@mi;
    if windows.SetMenuInfo(m,mia) then
    begin
      AllowDarkModeForWindow(m,1);

      SetWindowTheme(m,'',nil);
    end;

  end;
end;

procedure TNewMainMenu.SetParentComponent(Value: TComponent);
begin
  inherited SetParentComponent(value);


  if ShouldAppsUseDarkMode and (value is tcustomform) then
    tcustomform(value).AddHandlerFirstShow(@firstshow);
end;

function TNewMenuItem.DoDrawItem(ACanvas: TCanvas; ARect: TRect; AState: TOwnerDrawState): Boolean;
var oldc: tcolor;

  bmp: Tbitmap;
  ts: TTextStyle;

  i: integer;
  lastvisible: integer;
begin
  result:=inherited DoDrawItem(ACanvas, ARect, AState);

  if acanvas=nil then exit;
  if parent=nil then exit;
  if parent.menu=nil then exit;

  if uitextscale<>1.0 then
  begin
    //When the UI is scaled, the native win32 menu font can't be enlarged (it comes from the
    //system NONCLIENTMETRICS at 96 DPI), so owner-draw every item ourselves with a scaled font.
    if not result then
      result:=drawScaled(ACanvas, ARect, AState);
    exit;
  end;

  if ShouldAppsUseDarkMode() and (result=false) then
  begin
    result:=Parent.Menu is TMainMenu;
    oldc:=acanvas.Brush.color;

    if result then
    begin
      acanvas.Brush.color:=$313131;

      lastvisible:=-1;
      for i:=parent.count-1 downto 0 do
        if parent[i].Visible then
        begin
          lastvisible:=i;
          break;
        end;

      if MenuIndex=lastvisible then //name='MenuItem3' then
      begin
        if owner is TCustomForm then
          ARect.Width:=tcustomform(owner).width
        else
        begin
          ARect.Width:=acanvas.width-arect.Left;
        end;
      end;
      acanvas.FillRect(arect);


      if fCustomFontColor=clDefault then
        acanvas.font.color:=clWhite
      else
        acanvas.font.color:=fCustomFontColor;

      ts:=acanvas.TextStyle;
      ts.ShowPrefix:=true;
      acanvas.Brush.Style:=bsSolid;
      acanvas.TextRect(arect,arect.left,arect.top,caption, ts);
      acanvas.Brush.color:=oldc;
    end;

    if (not result) and (caption='-') then
    begin
      acanvas.Brush.color:=$2b2b2b;
      acanvas.FillRect(arect);
      ts:=acanvas.TextStyle;
      ts.ShowPrefix:=true;
      acanvas.Brush.Style:=bsSolid;
      acanvas.pen.color:=clGray;
      acanvas.pen.Width:=1;
      acanvas.Line(arect.left+acanvas.TextWidth(' '), arect.CenterPoint.Y,arect.right-acanvas.TextWidth(' '), arect.CenterPoint.Y);
      acanvas.Brush.color:=oldc;
      result:=true;
    end;

  end;
end;

function TNewMenuItem.DoMeasureItem(ACanvas: TCanvas; var AWidth, AHeight: Integer): Boolean;
begin
  Result:=inherited DoMeasureItem(ACanvas, AWidth, AHeight);
  if uitextscale<>1.0 then
  begin
    //AWidth/AHeight arrive as the widgetset's default (system-font) box; grow it to fit our scaled font
    AWidth:=round(AWidth*uitextscale);
    AHeight:=round(AHeight*uitextscale);
    Result:=True;
  end;
end;

function TNewMenuItem.drawScaled(ACanvas: TCanvas; ARect: TRect; AState: TOwnerDrawState): Boolean;
var
  dark, selected, disabled, isBar: boolean;
  bg, fg: TColor;
  il: TCustomImageList;
  iconSz, gap, tLeft, tRight, midY, fh, asz, penw: integer;
  scText: string;
  ts: TTextStyle;
  r2: TRect;
begin
  Result:=True;
  dark:=ShouldAppsUseDarkMode();
  selected:=odSelected in AState;
  disabled:=(odDisabled in AState) or (not Enabled);
  isBar:=IsInMenuBar;

  //background
  if dark then
  begin
    if selected then bg:=$00505050
    else if isBar then bg:=$00313131
    else bg:=$002b2b2b;
    fg:=clWhite;
  end
  else
  begin
    if selected then begin bg:=clHighlight; fg:=clHighlightText; end
    else begin bg:=clMenu; fg:=clMenuText; end;
  end;
  if disabled then fg:=clGrayText;
  if (fCustomFontColor<>clDefault) and (not selected) and (not disabled) then fg:=fCustomFontColor;

  ACanvas.Brush.Color:=bg;
  ACanvas.Brush.Style:=bsSolid;
  ACanvas.FillRect(ARect);

  midY:=(ARect.Top+ARect.Bottom) div 2;
  gap:=round(5*uitextscale);

  if IsLine then //separator
  begin
    ACanvas.Pen.Style:=psSolid;
    ACanvas.Pen.Color:=clGray;
    ACanvas.Pen.Width:=1;
    ACanvas.Line(ARect.Left+gap, midY, ARect.Right-gap, midY);
    exit;
  end;

  ACanvas.Font.Assign(Screen.MenuFont); //base menu font, scaled below
  fh:=ACanvas.Font.Height;
  if fh=0 then fh:=-12;
  ACanvas.Font.Height:=round(fh*uitextscale);
  ACanvas.Font.Color:=fg;

  ts:=ACanvas.TextStyle;
  ts.ShowPrefix:=True;  //& accelerator underline
  ts.SingleLine:=True;
  ts.Layout:=tlCenter;
  ts.Opaque:=False;
  ACanvas.Brush.Style:=bsClear;

  if isBar then //top-level bar item: just the centered caption
  begin
    ts.Alignment:=taCenter;
    ACanvas.TextRect(ARect, ARect.Left, ARect.Top, Caption, ts);
    exit;
  end;

  //dropdown item: [icon/check] caption ........ [shortcut | submenu-arrow]
  iconSz:=round(16*uitextscale);
  tLeft:=ARect.Left+iconSz+2*gap;
  tRight:=ARect.Right-gap;

  il:=GetImageList;
  if (il<>nil) and (ImageIndex>=0) and (ImageIndex<il.Count) then
    il.StretchDraw(ACanvas, ImageIndex, Rect(ARect.Left+gap, midY-iconSz div 2, ARect.Left+gap+iconSz, midY+iconSz div 2))
  else if Checked then
  begin
    penw:=round(1.5*uitextscale);
    if penw<1 then penw:=1;
    ACanvas.Pen.Style:=psSolid;
    ACanvas.Pen.Color:=fg;
    ACanvas.Pen.Width:=penw;
    ACanvas.MoveTo(ARect.Left+gap+iconSz div 5, midY);
    ACanvas.LineTo(ARect.Left+gap+(iconSz div 2), midY+iconSz div 4);
    ACanvas.LineTo(ARect.Left+gap+iconSz, midY-iconSz div 4);
  end;

  if Count>0 then //has submenu: draw an arrow at the right
  begin
    asz:=round(4*uitextscale);
    ACanvas.Pen.Style:=psSolid;
    ACanvas.Pen.Color:=fg;
    ACanvas.Brush.Color:=fg;
    ACanvas.Brush.Style:=bsSolid;
    ACanvas.Polygon([Point(tRight-asz, midY-asz), Point(tRight, midY), Point(tRight-asz, midY+asz)]);
    ACanvas.Brush.Style:=bsClear;
    tRight:=tRight-2*asz-gap;
  end
  else if ShortCut<>0 then //shortcut text at the right
  begin
    scText:=ShortCutToText(ShortCut);
    ts.Alignment:=taRightJustify;
    r2:=Rect(tLeft, ARect.Top, ARect.Right-gap, ARect.Bottom);
    ACanvas.TextRect(r2, r2.Left, r2.Top, scText, ts);
    tRight:=ARect.Right-gap-ACanvas.TextWidth(scText)-2*gap;
  end;

  //caption
  ts.Alignment:=taLeftJustify;
  r2:=Rect(tLeft, ARect.Top, tRight, ARect.Bottom);
  ACanvas.TextRect(r2, tLeft, ARect.Top, Caption, ts);
end;

procedure TNewMenuItem.setCustomFontColor(newcolor: TColor);
begin
  fCustomFontColor:=newcolor;
  enabled:=not enabled; //repaints it
  enabled:=not enabled;
end;

constructor TNewMenuItem.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  fCustomFontColor:=clDefault;
end;

end.

