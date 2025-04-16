// Bridge implementation for safely communicating between Lua and Objective-C
#include "lua_isolation.h"
#include "objc_isolation.h"
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

// Implementation of ObjCBridge functions
namespace ObjCBridge {
    // Actual implementations for iOS
    bool ShowAlert(const char* title, const char* message) {
        @autoreleasepool {
            // Convert C strings to NSString
            NSString* nsTitle = [NSString stringWithUTF8String:title ? title : "Alert"];
            NSString* nsMessage = [NSString stringWithUTF8String:message ? message : ""];
            
            // Create a semaphore to wait for user response
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            __block bool result = false;
            
            // Run on the main thread as UI operations require this
            dispatch_async(dispatch_get_main_queue(), ^{
                // Get the key window's root view controller
                UIWindow *keyWindow = nil;
                if (@available(iOS 13.0, *)) {
                    NSArray<UIScene *> *scenes = UIApplication.sharedApplication.connectedScenes.allObjects;
                    for (UIScene *scene in scenes) {
                        if (scene.activationState == UISceneActivationStateForegroundActive) {
                            UIWindowScene *windowScene = (UIWindowScene *)scene;
                            for (UIWindow *window in windowScene.windows) {
                                if (window.isKeyWindow) {
                                    keyWindow = window;
                                    break;
                                }
                            }
                        }
                    }
                } else {
                    keyWindow = UIApplication.sharedApplication.keyWindow;
                }
                
                UIViewController* rootVC = keyWindow.rootViewController;
                if (!rootVC) {
                    dispatch_semaphore_signal(semaphore);
                    return;
                }
                
                // Find the presented view controller to show alert on
                UIViewController* presentedVC = rootVC;
                while (presentedVC.presentedViewController) {
                    presentedVC = presentedVC.presentedViewController;
                }
                
                // Create and configure the alert controller
                UIAlertController* alert = [UIAlertController 
                    alertControllerWithTitle:nsTitle 
                    message:nsMessage 
                    preferredStyle:UIAlertControllerStyleAlert];
                
                // Add OK button
                [alert addAction:[UIAlertAction 
                    actionWithTitle:@"OK" 
                    style:UIAlertActionStyleDefault 
                    handler:^(UIAlertAction* action) {
                        result = true;
                        dispatch_semaphore_signal(semaphore);
                    }]];
                
                // Add Cancel button
                [alert addAction:[UIAlertAction 
                    actionWithTitle:@"Cancel" 
                    style:UIAlertActionStyleCancel 
                    handler:^(UIAlertAction* action) {
                        result = false;
                        dispatch_semaphore_signal(semaphore);
                    }]];
                
                // Present the alert
                [presentedVC presentViewController:alert animated:YES completion:nil];
            });
            
            // Wait for user response with a timeout
            dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
            return result;
        }
    }
    
    bool SaveScript(const char* name, const char* script) {
        @autoreleasepool {
            if (!name || !script) return false;
            
            // Convert inputs to NSStrings
            NSString* scriptName = [NSString stringWithUTF8String:name];
            NSString* scriptContent = [NSString stringWithUTF8String:script];
            
            // Sanitize the filename - remove any path components for security
            scriptName = [scriptName lastPathComponent];
            
            // Get the Documents directory
            NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString* documentsDirectory = paths.firstObject;
            
            // Create Scripts directory if it doesn't exist
            NSString* scriptsDirectory = [documentsDirectory stringByAppendingPathComponent:@"Scripts"];
            NSFileManager* fileManager = [NSFileManager defaultManager];
            
            if (![fileManager fileExistsAtPath:scriptsDirectory]) {
                NSError* error = nil;
                [fileManager createDirectoryAtPath:scriptsDirectory 
                       withIntermediateDirectories:YES 
                                        attributes:nil 
                                             error:&error];
                if (error) {
                    NSLog(@"Error creating Scripts directory: %@", error);
                    return false;
                }
            }
            
            // Create full path for the script file
            NSString* fullPath = [scriptsDirectory stringByAppendingPathComponent:
                                 [scriptName stringByAppendingPathExtension:@"lua"]];
            
            // Write the script to file
            NSError* error = nil;
            [scriptContent writeToFile:fullPath 
                           atomically:YES 
                             encoding:NSUTF8StringEncoding 
                                error:&error];
            
            if (error) {
                NSLog(@"Error saving script: %@", error);
                return false;
            }
            
            return true;
        }
    }
    
    const char* LoadScript(const char* name) {
        @autoreleasepool {
            if (!name) return "";
            
            // Convert input to NSString
            NSString* scriptName = [NSString stringWithUTF8String:name];
            
            // Sanitize the filename
            scriptName = [scriptName lastPathComponent];
            
            // Get the Documents directory
            NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString* documentsDirectory = paths.firstObject;
            
            // Create full path for the script file
            NSString* scriptsDirectory = [documentsDirectory stringByAppendingPathComponent:@"Scripts"];
            NSString* fullPath = [scriptsDirectory stringByAppendingPathComponent:
                                 [scriptName stringByAppendingPathExtension:@"lua"]];
            
            // Check if the file exists
            NSFileManager* fileManager = [NSFileManager defaultManager];
            if (![fileManager fileExistsAtPath:fullPath]) {
                NSLog(@"Script file not found: %@", fullPath);
                return "";
            }
            
            // Read the script from file
            NSError* error = nil;
            NSString* scriptContent = [NSString stringWithContentsOfFile:fullPath 
                                                                encoding:NSUTF8StringEncoding 
                                                                   error:&error];
            
            if (error) {
                NSLog(@"Error loading script: %@", error);
                return "";
            }
            
            // Use a static buffer to return the result
            // Warning: This is not thread-safe, but simplifies memory management
            static std::string scriptBuffer;
            scriptBuffer = [scriptContent UTF8String];
            return scriptBuffer.c_str();
        }
    }
    
