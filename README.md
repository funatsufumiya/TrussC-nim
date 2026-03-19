# TrussC-nim

[TrussC](https://github.com/TrussC-org/TrussC) nim integration

- TrussC version [v0.3.1 (2e8381a)](https://github.com/TrussC-org/TrussC/commit/2e8381a17b46edc4234925558ba336f753276e23)
- nim v2.2.8

![docs/screenshot.png](docs/screenshot.png)

```nim
import tcApp
import std/strformat
import nimline
import consoleUtil

{.emit: """
#include "TrussC.h"

using namespace trussc;
using namespace tc;
""".}

proc red {.importcpp: "tc::colors::red" .}

proc setup() {.cdecl.} =
  discard global.setFps(60)
  discard global.logNotice("hello Trussc!")

proc update() {.cdecl.} =
  let r: float = global.getFrameRate()
  let s = fmt"{r:.2f}"
  discard global.setWindowTitle(s)

proc draw() {.cdecl.} =
  discard global.setColor(red)
  discard global.drawRect(
    global.getMouseX() - 50,
    global.getMouseY() - 50,
    100, 100)

proc keyPressed(key: cint) {.cdecl.} =
  let ckey = cast[char](key)
  if ckey == 'f' or ckey == 'F':
    discard global.toggleFullscreen()
  elif key == global.KEY_ESCAPE or ckey == 'q' or ckey == 'Q':
    discard global.sapp_request_quit()

when isMainModule:
  showConsole() # this is necessary to see logs
  var app = makeTcApp(setup=setup, update=update, draw=draw, keyPressed=keyPressed)
  app.run(800, 600)
```

## Pre-requisites

### Windows

```bash
$ .¥scripts¥init_win.ps1
```

### Mac

```bash
$ ./scripts/init_mac.sh
```

## Examples

```bash
$ nim c -r examples/hello.nim
$ nim c -r examples/cpp_interop.nim
```

## How to use tcx addons

- At first, create `xxx.nim.addons` at side of the nim file.
    ```txt
    tcxOsc
    ```
- Copy tcxXXX folder into `addons/tcxXXX` (such as tcxOsc) from openFrameworks directory (or other github repository)
- Then try `nim c -r examples\osc_test.nim`
    - You can debug addon parse log by  `-d:addonsDebug`, such as `nim c -d:addonsDebug -r examples\osc_test.nim`

### NOTE: `import tcx_addons`

When you use ofx addons, you need `import tcx_addons` on nim side. This includes `generated/addon_dependencies.nim` on nim side, in order to compile required C++ files.

See [`examples/osc_test.nim`](examples/osc_test.nim) for detail.


## TODO

- Usage instruction for addons having CMakeLists.txt
- Linux support (etc)
