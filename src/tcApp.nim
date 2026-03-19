type
  SetupFn* = proc(){.cdecl.}
  UpdateFn* = proc(){.cdecl.}
  DrawFn*   = proc(){.cdecl.}
  KeyPressedFn*    = proc(key: cint){.cdecl.}
  KeyReleaseFn* = proc(key: cint){.cdecl.}
  MouseMoveFn* = proc(x: cint, y: cint){.cdecl.}
  MouseButtonFn* = proc(x: cint, y: cint, button: cint){.cdecl.}
  EnterExitFn* = proc(x: cint, y: cint){.cdecl.}
  ResizeFn* = proc(w: cint, h: cint){.cdecl.}
  FilesDroppedFn* = proc(info: pointer){.cdecl.}
  MessageFn* = proc(msg: pointer){.cdecl.}
  ExitFn* = proc(){.cdecl.}

{.emit: """
#include <memory>
#include "TrussC.h"

using SetupFn = void(*)();
using UpdateFn = void(*)();
using DrawFn   = void(*)();
using KeyPressedFn    = void(*)(int);
using KeyReleaseFn = void(*)(int);
using MouseMoveFn = void(*)(int, int);
using MouseButtonFn = void(*)(int, int, int);
using EnterExitFn = void(*)(int, int);
using ResizeFn = void(*)(int, int);
using FilesDroppedFn = void(*)(void*);
using MessageFn = void(*)(void*);
using ExitFn = void(*)();

struct NimCallbacks {
  SetupFn setup;
  UpdateFn update;
  DrawFn draw;
  KeyPressedFn keyPressed;
  KeyReleaseFn keyReleased;
  MouseMoveFn mouseMoved;
  MouseButtonFn mouseDragged;
  MouseButtonFn mousePressed;
  MouseButtonFn mouseReleased;
  EnterExitFn mouseEntered;
  EnterExitFn mouseExited;
  ResizeFn windowResized;
  FilesDroppedFn filesDropped;
  MessageFn gotMessage;
  ExitFn exit;
};

// A small opaque handle type to expose to Nim instead of raw void*.
inline std::shared_ptr<NimCallbacks> tcn_makeCallbacks() {
  auto p = std::make_shared<NimCallbacks>();
  p->setup = nullptr;
  p->update = nullptr;
  p->draw = nullptr;
  p->keyPressed = nullptr;
  p->keyReleased = nullptr;
  p->mouseMoved = nullptr;
  p->mouseDragged = nullptr;
  p->mousePressed = nullptr;
  p->mouseReleased = nullptr;
  p->mouseEntered = nullptr;
  p->mouseExited = nullptr;
  p->windowResized = nullptr;
  p->filesDropped = nullptr;
  p->gotMessage = nullptr;
  p->exit = nullptr;
  return p;
}

// Use a file-scope shared_ptr to hold callbacks while runApp constructs the
// application via its default constructor. This avoids function-scope static
// variables and preserves lifetime safely.
static std::shared_ptr<NimCallbacks> g_shared_cb;

class NimApp : public tc::App {
  std::shared_ptr<NimCallbacks> cb_;
public:
  NimApp() : cb_(g_shared_cb) {}
  void setup() override { if(cb_ && cb_->setup) cb_->setup(); }
  void update() override { if(cb_ && cb_->update) cb_->update(); }
  void draw() override   { if(cb_ && cb_->draw)   cb_->draw();  }
  void keyPressed(int k) override { if(cb_ && cb_->keyPressed) cb_->keyPressed(k); }
  void keyReleased(int k) override { if(cb_ && cb_->keyReleased) cb_->keyReleased(k); }
  void mousePressed(tc::Vec2 pos, int button) override { if(cb_ && cb_->mousePressed) cb_->mousePressed((int)pos.x, (int)pos.y, button); }
  void mouseReleased(tc::Vec2 pos, int button) override { if(cb_ && cb_->mouseReleased) cb_->mouseReleased((int)pos.x, (int)pos.y, button); }
  void mouseMoved(tc::Vec2 pos) override { if(cb_ && cb_->mouseMoved) cb_->mouseMoved((int)pos.x, (int)pos.y); }
  void mouseDragged(tc::Vec2 pos, int button) override { if(cb_ && cb_->mouseDragged) cb_->mouseDragged((int)pos.x, (int)pos.y, button); }
  void mouseScrolled(tc::Vec2 delta) override { (void)delta; }
  void windowResized(int w, int h) override { if(cb_ && cb_->windowResized) cb_->windowResized(w, h); }
  void filesDropped(const std::vector<std::string>& files) override { if(cb_ && cb_->filesDropped) cb_->filesDropped((void*)&files); }
  void exit() override { if(cb_ && cb_->exit) cb_->exit(); }
};

inline void tcn_runWithCallbacks(int w, int h, std::shared_ptr<NimCallbacks> cb) {
  tc::WindowSettings s;
  s.setSize(w,h);
  s.setFullscreen(false);
  // copy callbacks into shared storage for NimApp default constructor
  g_shared_cb = cb;
  tc::runApp<NimApp>(s);
}

inline void tcn_runWithCallbacks_withFlag(int w, int h, std::shared_ptr<NimCallbacks> cb, bool fullscreen) {
  tc::WindowSettings s;
  s.setSize(w,h);
  s.setFullscreen(fullscreen);
  g_shared_cb = cb;
  tc::runApp<NimApp>(s);
}

inline void tcn_runWithCallbacks_settings_auto_c(void* settingsPtr, std::shared_ptr<NimCallbacks> cb) {
  tc::WindowSettings* s = (tc::WindowSettings*)settingsPtr;
  if (s) {
    g_shared_cb = cb;
    tc::runApp<NimApp>(*s);
  } else {
    tcn_runWithCallbacks(800,600,cb);
  }
}
extern "C" {
  inline void* tcn_makeCallbacks_c() { return (void*) new std::shared_ptr<NimCallbacks>(tcn_makeCallbacks()); }
  inline void tcn_runWithCallbacks_c(int w, int h, void* cb) { tcn_runWithCallbacks(w,h, *(std::shared_ptr<NimCallbacks>*)cb); }
  inline void tcn_runWithCallbacks_fullscreen_c(int w, int h, void* cb, bool fullscreen) { tcn_runWithCallbacks_withFlag(w,h, *(std::shared_ptr<NimCallbacks>*)cb, fullscreen); }
  inline void tcn_runWithCallbacks_settings_auto_c(void* settingsPtr, void* cb) { tcn_runWithCallbacks_settings_auto_c(settingsPtr, *(std::shared_ptr<NimCallbacks>*)cb); }

  inline void tcn_setSetup_c(void* cb, SetupFn f) { (*(std::shared_ptr<NimCallbacks>*)cb)->setup = f; }
  inline void tcn_setUpdate_c(void* cb, UpdateFn f) { (*(std::shared_ptr<NimCallbacks>*)cb)->update = f; }
  inline void tcn_setDraw_c(void* cb, DrawFn f) { (*(std::shared_ptr<NimCallbacks>*)cb)->draw = f; }
  inline void tcn_setKeyPressed_c(void* cb, KeyPressedFn f) { (*(std::shared_ptr<NimCallbacks>*)cb)->keyPressed = f; }
  inline void tcn_setKeyReleased_c(void* cb, KeyReleaseFn f) { (*(std::shared_ptr<NimCallbacks>*)cb)->keyReleased = f; }
  inline void tcn_setMouseMoved_c(void* cb, MouseMoveFn f) { (*(std::shared_ptr<NimCallbacks>*)cb)->mouseMoved = f; }
  inline void tcn_setMouseDragged_c(void* cb, MouseButtonFn f) { (*(std::shared_ptr<NimCallbacks>*)cb)->mouseDragged = f; }
  inline void tcn_setMousePressed_c(void* cb, MouseButtonFn f) { (*(std::shared_ptr<NimCallbacks>*)cb)->mousePressed = f; }
  inline void tcn_setMouseReleased_c(void* cb, MouseButtonFn f) { (*(std::shared_ptr<NimCallbacks>*)cb)->mouseReleased = f; }
  inline void tcn_setMouseEntered_c(void* cb, EnterExitFn f) { (*(std::shared_ptr<NimCallbacks>*)cb)->mouseEntered = f; }
  inline void tcn_setMouseExited_c(void* cb, EnterExitFn f) { (*(std::shared_ptr<NimCallbacks>*)cb)->mouseExited = f; }
  inline void tcn_setWindowResized_c(void* cb, ResizeFn f) { (*(std::shared_ptr<NimCallbacks>*)cb)->windowResized = f; }
  inline void tcn_setFilesDropped_c(void* cb, FilesDroppedFn f) { (*(std::shared_ptr<NimCallbacks>*)cb)->filesDropped = f; }
  inline void tcn_setGotMessage_c(void* cb, MessageFn f) { (*(std::shared_ptr<NimCallbacks>*)cb)->gotMessage = f; }
  inline void tcn_setExit_c(void* cb, ExitFn f) { (*(std::shared_ptr<NimCallbacks>*)cb)->exit = f; }
}
""" .}

