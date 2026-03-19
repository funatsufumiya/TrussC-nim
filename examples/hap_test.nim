import tcApp
import tcx_addons
import consoleUtil

import std/strformat
import nimline
import cppstl

{.emit: """
#include "TrussC.h"
#include "tcxHapPlayer.h"

using namespace trussc;
using namespace tc;
""" .}

# defineCppType(OscSender, "OscSender", "tcxOsc.h")
# defineCppType(OscMessage, "OscMessage", "tcxOsc.h")

# var osc_sender: OscSender
# var osc_msg: OscMessage

proc setup() {.cdecl.} =
    discard
    # discard osc_sender.setup("127.0.0.1", 12345)
    # discard osc_msg.setAddress("/test")
    # discard osc_sender.send(osc_msg)
    # discard osc_msg.clear()

proc update() {.cdecl.} =
    discard

proc draw() {.cdecl.} =
    discard

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

when isMainModule:
    showConsole() # this is necessary to see logs
    var app = makeTcApp(
        setup=setup, update=update, draw=draw,
        keyPressed=keyPressed,
        filesDropped=filesDropped)
    app.run(800, 600)