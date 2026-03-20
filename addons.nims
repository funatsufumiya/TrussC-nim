import std/os
import std/strutils
import std/strformat
include "config_parser.nims"

when defined(addonsDebug):
  const debugAddons = true
else:
  const debugAddons = false

proc logAdd(s: string) =
  if debugAddons:
    echo s

proc getFileName(path: string): string =
  # return the last path component (basename)
  let (_, base) = splitPath(path)
  return base

proc copyFile(src: string, dst: string) =
  # Cross-platform copy using shell commands via execShell
  if src.len == 0 or dst.len == 0: return
  let dq = "\""
  when defined(windows):
    let cmd = fmt"cmd /C copy /Y {dq}{src}{dq} {dq}{dst}{dq}"
  else:
    let cmd = fmt"cp -f {dq}{src}{dq} {dq}{dst}{dq}"
  try:
    exec(cmd)
    logAdd(fmt"copyFile: {src} -> {dst}")
  except OSError as e:
    quit(fmt"[Error] failed to copy {src} -> {dst}: {e.msg}\n")

# collected C/C++ sources to generate a Nim file with {.compile: ...} pragmas
var discoveredCppSources: seq[string] = @[]

proc walkDirRec(root: string): seq[string] =
  result = @[]
  if not dirExists(root): return result
  for kind, p in walkDir(root):
    if kind == pcDir:
      result.add(p)
      let subs = walkDirRec(p)
      for sp in subs: result.add(sp)

proc findSourceFiles(root: string): seq[string] =
  result = @[]
  if not dirExists(root): return result
  for kind, p in walkDir(root):
    if kind == pcFile:
      let lower = p.toLowerAscii()
      if lower.endsWith(".cpp") or lower.endsWith(".c") or lower.endsWith(".cc") or lower.endsWith(".cxx") or lower.endsWith(".mm") or lower.endsWith(".m"):
        result.add(p)
    elif kind == pcDir:
      let subs = findSourceFiles(p)
      for s in subs: result.add(s)
  return result

proc addInclude(path: string) =
  if path.len == 0: return
  if dirExists(path):
    logAdd(fmt"passC: -I{path}")
    switch("passC", fmt"-I{path}")

proc addLink(path: string) =
  if path.len == 0: return
  logAdd(fmt"passL: {path}")
  switch("passL", path)

proc scanPrebuiltDir(dir: string, lname: string, projectRootArg: string): bool =
  var found = false
  if dir.len == 0 or not dirExists(dir): return found
  for kind, p in walkDir(dir):
    if kind == pcFile:
      let low = p.toLowerAscii()
      when defined(windows):
        if low.endsWith(".lib") and low.contains(lname):
          addLink(p)
          found = true
        elif low.endsWith(".dll") and low.contains(lname):
          addLink(p)
          copyFile(p, joinPath(projectRootArg, getFileName(p)))
          found = true
      elif defined(macosx):
        if low.endsWith(".a") and low.contains(lname):
          addLink(p)
          found = true
        elif low.endsWith(".dylib") and low.contains(lname):
          addLink(p)
          copyFile(p, joinPath(projectRootArg, getFileName(p)))
          found = true
      elif defined(linux):
        if low.endsWith(".a") and low.contains(lname):
          addLink(p)
          found = true
        elif low.endsWith(".so") and low.contains(lname):
          addLink(p)
          found = true
      else:
        if (low.endsWith(".lib") or low.endsWith(".a") or low.endsWith(".dll") or low.endsWith(".dylib") or low.endsWith(".so")) and low.contains(lname):
          addLink(p)
          found = true
  return found