proc tcn_makeCallbacks_c(): pointer {.importc: "tcn_makeCallbacks_c", cdecl.}
proc tcn_runWithCallbacks_c(w: cint, h: cint, cb: pointer) {.importc: "tcn_runWithCallbacks_c", cdecl, used.}
proc tcn_runWithCallbacks_fullscreen_c(w: cint, h: cint, cb: pointer, fullscreen: bool) {.importc: "tcn_runWithCallbacks_fullscreen_c", cdecl.}
proc tcn_runWithCallbacks_settings_auto_c(settings: pointer, cb: pointer) {.importc: "tcn_runWithCallbacks_settings_auto_c", cdecl.}

proc tcn_setSetup_c(cb: pointer, f: UpdateFn) {.importc: "tcn_setSetup_c", cdecl.}
proc tcn_setUpdate_c(cb: pointer, f: UpdateFn) {.importc: "tcn_setUpdate_c", cdecl.}
proc tcn_setDraw_c(cb: pointer, f: DrawFn) {.importc: "tcn_setDraw_c", cdecl.}
proc tcn_setKeyPressed_c(cb: pointer, f: KeyPressedFn) {.importc: "tcn_setKeyPressed_c", cdecl.}
proc tcn_setKeyReleased_c(cb: pointer, f: KeyReleaseFn) {.importc: "tcn_setKeyReleased_c", cdecl.}
proc tcn_setMouseMoved_c(cb: pointer, f: MouseMoveFn) {.importc: "tcn_setMouseMoved_c", cdecl.}
proc tcn_setMouseDragged_c(cb: pointer, f: MouseButtonFn) {.importc: "tcn_setMouseDragged_c", cdecl.}
proc tcn_setMousePressed_c(cb: pointer, f: MouseButtonFn) {.importc: "tcn_setMousePressed_c", cdecl.}
proc tcn_setMouseReleased_c(cb: pointer, f: MouseButtonFn) {.importc: "tcn_setMouseReleased_c", cdecl.}
proc tcn_setMouseEntered_c(cb: pointer, f: EnterExitFn) {.importc: "tcn_setMouseEntered_c", cdecl.}
proc tcn_setMouseExited_c(cb: pointer, f: EnterExitFn) {.importc: "tcn_setMouseExited_c", cdecl.}
proc tcn_setWindowResized_c(cb: pointer, f: ResizeFn) {.importc: "tcn_setWindowResized_c", cdecl.}
proc tcn_setFilesDropped_c(cb: pointer, f: FilesDroppedFn) {.importc: "tcn_setFilesDropped_c", cdecl.}
proc tcn_setGotMessage_c(cb: pointer, f: MessageFn) {.importc: "tcn_setGotMessage_c", cdecl.}
proc tcn_setExit_c(cb: pointer, f: ExitFn) {.importc: "tcn_setExit_c", cdecl.}

