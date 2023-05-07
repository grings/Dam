{$IFNDEF FMX}unit Vcl.DamDialog;{$ENDIF}

{$INCLUDE 'Defines.inc'}

{$IFDEF FPC}{$mode delphi}{$ENDIF}

{
-------------------------------------------------------------------------------
Important things about DPI:

1. FMX has your own internal scaling (works like DPI aware), so the controls
   are automatically shown proportional (no need scaling control).

2. In VCL, when creating form dinamically, scaling is not changed
   automatically (it's only changed when moving form already shown, of course,
   if Scaling = True).

3. ScalingUtils depends on Windows, so it only works in VCL with MSWINDOWS.

4. DPI Change event after form already shown (when moving form through
   different monitors) is only available in Delphi 10 Seattle and posterior.

5. Font should be always calculated using stored property "Height" than dynamic
   property "Size" when apllying proportional DPI.

6. In Delphi 11, the property PixelPerInch is changed dynamically when DPI
   changes, so we lose the original DPI that form was designed. This is an
   important value for DzHTMLText, because the HTML tags are configured
   based in designer DPI scale. So there is a property to deal with that in
   DzHTMLText (DesignDPI), storing original DPI.

7. Delphi versions have different behavior about DPI, so here I set all form
   controls DPI manually, calculating using Design DPI versus Monitor DPI.

-------------------------------------------------------------------------------
}

interface

uses
  {$IFDEF FMX}
  FMX.DamUnit
  {$ELSE}
  Vcl.DamUnit
  {$ENDIF};

function RunDamDialog(DamMsg: TDamMsg; const aText: string): TDamMsgRes;

implementation

uses
{$IFDEF USE_SCALING}ScalingUtils, {$ENDIF}
{$IFDEF FPC}
  Vcl.DzHTMLText,
  Forms, Classes, FGL, ActnList, Buttons, Controls, StdCtrls, ExtCtrls, Clipbrd,
  SysUtils, Math, Graphics,
  {$IFDEF MSWINDOWS}
  Windows, MMSystem,
  {$ENDIF}
{$ELSE}
  System.Math, System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Generics.Collections,
  {$IFDEF MSWINDOWS}
  Winapi.Windows, Winapi.MMSystem,
  {$ENDIF}
  {$IFDEF FMX}
  FMX.DzHTMLText,
  FMX.Forms, FMX.Objects, FMX.ActnList, FMX.Types, FMX.Controls, FMX.Platform,
    {$IFDEF USE_NEW_UNITS}
    FMX.StdCtrls, FMX.Graphics,
    {$ENDIF}
  {$ELSE}
  Vcl.DzHTMLText,
  Vcl.Forms, System.Actions, Vcl.ActnList, Vcl.StdCtrls,
  Vcl.Buttons, Vcl.Controls, Vcl.ExtCtrls, Vcl.Graphics, Vcl.Clipbrd,
  Vcl.Imaging.pngimage,
  {$ENDIF}
{$ENDIF}
  //
  DamLanguage;

{$IFDEF FPC}
const
  {$EXTERNALSYM IDI_HAND}
  IDI_HAND = MakeIntResource(32513);
  {$EXTERNALSYM IDI_QUESTION}
  IDI_QUESTION = MakeIntResource(32514);
  {$EXTERNALSYM IDI_EXCLAMATION}
  IDI_EXCLAMATION = MakeIntResource(32515);
  {$EXTERNALSYM IDI_ASTERISK}
  IDI_ASTERISK = MakeIntResource(32516);
  {$EXTERNALSYM IDI_WINLOGO}
  IDI_WINLOGO = MakeIntResource(32517);
  {$EXTERNALSYM IDI_WARNING}
  IDI_WARNING = IDI_EXCLAMATION;
  {$EXTERNALSYM IDI_ERROR}
  IDI_ERROR = IDI_HAND;
  {$EXTERNALSYM IDI_INFORMATION}
  IDI_INFORMATION = IDI_ASTERISK;
{$ENDIF}

