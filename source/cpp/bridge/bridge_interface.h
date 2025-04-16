// bridge_interface.h - Provides a clean interface between C++ and Objective-C components
#pragma once

// This header provides forward declarations of key types without including
// both Lua and Objective-C headers in the same translation unit

// Forward declare the Lua state type without including Lua headers
struct lua_State;

// LuaBridge namespace provides C++ functions for Lua interaction
namespace LuaBridge {
    // Functions to safely execute Lua code
    bool ExecuteScript(lua_State* L, const char* script, const char* chunkname = "");
    const char* GetLastError(lua_State* L);
    
    // Memory management
    void CollectGarbage(lua_State* L);
    
    // Register a function
    void RegisterFunction(lua_State* L, const char* name, int (*func)(lua_State*));
}

// ObjCBridge namespace provides Objective-C functions callable from C++
namespace ObjCBridge {
    // UI Functions
    bool ShowAlert(const char* title, const char* message);
    void ShowScriptEditor();
    bool InjectFloatingButton();
    
    // File Operations
    bool SaveScript(const char* name, const char* script);
    const char* LoadScript(const char* name);
}
