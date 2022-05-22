#include <SDL.h>
#include <SDL_syswm.h>
#include <bx/bx.h>
#include <bgfx/bgfx.h>
#include <bgfx/platform.h>
#include "../examples/00-helloworld/logo.h"

// On Windows bgfx defaults to considering D3D version, Vulkan must be specified explicitly
// Similarly we need to specify SDL_WINDOW_VULKAN if we want a Vulkan-friendly window surface
// Of course you could do this at runtime with the proper window recreation processes
#define USING_VULKAN 1

class MyApp
{
public:
  MyApp();

  int Init();
  void Run();
  void Draw();
  void Cleanup();

protected:
  SDL_Window* Window;
  uint32_t WindowWidth, WindowHeight;

  uint32_t Debug;

  const bgfx::ViewId kClearView = 0;
};

MyApp::MyApp()
  : Window(nullptr)
  , WindowWidth(1024)
  , WindowHeight(768)
{
}

int MyApp::Init()
{
  // Init SDL
  SDL_Init(SDL_INIT_VIDEO);

  SDL_WindowFlags windowFlags = (SDL_WindowFlags)0;
#if USING_VULKAN
  // c-style enums suck.
  windowFlags = (SDL_WindowFlags)((int)windowFlags | (int)SDL_WINDOW_VULKAN);
#endif

  Window = SDL_CreateWindow(
    "MyApp",
    SDL_WINDOWPOS_UNDEFINED,
    SDL_WINDOWPOS_UNDEFINED,
    WindowWidth,
    WindowHeight,
    windowFlags
  );

  SDL_SysWMinfo wmInfo;
  SDL_VERSION(&wmInfo.version);
  SDL_GetWindowWMInfo(Window, &wmInfo);

  // Call bgfx::renderFrame before bgfx::init to singal to bgfx to not create a render thread
  bgfx::renderFrame();

  // Initial bgfx using data from SDL wmInfo
  bgfx::Init init;
#if USING_VULKAN
  init.type = bgfx::RendererType::Vulkan;
#endif
#if BX_PLATFORM_WINDOWS
  init.platformData.nwh = wmInfo.info.win.window;
#elif BX_PLATFORM_OSX
  init.platformData.nwh = wmInfo.info.cocoa.window;
#elif BX_PLATFORM_LINUX || BX_PLATFORM_BSD
  init.platformData.nwh = wmInfo.info.x11.window;
#endif
  init.resolution.width = WindowWidth;
  init.resolution.height = WindowHeight;
  init.resolution.reset = BGFX_RESET_VSYNC; // Enable V-Sync

  // Try init bgfx
  if (!bgfx::init(init))
    return 1;

  Debug = BGFX_DEBUG_TEXT;
  bgfx::setDebug(Debug);

  bgfx::setViewClear(kClearView
    , BGFX_CLEAR_COLOR | BGFX_CLEAR_DEPTH
    , 0x303030ff
    , 1.f
    , 0
  );

  // Init Success!
  return 0;
}

void MyApp::Run()
{
  SDL_Event event;
  bool bWantToQuit = false;

  do
  {
    while (SDL_PollEvent(&event) != 0)
    {
      if (event.type == SDL_QUIT)
      {
        bWantToQuit = true;
      }
    }

    // Handle window resize
    int currentWidth, currentHeight;
    SDL_GetWindowSize(Window, &currentWidth, &currentHeight);
    if (currentWidth != WindowWidth || currentHeight != WindowHeight)
    {
      bgfx::reset((uint32_t)currentWidth, (uint32_t)currentHeight, BGFX_RESET_VSYNC);
      bgfx::setViewRect(kClearView, 0, 0, bgfx::BackbufferRatio::Equal);
    }

    if (!bWantToQuit)
    {
      Draw();
    }

  } while (!bWantToQuit);
}

void MyApp::Draw()
{
  // Set view 0 as default viewport
  bgfx::setViewRect(0, 0, 0, (uint16_t)WindowWidth, (uint16_t)WindowHeight);

  // Dummy draw call in case nothing else is submitted
  bgfx::touch(kClearView);

  // Use debug font to print information about this example.
  bgfx::dbgTextClear();
  bgfx::dbgTextImage(
    bx::max<uint16_t>(uint16_t(WindowWidth / 2 / 8), 20) - 20
    , bx::max<uint16_t>(uint16_t(WindowHeight / 2 / 16), 6) - 6
    , 40
    , 12
    , s_logo
    , 160
  );
  bgfx::dbgTextPrintf(0, 1, 0x0f, "Color can be changed with ANSI \x1b[9;me\x1b[10;ms\x1b[11;mc\x1b[12;ma\x1b[13;mp\x1b[14;me\x1b[0m code too.");

  bgfx::dbgTextPrintf(80, 1, 0x0f, "\x1b[;0m    \x1b[;1m    \x1b[; 2m    \x1b[; 3m    \x1b[; 4m    \x1b[; 5m    \x1b[; 6m    \x1b[; 7m    \x1b[0m");
  bgfx::dbgTextPrintf(80, 2, 0x0f, "\x1b[;8m    \x1b[;9m    \x1b[;10m    \x1b[;11m    \x1b[;12m    \x1b[;13m    \x1b[;14m    \x1b[;15m    \x1b[0m");

  const bgfx::Stats* stats = bgfx::getStats();
  bgfx::dbgTextPrintf(0, 2, 0x0f, "Backbuffer %dW x %dH in pixels, debug text %dW x %dH in characters."
    , stats->width
    , stats->height
    , stats->textWidth
    , stats->textHeight
  );

  // Advance to next frame. Process submitted rendering primitives.
  bgfx::frame();
}

void MyApp::Cleanup()
{
  SDL_DestroyWindow(Window);
}

int main(int argv, char** args)
{
  MyApp myApp;

  if (myApp.Init() != 0)
  {
    // Failed init
    return 1;
  }

  myApp.Run();

  myApp.Cleanup();

  return 0;
}