    bool InjectFloatingButton() {
        // This should be implemented in a more sophisticated way
        // in a real product, integrating with the FloatingButtonController
        @autoreleasepool {
            dispatch_async(dispatch_get_main_queue(), ^{
                // We'll call the shared instance method of FloatingButtonController
                Class buttonControllerClass = NSClassFromString(@"FloatingButtonController");
                if (buttonControllerClass) {
                    id controller = [buttonControllerClass performSelector:@selector(sharedInstance)];
                    if (controller) {
                        [controller performSelector:@selector(showButton)];
                        return;
                    }
                }
                
                // If the controller class isn't available, create a basic floating button
                UIWindow *keyWindow = nil;
                if (@available(iOS 13.0, *)) {
                    NSArray<UIScene *> *scenes = UIApplication.sharedApplication.connectedScenes.allObjects;
                    for (UIScene *scene in scenes) {
                        if (scene.activationState == UISceneActivationStateForegroundActive) {
                            UIWindowScene *windowScene = (UIWindowScene *)scene;
                            for (UIWindow *window in windowScene.windows) {
                                if (window.isKeyWindow) {
                                    keyWindow = window;
                                    break;
                                }
                            }
                        }
                    }
                } else {
                    keyWindow = UIApplication.sharedApplication.keyWindow;
                }
                
                if (!keyWindow) return;
                
                // Create a simple floating button
                UIButton *floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
                floatingButton.frame = CGRectMake(20, 100, 60, 60);
                floatingButton.backgroundColor = [UIColor systemBlueColor];
                floatingButton.layer.cornerRadius = 30;
                floatingButton.layer.shadowColor = [UIColor blackColor].CGColor;
                floatingButton.layer.shadowOffset = CGSizeMake(0, 3);
                floatingButton.layer.shadowOpacity = 0.5;
                floatingButton.layer.shadowRadius = 5;
                [floatingButton setTitle:@"🚀" forState:UIControlStateNormal];
                
                // Make it draggable with pan gesture
                UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] 
                    initWithTarget:floatingButton 
                    action:@selector(handlePan:)];
                [floatingButton addGestureRecognizer:panGesture];
                
                // Add the button to the window
                [keyWindow addSubview:floatingButton];
                
                // Make sure it's above other views
                [keyWindow bringSubviewToFront:floatingButton];
                
                // Add tap handler to show script manager
                [floatingButton addTarget:nil 
                                   action:@selector(ShowScriptEditor) 
                         forControlEvents:UIControlEventTouchUpInside];
            });
            
            return true;
        }
    }
    
    void ShowScriptEditor() {
        @autoreleasepool {
            dispatch_async(dispatch_get_main_queue(), ^{
                // We'll call the method from UIController if available
                Class uiControllerClass = NSClassFromString(@"UIController");
                if (uiControllerClass) {
                    id controller = [uiControllerClass performSelector:@selector(sharedInstance)];
                    if (controller) {
                        [controller performSelector:@selector(showScriptEditor)];
                        return;
                    }
                }
                
                // Otherwise, show a simple alert that we'd need a proper implementation
                UIAlertController *alert = [UIAlertController 
                    alertControllerWithTitle:@"Script Editor" 
                    message:@"Script editor implementation required for full functionality." 
                    preferredStyle:UIAlertControllerStyleAlert];
                
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" 
                                                          style:UIAlertActionStyleDefault 
                                                        handler:nil]];
                
                // Show the alert on the top view controller
                UIWindow *keyWindow = nil;
                if (@available(iOS 13.0, *)) {
                    NSArray<UIScene *> *scenes = UIApplication.sharedApplication.connectedScenes.allObjects;
                    for (UIScene *scene in scenes) {
                        if (scene.activationState == UISceneActivationStateForegroundActive) {
                            UIWindowScene *windowScene = (UIWindowScene *)scene;
                            for (UIWindow *window in windowScene.windows) {
                                if (window.isKeyWindow) {
                                    keyWindow = window;
                                    break;
                                }
                            }
                        }
                    }
                } else {
                    keyWindow = UIApplication.sharedApplication.keyWindow;
                }
                
                if (!keyWindow) return;
                
                UIViewController *rootVC = keyWindow.rootViewController;
                UIViewController *topVC = rootVC;
                while (topVC.presentedViewController) {
                    topVC = topVC.presentedViewController;
                }
                
                [topVC presentViewController:alert animated:YES completion:nil];
            });
        }
    }
}