type
  TBoxComps = {$IFDEF FMX}TRectangle{$ELSE}TPanel{$ENDIF};

type
  TFrmDamDialogDyn = class(TForm)
  private
    Icon: TImage;
    LbMsg: TDzHTMLText;
    BoxMsg, BoxButtons, BoxFloatBtns: TBoxComps;
    ButtonsList: TList<TButton>;
    BtnHelp: TSpeedButton;
    ActionList: TActionList;

    DamMsg: TDamMsg;
    DamResult: TDamMsgRes;
    LangStrs: TDamLanguageDefinition;

    {$IFDEF USE_SCALING}
    Scaling: TDzFormScaling;
    {$ENDIF}

    function ToScale(Value: TPixels): TPixels;
    function GetCurrentMonitorRect: TRect;

    procedure SetFormCustomization;
    procedure SetFormTitle;
    procedure SetIcon;
    procedure BuildButtons;
    procedure LoadHelp;
    procedure LoadTextProps;

    procedure OverallAlign;
    procedure ManualFormScale;
    procedure AlignButtons;
    procedure CalcWidth;
    procedure CalcHeight;

    procedure CenterForm;

    procedure DoSound;

    procedure FormShow(Sender: TObject);
    procedure LbMsgLinkClick(Sender: TObject; Link: TDHBaseLink; var Handled: Boolean);
    procedure BtnHelpClick(Sender: TObject);
    procedure Action_CopyExecute(Sender: TObject);
    procedure Action_HelpExecute(Sender: TObject);

    {$IFDEF USE_DPICHANGE}
    procedure OnAfterDpiChanged(Sender: TObject; Old, New: Integer);
    {$ENDIF}

    procedure OnBtnClick(Sender: TObject);
  public
    constructor CreateNew; reintroduce;
    destructor Destroy; override;
  end;

const
  DESIGN_DPI = 96;

  {$IFDEF FMX}
  BRUSH_KIND_NONE = TBrushKind.{$IFDEF USE_NEW_ENUMS}None{$ELSE}bkNone{$ENDIF};
  {$ENDIF}

constructor TFrmDamDialogDyn.CreateNew;
var
  Action: TAction;
begin
  inherited CreateNew(Application);

  ButtonsList := TList<TButton>.Create;

  OnShow := FormShow;

  {$IFDEF FMX}
  BorderIcons := [];
  {$ELSE}
  Position := poDesigned;
  {$ENDIF}

  {$IFDEF USE_DPICHANGE}
  OnAfterMonitorDpiChanged := OnAfterDpiChanged;
  {$ENDIF}

  ActionList := TActionList.Create(Self);

  Action := TAction.Create(Self);
  Action.ActionList := ActionList;
  Action.ShortCut := 16451; //CTRL+C
  Action.OnExecute := Action_CopyExecute;

  Action := TAction.Create(Self);
  Action.ActionList := ActionList;
  Action.ShortCut := 112; //F1
  Action.OnExecute := Action_HelpExecute;

  BoxMsg := TBoxComps.Create(Self);
  BoxMsg.Parent := Self;
  {$IFDEF FMX}
  BoxMsg.Align := TAlignLayout.{$IFDEF USE_NEW_ENUMS}Client{$ELSE}alClient{$ENDIF};
  BoxMsg.Stroke.Kind := BRUSH_KIND_NONE; //remove border
  {$ELSE}
  BoxMsg.Align := alClient;
  BoxMsg.BevelOuter := bvNone;
  BoxMsg.ParentBackground := False;
  {$ENDIF}

  Icon := TImage.Create(Self);
  Icon.Parent := BoxMsg;
  {$IFDEF VCL}
  Icon.Proportional := True;
  {$ENDIF}

  LbMsg := TDzHTMLText.Create(Self);
  LbMsg.Parent := BoxMsg;
  LbMsg.OnLinkClick := LbMsgLinkClick;
  {$IFDEF VCL}
  LbMsg.ParentColor := True;
  LbMsg.ParentFont := False;
  {$ENDIF}

  BoxButtons := TBoxComps.Create(Self);
  BoxButtons.Parent := Self;
  {$IFDEF FMX}
  BoxButtons.Align := TAlignLayout.{$IFDEF USE_NEW_ENUMS}Bottom{$ELSE}alBottom{$ENDIF};
  BoxButtons.Stroke.Kind := BRUSH_KIND_NONE; //remove border
  {$ELSE}
  BoxButtons.Align := alBottom;
  BoxButtons.BevelOuter := bvNone;
  BoxButtons.ParentBackground := False;
  {$ENDIF}

  BoxFloatBtns := TBoxComps.Create(Self);
  BoxFloatBtns.Parent := BoxButtons;
  {$IFDEF FMX}
  BoxFloatBtns.Stroke.Kind := BRUSH_KIND_NONE; //remove border
  BoxFloatBtns.Fill.Kind := BRUSH_KIND_NONE; //transparent background
  {$ELSE}
  BoxFloatBtns.BevelOuter := bvNone;
  {$ENDIF}

  BtnHelp := TSpeedButton.Create(Self);
  BtnHelp.Parent := BoxButtons;
  BtnHelp.{$IFDEF FMX}Text{$ELSE}Caption{$ENDIF} := '?';
  BtnHelp.OnClick := BtnHelpClick;
