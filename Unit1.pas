unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Controls, Vcl.Forms, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Dialogs,
  Vcl.OleCtrls, WMPLib_TLB, cxGraphics, cxControls,
  cxLookAndFeels, cxLookAndFeelPainters, cxContainer, cxEdit, cxImage, Vcl.StdCtrls, Unit2;

type
  TForm1 = class(TForm)
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    TabSheet3: TTabSheet;
    PanelHome: TPanel;
    PanelApp1: TPanel;
    PanelApp2: TPanel;
    WindowsMediaPlayer1: TWindowsMediaPlayer;
    ImgApp1: TcxImage;
    ImgApp2: TcxImage;
    ImgAppHome: TcxImage;
    ImgApp3: TcxImage;
    ImgApp4: TcxImage;
    ImgApp5: TcxImage;
    ImgApp6: TcxImage;
    TabSheet4: TTabSheet;
    TabSheet5: TTabSheet;
    TabSheet6: TTabSheet;
    PanelApp3: TPanel;
    PanelApp4: TPanel;
    PanelApp5: TPanel;
    TabSheet7: TTabSheet;
    PanelApp6: TPanel;
    ImgAppClose: TcxImage;
    Memo1_Debugger: TMemo;
    Timer1: TTimer;
    ProgressBar1: TProgressBar;
    Panel1: TPanel;
    Label1: TLabel;
    cxImage1: TcxImage;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure PageControl1Change(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure Log(const Msg: String);
    procedure Timer1Timer(Sender: TObject);
    procedure HideProgressBar(progressBarState: integer);
    procedure ImgApp1Click(Sender: TObject);
    procedure ImgAppHomeClick(Sender: TObject);
    procedure ImgApp2Click(Sender: TObject);
    procedure ImgApp3Click(Sender: TObject);
    procedure ImgApp4Click(Sender: TObject);
    procedure ImgApp5Click(Sender: TObject);
    procedure ImgApp6Click(Sender: TObject);
    procedure ImgCloseAppClick(Sender: TObject);

  private
    ButtonList: TList;
    procedure HighlightActiveButton(ActiveButton: TcxImage);

  type
    TAppRec = record
      ProcInfo: TProcessInformation;
      MainWnd: HWND;
      Panel: TPanel;
      Running: Boolean;
    end;

  var
    ProgressBarPosition: integer;
    Apps: array [1 .. 6] of TAppRec;
    function StartAndEmbed(const AExePath: string; APanel: TPanel;
      out AppRec: TAppRec): Boolean;
    function FindMainWindowForPid(ProcId: DWORD;
      TimeoutMs: integer = 8000): HWND;
    procedure EmbedWindowIntoPanel(hWin: HWND; APanel: TPanel);
    procedure ResizeEmbeddedWindows;
    procedure StopApp(var AppRec: TAppRec);
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

{ enum helper }
type
  PFindData = ^TFindData;
  // PFindData is a pointer to a record of type TFindData

  TFindData = record
    ProcId: DWORD;
    Found: HWND;
  end;

// Logger which streams messages to a UI element
procedure TForm1.Log(const Msg: String);
begin
  Memo1_Debugger.Lines.Add(FormatDateTime('hh:nn:ss', Now) + ' - ' + Msg);
end;

// Apply styles to current active TabSheet button
procedure TForm1.HighlightActiveButton(ActiveButton: TcxImage);
var
  I: integer;
  Img: TcxImage;

begin

  for I := 0 to ButtonList.Count - 1 do
  begin

    Img := TcxImage(ButtonList[I]);

    if Img = ActiveButton then
      ActiveButton.Height := 60
    else
      Img.Height := 50;

  end;

end;

// Hide loading bar and welcome screen
procedure TForm1.HideProgressBar(progressBarState: integer);
begin

  if progressBarState = Length(Apps) then
  begin
    ProgressBar1.Visible := False;
    Panel1.Visible := False;
  end;

end;

{ Helper callback function for the Windows API EnumWindows -> Enumerates all top-level windows }
function EnumFindWindow(HWND: HWND; lParam: lParam): BOOL; stdcall;
var
  pid: DWORD;
  fd: PFindData;
  // Variable fd points to a memory address which has a type record: TFindData
begin
  fd := PFindData(lParam); // CONVERTS lParam: number back into a pointer to TFindData...
  GetWindowThreadProcessId(HWND, @pid); // This basically asks Windows: What process does this window handle (HWND) belong to? Write that processId into our pid variable.

  // the Process ID we need is written into stack-memory fd^. This is safe to do beacuse EnumWindows is synchronous. 
  //Should also check the window isnt invisible and we aren't targetting a child window, the main window is most likely the app.
  if (pid = fd^.ProcId) and IsWindowVisible(HWND) and (GetParent(HWND) = 0) then
  begin
    fd^.Found := HWND;
    Result := False; // stop enumeration
    Exit;
  end;
  Result := True;
end;

{ wait/find main window for process id with retries }
function TForm1.FindMainWindowForPid(ProcId: DWORD;
  TimeoutMs: integer = 8000): HWND;
var
  fd: TFindData;
  waited, step: integer;
begin
  Result := 0;
  fd.ProcId := ProcId;
  fd.Found := 0;
  waited := 0;
  step := 100;
  while (waited < TimeoutMs) do
  begin
    fd.Found := 0;
    // if a top-level window matches our fd.ProcId we found our window handle, and fd.Found should no longer be 0
    // We give the Windows EnumWindows a function callback to use on every top-level window: @EnumFindWindow
    // And a custom data-pointer fd to be used for checking if we found our process.
    EnumWindows(@EnumFindWindow, lParam(@fd));
    if fd.Found <> 0 then
    begin
      Result := fd.Found; // fd.Found will be equal to the process window handle HWND as per our callback function once it's found.
      Exit;
    end;
    Sleep(step);
    Application.ProcessMessages; // unblock UI while we wait
    Inc(waited, step);
  end;
end;

{ remove window chrome, prevent maximize, parent and fit to panel }
procedure TForm1.EmbedWindowIntoPanel(hWin: HWND; APanel: TPanel);
var
  style: NativeInt;
  exStyle: NativeInt;
  wp: TWindowPlacement;
begin
  if (hWin = 0) or not IsWindow(hWin) then
  begin
    Logger('EmbedWindowIntoPanel failed for: ' + APanel.Name);
    Exit;
  end;

  { restore to normal first }
  FillChar(wp, SizeOf(wp), 0);
  wp.Length := SizeOf(wp);
  if GetWindowPlacement(hWin, wp) then
  begin
    wp.showCmd := SW_SHOWNORMAL;
    SetWindowPlacement(hWin, wp);
  end
  else
    ShowWindow(hWin, SW_RESTORE);

  { adjust styles: remove maximize and popup bits, set child }
  style := GetWindowLongPtr(hWin, GWL_STYLE);
  exStyle := GetWindowLongPtr(hWin, GWL_EXSTYLE);

  style := style and not(WS_CAPTION or WS_THICKFRAME or WS_MAXIMIZE or
    WS_MAXIMIZEBOX or WS_POPUP);
  style := style or WS_CHILD;
  exStyle := exStyle and not WS_EX_TOOLWINDOW;

  SetWindowLongPtr(hWin, GWL_STYLE, style);
  SetWindowLongPtr(hWin, GWL_EXSTYLE, exStyle);

  { parent and force style apply }
  Winapi.Windows.SetParent(hWin, APanel.Handle);
  SetWindowPos(hWin, HWND_TOP, 0, 0, APanel.Width, APanel.Height,
    SWP_NOZORDER or SWP_SHOWWINDOW or SWP_FRAMECHANGED);
  ShowWindow(hWin, SW_SHOWNORMAL);
  Logger('Embedding External Application onto: ' + APanel.Name);
end;

{ start process, wait for its window, enforce normal state, embed }
function TForm1.StartAndEmbed(const AExePath: string; APanel: TPanel;
  out AppRec: TAppRec): Boolean;
const
  FIND_TIMEOUT = 8000; // ms per app
var
  si: TStartupInfo;
  ok: Boolean;
  h: HWND;
  ExeDir: string;
begin
  Result := False;

  // Always use this pattern of safe-default-init when calling Windows API structures that have many fields, especially if the API docs say �must be zeroed if unused.�
  ZeroMemory(@si, SizeOf(si));
  si.cb := SizeOf(si);

  // AppRec.ProcInfo will be filled out by Windows.CreateProcess later. We zero it now so it doesn't contain random garbage when Windows tries to read it later.
  ZeroMemory(@AppRec.ProcInfo, SizeOf(AppRec.ProcInfo));
  AppRec.MainWnd := 0;
  AppRec.Panel := APanel;
  AppRec.Running := False;

  if not FileExists(AExePath) then
  begin
    Logger('File path does not exist: ' + AExePath);
    Exit;
  end;

  ExeDir := ExtractFilePath(AExePath);
  // Setting the directory of the external exe's to NOT be the MainApp root. Fixes resource lookup issue.

  ok := CreateProcess(PChar(AExePath), nil, nil, nil, False,
    NORMAL_PRIORITY_CLASS, nil, PChar(ExeDir), si, AppRec.ProcInfo);
  if not ok then
  begin
    Logger('CreateProcess failed for: ' + ExeDir);
    Exit;
  end;

  AppRec.Running := True;

  { Wait for main window. Try a couple of times to account for late creation. }
  h := FindMainWindowForPid(AppRec.ProcInfo.dwProcessId, FIND_TIMEOUT);
  if h = 0 then
  begin
    { brief pause and one retry }
    Sleep(200);
    Application.ProcessMessages;
    h := FindMainWindowForPid(AppRec.ProcInfo.dwProcessId, FIND_TIMEOUT div 2);
  end;

  { If still not found, kill process to avoid orphan locks }
  if h = 0 then
  begin
    TerminateProcess(AppRec.ProcInfo.hProcess, 1);
    CloseHandle(AppRec.ProcInfo.hProcess);
    CloseHandle(AppRec.ProcInfo.hThread);
    AppRec.Running := False;
    Exit;
  end;

  { Ensure window is not fullscreen/maximized and then embed }
  AppRec.MainWnd := h;
  { small safety delay to let the window settle }
  Sleep(100);
  Application.ProcessMessages;

  EmbedWindowIntoPanel(h, APanel);

  Inc(ProgressBarPosition, 1);
  ProgressBar1.Position := ProgressBarPosition;

  Logger('External Application started and embedded: ' + ExeDir);

  HideProgressBar(ProgressBarPosition);

  Result := True;
end;

{ resize embedded windows to their panels }
procedure TForm1.ResizeEmbeddedWindows;
var
  I: integer;
  w, h: integer;
begin
  Logger('ResizeEmbeddedWindows procedure running');
  for I := 1 to High(Apps) do
    if Apps[I].Running and (Apps[I].MainWnd <> 0) and IsWindow(Apps[I].MainWnd)
    then
    begin
      w := Apps[I].Panel.Width;
      h := Apps[I].Panel.Height;
      SetWindowPos(Apps[I].MainWnd, HWND_TOP, 0, 0, w, h, SWP_NOZORDER or
        SWP_SHOWWINDOW);
    end;
end;

{ try to close process ( our App array ) gracefully then force if needed }
procedure TForm1.StopApp(var AppRec: TAppRec);
begin
  if not AppRec.Running then
    Exit;
  try
    if (AppRec.MainWnd <> 0) and IsWindow(AppRec.MainWnd) then
    begin
      PostMessage(AppRec.MainWnd, WM_CLOSE, 0, 0);
      if WaitForSingleObject(AppRec.ProcInfo.hProcess, 2000) = WAIT_TIMEOUT then
        TerminateProcess(AppRec.ProcInfo.hProcess, 0);
    end
    else
    begin // One retry just in case
      if WaitForSingleObject(AppRec.ProcInfo.hProcess, 100) = WAIT_TIMEOUT then
        TerminateProcess(AppRec.ProcInfo.hProcess, 0);
    end;
  finally
    if AppRec.ProcInfo.hProcess <> 0 then
      CloseHandle(AppRec.ProcInfo.hProcess);
    if AppRec.ProcInfo.hThread <> 0 then
      CloseHandle(AppRec.ProcInfo.hThread);
    AppRec.Running := False;
    AppRec.MainWnd := 0;
  end;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
var
  I: integer;
const
  EXE1_PATH = 'C:\Path\Your1.exe';
  EXE2_PATH = 'C:\Path\Your2.exe';
  EXE3_PATH = 'C:\Path\Your3.exe';
  EXE4_PATH = 'C:\Path\Your4.exe';
  EXE5_PATH = 'C:\Path\Your5.exe';
  EXE6_PATH = 'C:\Path\Your6.exe';

begin
  // RUN Startup logic for exes here after defering for a little bit allowing the MainForm to render with a loading bar...
  Timer1.Enabled := False;
  
  Application.ProcessMessages; // unblock UI

  { start and embed apps at launch for fluid switching }
  StartAndEmbed(EXE1_PATH, PanelApp1, Apps[1]);
  StartAndEmbed(EXE2_PATH, PanelApp2, Apps[2]);
  StartAndEmbed(EXE3_PATH, PanelApp3, Apps[3]);
  StartAndEmbed(EXE4_PATH, PanelApp4, Apps[4]);
  StartAndEmbed(EXE5_PATH, PanelApp5, Apps[5]);
  StartAndEmbed(EXE6_PATH, PanelApp6, Apps[6]);

  { Handling home video }
  with WindowsMediaPlayer1 do
  begin
    WindowsMediaPlayer1.URL := 'NikaDemoVideo1.mp4';
    WindowsMediaPlayer1.uiMode := 'none';
    settings.setMode('loop', True);
    Controls.play;
  end;

  // Expecting apps to be running, checking functions:
  Logger('External Applications currently running: ' + Length(Apps).ToString());

  Logger('Current state of Apps after all startAndEmbeds: TAppRec record: ');
  for I := Low(Apps) to High(Apps) do
    Logger('App ' + I.ToString() + ' --> External application info: ' +
      'Running on Panel: ' + Apps[I].Panel.Name + ' with processId: ' +
      Apps[I].ProcInfo.dwProcessId.ToString());

end;

{ Form events }
procedure TForm1.FormCreate(Sender: TObject);
begin
  Memo1_Debugger.WordWrap := True;
  Memo1_Debugger.ReadOnly := True;

  ButtonList := TList.Create;

  Unit2.SetLogHandler(Log); // Subscribing to logger

  ButtonList.Add(ImgAppHome);
  ButtonList.Add(ImgApp1);
  ButtonList.Add(ImgApp2);
  ButtonList.Add(ImgApp3);
  ButtonList.Add(ImgApp4);
  ButtonList.Add(ImgApp5);
  ButtonList.Add(ImgApp6);

  Form1.BorderStyle := bsNone;
  Form1.BorderIcons := [];

  TabSheet1.TabVisible := False;
  TabSheet2.TabVisible := False;
  TabSheet3.TabVisible := False;
  TabSheet4.TabVisible := False;
  TabSheet5.TabVisible := False;
  TabSheet6.TabVisible := False;
  TabSheet7.TabVisible := False;

  { show home tab initially }
  PageControl1.ActivePageIndex := 0;

  ProgressBar1.Max := Length(Apps);
  ProgressBarPosition := 0;
  ProgressBar1.Position := ProgressBarPosition;

end;

procedure TForm1.PageControl1Change(Sender: TObject);
begin
  { ensure embedded windows are sized and get focus via ForeGroundWindow when their tab is active }
  ResizeEmbeddedWindows;
  if PageControl1.ActivePage = TabSheet2 then
    if (Apps[1].MainWnd <> 0) then
      SetForegroundWindow(Apps[1].MainWnd);
  if PageControl1.ActivePage = TabSheet3 then
    if (Apps[2].MainWnd <> 0) then
      SetForegroundWindow(Apps[2].MainWnd);
  if PageControl1.ActivePage = TabSheet4 then
    if (Apps[3].MainWnd <> 0) then
      SetForegroundWindow(Apps[3].MainWnd);
  if PageControl1.ActivePage = TabSheet5 then
    if (Apps[4].MainWnd <> 0) then
      SetForegroundWindow(Apps[4].MainWnd);
  if PageControl1.ActivePage = TabSheet6 then
    if (Apps[5].MainWnd <> 0) then
      SetForegroundWindow(Apps[5].MainWnd);
  if PageControl1.ActivePage = TabSheet7 then
    if (Apps[6].MainWnd <> 0) then
      SetForegroundWindow(Apps[6].MainWnd);
end;

procedure TForm1.FormResize(Sender: TObject);
begin
  ResizeEmbeddedWindows;
end;

// Defer start-up to FormShow, i need my FormCreate to show Form first so i can setup a loading progress bar..
procedure TForm1.FormShow(Sender: TObject);
begin

  Timer1.Enabled := True;

end;

procedure TForm1.ImgApp1Click(Sender: TObject);
begin
  HighlightActiveButton(ImgApp1);
  PageControl1.ActivePage := TabSheet2;
end;

procedure TForm1.ImgApp2Click(Sender: TObject);
begin
  HighlightActiveButton(ImgApp2);
  PageControl1.ActivePage := TabSheet3;
end;

procedure TForm1.ImgApp3Click(Sender: TObject);
begin
  HighlightActiveButton(ImgApp3);
  PageControl1.ActivePage := TabSheet4;
end;

procedure TForm1.ImgApp4Click(Sender: TObject);
begin
  HighlightActiveButton(ImgApp4);
  PageControl1.ActivePage := TabSheet5;
end;

procedure TForm1.ImgApp5Click(Sender: TObject);
begin
  HighlightActiveButton(ImgApp5);
  PageControl1.ActivePage := TabSheet6;
end;

procedure TForm1.ImgApp6Click(Sender: TObject);
begin
  HighlightActiveButton(ImgApp6);
  PageControl1.ActivePage := TabSheet7;
end;

procedure TForm1.ImgAppHomeClick(Sender: TObject);
begin
  HighlightActiveButton(ImgAppHome);
  PageControl1.ActivePage := TabSheet1;
end;

procedure TForm1.ImgCloseAppClick(Sender: TObject);
begin
  Application.Terminate;
end;

// Exit process to gracefully or forcefully stop external PID's and the main form shutdown
procedure TForm1.FormDestroy(Sender: TObject);
var
  I: integer;
begin
  for I := 1 to High(Apps) do
    StopApp(Apps[I]);

  ButtonList.Free;
end;

end.
