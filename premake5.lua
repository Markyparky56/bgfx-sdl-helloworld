-- Append solution type to build dir
local BUILD_DIR = path.join("build/", _ACTION)
-- If specific compiler specified, append that too
if _OPTIONS["cc"] ~= nil then
    BUILD_DIR = BUILD_DIR .. "_" .. _OPTIONS["cc"]
end

newoption {
    trigger = "with-exceptions",
    description = "Exceptions Always Enabled? (ON/OFF)"
}
local EXCEPTIONS_ENABLED = "Off"
if _OPTIONS["with-exceptions"] ~= nil then
    EXCEPTIONS_ENABLED = "On"
end

newoption {
    trigger = "dynamic-runtime",
    description = "Should use dynamically linked runtime?"
}
local STATIC_RUNTIME = "On"
if _OPTIONS["dynamic-runtime"] ~= nil then
    STATIC_RUNTIME = "Off"
end

local SRC_DIR = "src/"

-- Known paths to libraries
local BX_DIR = "thirdparty/bx"
local BIMG_DIR = "thirdparty/bimg"
local BGFX_DIR = "thirdparty/bgfx"
local IMGUI_DIR = "thirdparty/imgui"
local IMGUI_BGFX_DIR = "thirdparty/imgui-bgfx"

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
        -- Kinda sucky msvc hasn't turned this on by default yet
        buildoptions { "/Zc:__cplusplus" }
        -- Cores go brrrrr
        flags { "MultiProcessorCompile" }
   
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
    exceptionhandling (EXCEPTIONS_ENABLED)
    rtti "Off"
    staticruntime (STATIC_RUNTIME)
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
        path.join(SDL_PATH,"include"),
        path.join(IMGUI_DIR,""),
        path.join(IMGUI_BGFX_DIR,"")
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
        "SDL2main",
        "imgui"
    }
    filter "system:windows"
        links { "gdi32", "kernel32", "psapi" }        
    
    -- untested
    filter "system:linux"
        links { "dl", "GL", "pthread", "X11" }
    filter "system:macosx"
        links { "QuartzCore.framework", "Metal.framework", "Cocoa.framework", "IOKit.framework", "CoreVideo.framework" }

    bxCompat()

group "bgfx Libs"

-- BGFX libs lifted from bgfx-minimal-example
-- Note: bgfx requires a minimum of C++14, accepts C++17, and judges you for using anything newer
-- See: https://gist.github.com/bkaradzic/2e39896bc7d8c34e042b#orthodox-c
project "bgfx"
    kind "StaticLib"
    language "C++"
    cppdialect "C++14"
    exceptionhandling (EXCEPTIONS_ENABLED)
    rtti "Off"
    defines "__STDC_FORMAT_MACROS"
    staticruntime (STATIC_RUNTIME)
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
    exceptionhandling (EXCEPTIONS_ENABLED)
    rtti "Off"
    staticruntime (STATIC_RUNTIME)
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
    exceptionhandling (EXCEPTIONS_ENABLED)
    rtti "Off"
    defines "__STDC_FORMAT_MACROS"
    staticruntime (STATIC_RUNTIME)
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

project "imgui"
    kind "StaticLib"
    language "C++"
    exceptionhandling (EXCEPTIONS_ENABLED)
    rtti "Off"
    staticruntime (STATIC_RUNTIME)
    files
    {
        path.join(IMGUI_DIR, "*.h"),
        path.join(IMGUI_DIR, "*.cpp"),
        path.join(IMGUI_DIR, "backends/imgui_impl_sdl.h"),
        path.join(IMGUI_DIR, "backends/imgui_impl_sdl.cpp"),
        path.join(IMGUI_BGFX_DIR, "imgui_impl_bgfx.h"),
        path.join(IMGUI_BGFX_DIR, "imgui_impl_bgfx.cpp")
    }
    includedirs
    {
        path.join(IMGUI_DIR,""),
        path.join(BX_DIR, "include"),
        path.join(BGFX_DIR, "include"),
        path.join(BGFX_DIR,"examples/common/imgui"), -- For vs/fs_ocornut_imgui.bin.h
        path.join(SDL_PATH,"include")
    }
    bxCompat()

group "Tools"
-- bgfx tools (+thirdparty tools)
local BGFX_TOOLS_DIR = path.join(BGFX_DIR, "tools")
local BGFX_3RDPARTY_DIR = path.join(BGFX_DIR, "3rdparty")

project "fcpp"
    kind "StaticLib"
    language "C++" -- C?
    exceptionhandling (EXCEPTIONS_ENABLED)
    rtti "Off"
    staticruntime (STATIC_RUNTIME)
    files
    {
        path.join(BGFX_3RDPARTY_DIR, "fcpp/*.h"),
        path.join(BGFX_3RDPARTY_DIR, "fcpp/*.c")
    }
    excludes
    {
        path.join(BGFX_3RDPARTY_DIR, "fcpp/usecpp.c")
    }
    filter { "action:vs*" }
        defines {
            "_CRT_SECURE_NO_WARNINGS"
        }
    bxCompat()

