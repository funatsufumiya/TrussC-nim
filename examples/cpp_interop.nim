import tcApp
import std/strformat
import nimline

{.emit: """
#include "TrussC.h"

using namespace trussc;
using namespace tc;
""".}

# proc red {.importcpp: "tc::colors::red" .}

proc setup() {.cdecl.} =
  discard global.setFps(60)

proc update() {.cdecl.} =
  let r: float = global.getFrameRate()
  let s = fmt"{r:.2f}"
  discard global.setWindowTitle(s)

proc draw() {.cdecl.} =
  discard global.setColor(1.0, 0.0, 0.0)
  discard global.drawRect(
    global.getMouseX() - 50,
    global.getMouseY() - 50,
    100, 100)

when isMainModule:
  var app = makeTcApp(setup=setup, update=update, draw=draw)
  app.run(800, 600)
