unit newListView;

{$mode objfpc}{$H+}

{
For people wondering WHY the first subitem has a black background when
highlighted and not the CE version released on the website:
lazarus 2.0.6(and 2.2.2): win32wscustomlistview.inc subfunction HandleListViewCustomDraw of
ListViewParentMsgHandler

originalcode:
if DrawInfo^.iSubItem = 0 then Exit;
DrawResult := ALV.IntfCustomDraw(dtSubItem, Stage,
  DrawInfo^.nmcd.dwItemSpec, DrawInfo^.iSubItem,
  ConvState(DrawInfo^.nmcd.uItemState), nil);


new code:
DrawResult := ALV.IntfCustomDraw(dtSubItem, Stage,
  DrawInfo^.nmcd.dwItemSpec, DrawInfo^.iSubItem,
  ConvState(DrawInfo^.nmcd.uItemState), nil);

if DrawInfo^.iSubItem = 0 then Exit;


}

interface

uses
  jwawindows, windows, Classes, SysUtils, ComCtrls, Controls, messages, lmessages, graphics,
  CommCtrl;

type
  TNewListView=class(ComCtrls.TListView)
  private
    fDefaultBackgroundColor: COLORREF;
    fDefaultTextColor: COLORREF;
    procedure setViewStyle(style: TViewStyle);
    function getViewStyle: TViewStyle;
    procedure pp(var msg: TMessage); message WM_NOTIFY;
  protected
    procedure ChildHandlesCreated; override;
    function CustomDraw(const ARect: TRect; AStage: TCustomDrawStage): Boolean;  override;
    function CustomDrawItem(AItem: TListItem; AState: TCustomDrawState; AStage: TCustomDrawStage): Boolean; override;
    function CustomDrawSubItem(AItem: TListItem; ASubItem: Integer; AState: TCustomDrawState; AStage: TCustomDrawStage): Boolean; override;

    procedure SetParent(NewParent: TWinControl); override;
  public
  published
    property ViewStyle: TViewStyle read getViewStyle write setViewStyle;
  end;


implementation

uses betterControls;


procedure TNewListView.SetParent(NewParent: TWinControl);
var h: tHandle;
begin
  inherited SetParent(newparent);

  if (parent<>nil) and (viewstyle=vsReport) and (not (csReadingState in ControlState)) then
  begin
    h:=ListView_GetHeader(handle);
    if (h<>0) and (h<>INVALID_HANDLE_VALUE) then
    begin
      AllowDarkModeForWindow(h, 1);
      SetWindowTheme(h, 'ItemsView',nil);
    end;
  end;

end;

procedure TNewListView.setViewStyle(style: TViewStyle);
var
  h: THandle;
  olds: TViewstyle;

  cs: Tcontrolstate;
begin
  olds:=viewstyle;
  inherited ViewStyle:=style;

  if ShouldAppsUseDarkMode() then
  begin
    cs:=ControlState;

    if (parent<>nil) and (olds<>style) and (style=vsReport) and (not (csReadingState in cs)) then
    begin
      h:=ListView_GetHeader(handle);
      if (h<>0) and (h<>INVALID_HANDLE_VALUE) then
      begin
        AllowDarkModeForWindow(h, 1);
        SetWindowTheme(h, 'ItemsView',nil);
      end;
    end;
  end;
end;

function TNewListView.getViewStyle: TViewStyle;
begin
  result:=inherited ViewStyle;
end;

function TNewListView.CustomDraw(const ARect: TRect; AStage: TCustomDrawStage): Boolean;
begin
  if ShouldAppsUseDarkMode then Canvas.Brush.style:=bsClear;
  result:=inherited customdraw(ARect, AStage);
end;

function TNewListView.CustomDrawItem(AItem: TListItem; AState: TCustomDrawState; AStage: TCustomDrawStage): Boolean;
begin
  if ShouldAppsUseDarkMode then Canvas.Brush.style:=bsClear;
  result:=inherited CustomDrawItem(AItem, AState, AStage);
end;

function TNewListView.CustomDrawSubItem(AItem: TListItem; ASubItem: Integer; AState: TCustomDrawState; AStage: TCustomDrawStage): Boolean;
begin
  if ShouldAppsUseDarkMode then Canvas.Brush.style:=bsClear;
  result:=inherited CustomDrawSubItem(AItem, ASubItem, AState, AStage);
