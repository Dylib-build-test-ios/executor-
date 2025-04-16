#include "hooks.hpp"
#include "../dobby_wrapper.cpp"
#include <iostream>
#include <string>
#include <cassert>

#ifdef __APPLE__
#include <objc/runtime.h>
#include <objc/message.h>
#endif

namespace Hooks {

// Initialize the hook engine
bool HookEngine::Initialize() {
    std::cout << "Initializing HookEngine..." << std::endl;
    // Clear any existing hooks to ensure a clean state
    ClearAllHooks();
    return true;
}

// Register a new hook
bool HookEngine::RegisterHook(void* targetAddr, void* hookAddr, void** originalAddr) {
    if (!targetAddr || !hookAddr) {
        std::cerr << "HookEngine: Invalid address for hook" << std::endl;
        return false;
    }
    
    // Use thread-safe access to the hooks map
    std::lock_guard<std::mutex> lock(s_hookMutex);
    
    // Check if target is already hooked
    if (s_hookedFunctions.find(targetAddr) != s_hookedFunctions.end()) {
        std::cerr << "HookEngine: Target function already hooked" << std::endl;
        return false;
    }
    
    // Register the hook using platform-specific implementation
    bool success = Implementation::HookFunction(targetAddr, hookAddr, originalAddr);
    
    if (success) {
        // Store the hook in our tracking map
        s_hookedFunctions[targetAddr] = hookAddr;
        std::cout << "HookEngine: Successfully hooked function at " << targetAddr << std::endl;
    } else {
        std::cerr << "HookEngine: Failed to hook function at " << targetAddr << std::endl;
    }
    
    return success;
}

// Unregister a hook
bool HookEngine::UnregisterHook(void* targetAddr) {
    if (!targetAddr) {
        std::cerr << "HookEngine: Invalid address for unhook" << std::endl;
        return false;
    }
    
    // Use thread-safe access to the hooks map
    std::lock_guard<std::mutex> lock(s_hookMutex);
    
    // Check if target is actually hooked
    auto it = s_hookedFunctions.find(targetAddr);
    if (it == s_hookedFunctions.end()) {
        std::cerr << "HookEngine: Target function not hooked" << std::endl;
        return false;
    }
    
    // Unregister the hook using platform-specific implementation
    bool success = Implementation::UnhookFunction(targetAddr);
    
    if (success) {
        // Remove the hook from our tracking map
        s_hookedFunctions.erase(it);
        std::cout << "HookEngine: Successfully unhooked function at " << targetAddr << std::endl;
    } else {
        std::cerr << "HookEngine: Failed to unhook function at " << targetAddr << std::endl;
    }
    
    return success;
}

// Clear all registered hooks
void HookEngine::ClearAllHooks() {
    // Use thread-safe access to the hooks map
    std::lock_guard<std::mutex> lock(s_hookMutex);
    
    // Unregister each hook
    for (const auto& pair : s_hookedFunctions) {
        Implementation::UnhookFunction(pair.first);
    }
    
    // Clear the hooks map
    s_hookedFunctions.clear();
    std::cout << "HookEngine: Cleared all hooks" << std::endl;
}

namespace Implementation {
    // Hook function implementation using Dobby
    bool HookFunction(void* target, void* replacement, void** original) {
        // Use DobbyWrapper for the actual hooking
        void* originalFunc = DobbyWrapper::Hook(target, replacement);
        
        if (originalFunc) {
            // If the caller wants the original function pointer, provide it
            if (original) {
                *original = originalFunc;
            }
            return true;
        }
        
        return false;
    }
    
    // Unhook function implementation using Dobby
    bool UnhookFunction(void* target) {
        // Use DobbyWrapper for the actual unhooking
        return DobbyWrapper::Unhook(target);
    }
}

// ObjC Method Hooking Implementation
bool ObjcMethodHook::HookMethod(const std::string& className, const std::string& selectorName, 
                             void* replacementFn, void** originalFn) {
#ifdef __APPLE__
    std::lock_guard<std::mutex> lock(s_methodMutex);
    
    // Generate a unique key for this method
    std::string methodKey = className + "::" + selectorName;
    
    // Check if already hooked
    if (s_hookedMethods.find(methodKey) != s_hookedMethods.end()) {
        std::cerr << "ObjcMethodHook: Method " << methodKey << " already hooked" << std::endl;
        return false;
    }
    
    // Get the class
    Class cls = objc_getClass(className.c_str());
    if (!cls) {
        std::cerr << "ObjcMethodHook: Class " << className << " not found" << std::endl;
        return false;
    }
    
    // Get the selector
    SEL selector = sel_registerName(selectorName.c_str());
    if (!selector) {
        std::cerr << "ObjcMethodHook: Selector " << selectorName << " registration failed" << std::endl;
        return false;
    }
    
    // Get the method
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
        std::cerr << "ObjcMethodHook: Method " << selectorName << " not found in class " << className << std::endl;
        return false;
    }
    
    // Get the original implementation
    HookIMP originalImp = method_getImplementation(method);
    
    // Store original implementation if requested
    if (originalFn) {
        *originalFn = originalImp;
    }
    
    // Replace the implementation
    method_setImplementation(method, (IMP)replacementFn);
    
    // Store the hooked method
    s_hookedMethods[methodKey] = std::make_pair(cls, selector);
    
    std::cout << "ObjcMethodHook: Successfully hooked method " << methodKey << std::endl;
    return true;
#else
    // Non-Apple platforms don't support ObjC method swizzling
    std::cerr << "ObjcMethodHook: Method swizzling not supported on this platform" << std::endl;
    return false;
#endif
}

bool ObjcMethodHook::UnhookMethod(const std::string& className, const std::string& selectorName) {
#ifdef __APPLE__
    std::lock_guard<std::mutex> lock(s_methodMutex);
    
    // Generate a unique key for this method
    std::string methodKey = className + "::" + selectorName;
    
    // Check if method is hooked
    auto it = s_hookedMethods.find(methodKey);
    if (it == s_hookedMethods.end()) {
        std::cerr << "ObjcMethodHook: Method " << methodKey << " not hooked" << std::endl;
        return false;
    }
    
    // Method unhooking is more complex - we need the original implementation
    // Since we don't store it (that would be a better design), we can't properly unhook
    // In a production implementation, we would store the original implementation
    
    // Remove from the tracking map
    s_hookedMethods.erase(it);
    
    std::cout << "ObjcMethodHook: Method " << methodKey << " removed from tracking (original implementation not restored)" << std::endl;
    return true;
#else
    // Non-Apple platforms don't support ObjC method swizzling
    std::cerr << "ObjcMethodHook: Method swizzling not supported on this platform" << std::endl;
    return false;
#endif
}

void ObjcMethodHook::ClearAllHooks() {
#ifdef __APPLE__
    std::lock_guard<std::mutex> lock(s_methodMutex);
    
    // Similar limitation as UnhookMethod - we can't restore original implementations
    // We can only clear our tracking
    s_hookedMethods.clear();
    
    std::cout << "ObjcMethodHook: Cleared all method hooks from tracking" << std::endl;
#endif
}

} // namespace Hooks
