-- Append solution type to build dir
local BUILD_DIR = path.join("build/", _ACTION)
-- If specific compiler specified, append that too
if _OPTIONS["cc"] ~= nil then
    BUILD_DIR = BUILD_DIR .. "_" .. _OPTIONS["cc"]
end

local SRC_DIR = "src/"

-- Known paths to libraries
local BX_DIR = "thirdparty/bx"
local BIMG_DIR = "thirdparty/bimg"
local BGFX_DIR = "thirdparty/bgfx"

-- Try get SDL path
local SDL_PATH = ""
newoption {
    trigger = "sdlpath",
    value = "SDL_PATH",
    description = "Location of SDL includes and libs",
    default = "SDL_PATH"
}
if _OPTIONS["sdlpath"] ~= "SDL_PATH" then
    SDL_PATH = _OPTIONS["sdlpath"]
else
    SDL_PATH = os.getenv("SDL_PATH")
end
SDL_LIB_DIR = path.join(SDL_PATH,"lib")

-- Toplevel workspace, name arbitrary
workspace "bgfx-sdl-helloworld"
    location (BUILD_DIR)
    startproject "bgfx-sdl-helloworld"
    -- Further configs go here
    configurations { "Debug", "Release" }
    -- Let 32 bit die already
    if os.is64bit() then
        platforms "x86_64"
    else
        platforms "x86"
    end
    filter "configurations:Debug"
        defines
        {
            "_DEBUG",
            "BX_CONFIG_DEBUG=1"
        }
        optimize "Debug"
        symbols "On"
    filter "configurations:Release"
        defines
        {
            "NDEBUG",
            "BX_CONFIG_DEBUG=0"
        }
        optimize "Full"
    filter "platforms:x86"
        architecture "x86"
    filter "platforms:x86_64"
        architecture "x86_64"
    -- untested
    filter "system:macosx"
        xcodebuildsettings {
            ["MAXOSC_DEPLOYMENT_TARGET"] = "10.9",
            ["ALWAYS_SEARCH_USER_PATHS"] = "YES"
        }
	filter "action:vs*"
		-- BGFX requires __cplusplus to actually report the correct version which requires the /Zc:__cplusplus option set
		-- Kinda sucky msvc hasn't turned this on by default yes
		buildoptions { "/Zc:__cplusplus" }
   
function bxCompat()
    filter "action:vs*"
        includedirs { path.join(BX_DIR, "include/compat/msvc") }
    filter { "system:windows", "action:gmake" }
        includedirs { path.join(BX_DIR, "include/compat/mingw") }
    filter { "system:macosx" }
        includedirs { path.join(BX_DIR, "include/compat/osx") }
        buildoptions { "-x objective-c++" }
end

project "bgfx-sdl-helloworld"
    kind "ConsoleApp" -- Maybe want to make this filter on config, e.g. WindowedApp instead for Shipping
    language "C++"
    cppdialect "C++20" -- Shiny, gimmie those designated initialisers
    rtti "Off"
    staticruntime "On" -- Maybe make this a commandline option?
    targetdir (BUILD_DIR .. "/bin/" .. "%{cfg.architecture}" .. "/" .. "%{cfg.shortname}")
    objdir (BUILD_DIR .. "/bin/obj/" .. "%{cfg.architecture}" .. "/" .. "%{cfg.shortname}")
    files 
    {
        path.join(SRC_DIR,"**.h"),  -- Switch to .hpp if that's your flavour
        path.join(SRC_DIR,"**.cpp"),-- Same for .cc if you're weird like that
        path.join(SRC_DIR,"**.c")   -- .c because why not
    }
    includedirs 
    {
        path.join(BX_DIR,"include"),
        path.join(BGFX_DIR,"include"),
        path.join(SDL_PATH,"include")
    }
    filter "architecture:x86"
        libdirs { path.join(SDL_LIB_DIR,"x86") }
    filter "architecture:x86_64"
        libdirs { path.join(SDL_LIB_DIR,"x64") }
    links {
        "bx",
        "bimg",
        "bgfx",
        "SDL2",
        "SDL2main"
    }
    filter "system:windows"
        links { "gdi32", "kernel32", "psapi" }		
    
    -- untested
    filter "system:linux"
        links { "dl", "GL", "pthread", "X11" }
    filter "system:macosx"
        links { "QuartzCore.framework", "Metal.framework", "Cocoa.framework", "IOKit.framework", "CoreVideo.framework" }

    bxCompat()