project "glslang"
    kind "StaticLib"
    language "C++"
    exceptionhandling (EXCEPTIONS_ENABLED)
    rtti "Off"
    staticruntime (STATIC_RUNTIME)
    files
    {
        path.join(BGFX_3RDPARTY_DIR, "glslang/glslang/**.h"),
        path.join(BGFX_3RDPARTY_DIR, "glslang/glslang/**.cpp"),
        path.join(BGFX_3RDPARTY_DIR, "glslang/hlsl/*.cpp"),
        path.join(BGFX_3RDPARTY_DIR, "glslang/OGLCompilersDLL/*.h"),
        path.join(BGFX_3RDPARTY_DIR, "glslang/OGLCompilersDLL/*.cpp"),
        path.join(BGFX_3RDPARTY_DIR, "glslang/SPIRV/**.h"),
        path.join(BGFX_3RDPARTY_DIR, "glslang/SPIRV/**.cpp"),
    }
    excludes 
    {
        path.join(BGFX_3RDPARTY_DIR, "glslang/glslang/OSDependent/Windows/main.cpp")
    }
    filter { "system:linux" }
        excludes {
            path.join(BGFX_3RDPARTY_DIR, "glslang/glslang/OSDependent/Windows/ossource.cpp")
        }
    filter { "system:windows" }
        excludes {
            path.join(BGFX_3RDPARTY_DIR, "glslang/glslang/OSDependent/Unix/ossource.cpp")
        }
    includedirs
    {
        path.join(BGFX_3RDPARTY_DIR),
        path.join(BGFX_3RDPARTY_DIR, "glslang"),
        path.join(BGFX_3RDPARTY_DIR, "spirv-tools/include"),
        path.join(BGFX_3RDPARTY_DIR, "spirv-tools/source"),
    }
    defines 
    {
        "ENABLE_OPT=1",
        "ENABLE_HLSL=1"
    }
    bxCompat()

project "glsl-optimizer"
    kind "StaticLib"
    language "C++"
    exceptionhandling (EXCEPTIONS_ENABLED)
    rtti ("Off")
    staticruntime (STATIC_RUNTIME)
    files
    {
        path.join(BGFX_3RDPARTY_DIR, "glsl-optimizer/src/glsl/**.h"),
        path.join(BGFX_3RDPARTY_DIR, "glsl-optimizer/src/glsl/**.cpp"),
        path.join(BGFX_3RDPARTY_DIR, "glsl-optimizer/src/glsl/**.c"),
        path.join(BGFX_3RDPARTY_DIR, "glsl-optimizer/src/mesa/**.h"),
        path.join(BGFX_3RDPARTY_DIR, "glsl-optimizer/src/mesa/**.cpp"),
        path.join(BGFX_3RDPARTY_DIR, "glsl-optimizer/src/mesa/**.c"),
        path.join(BGFX_3RDPARTY_DIR, "glsl-optimizer/src/util/*.h"),
        path.join(BGFX_3RDPARTY_DIR, "glsl-optimizer/src/util/*.c"),
    }
    excludes
    {
        path.join(BGFX_3RDPARTY_DIR, "glsl-optimizer/src/glsl/main.cpp")
    }
    includedirs
    {
        path.join(BGFX_3RDPARTY_DIR, "glsl-optimizer/src"),
        path.join(BGFX_3RDPARTY_DIR, "glsl-optimizer/include"),
        path.join(BGFX_3RDPARTY_DIR, "glsl-optimizer/src/mesa"),
        path.join(BGFX_3RDPARTY_DIR, "glsl-optimizer/src/glsl"),
    }
    filter { "action:vs*" }
        defines {
            "_CRT_SECURE_NO_WARNINGS",            
            "strdup=_strdup",
        }
    bxCompat()

project "spirv-cross"
    kind "StaticLib"
    language "C++"
    exceptionhandling (EXCEPTIONS_ENABLED)
    rtti "Off"
    staticruntime (STATIC_RUNTIME)
    files
    {
        path.join(BGFX_3RDPARTY_DIR, "spirv-cross/*.hpp"),
        path.join(BGFX_3RDPARTY_DIR, "spirv-cross/*.cpp")
    }
    excludes
    {
        path.join(BGFX_3RDPARTY_DIR, "spirv-cross/spirv_cross_c.cpp")
    }
    includedirs
    {
        path.join(BGFX_3RDPARTY_DIR, "spirv-cross/include")
    }
    if EXCEPTIONS_ENABLED == "Off" then
        defines {
            "SPIRV_CROSS_EXCEPTIONS_TO_ASSERTIONS"
        }
    end
    filter { "action:vs*" }
        defines {
            "_CRT_SECURE_NO_WARNINGS"
        }
    bxCompat()

