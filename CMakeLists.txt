cmake_minimum_required(VERSION 3.13)
project(RobloxExecutor VERSION 1.0.0 LANGUAGES C CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Set iOS specific flags
if(CMAKE_SYSTEM_NAME STREQUAL "iOS" OR APPLE)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "15.0" CACHE STRING "iOS deployment target" FORCE)
    set(CMAKE_XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "15.0" CACHE STRING "iOS deployment target" FORCE)
    set(CMAKE_OSX_ARCHITECTURES "arm64" CACHE STRING "Build architectures for iOS" FORCE)
endif()

# Output directories
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# Set CMake module path
set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake ${CMAKE_MODULE_PATH})

# Set Dobby paths explicitly
set(DOBBY_INCLUDE_DIR ${CMAKE_SOURCE_DIR}/external/dobby/include)
set(DOBBY_LIBRARY ${CMAKE_SOURCE_DIR}/external/dobby/lib/libdobby.a)

# Set Lua includes and libraries
set(LUA_INCLUDE_DIR "${CMAKE_SOURCE_DIR}/source/cpp/luau")
set(LUA_LIBRARIES "")

# Production build flags
add_definitions(
    -DPRODUCTION_BUILD=1
    -DUSE_DOBBY=1
)

# Include directories 
include_directories(
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/source
    ${CMAKE_SOURCE_DIR}/source/cpp
    ${LUA_INCLUDE_DIR}
    ${DOBBY_INCLUDE_DIR}
)

# LuaFileSystem object library
add_library(lfs_obj OBJECT ${CMAKE_SOURCE_DIR}/source/lfs.c)
target_include_directories(lfs_obj PRIVATE ${CMAKE_SOURCE_DIR}/source ${LUA_INCLUDE_DIR})
target_compile_definitions(lfs_obj PRIVATE LUA_COMPAT_5_1=1)

# Define source files
file(GLOB_RECURSE ALL_SOURCES
    "${CMAKE_SOURCE_DIR}/source/*.cpp"
    "${CMAKE_SOURCE_DIR}/source/*.c"
    "${CMAKE_SOURCE_DIR}/source/*.mm"
)

# Create the dynamic library
add_library(roblox_executor SHARED ${ALL_SOURCES})

# Set library properties for iOS
set_target_properties(roblox_executor PROPERTIES
    OUTPUT_NAME "mylibrary"
    PREFIX "lib"
    SUFFIX ".dylib"
)

# Define preprocessor macros
target_compile_definitions(roblox_executor PRIVATE
    ENABLE_AI_FEATURES=1
    ENABLE_LED_EFFECTS=1
    ENABLE_ANTI_DETECTION=1
    USE_DOBBY=1
    $<$<PLATFORM_ID:iOS>:IOS_TARGET>
    $<$<BOOL:${APPLE}>:__APPLE__>
)

# Set include directories for the target
target_include_directories(roblox_executor PRIVATE
    ${CMAKE_SOURCE_DIR}/source/cpp
    ${CMAKE_SOURCE_DIR}/source/cpp/ios
    ${CMAKE_SOURCE_DIR}/source/cpp/memory
    ${CMAKE_SOURCE_DIR}/source/cpp/hooks
    ${CMAKE_SOURCE_DIR}/source/cpp/exec
    ${CMAKE_SOURCE_DIR}/source/cpp/ios/ui
    ${CMAKE_SOURCE_DIR}/source/cpp/ios/ai_features
    ${CMAKE_SOURCE_DIR}/source/cpp/ios/advanced_bypass
    ${CMAKE_SOURCE_DIR}/source/cpp/anti_detection
    ${DOBBY_INCLUDE_DIR}
)

# Add LuaFileSystem
target_sources(roblox_executor PRIVATE $<TARGET_OBJECTS:lfs_obj>)

# Link against Dobby
target_link_libraries(roblox_executor PRIVATE ${DOBBY_LIBRARY})

# Link against system frameworks for iOS
if(APPLE)
    find_library(UIKIT UIKit REQUIRED)
    find_library(FOUNDATION Foundation REQUIRED)
    find_library(WEBKIT WebKit REQUIRED)
    find_library(COREGRAPHICS CoreGraphics REQUIRED)
    find_library(SECURITY Security)
    find_library(SYSTEMCONFIGURATION SystemConfiguration)
    
    target_link_libraries(roblox_executor PRIVATE
        ${UIKIT}
        ${FOUNDATION}
        ${WEBKIT}
        ${COREGRAPHICS}
        ${SECURITY}
        ${SYSTEMCONFIGURATION}
    )
endif()

# Copy to output
file(MAKE_DIRECTORY ${CMAKE_SOURCE_DIR}/output)
