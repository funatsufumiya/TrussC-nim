import tcApp
import std/strformat
import nimline
import consoleUtil
import system

{.emit: """
#include "TrussC.h"

using namespace trussc;
using namespace tc;
""".}

proc ImGui_Begin(s: cstring) {.importcpp: "ImGui::Begin(@)" .}
proc ImGui_End() {.importcpp: "ImGui::End()" .}
proc ImGui_Text(s: cstring) {.importcpp: "ImGui::Text(@)" .}
proc ImGui_SliderFloat(s: cstring, f: ptr[cfloat], min: float, max: float) {.importcpp: "ImGui::SliderFloat(@)" .}

proc setup() {.cdecl.} =
  discard global.setFps(60)
  discard global.imguiSetup();

proc update() {.cdecl.} =
  let r: float = global.getFrameRate()
  let s = fmt"{r:.2f}"
  discard global.setWindowTitle(s)

var float_val: cfloat = 1.0

proc draw() {.cdecl.} =
  discard global.resetStyle()
  discard global.imguiBegin();
  ImGui_Begin("test")
  ImGui_Text("this is test!!")
  ImGui_SliderFloat("slider", float_val.addr, 0, 1)
  ImGui_End()
  discard global.imguiEnd();

proc keyPressed(key: cint) {.cdecl.} =
  let ckey = cast[char](key)
  if ckey == 'f' or ckey == 'F':
    discard global.toggleFullscreen()
  elif key == global.KEY_ESCAPE or ckey == 'q' or ckey == 'Q':
    discard global.exitApp()
    quit(0)
  elif ckey == 'm' or ckey == 'M':
    echo "total mem: ", getTotalMem()

when isMainModule:
  showConsole() # this is necessary to see logs
  var app = makeTcApp(setup=setup, update=update, draw=draw, keyPressed=keyPressed)
  app.run(800, 600)
