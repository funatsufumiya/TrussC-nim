import tcApp
import tcx_addons
import consoleUtil

import std/strformat
import std/strutils
import nimline
import cppstl

{.emit: """
#include "TrussC.h"
#include "tcxHapPlayer.h"

using namespace trussc;
using namespace tc;
using namespace tcx::hap;
""" .}

defineCppType(HapPlayer, "HapPlayer", "tcxHapPlayer.h")

var is_loaded = false
var player: HapPlayer

proc setup() {.cdecl.} =
    discard
    # discard osc_sender.setup("127.0.0.1", 12345)
    # discard osc_msg.setAddress("/test")
    # discard osc_sender.send(osc_msg)
    # discard osc_msg.clear()

proc update() {.cdecl.} =
    let r: float = global.getFrameRate()
    let s = fmt"{r:.2f}"
    discard global.setWindowTitle(s)

    if is_loaded and player.isLoaded().to(bool):
        discard player.update()
        # echo $player.getCurrentTime().to(float)

proc draw() {.cdecl.} =
    discard global.setColor(1, 1, 1)

    if not is_loaded:
        discard global.drawBitmapString("drop hap file here", 30, 30)
    else:
        if player.isLoaded().to(bool):
            discard global.resetStyle()
            discard player.draw(0, 0, global.getWindowWidth(), global.getWindowHeight())

            discard global.setColor(0.3, 0.3, 0.3, 0.5)
            discard global.drawRect(0, 20, 200, 40)

            discard global.setColor(1, 1, 1)
            let t = player.getCurrentTime().to(float)
            discard global.drawBitmapString(fmt"{t:0.2f}", 30, 30)

proc keyPressed(key: cint) {.cdecl.} =
    let ckey = cast[char](key)
    echo "key: ", $ckey
    if key == global.KEY_ESCAPE or ckey == 'q' or ckey == 'Q':
        discard global.sapp_request_quit()

proc filesDropped(info: pointer) {.cdecl.} =
    let raw_files = cast[ptr CppVector[CppString]](info)[]

    var files: seq[string] = @[]
    for i in 0 ..< raw_files.len:
        let f = raw_files[i]
        files.add($f)

    echo "dropped files: ", $(files)

    if files.len > 0 and 
        (files[0].endsWith(".mov") or files[0].endsWith(".avi")):
        discard player.load(files[0])
        discard player.play()
        discard player.setLoop(true)

        is_loaded = true
    else:
        echo "[Warning] files dropped, but only .mov and .avi is supported!"

when isMainModule:
    showConsole() # this is necessary to see logs
    var app = makeTcApp(
        setup=setup, update=update, draw=draw,
        keyPressed=keyPressed,
        filesDropped=filesDropped)
    app.run(800, 600)