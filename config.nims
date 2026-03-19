import std/strutils
import std/strformat
import std/os
# import std/private/ospaths2
from std/sequtils import toSeq

let projectRoot = parentDir(system.currentSourcePath)

var detectedMainNim = ""
var i = paramCount()
while i >= 1:
  let p = paramStr(i)
  if p.len > 0 and p[0] != '-' and p.toLowerAscii().endsWith(".nim"):
    detectedMainNim = p
    break
  i = i - 1

let mainNimRelPath = detectedMainNim

# Ensure required library folders exist; if missing, instruct user to run installer scripts.
proc requireDirs(dirs: seq[string], hintCmd: string) =
  for d in dirs:
    let p = joinPath(projectRoot, d)
    if not dirExists(p):
      let newline = "\n"
      quit(fmt"[Error] {p} not found.{newline}Please run: {hintCmd} to install the libraries and retry.{newline}")

when defined(windows):
  requireDirs(@["lib\\vs"], ".\\scripts\\init_win.ps1")
elif defined(macosx):
  requireDirs(@["lib/osx"], "./scripts/init_mac.sh")

switch("backend", "cpp")

when defined(windows):
  # switch("cc", "vcc")
  switch("cc", "clang_cl")
  switch("passC", "/std:c++17")
  switch("passC", "/utf-8")
  switch("passC", "/MD")
  switch("passC", "/DWIN32_LEAN_AND_MEAN")
  switch("passC", "/DFAR=")
  switch("passC", "/DNOMINMAX")
else:
  switch("passC", "-std=c++17")

switch("path", "src")
switch("passC", "-Iinclude")
switch("passC", "-Ihap")

include "addons.nims"

# load xxx.nim.addons
let preferredAddons = selectAddonsFile(projectRoot, mainNimRelPath)
if preferredAddons.len > 0:
  let localAddonsDir = joinPath(projectRoot, "addons")
  if dirExists(localAddonsDir):
    processAddons(preferredAddons, localAddonsDir, projectRoot)
  else:
    let nl = "\n"
    quit(fmt"[Error] addons file found: {preferredAddons}{nl}but addons directory not present: {localAddonsDir}{nl}Create the directory or remove the addons file and retry.{nl}")

when defined(windows):
  switch("passL", "lib\\vs\\x64\\TrussC.lib")
elif defined(macosx):
  switch("passL", "lib/osx/libTrussC.a")
  switch("passL", "-framework CoreFoundation")
  switch("passL", "-framework AudioToolbox")
  switch("passL", "-framework CoreGraphics")
  switch("passL", "-framework Metal")
  switch("passL", "-framework AppKit")
  switch("passL", "-framework Foundation")
  switch("passL", "-framework QuartzCore")
  switch("passL", "-lobjc")
  switch("passL", fmt"-rpath {projectRoot}/lib/osx")