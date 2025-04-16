// Stub file to replace lua_objc_bridge.cpp
#include "bridge/bridge_interface.h"
#include <stdio.h>

// Stub implementations for when Objective-C is not available
// The real implementations are in lua_objc_bridge.mm
namespace ObjCBridge {
    bool ShowAlert(const char* title, const char* message) {
        printf("ALERT: %s - %s\n", title, message);
        return true;
    }
    
    bool SaveScript(const char* name, const char* script) {
        printf("SAVE SCRIPT: %s\n", name);
        return true;
    }
    
    const char* LoadScript(const char* name) {
        static const char* script = "-- Loaded script content";
        return script;
    }
    
    bool InjectFloatingButton() {
        printf("INJECT FLOATING BUTTON\n");
        return true;
    }
    
    void ShowScriptEditor() {
        printf("SHOW SCRIPT EDITOR\n");
    }
}