end;

destructor TFrmDamDialogDyn.Destroy;
begin
  ButtonsList.Free;
  inherited;
end;

function RunDamDialog(DamMsg: TDamMsg; const aText: string): TDamMsgRes;
var
  F: TFrmDamDialogDyn;
begin
  F := TFrmDamDialogDyn.CreateNew;
  try
    {$IFDEF VCL_DCC}
    //using Dam component state, because in Preview, we have new TDamMsg, but TDam of form in design
    if (csDesigning in DamMsg.Dam.ComponentState) then F.LbMsg.StyleElements := []; //do not use themes in Delphi IDE
    {$ENDIF}

    F.DamMsg := DamMsg;
    F.LangStrs := LoadLanguage(DamMsg.Dam.Language);

    F.SetFormCustomization;
    F.SetFormTitle;
    F.BuildButtons;
    F.LoadHelp;
    F.LoadTextProps; //required before auto form scaling

    F.OverallAlign;

    F.CenterForm;

    F.ShowModal;
    Result := F.DamResult;
  finally
    F.Free;
  end;
end;

//

procedure TFrmDamDialogDyn.SetFormCustomization;
begin
  //form border
  {$IFDEF FMX}
  //if DamMsg.Dam.DialogBorder then
  //  BorderStyle := TFmxFormBorderStyle.Single
  //else
  //  BorderStyle := TFmxFormBorderStyle.None;
  {$ELSE}
  if DamMsg.Dam.DialogBorder then
    BorderStyle := bsDialog
  else
    BorderStyle := bsNone;
  {$ENDIF}

  //form theme colors
  {$IFDEF FMX}
  if DamMsg.Dam.MessageColor <> TAlphaColors.Null then
    BoxMsg.Fill.Color := DamMsg.Dam.MessageColor
  else
    BoxMsg.Fill.Kind := BRUSH_KIND_NONE;

  if DamMsg.Dam.ButtonsColor <> TAlphaColors.Null then
    BoxButtons.Fill.Color := DamMsg.Dam.ButtonsColor
  else
    BoxButtons.Fill.Kind := BRUSH_KIND_NONE;
  {$ELSE}
  BoxMsg.Color := DamMsg.Dam.MessageColor;
  BoxButtons.Color := DamMsg.Dam.ButtonsColor;
  {$ENDIF}

  //icon
  if DamMsg.Dam.HideIcon then
    Icon.Visible := False;
end;

