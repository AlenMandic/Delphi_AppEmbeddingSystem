# This is a system for embedding external applications onto a main VCL form

## This was developed by myself as a robust and efficient optimisation solution for company needs and immediate use

### The problem / Why optimisation and this system was needed

Having a digital kiosk used in live sales presentations which opens external applications for showcasing is fine, however using ShellExecute to open the external apps proved very slow. ( 3-7 seconds based on external .exe ), thus making it not very fitting for live sales and showcasing.

I came up with a solution of opening the main VCL form once and having the external applications open silently/minimized in the background, they would then be embedded onto Delphi pages/panels ( TPageControl -> TTabSheet -> TPanel ). // Winapi.Windows.SetParent(WINDOW_HANDLE, TPanel)

I've also added in a debugger which streams logs to a UI element ( TMemo ) in Debug mode and a loading progress bar to show progress of external applications starting up alongisde a home screen.

The end result ended up being a robust and fast solution which allowed us to run a main program on older hardware and still be able to embedd external applications.

## Instead of waiting for 3-7 seconds for ShellExecute to run and startup a program; we load the exes silently on startup and can then switch through them INSTANTLY, cutting down the waiting time from 3-7 seconds to virtually nothing, a few miliseconds

#### Data Structures used:

An Array of Records(TAppRec type) will hold each external process runtime information, panel to embedd onto, isRunning bool.

`Apps [ 1.. N ] of TAppRec`

`TAppRec = record`
`ProcInfo: TProcessInformation` --> handles/IDs from Windows.CreateProcess.
`MainWnd: HWND` --> the main window handle discovered for the child process.
`Panel: TPanel` --> the hosting panel.
`Running: Boolean` --> whether the app was started.

And a simple enum helper, not tied to main Form lifecycle ( Only exists while FindMainWindowForPid function runs )
`type PFindData = ^TFindData` --> pointer to a memory address containing a record of type TFindData.

`TFindData = record
 ProcID: DWORD;` --> INPUT: Pass in a ProcessId for which we want to find it's main window handle ( HWND )
 `Found: HWND;` --> OUTPUT: The main window handle for a given ProcID

Why am i using pointers and not simpler data structures? Beacuse Windows API methods use older C style API calls. EnumWindows expects Lparam to be an integer, a pointer let's me share data between the main function ( Windows.EnumWindows ) and the callback ( EnumFindWindows ). So we create a temporary data record TFindData, give it an input ( ProcId ) and an output which we will read ( Found: HWND ). This way as EnumWindows runs our callback for each window, once it finds what we need, it will set our fd.Found variable to the correct window handle.

#### Below are the important functions and what they do (quick reference):

`EnumFindWindow(HWND: HWND; lParam: lParam): BOOL; stdcall`
Helper used with EnumWindows to find the first top-level window belonging to a process id (filters for visible top-level windows with no parent). Used by the window-find loop. 

`FindMainWindowForPid(ProcId: DWORD; TimeoutMs: Integer): HWND`
Repeatedly calls EnumWindows/EnumFindWindow within a timeout to wait for the child process's main window. Sleeps briefly between attempts and processes messages to keep UI responsive. Default timeout is 5000ms in the docs. 

`EmbedWindowIntoPanel(hWin: HWND; APanel: TPanel)`
Removes chrome (caps, borders), sets WS_CHILD, calls SetParent, SetWindowPos and ShowWindow to embed and size the window to the panel. Use ClientWidth/ClientHeight when using Align := alClient. Use NativeInt for style manipulation under range checking. 

`StartAndEmbed(const AExePath: string; APanel: TPanel; out AppRec: TAppRec): Boolean`
Verifies file exists, computes ExeDir, calls CreateProcess (with lpCurrentDirectory := ExeDir), stores handles/IDs, sets Running := True, then calls FindMainWindowForPid and EmbedWindowIntoPanel if found. Flags used in docs: CREATE_NEW_CONSOLE and NORMAL_PRIORITY_CLASS. 

`ResizeEmbeddedWindows`
Iterates Apps[] and SetWindowPos for running apps so the child windows match panel sizes. Called on FormResize. 

`StopApp(var AppRec: TAppRec)`
Posts WM_CLOSE, waits (up to ~2000ms), calls TerminateProcess if necessary, closes handles, clears the AppRec and marks Running := False. Avoids leaks.