-- BGFX libs lifted from bgfx-minimal-example
-- Note: bgfx requires a minimum of C++14, accepts C++17, and judges you for using anything newer
-- See: https://gist.github.com/bkaradzic/2e39896bc7d8c34e042b#orthodox-c
project "bgfx"
	kind "StaticLib"
	language "C++"
	cppdialect "C++14"
	exceptionhandling "Off"
	rtti "Off"
	defines "__STDC_FORMAT_MACROS"
	staticruntime "On"
	files
	{
		path.join(BGFX_DIR, "include/bgfx/**.h"),
		path.join(BGFX_DIR, "src/*.cpp"),
		path.join(BGFX_DIR, "src/*.h"),
	}
	excludes
	{
		path.join(BGFX_DIR, "src/amalgamated.cpp"),
	}
	includedirs
	{
		path.join(BX_DIR, "include"),
		path.join(BIMG_DIR, "include"),
		path.join(BGFX_DIR, "include"),
		path.join(BGFX_DIR, "3rdparty"),
		path.join(BGFX_DIR, "3rdparty/dxsdk/include"),
		path.join(BGFX_DIR, "3rdparty/khronos")
	}
	filter "action:vs*"
		defines "_CRT_SECURE_NO_WARNINGS"
		excludes
		{
			path.join(BGFX_DIR, "src/glcontext_glx.cpp"),
			path.join(BGFX_DIR, "src/glcontext_egl.cpp")
		}
	filter "system:macosx"
		files
		{
			path.join(BGFX_DIR, "src/*.mm"),
		}
	bxCompat()

project "bimg"
	kind "StaticLib"
	language "C++"
	cppdialect "C++14"
	exceptionhandling "Off"
	rtti "Off"
	staticruntime "On"
	files
	{
		path.join(BIMG_DIR, "include/bimg/*.h"),
		path.join(BIMG_DIR, "src/image.cpp"),
		path.join(BIMG_DIR, "src/image_gnf.cpp"),
		path.join(BIMG_DIR, "src/*.h"),
		path.join(BIMG_DIR, "3rdparty/astc-codec/src/decoder/*.cc")
	}
	includedirs
	{
		path.join(BX_DIR, "include"),
		path.join(BIMG_DIR, "include"),
		path.join(BIMG_DIR, "3rdparty/astc-codec"),
		path.join(BIMG_DIR, "3rdparty/astc-codec/include"),
	}
	bxCompat()

project "bx"
	kind "StaticLib"
	language "C++"
	cppdialect "C++14"
	exceptionhandling "Off"
	rtti "Off"
	defines "__STDC_FORMAT_MACROS"
	staticruntime "On"
	files
	{
		path.join(BX_DIR, "include/bx/*.h"),
		path.join(BX_DIR, "include/bx/inline/*.inl"),
		path.join(BX_DIR, "src/*.cpp")
	}
	excludes
	{
		path.join(BX_DIR, "src/amalgamated.cpp"),
		path.join(BX_DIR, "src/crtnone.cpp")
	}
	includedirs
	{
		path.join(BX_DIR, "3rdparty"),
		path.join(BX_DIR, "include")
	}
	filter "configurations:Release"
		defines "BX_CONFIG_DEBUG=0"
	filter "configurations:Debug"
		defines "BX_CONFIG_DEBUG=1"
	filter "action:vs*"
		defines "_CRT_SECURE_NO_WARNINGS"
	bxCompat()