procedure TFrmDamDialogDyn.SetFormTitle;

  function GetIconTitle: string;
  begin
    case DamMsg.Icon of
      diApp   : Result := Application.Title;
      diInfo  : Result := LangStrs.Info;
      diQuest : Result := LangStrs.Quest;
      diWarn  : Result := LangStrs.Warn;
      diError : Result := LangStrs.Error;
      diCustom: Result := LangStrs.Msg;
      else raise Exception.Create('Unknown icon kind property');
    end;
  end;

begin
  case DamMsg.Title of
    dtApp       : Caption := Application.Title;
    dtParentForm: Caption := TForm(DamMsg.Dam.Owner).Caption;
    dtMainForm  : Caption := Application.MainForm.Caption;
    dtByIcon    : Caption := GetIconTitle;
    dtCustom    : Caption := DamMsg.CustomTitle;
    else raise Exception.Create('Unknown title kind property');
  end;
end;

procedure TFrmDamDialogDyn.BuildButtons;
var
  NumButtons: Byte;
  I: Integer;
  Btn: TButton;
  Names: array[1..3] of string;
begin
  case DamMsg.Buttons of
    dbOne, dbOK: NumButtons := 1;
    dbTwo, dbYesNo: NumButtons := 2;
    dbThree: NumButtons := 3;
    else raise Exception.Create('Unknown buttons kind property');
  end;

  DamResult := NumButtons; //default result - last button

  Names[1] := DamMsg.Button1;
  Names[2] := DamMsg.Button2;
  Names[3] := DamMsg.Button3;

  case DamMsg.Buttons of
    dbOK: Names[1] := LangStrs.OK;
    dbYesNo:
      begin
        Names[1] := '&'+LangStrs.Yes;
        Names[2] := '&'+LangStrs.No;
      end;
  end;

  for I := 1 to NumButtons do
  begin
    Btn := TButton.Create(Self);
    Btn.Parent := BoxFloatBtns;
    Btn.{$IFDEF FMX}Text{$ELSE}Caption{$ENDIF} := Names[I];
    Btn.OnClick := OnBtnClick;
    Btn.Tag := I;

    ButtonsList.Add(Btn);
  end;

  ButtonsList.Last.Cancel := True;
  if DamMsg.SwapFocus then
    ActiveControl := ButtonsList.Last
  else
    ActiveControl := ButtonsList.First; //In FMX, first control is not auto focused
end;

procedure TFrmDamDialogDyn.LoadHelp;
begin
  BtnHelp.Visible :=
    {$IFDEF VCL}
    (DamMsg.HelpContext<>0) or (DamMsg.HelpKeyword<>EmptyStr)
    {$ELSE}
    False
    {$ENDIF};
end;

procedure TFrmDamDialogDyn.LoadTextProps;
begin
  {$IFDEF USE_IMGLST}
  LbMsg.Images := DamMsg.Dam.Images;
  {$ENDIF}
  LbMsg.Font.Assign(DamMsg.Dam.MessageFont);
  {$IFDEF FMX}
  LbMsg.FontColor := DamMsg.Dam.MessageFontColor;
  {$ENDIF}
end;

function TFrmDamDialogDyn.ToScale(Value: TPixels): TPixels;
begin
  {$IFDEF USE_SCALING}
  Result := Scaling.Calc(Value);
  {$ELSE}
  Result := Value;
  {$ENDIF}
end;

function TFrmDamDialogDyn.GetCurrentMonitorRect: TRect;
{$IFDEF USE_FMX_OLD_ENV}
var
  ScreenService: IFMXScreenService;
{$ENDIF}
begin
  {$IFDEF FMX}
    {$IFDEF USE_FMX_OLD_ENV}
    if TPlatformServices.Current.SupportsPlatformService(IFMXScreenService, IInterface(ScreenService)) then
      Result := TRect.Create(0, 0, Round(ScreenService.GetScreenSize.X), Round(ScreenService.GetScreenSize.Y))
    else
      raise Exception.Create('Could not get Monitor Rect');
    {$ELSE}
    Result := Screen.DisplayFromForm(Self).BoundsRect{$IF CompilerVersion >= 35}.Round{$ENDIF}; //Round - Delphi 11
    {$ENDIF}
  {$ELSE}
    Result := Monitor.BoundsRect;
  {$ENDIF}