project "spirv-opt"
    kind "StaticLib"
    language "C++"
    exceptionhandling (EXCEPTIONS_ENABLED)
    rtti "Off"
    staticruntime (STATIC_RUNTIME)
    files
    {
        path.join(BGFX_3RDPARTY_DIR, "spirv-tools/source/*.h"),
        path.join(BGFX_3RDPARTY_DIR, "spirv-tools/source/*.cpp"),
        path.join(BGFX_3RDPARTY_DIR, "spirv-tools/source/opt/*.h"),
        path.join(BGFX_3RDPARTY_DIR, "spirv-tools/source/opt/*.cpp"),
        path.join(BGFX_3RDPARTY_DIR, "spirv-tools/source/reduce/*.h"),
        path.join(BGFX_3RDPARTY_DIR, "spirv-tools/source/reduce/*.cpp"),
        path.join(BGFX_3RDPARTY_DIR, "spirv-tools/source/util/*.h"),
        path.join(BGFX_3RDPARTY_DIR, "spirv-tools/source/util/*.cpp"),
        path.join(BGFX_3RDPARTY_DIR, "spirv-tools/source/val/*.h"),
        path.join(BGFX_3RDPARTY_DIR, "spirv-tools/source/val/*.cpp"),
    }
    includedirs
    {
        path.join(BGFX_3RDPARTY_DIR, "spirv-tools"),
        path.join(BGFX_3RDPARTY_DIR, "spirv-tools/include"),
        path.join(BGFX_3RDPARTY_DIR, "spirv-tools/include/generated"),
        path.join(BGFX_3RDPARTY_DIR, "spirv-tools/source"),
        path.join(BGFX_3RDPARTY_DIR, "spirv-headers/include"),
    }
    filter { "action:vs*" }
        defines {
            "_CRT_SECURE_NO_WARNINGS"
        }
    bxCompat()

project "shaderc"
    kind "ConsoleApp"
    language "C++"
    exceptionhandling (EXCEPTIONS_ENABLED)
    rtti "Off"
    staticruntime (STATIC_RUNTIME)
    files
    {
        -- hard-coded files in the src folder
        path.join(BGFX_DIR, "src/shader.h"),
        path.join(BGFX_DIR, "src/shader.cpp"),
        path.join(BGFX_DIR, "src/shader_dx9bc.h"),
        path.join(BGFX_DIR, "src/shader_dx9bc.cpp"),
        path.join(BGFX_DIR, "src/shader_dxbc.h"),
        path.join(BGFX_DIR, "src/shader_dxbc.cpp"),
        path.join(BGFX_DIR, "src/shader_spirv.h"),
        path.join(BGFX_DIR, "src/shader_spirv.cpp"),
        path.join(BGFX_DIR, "src/vertexlayout.h"),
        path.join(BGFX_DIR, "src/vertexlayout.cpp"),

        -- the rest in the actual shaderc tools folder
        path.join(BGFX_DIR, "tools/shaderc/*.h"),
        path.join(BGFX_DIR, "tools/shaderc/*.cpp")
    }
    includedirs
    {
        path.join(BX_DIR, "include"),
        path.join(BIMG_DIR, "include"),
        path.join(BGFX_DIR, "include"),
        path.join(BGFX_DIR, "3rdparty/webgpu/include"),
        path.join(BGFX_DIR, "3rdparty/dxsdk/include"),
        path.join(BGFX_DIR, "3rdparty/fcpp"),
        path.join(BGFX_DIR, "3rdparty/glslang/glslang/Public"),
        path.join(BGFX_DIR, "3rdparty/glslang/glslang/Include"),
        path.join(BGFX_DIR, "3rdparty/glslang"),
        path.join(BGFX_DIR, "3rdparty/glsl-optimizer/include"),
        path.join(BGFX_DIR, "3rdparty/glsl-optimizer/src/glsl"),
        path.join(BGFX_DIR, "3rdparty/spirv-cross"),
        path.join(BGFX_DIR, "3rdparty/spirv-tools/include"),
        path.join(BGFX_DIR, "3rdparty/glsl-optimizer/include/c99"),
    }
    defines 
    {
        "__STDC_LIMIT_MACROS",
        "__STDC_FORMAT_MACROS",
        "__STDC_CONSTANT_MACROS"
    }
    links 
    {
        "bx",
        "glslang",
        "glsl-optimizer",
        "fcpp",
        "spirv-cross",
        "spirv-opt"
    }
    filter "system:windows"
        links { "psapi" }
    filter { "action:vs*" }
        defines {
            "_CRT_SECURE_NO_WARNINGS"
        }
    bxCompat()

-- TODO:
-- geometryc/v
-- texturec/v
