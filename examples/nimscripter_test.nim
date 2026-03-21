import tcApp
import std/strformat
import nimline
import consoleUtil
import system
import nimscripter
import std/random

randomize()

{.emit: """
#include "TrussC.h"

using namespace trussc;
using namespace tc;
""".}

proc red {.importcpp: "tc::colors::red" .}

proc mouseX(): float =
  let v: float = global.getMouseX()
  return v

proc mouseY(): float =
  let v: float = global.getMouseY()
  return v

proc color(r, g, b: float) =
  discard global.setColor(r, g, b)

proc randf(): float =
  return rand(1.0)

proc text(s:string, x, y: float) =
  discard global.drawBitmapString(s, x, y)

proc drawAt(x, y: float, s:float = 30) =
  discard global.drawCircle(x, y, s)

exportTo(myImpl, text, drawAt, mouseX, mouseY, color, randf)

let script = NimScriptFile("""
proc setup*() =
  echo "hello from nimscript!"

proc update*() =
  discard

proc draw*() =
  text("this is drawn from script!", 30, 30)

  color(randf(), randf(), randf())
  drawAt(mouseX(), mouseY())
""")

let intr = loadScript(script, implNimScriptModule(myImpl))

proc setup() {.cdecl.} =
  discard global.setFps(60)
  intr.invoke(setup)

proc update() {.cdecl.} =
  let r: float = global.getFrameRate()
  let s = fmt"{r:.2f}"
  discard global.setWindowTitle(s)
  intr.invoke(update)

proc draw() {.cdecl.} =
  intr.invoke(draw)

  # discard global.setColor(red)
  # discard global.drawRect(
  #   global.getMouseX() - 50,
  #   global.getMouseY() - 50,
  #   100, 100)

proc keyPressed(key: cint) {.cdecl.} =
  let ckey = cast[char](key)
  if ckey == 'f' or ckey == 'F':
    discard global.toggleFullscreen()
  elif key == global.KEY_ESCAPE or ckey == 'q' or ckey == 'Q':
    discard global.exitApp()
    quit()

when isMainModule:
  showConsole() # this is necessary to see logs
  var app = makeTcApp(setup=setup, update=update, draw=draw, keyPressed=keyPressed)
  app.run(800, 600)