end;

function GetDiv2(Value: TPixels): TPixels;
begin
  Result := Value {$IFDEF FMX}/{$ELSE}div{$ENDIF} 2;
end;

procedure TFrmDamDialogDyn.OverallAlign;
begin
  {$IFDEF USE_SCALING}
  Scaling := TDzFormScaling.Create;
  try
    Scaling.Update(Self, DESIGN_DPI);
  {$ENDIF}
    ManualFormScale;
    SetIcon;
    AlignButtons;
    CalcWidth;
    CalcHeight;
  {$IFDEF USE_SCALING}
  finally
    Scaling.Free;
  end;
  {$ENDIF}
end;

procedure TFrmDamDialogDyn.ManualFormScale;
{$IFDEF VCL}
var
  DPI: Integer;
{$ENDIF}
begin
  Icon.SetBounds(ToScale(8), ToScale(8), ToScale(32), ToScale(32));
  LbMsg.SetBounds(IfThen(Icon.Visible, ToScale(48), ToScale(8)), ToScale(8), 0, 0);
  BoxButtons.Height := ToScale(39);
  BoxFloatBtns.SetBounds(0, ToScale(8), 0, ToScale(25));
  BtnHelp.SetBounds(ToScale(8), ToScale(8), ToScale(25), ToScale(25));

  {$IFDEF VCL}
  //here we can't use ToScale (Scaling.Calc), because is set with Design DPI, instead of Monitor DPI
  DPI := {$IFDEF USE_SCALING}Scaling.MonitorPPI{$ELSE}DESIGN_DPI{$ENDIF};
  BoxButtons.Font.Height := CalcFontHeight(9, DPI);
  LbMsg.Font.Height := CalcFontHeight(DamMsg.Dam.MessageFont.Size, DPI);
  {$ENDIF}
end;

{$IFDEF VCL}
type TPictureAccess = class(TPicture); //needed in Delphi 10.1 Berlin and previous versions (LoadFromStream)
{$ENDIF}
procedure TFrmDamDialogDyn.SetIcon;

  {$IFDEF VCL_WIN}
  procedure LoadWindowsIcon(Code: Integer);
  begin
    Icon.Picture.Icon.Handle := LoadImage(GetModuleHandle('user32'),
      MAKEINTRESOURCE(Code), IMAGE_ICON, Icon.Width, Icon.Height, LR_DEFAULTCOLOR); //scaled
  end;
  {$ENDIF}

  procedure GetIconFromResource;
  var
    R: TResourceStream;
    ResName: string;
  begin
    ResName := string.Empty;
    case DamMsg.Icon of
      diApp   :
        {$IFDEF FMX}
        raise Exception.Create('Unsupported app icon in FMX environment');
        {$ELSE}
        Icon.Picture.Icon.Assign(Application.Icon);
        {$ENDIF}
      diCustom :
        {$IFDEF FMX}
        Icon.Bitmap.Assign(DamMsg.CustomIcon);
        {$ELSE}
        Icon.Picture.Icon.Assign(DamMsg.CustomIcon);
        {$ENDIF}
      diInfo  : ResName := 'IC_INFO';
      diQuest : ResName := 'IC_QUESTION';
      diWarn  : ResName := 'IC_WARNING';
      diError : ResName := 'IC_ERROR';
      else raise Exception.Create('Unknown icon kind property');
    end;

    if not ResName.IsEmpty then
    begin
      R := GetResource(ResName);
      try
        {$IFDEF FMX}
        Icon.Bitmap.LoadFromStream(R);
        {$ELSE}
        TPictureAccess(Icon.Picture).LoadFromStream(R);
        {$ENDIF}
      finally
        R.Free;
      end;
    end;
  end;