proc scanAddonLibs(addonLibs: string, projectRootArg: string): bool =
  var found = false
  if addonLibs.len == 0 or not dirExists(addonLibs): return found
  for kind, p in walkDir(addonLibs):
    if kind == pcFile:
      let low = p.toLowerAscii()
      when defined(windows):
        if low.endsWith(".lib") or low.endsWith(".dll"):
          addLink(p)
          if low.endsWith(".dll"): copyFile(p, joinPath(projectRootArg, getFileName(p)))
          found = true
      elif defined(macosx):
        if low.endsWith(".a") or low.endsWith(".dylib"):
          addLink(p)
          if low.endsWith(".dylib"): copyFile(p, joinPath(projectRootArg, getFileName(p)))
          found = true
      elif defined(linux):
        if low.endsWith(".a") or low.endsWith(".so"):
          addLink(p)
          found = true
      else:
        if low.endsWith(".lib") or low.endsWith(".a") or low.endsWith(".dll") or low.endsWith(".dylib") or low.endsWith(".so"):
          addLink(p)
          found = true
  return found

proc prebuiltMissingNote(addonName: string, projectRootArg: string): string =
  let nl = "\n"
  let note = "[NOTE]"
  let addonRel = joinPath("addons", addonName)
  return fmt"{nl}{note} The addon '{addonRel}' contains a CMakeLists.txt.{nl}       TrussC-nim does not run CMake; {nl}       Please build this addon using TrussC and place the resulting prebuilt libraries {nl}       under the project's `prebuilt/<platform>` directory before retrying. See README.md for details.{nl}"

proc selectAddonsFile*(projectRoot: string, mainNimRelPath: string): string =
  if mainNimRelPath.len == 0: return ""
  let candidate = mainNimRelPath & ".addons"
  if fileExists(candidate): return candidate
  if not isAbsolute(mainNimRelPath):
    let relativeCandidate = joinPath(projectRoot, candidate)
    if fileExists(relativeCandidate): return relativeCandidate
  let (_, base) = splitPath(mainNimRelPath)
  if base.endsWith(".nim"):
    let baseCandidate = joinPath(projectRoot, base & ".addons")
    if fileExists(baseCandidate): return baseCandidate
  return ""

