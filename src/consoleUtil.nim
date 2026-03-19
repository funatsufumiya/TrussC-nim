## Windows console utility for showing/hiding a console window
## Usage: import tcConsoleWin; showConsole()

{.emit: """
#ifdef _WIN32
#include <Windows.h>
#include <stdio.h>
extern "C" {
  inline void tcn_showConsole_c() {
    AllocConsole();
    FILE* fp = nullptr;
    freopen_s(&fp, "CONOUT$", "w", stdout);
    freopen_s(&fp, "CONOUT$", "w", stderr);
    SetConsoleOutputCP(CP_UTF8);
  }
  inline void tcn_hideConsole_c() {
    FreeConsole();
  }
}
#else
extern "C" {
  inline void tcn_showConsole_c() {}
  inline void tcn_hideConsole_c() {}
}
#endif
""".}

proc tcn_showConsole_c() {.importc: "tcn_showConsole_c", cdecl.}
proc tcn_hideConsole_c() {.importc: "tcn_hideConsole_c", cdecl.}

proc showConsole*() {.cdecl.} =
  tcn_showConsole_c()

proc hideConsole*() {.cdecl.} =
  tcn_hideConsole_c()