begin
  {$IFDEF VCL_WIN}
  case DamMsg.Icon of
    diApp   : Icon.Picture.Icon.Assign(Application.Icon);
    diCustom: Icon.Picture.Icon.Assign(DamMsg.CustomIcon);
    diInfo  : LoadWindowsIcon(104);
    diQuest : LoadWindowsIcon(102);
    diWarn  : LoadWindowsIcon(101);
    diError : LoadWindowsIcon(103);
    else raise Exception.Create('Unknown icon kind property');
  end;
  {$ELSE}
  GetIconFromResource;
  {$ENDIF}
end;

procedure TFrmDamDialogDyn.AlignButtons;
type TBmp =
  {$IFDEF FPC}
    Graphics
  {$ELSE}
    {$IFDEF FMX}
    FMX.{$IFDEF USE_NEW_UNITS}Graphics{$ELSE}Types{$ENDIF}
    {$ELSE}
    Vcl.Graphics
    {$ENDIF}
  {$ENDIF}.TBitmap;
var
  B: TBmp;
  Btn: TButton;
  X, W: TPixels;
begin
  B := TBmp.Create{$IFDEF USE_FMX_OLD_ENV}(1, 1){$ENDIF};
  try
    B.Canvas.Font.Assign(ButtonsList.First.Font);

    X := 0;
    for Btn in ButtonsList do
    begin
      W := Max(B.Canvas.TextWidth(Btn.{$IFDEF FMX}Text{$ELSE}Caption{$ENDIF})+ToScale(20), ToScale(75));
      Btn.SetBounds(X, 0, W, BoxFloatBtns.Height);
      X := X + Btn.Width + ToScale(8);
    end;
  finally
    B.Free;
  end;

  BoxFloatBtns.Width := ButtonsList.Last.BoundsRect.Right;
end;

procedure TFrmDamDialogDyn.CalcWidth;
var
  MinSize, X: TPixels;
begin
  if DamMsg.FixedWidth=0 then
    LbMsg.Width := Round(GetCurrentMonitorRect.Width * 0.75) //max width
  else
    LbMsg.Width := ToScale(DamMsg.FixedWidth);

  {$IFDEF USE_SCALING}
  LbMsg.DesignDPI := RetrieveDesignerPPI(TCustomForm(DamMsg.Dam.Owner));
  {$ENDIF}
  LbMsg.Text := DamMsg.Message; //set TEXT

  if (DamMsg.FixedWidth=0) and (LbMsg.TextWidth < LbMsg.Width) then
  begin
    MinSize := Max(ToScale(300), BoxFloatBtns.Width);
    LbMsg.Width := Max(LbMsg.TextWidth, MinSize);
  end;

  ClientWidth := Round(LbMsg.BoundsRect.Right+ToScale(8));

  //align FloatBtns
  if DamMsg.Dam.CenterButtons then
    X := GetDiv2(ClientWidth-BoxFloatBtns.Width) //center
  else
    X := ClientWidth-BoxFloatBtns.Width-ToScale(8); //right

  BoxFloatBtns.{$IFDEF FMX}Position.X{$ELSE}Left{$ENDIF} := X;
end;

procedure TFrmDamDialogDyn.CalcHeight;
var
  IconHeight: TPixels;
begin
  IconHeight := IfThen(Icon.Visible, Icon.Height);

  LbMsg.Height := LbMsg.TextHeight;
  ClientHeight := Round(
    Max(LbMsg.Height, IconHeight)+
    (LbMsg.{$IFDEF FMX}Position.Y{$ELSE}Top{$ENDIF}*2)+
    BoxButtons.Height);

  if LbMsg.Height<IconHeight then //text smaller than icon
  begin
    LbMsg.{$IFDEF FMX}Position.Y{$ELSE}Top{$ENDIF} :=
      LbMsg.{$IFDEF FMX}Position.Y{$ELSE}Top{$ENDIF} + GetDiv2(IconHeight-LbMsg.Height);
  end;
end;

type TFormAccess = class(TForm);
procedure TFrmDamDialogDyn.CenterForm;
var
  R: TRect;
  F: {$IFDEF FMX}TCommonCustomForm{$ELSE}TForm{$ENDIF};