type TcApp* = object
  cb*: pointer

type TcAppConfig* = object
  setup*: SetupFn
  update*: UpdateFn
  draw*: DrawFn
  keyPressed*: KeyPressedFn
  keyReleased*: KeyReleaseFn
  mouseMoved*: MouseMoveFn
  mouseDragged*: MouseButtonFn
  mousePressed*: MouseButtonFn
  mouseReleased*: MouseButtonFn
  mouseEntered*: EnterExitFn
  mouseExited*: EnterExitFn
  windowResized*: ResizeFn
  filesDropped*: FilesDroppedFn
  gotMessage*: MessageFn
  exit*: ExitFn

proc makeTcApp*(
  setup: SetupFn = nil;
  update: UpdateFn = nil;
  draw: DrawFn = nil;
  keyPressed: KeyPressedFn = nil;
  keyReleased: KeyReleaseFn = nil;
  mouseMoved: MouseMoveFn = nil;
  mouseDragged: MouseButtonFn = nil;
  mousePressed: MouseButtonFn = nil;
  mouseReleased: MouseButtonFn = nil;
  mouseEntered: EnterExitFn = nil;
  mouseExited: EnterExitFn = nil;
  windowResized: ResizeFn = nil;
  filesDropped: FilesDroppedFn = nil;
  gotMessage: MessageFn = nil;
  exit: ExitFn = nil;
  ): TcApp =

  var a: TcApp
  a.cb = tcn_makeCallbacks_c()
  if setup != nil: tcn_setSetup_c(a.cb, setup)
  if update != nil: tcn_setUpdate_c(a.cb, update)
  if draw != nil: tcn_setDraw_c(a.cb, draw)
  if keyPressed != nil: tcn_setKeyPressed_c(a.cb, keyPressed)
  if keyReleased != nil: tcn_setKeyReleased_c(a.cb, keyReleased)
  if mouseMoved != nil: tcn_setMouseMoved_c(a.cb, mouseMoved)
  if mouseDragged != nil: tcn_setMouseDragged_c(a.cb, mouseDragged)
  if mousePressed != nil: tcn_setMousePressed_c(a.cb, mousePressed)
  if mouseReleased != nil: tcn_setMouseReleased_c(a.cb, mouseReleased)
  if mouseEntered != nil: tcn_setMouseEntered_c(a.cb, mouseEntered)
  if mouseExited != nil: tcn_setMouseExited_c(a.cb, mouseExited)
  if windowResized != nil: tcn_setWindowResized_c(a.cb, windowResized)
  if filesDropped != nil: tcn_setFilesDropped_c(a.cb, filesDropped)
  if gotMessage != nil: tcn_setGotMessage_c(a.cb, gotMessage)
  if exit != nil: tcn_setExit_c(a.cb, exit)
  return a

proc makeTcApp*(cfg: TcAppConfig): TcApp =
  return makeTcApp(
    setup = cfg.setup,
    update = cfg.update,
    draw = cfg.draw,
    keyPressed = cfg.keyPressed,
    keyReleased = cfg.keyReleased,
    mouseMoved = cfg.mouseMoved,
    mouseDragged = cfg.mouseDragged,
    mousePressed = cfg.mousePressed,
    mouseReleased = cfg.mouseReleased,
    mouseEntered = cfg.mouseEntered,
    mouseExited = cfg.mouseExited,
    windowResized = cfg.windowResized,
    filesDropped = cfg.filesDropped,
    gotMessage = cfg.gotMessage,
    exit = cfg.exit
    )

proc run*(a: var TcApp; w: int = 800; h: int = 600; fullscreen: bool = false) =
  tcn_runWithCallbacks_fullscreen_c(cast[cint](w), cast[cint](h), a.cb, fullscreen)

proc runWithSettings*(a: var TcApp; settings: pointer) =
  tcn_runWithCallbacks_settings_auto_c(settings, a.cb)
