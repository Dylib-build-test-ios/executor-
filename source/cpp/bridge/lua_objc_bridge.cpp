// Bridge implementation for safely communicating between Lua and Objective-C
#include "lua_isolation.h"
#include "bridge_interface.h"
#include <string>
#include <vector>

// Implementation of LuaBridge functions
namespace LuaBridge {
    bool ExecuteScript(lua_State* L, const char* script, const char* chunkname) {
        // Directly use real Lua API since we're in a Lua-enabled compilation unit
        int status = luaL_loadbuffer(L, script, strlen(script), chunkname);
        if (status != 0) {
            return false;
        }
        status = lua_pcall(L, 0, 0, 0);
        return status == 0;
    }
    
    const char* GetLastError(lua_State* L) {
        if (lua_gettop(L) > 0 && lua_isstring(L, -1)) {
            return lua_tostring(L, -1);
        }
        return "Unknown error";
    }
    
    void CollectGarbage(lua_State* L) {
        lua_gc(L, LUA_GCCOLLECT, 0);
    }
    
    void RegisterFunction(lua_State* L, const char* name, int (*func)(lua_State*)) {
        lua_pushcfunction(L, func, name);
        lua_setglobal(L, name);
    }
}

// The ObjC implementation has been moved to lua_objc_bridge.mm
// These forward declarations ensure that the C++ compiler knows about the functions
// defined in the Objective-C++ file (.mm)
namespace ObjCBridge {
    // Forward declarations only
    // The actual implementation is in lua_objc_bridge.mm
}
