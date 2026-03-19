import std/os
import std/strutils
import std/strformat

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
    if not dirExists(addonPath): continue

    let hasCMake = fileExists(joinPath(addonPath, "CMakeLists.txt"))

    if hasCMake:
      # CMake-based addon: require prebuilt libs under projectRoot/lib/vs or lib/osx
      let libVs = joinPath(projectRootArg, "lib", "vs")
      let libOsx = joinPath(projectRootArg, "lib", "osx")
      if not dirExists(libVs) and not dirExists(libOsx):
        let nl = "\n"
        quit(fmt"[Error] required library directories not found: {libVs} or {libOsx}{nl}Please provide prebuilt addon libraries before proceeding.{nl}")

      let lname = n.toLowerAscii()
      var foundAny = false

      # search for .lib under lib/vs that match addon name
      if dirExists(libVs):
        for kind, p in walkDir(libVs):
          if kind == pcFile:
            let low = p.toLowerAscii()
            if low.endsWith(".lib") and low.contains(lname):
              addLink(p)
              foundAny = true
            if low.endsWith(".dll") and low.contains(lname):
              addLink(p)
              # copy to project root
              copyFile(p, joinPath(projectRootArg, getFileName(p)))
              foundAny = true

      # search for .a / .dylib under lib/osx that match addon name
      if dirExists(libOsx):
        for kind, p in walkDir(libOsx):
          if kind == pcFile:
            let low = p.toLowerAscii()
            if low.endsWith(".a") and low.contains(lname):
              addLink(p)
              foundAny = true
            if low.endsWith(".dylib") and low.contains(lname):
              addLink(p)
              copyFile(p, joinPath(projectRootArg, getFileName(p)))
              foundAny = true

      if not foundAny:
        let nl = "\n"
        quit(fmt"[Error] prebuilt library for addon '{n}' not found under {libVs} or {libOsx}.{nl}Please build or place the library and retry.{nl}")

      # Include headers only (do not collect .cpp)
      let srcDir = joinPath(addonPath, "src")
      if dirExists(srcDir):
        addInclude(srcDir)
        let subdirs = walkDirRec(srcDir)
        for sd in subdirs:
          if dirExists(sd): addInclude(sd)
      let incl = joinPath(addonPath, "include")
      if dirExists(incl): addInclude(incl)

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
          if rel notin discoveredCppSources: discoveredCppSources.add(rel)
      let inc = joinPath(addonPath, "include")
      if dirExists(inc): addInclude(inc)

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
