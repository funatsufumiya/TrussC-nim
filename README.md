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

when isMainModule:
  showConsole() # this is necessary to see logs
  var app = makeTcApp(setup=setup, update=update, draw=draw)
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

## TODO

- addons
- Linux support (etc)
