import std/strutils
import std/strformat
import std/os
# import std/private/ospaths2
from std/sequtils import toSeq

let projectRoot = parentDir(system.currentSourcePath)

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
#   requireDirs(@["lib/osx"], "./scripts/init_mac.sh")
    discard

switch("backend", "cpp")

when defined(windows):
  # switch("cc", "vcc")
  switch("cc", "clang_cl")
  switch("passC", "/std:c++17")
  switch("passC", "/utf-8")
  switch("passC", "/MD")
  switch("passC", "/DWIN32_LEAN_AND_MEAN")
  switch("passC", "/DNOMINMAX")
else:
  switch("passC", "-std=c++17")

switch("path", "src")
switch("passC", "-Iinclude")

when defined(windows):
  switch("passL", "lib\\vs\\x64\\TrussC.lib")