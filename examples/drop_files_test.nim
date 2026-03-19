import tcApp
import consoleUtil

import std/strformat
import std/strutils
import nimline
import cppstl

{.emit: """
#include "TrussC.h"

using namespace trussc;
using namespace tc;
""" .}

var str = "drop files here"

proc setup() {.cdecl.} =
    discard

proc update() {.cdecl.} =
    discard

proc draw() {.cdecl.} =
    discard global.drawBitmapString(str, 10, 10)

proc keyPressed(key: cint) {.cdecl.} =
    let ckey = cast[char](key)
    echo "key: ", $ckey
    if key == global.KEY_ESCAPE or ckey == 'q' or ckey == 'Q':
        discard global.sapp_request_quit()

proc wrapText(s: string, width: int): string =
    if width <= 0:
        return s
    result = ""
    var cnt = 0
    for ch in s:
        result.add ch
        inc cnt
        if cnt >= width:
            result.add '\n'
            cnt = 0
    return result

proc baseName(path: string): string =
    var i = path.len - 1
    while i >= 0:
        if path[i] == '/' or path[i] == '\\':
            return path[i+1 .. ^1]
        dec i
    return path

proc filesDropped(info: pointer) {.cdecl.} =
    let files = cast[ptr CppVector[CppString]](info)[]
    echo "files: ", $(files)

    var names: seq[string] = @[]
    for i in 0 ..< files.len:
        let f = files[i]
        names.add(baseName($f))

    str = wrapText(names.join(", "), 60)

when isMainModule:
    showConsole() # this is necessary to see logs
    var app = makeTcApp(
        setup=setup, update=update, draw=draw,
        keyPressed=keyPressed,
        filesDropped=filesDropped)
    app.run(800, 600)