# This is a system for embedding external applications onto a main VCL form
## This was developed by myself as a robust and efficient optimisation solution for company needs and immediate use

### The problem / Why optimisation and this system was needed: 
Having a digital kiosk used in live sales presentations which opens external applications for showcasing is fine, however using ShellExecute to open the external apps proved very slow. ( 3-7 seconds based on external .exe ), thus making it not very fitting for live sales and showcasing.

I came up with a solution of opening the main VCL form once and having the external applications open silently/minimized in the background, they would then be embedded onto Delphi pages/panels ( TPageControl -> TTabSheet -> TPanel ). // Winapi.Windows.SetParent(WINDOW_HANDLE, TPanel)

I've also added in a debugger which streams logs to a UI element ( TMemo ) in Debug mode and a loading progress bar to show progress of external applications starting up alongisde a home screen.

The end result ended up being a robust and fast solution which allowed us to run a main program on older hardware and still be able to embedd external applications.
## Instead of waiting for 3-7 seconds for ShellExecute to run and startup a program; we load the exes silently on startup and can then switch through them INSTANTLY, cutting down the waiting time from 3-7 seconds to virtually nothing, a few miliseconds.

Breakdown of the app workflow: coming soon...