proc processAddons*(addonsMakePath: string, addonsDir: string, projectRootArg: string) =
  if addonsMakePath.len == 0: return
  if not fileExists(addonsMakePath): return
  if not dirExists(addonsDir): return

  let lines = readFile(addonsMakePath).splitLines()
  var names: seq[string] = @[]
  for raw in lines:
    var line = raw.strip()
    if line.len == 0: continue
    if line.startsWith("#"): continue
    let token = line.splitWhitespace()[0]
    var name = token
    if name.contains("/") or name.contains("\\"):
      var parts = if name.contains("/"): name.split("/") else: name.split("\\")
      if parts.len > 0: name = parts[parts.len-1]
    if name.len == 0: continue
    names.add(name)

  for n in names:
    let addonPath = joinPath(addonsDir, n)
    if not dirExists(addonPath):
      let nl = "\n"
      quit(fmt"[Error] addon not found: {addonPath}{nl}Please ensure the addon '{n}' exists under {addonsDir}{nl}")

    # parse a simple config.txt if provided by addon (restricted DSL)
    let addonTxt = joinPath(addonPath, "config.txt")
    if fileExists(addonTxt):
      let addonRoot = addonPath
      let addonName = n
      let projectRoot = parentDir(system.currentSourcePath)
      when defined(addonsDebug):
        echo(fmt"[addon {addonName}] included: {addonTxt}")
      parseConfigTxt(addonTxt, addonRoot, projectRoot, addonName)

    let hasCMake = fileExists(joinPath(addonPath, "CMakeLists.txt"))

    if hasCMake:
      # CMake-based addon: prefer platform-specific prebuilt dirs under the addon folder
      let libVs = joinPath(addonPath, "prebuilt", "vs")
      let libOsx = joinPath(addonPath, "prebuilt", "osx")
      let libLinux = joinPath(addonPath, "prebuilt", "linux")

      let lname = n.toLowerAscii()
      var foundAny = false

      let note = prebuiltMissingNote(n, projectRootArg)

      # Platform-specific scanning using compile-time branches
      when defined(windows):
        if not dirExists(libVs):
          let nl = "\n"
          quit(fmt"[Error] required library directory not found: {libVs}{nl}Please provide prebuilt addon libraries before proceeding.{nl}{note}")
        let ok = scanPrebuiltDir(libVs, lname, projectRootArg)
        if ok: foundAny = true

      elif defined(macosx):
        if not dirExists(libOsx):
          let nl = "\n"
          quit(fmt"[Error] required library directory not found: {libOsx}{nl}Please provide prebuilt addon libraries before proceeding.{nl}{note}")
        let ok = scanPrebuiltDir(libOsx, lname, projectRootArg)
        if ok: foundAny = true

      elif defined(linux):
        if not dirExists(libLinux):
          let nl = "\n"
          quit(fmt"[Error] required library directory not found: {libLinux}{nl}Please provide prebuilt addon libraries before proceeding.{nl}{note}")
        if scanPrebuiltDir(libLinux, lname, projectRootArg): foundAny = true

      if not foundAny:
        let nl = "\n"
        quit(fmt"[Error] prebuilt library for addon '{n}' not found in expected prebuilt directory for this platform.{nl}Please build or place the library and retry.{nl}{note}")

      # Include headers only (do not collect .cpp)
      let srcDir = joinPath(addonPath, "src")
      if dirExists(srcDir):
        addInclude(srcDir)
        let subdirs = walkDirRec(srcDir)
        for sd in subdirs:
          if dirExists(sd): addInclude(sd)
      let incl = joinPath(addonPath, "include")
      if dirExists(incl): addInclude(incl)
      # Also accept prebuilt libraries placed inside the addon under "libs/" and filter by platform
      let addonLibs = joinPath(addonPath, "libs")
      if dirExists(addonLibs):
        if scanAddonLibs(addonLibs, projectRootArg):
          # note: we don't rely on the return value here beyond acceptance
          discard

    else:
      # Non-CMake addon: include headers and collect cpp sources for compilation
      let src = joinPath(addonPath, "src")
      if dirExists(src):
        addInclude(src)
        let subdirs = walkDirRec(src)
        for sd in subdirs:
          if dirExists(sd): addInclude(sd)
        # discover source files
        let srcFiles = findSourceFiles(src)
        for sf in srcFiles:
          var nf = sf.replace('\\', '/')
          var proj = projectRootArg.replace('\\', '/')
          var nfn = nf.toLowerAscii()
          var projn = proj.toLowerAscii()
          var rel = nf
          if nfn.startsWith(projn):
            rel = nf.substr(proj.len)
            if rel.startsWith("/"): rel = rel.substr(1)
          if rel notin discoveredCppSources:
            logAdd(fmt"add source: {rel}")
            discoveredCppSources.add(rel)
      let inc = joinPath(addonPath, "include")
      if dirExists(inc): addInclude(inc)
      # Also accept prebuilt libraries placed inside the addon under "libs/" and filter by platform
      let addonLibs = joinPath(addonPath, "libs")
      if dirExists(addonLibs):
        if scanAddonLibs(addonLibs, projectRootArg):
          discard

  # emit generated Nim file with {.compile: ...} pragmas for discovered C/C++ sources
  if discoveredCppSources.len > 0:
    let genDir = joinPath(projectRootArg, "generated")
    # if not dirExists(genDir):
    #   createDir(genDir)
    let outPath = joinPath(genDir, "addon_dependencies.nim")
    var contents = "# This file is generated by addons.nims - contains compile pragmas\n"
    for s in discoveredCppSources:
      let dq = "\""
      let nl = "\n"
      let s_start = "{.compile:"
      let s_end = ".}"
      contents.add(fmt"{s_start} {dq}{s}{dq}{s_end}{nl}")
    writeFile(outPath, contents)
    logAdd(fmt"wrote generated file: {outPath}")