begin
  //form screen position
  R := GetCurrentMonitorRect;
  F := nil;
  case DamMsg.Dam.DialogPosition of
    dpScreenCenter: {};
    dpMainFormCenter: F := Application.MainForm;
    dpActiveFormCenter: F := Screen.ActiveForm;
    else raise Exception.Create('Invalid dialog position property');
  end;
  if F<>nil then
    R :=
    {$IFDEF FMX}
      {$IF CompilerVersion >= 30} //Delphi 10 Seattle
      F.Bounds
      {$ELSE}
      TFormAccess(F).FWinService.GetWindowRect(Self).Round
      {$ENDIF}
    {$ELSE}
    F.BoundsRect
    {$ENDIF};

  Left := Round(R.Left + GetDiv2(R.Width - Width));
  Top := Round(R.Top + GetDiv2(R.Height - Height));
end;

procedure TFrmDamDialogDyn.FormShow(Sender: TObject);
begin
  if DamMsg.Dam.PlaySounds then
    DoSound;
end;

procedure TFrmDamDialogDyn.DoSound;

  procedure Play(const aSound: string);
  begin
    {$IFDEF MSWINDOWS}
    PlaySound(PChar(aSound), 0, SND_ASYNC);
    {$ENDIF}
  end;

begin
  case DamMsg.Icon of
    diQuest: Play('SYSTEMQUESTION');
    diWarn: Play('SYSTEMEXCLAMATION');
    diError: Play('SYSTEMHAND');
  end;
end;

procedure TFrmDamDialogDyn.Action_CopyExecute(Sender: TObject);
var
  aMsg: string;
  {$IFDEF FMX}
  uClipBoard: IFMXClipboardService;
  {$ENDIF}
begin
  aMsg := TDzHTMLText.HTMLToPlainText(LbMsg.Text);

  {$IFDEF FMX}
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService,
    {$IFDEF USE_FMX_OLD_ENV}IInterface(uClipBoard){$ELSE}uClipBoard{$ENDIF}) then
    uClipBoard.SetClipboard(aMsg);
  {$ELSE}
  Clipboard.AsText := aMsg;
  {$ENDIF}
end;

procedure TFrmDamDialogDyn.Action_HelpExecute(Sender: TObject);
begin
  if BtnHelp.Visible then
    BtnHelpClick(nil);
end;

procedure TFrmDamDialogDyn.BtnHelpClick(Sender: TObject);
begin
  {$IFDEF VCL}
  if DamMsg.HelpContext<>0 then
    Application.HelpContext(DamMsg.HelpContext)
  else
  if DamMsg.HelpKeyword<>EmptyStr then
    Application.HelpKeyword(DamMsg.HelpKeyword)
  else
    raise Exception.Create('Unknown help property');
  {$ENDIF}
end;

procedure TFrmDamDialogDyn.LbMsgLinkClick(Sender: TObject; Link: TDHBaseLink;
  var Handled: Boolean);
var
  CloseMsg: Boolean;
  ImmediateRes: TDamMsgRes;
begin
  if (Link.Kind = lkLinkRef) and Assigned(DamMsg.Dam.OnLinkClick) then
  begin
    CloseMsg := False;
    ImmediateRes := DamResult;

    DamMsg.Dam.OnLinkClick(DamMsg.Dam, DamMsg,
      Link.LinkRef.Target, Handled, CloseMsg, ImmediateRes);

    if CloseMsg then
    begin
      DamResult := ImmediateRes;
      Close;
    end;
  end;
end;

{$IFDEF USE_DPICHANGE}
procedure TFrmDamDialogDyn.OnAfterDpiChanged(Sender: TObject; Old, New: Integer);
begin
  OverallAlign;
end;
{$ENDIF}

procedure TFrmDamDialogDyn.OnBtnClick(Sender: TObject);
begin
  DamResult := TButton(Sender).Tag;
  Close;
end;

end.