end;


procedure TNewListView.ChildHandlesCreated;
var
  theme: THandle;
  h: thandle;
begin
  inherited ChildHandlesCreated;

  if ShouldAppsUseDarkMode then
  begin
    if parent<>nil then
    begin
      AllowDarkModeForWindow(handle, 1);
      SetWindowTheme(handle, 'Explorer', nil);

      theme:=OpenThemeData(0,'ItemsView');  //yeah....why make it obvious if you can make it obscure right ?  (This is a microsoft thing, not because i'm an asshole )

      if theme<>0 then
      begin
        GetThemeColor(theme, 0,0,TMT_TEXTCOLOR,fDefaultTextColor);
        GetThemeColor(theme, 0,0,TMT_FILLCOLOR,fDefaultBackgroundColor);
        CloseThemeData(theme);
      end
      else
      begin
        //Wine has no ItemsView theme, so OpenThemeData failed -> fall back to our
        //explicit dark palette instead of leaving the background at 0 (pure black).
        fDefaultTextColor:=colorset.FontColor;
        fDefaultBackgroundColor:=colorset.TextBackground;
      end;

      Font.color:=fDefaultTextColor;
      Color:=fDefaultBackgroundColor;

      h:=ListView_GetHeader(handle);
      if (h<>0) and (h<>INVALID_HANDLE_VALUE) then
      begin
        AllowDarkModeForWindow(h, 1);
        SetWindowTheme(h, 'ItemsView',nil);
      end;

    end;

  end;
end;

procedure TNewListView.pp(var msg: TMessage);
var
  p1: LPNMHDR;
  p2: LPNMCUSTOMDRAW;
  columnid: integer;
  c: tcolor;
  br: HBRUSH;
  r, r2: TRect;
  txt: string;
  dtflags: DWORD;
begin

    p1:=LPNMHDR(msg.lparam);
    if p1^.code=UINT(NM_CUSTOMDRAW) then
    begin
      p2:=LPNMCUSTOMDRAW(msg.lParam);


      case p2^.dwDrawStage of
        CDDS_PREPAINT: msg.Result:=CDRF_NOTIFYITEMDRAW;
        CDDS_ITEMPREPAINT:
        begin
          columnid:=p2^.dwItemSpec;

          if ShouldAppsUseDarkMode and (p1^.hwndFrom = ListView_GetHeader(handle)) then
          begin
            //Wine draws the native listview header light-on-light (its 'ItemsView'
            //dark theme doesn't exist), so own-draw it: dark strip + readable light
            //text. CDRF_SKIPDEFAULT so this wins regardless of the (missing) theme.
            br:=CreateSolidBrush(ColorToRGB(incColor(colorset.TextBackground,10)));
            FillRect(p2^.hdc, p2^.rc, br);
            DeleteObject(br);

            //subtle right-edge column divider
            br:=CreateSolidBrush(ColorToRGB(colorset.ButtonBorderColor));
            r2:=p2^.rc; r2.left:=r2.right-1;
            FillRect(p2^.hdc, r2, br);
            DeleteObject(br);

            if (columnid>=0) and (columnid<columncount) then
            begin
              txt:=column[columnid].Caption;
              case column[columnid].Alignment of
                taCenter:       dtflags:=DT_CENTER;
                taRightJustify: dtflags:=DT_RIGHT;
              else              dtflags:=DT_LEFT;
              end;
              r:=p2^.rc;
              inc(r.left,5); dec(r.right,5);
              SetTextColor(p2^.hdc, ColorToRGB(colorset.FontColor));
              SetBkMode(p2^.hdc, TRANSPARENT);
              DrawText(p2^.hdc, PChar(txt), length(txt), r,
                       dtflags or DT_VCENTER or DT_SINGLELINE or DT_END_ELLIPSIS or DT_NOPREFIX);
            end;

            msg.result:=CDRF_SKIPDEFAULT;
          end
          else
          begin
            msg.result:=CDRF_DODEFAULT;

            if (columnid>=0) and (columnid<columncount) and (column[columnid].tag<>0) then
              c:=column[columnid].tag
            else
              c:=clWindowtext;

            SetTextColor(p2^.hdc, c);
          end;
        end;
      end;
    end;

end;


end.

