import tcApp
import consoleUtil

# example state
var frameCount = 0

proc setup() {.cdecl.} =
    echo "hello TrussC!"

proc update() {.cdecl.} =
    inc frameCount

proc draw() {.cdecl.} =
    discard

proc keyPressed(key: cint) {.cdecl.} =
    let ckey = cast[char](key)
    echo "key: ", $ckey, " (", $key, "), frameCount: ", $frameCount

when isMainModule:
    showConsole()
    var app = makeTcApp(setup=setup, update=update, draw=draw, keyPressed=keyPressed)
    app.run(800, 600)