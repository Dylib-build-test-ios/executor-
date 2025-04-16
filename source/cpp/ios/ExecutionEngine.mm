
#include "../ios_compat.h"
#include "ExecutionEngine.h"
#include <iostream>
#include <chrono>
#include <thread>
#include <sstream>
#include <algorithm>
#include <random>
#include <iomanip>  // For std::setw and std::setfill

// Objective-C frameworks need to be imported at the top level
#import <WebKit/WebKit.h>

namespace iOS {
    // Constructor
    ExecutionEngine::ExecutionEngine(std::shared_ptr<ScriptManager> scriptManager)
        : m_scriptManager(scriptManager),
          m_outputCallback(nullptr),
          m_isExecuting(false),
          m_retryCount(0) {
        
        // Initialize default context
        m_defaultContext.m_isJailbroken = CheckJailbreakStatus();
    }
    
    // Initialize the execution engine
    bool ExecutionEngine::Initialize() {
        try {
            // Detect jailbreak status
            m_defaultContext.m_isJailbroken = CheckJailbreakStatus();
            
            // Create script manager if not provided
            if (!m_scriptManager) {
                m_scriptManager = std::make_shared<ScriptManager>();
                if (!m_scriptManager->Initialize()) {
                    std::cerr << "ExecutionEngine: Failed to initialize script manager" << std::endl;
                    return false;
                }
            }
            
            // Initialize default context based on device capabilities
            SetupBypassEnvironment(m_defaultContext);
            
            std::cout << "ExecutionEngine: Initialized for " 
                      << (m_defaultContext.m_isJailbroken ? "jailbroken" : "non-jailbroken") 
                      << " device" << std::endl;
            
            return true;
        } catch (const std::exception& e) {
            std::cerr << "ExecutionEngine: Exception during initialization: " << e.what() << std::endl;
            return false;
        }
    }
    
    // Execute a script
    ExecutionEngine::ExecutionResult ExecutionEngine::Execute(
        const std::string& script, const ExecutionContext& context) {
        
        // Check if already executing
        if (m_isExecuting) {
            return ExecutionResult(false, "Another script is already executing");
        }
        
        // Set executing flag
        std::lock_guard<std::mutex> lock(m_executionMutex);
        m_isExecuting = true;
        m_retryCount = 0;
        
        // Start timing
        auto startTime = std::chrono::high_resolution_clock::now();
        
        try {
            // Make a copy of the provided context (or use default if empty)
            ExecutionContext executionContext = context;
            
            // Call before-execute callbacks
            for (const auto& callback : m_beforeCallbacks) {
                if (!callback(script, executionContext)) {
                    // Callback returned false, abort execution
                    m_isExecuting = false;
                    return ExecutionResult(false, "Execution aborted by before-execute callback");
                }
            }
            
            // Prepare the script for execution
            std::string preparedScript = PrepareScript(script, executionContext);
            
            // Execute script based on available methods
            
            // Variables to build the execution result - using __block to allow modification in blocks
            __block std::string resultOutput;
            __block bool resultSuccess = false;
            __block std::string resultError;
            
            // Non-jailbroken approach - use UIWebView JavaScript bridge
            // This works on non-jailbroken devices but has limitations
            if (!executionContext.m_isJailbroken) {
                @autoreleasepool {
                    // Create a dispatch group to wait for execution to complete
                    dispatch_group_t group = dispatch_group_create();
                    dispatch_group_enter(group);
                    
                    // Execute on main thread since UIKit requires it
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // Create a hidden web view for JavaScript execution
                        WKWebView* webView = [[WKWebView alloc] initWithFrame:CGRectZero];
                        webView.hidden = YES;
                    
                        // Add to view hierarchy temporarily
                        __block UIWindow* keyWindow = nil;
                        if (@available(iOS 13.0, *)) {
                            for (UIWindowScene* scene in [[UIApplication sharedApplication] connectedScenes]) {
                                if (scene.activationState == UISceneActivationStateForegroundActive) {
                                    keyWindow = scene.windows.firstObject;
                                    break;
                                }
                            }
                        } else {
                            #pragma clang diagnostic push
                            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
                            keyWindow = [[UIApplication sharedApplication] keyWindow];
                            #pragma clang diagnostic pop
                        }
                    
                        if (keyWindow) {
                            [keyWindow addSubview:webView];
                        
                            // Declare local mutable variables to store results
                            __block NSString* capturedOutput = nil;
                            __block NSString* capturedError = nil;
                            __block BOOL capturedSuccess = NO;
                        
                            // Create a dispatch semaphore to wait for async execution to complete
                            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                        
                            // Set up console.log capture
                            NSString* logCaptureJS = @"var originalLog = console.log;"
                                                    "var logOutput = '';"
                                                    "console.log = function() {"
                                                    "    var args = Array.prototype.slice.call(arguments);"
                                                    "    originalLog.apply(console, args);"
                                                    "    logOutput += args.join(' ') + '\\n';"
                                                    "};";
                        
                            [webView evaluateJavaScript:logCaptureJS completionHandler:^(id _Nullable logResult, NSError* _Nullable logError) {
                                // Now that console.log is set up, evaluate the actual script
                                NSString* nsScript = [NSString stringWithUTF8String:preparedScript.c_str()];
                                [webView evaluateJavaScript:nsScript completionHandler:^(id _Nullable scriptResult, NSError* _Nullable scriptError) {
                                    // Get console output
                                    [webView evaluateJavaScript:@"logOutput" completionHandler:^(id _Nullable consoleOutput, NSError* _Nullable outputError) {
                                        // Handle results
                                        capturedSuccess = (scriptResult != nil && ![scriptResult isEqual:[NSNull null]]);
                                    
                                        if (consoleOutput && [consoleOutput isKindOfClass:[NSString class]]) {
                                            capturedOutput = (NSString*)consoleOutput;
                                        }
                                    
                                        if (scriptError) {
                                            capturedError = [scriptError localizedDescription];
                                            capturedSuccess = NO;
                                        }
                                    
                                        // Process output
                                        if ((capturedOutput.length == 0) && !capturedSuccess) {
                                            capturedError = @"Script execution failed with no output";
                                        }
                                    
                                        // Signal completion
                                        dispatch_semaphore_signal(semaphore);
                                    }];
                                }];
                            }];
                        
                            // Wait for the script execution to complete with timeout
                            __block BOOL timedOut = NO;
                            uint64_t timeoutNs = executionContext.m_timeout * 1000000ULL;
                            dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, timeoutNs);
                            if (dispatch_semaphore_wait(semaphore, timeout) != 0) {
                                capturedError = @"Script execution timed out";
                                capturedSuccess = NO;
                                timedOut = YES;
                            }
                        
                            // Capture results from the block
                            if (capturedOutput) {
                                resultOutput = [capturedOutput UTF8String];
                            }
                            
                            if (capturedError) {
                                resultError = [capturedError UTF8String];
                            }
                            
                            resultSuccess = capturedSuccess;
                        
                            // Remove web view
                            [webView removeFromSuperview];
                        } else {
                            // Handle missing key window
                            resultError = "Failed to find key window for execution";
                            resultSuccess = false;
                        }
                        
                        dispatch_group_leave(group);
                    });
                    
                    // Wait for execution to complete with timeout
                    uint64_t timeoutNs = executionContext.m_timeout * 1000000ULL;
                    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, timeoutNs);
                    
                    if (dispatch_group_wait(group, timeout) != 0) {
                        resultError = "Script execution timed out";
                        resultSuccess = false;
                    }
                }
            } else {
                // Jailbroken approach - use advanced bypass methods
                @autoreleasepool {
                    // Create a dispatch group to wait for execution to complete
                    dispatch_group_t group = dispatch_group_create();
                    dispatch_group_enter(group);
                    
                    // Execute on a separate thread to avoid blocking
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        // Use local variables for thread safety
                        std::string localOutput;
                        bool localSuccess = false;
                        std::string localError;
                        
                        // Try to use an alternative execution approach
                        if (@available(iOS 15.0, *)) {
                            // Use JavaScript context for execution in newer iOS versions
                            JSContext *context = [[JSContext alloc] init];
                            
                            // Set up console.log to capture output
                            context[@"consoleLog"] = ^(NSString *message) {
                                localOutput += [message UTF8String];
                                localOutput += "\n";
                            };
                            
                            // Add console.log implementation
                            [context evaluateScript:@"console = { log: function(msg) { consoleLog(msg); } }"];
                            
                            @try {
                                // Convert script to NSString
                                NSString *scriptStr = [NSString stringWithUTF8String:preparedScript.c_str()];
                                
                                // Execute the script
                                JSValue *result = [context evaluateScript:scriptStr];
                                
                                // Handle result
                                if (![result isUndefined]) {
                                    NSString *resultStr = [result toString];
                                    localOutput += [resultStr UTF8String];
                                    localSuccess = true;
                                } else if (context.exception) {
                                    localError = [[context.exception toString] UTF8String];
                                    localSuccess = false;
                                } else {
                                    localSuccess = true;
                                    localOutput += "[Script executed with no return value]";
                                }
                                
                                // Add execution method info
                                localOutput += "\n[Executed using: JSContext]";
                            } @catch (NSException *exception) {
                                localError = [[exception reason] UTF8String];
                                localSuccess = false;
                            }
                        } else {
                            // Fall back to older method for earlier iOS versions
                            try {
                                // Create a simple execution context using available frameworks
                                WebKit::WebView *webView = [[WebKit::WebView alloc] init];
                                BOOL executeResult = [webView evaluateScript:[NSString stringWithUTF8String:preparedScript.c_str()]];
                                
                                if (executeResult) {
                                    localSuccess = true;
                                    localOutput = "Script executed in WebKit (iOS < 15.0)";
                                } else {
                                    localError = "Failed to execute script in WebKit";
                                    localSuccess = false;
                                }
                                
                                localOutput += "\n[Executed using: WebKit fallback]";
                            } catch (const std::exception& e) {
                                localError = std::string("Exception in fallback execution: ") + e.what();
                                localSuccess = false;
                            }
                        }
                        
                        // Try alternative approach using Objective-C runtime if all else fails
                        if (!localSuccess) {
                            try {
                                Class luaClass = objc_lookUpClass("Lua");
                                if (luaClass) {
                                    SEL executeSelector = sel_registerName("executeScript:");
                                    if ([luaClass respondsToSelector:executeSelector]) {
                                        NSString* script = [NSString stringWithUTF8String:preparedScript.c_str()];
                                        id result = [luaClass performSelector:executeSelector withObject:script];
                                        
                                        if (result) {
                                            localSuccess = true;
                                            if ([result isKindOfClass:[NSString class]]) {
                                                localOutput = [(NSString*)result UTF8String];
                                            } else {
                                                localOutput = "Script executed successfully (no output)";
                                            }
                                            localOutput += "\n[Executed using: ObjC Runtime]";
                                        } else {
                                            localError = "Script execution failed with Lua class";
                                        }
                                    } else {
                                        localError = "Lua class does not implement executeScript method";
                                    }
                                } else {
                                    localError = "Lua class not found";
                                }
                            } catch (const std::exception& e) {
                                if (localError.empty()) {
                                    localError = std::string("Exception in fallback execution: ") + e.what();
                                }
                            }
                        }
                        
                        // Update the shared result variables in a thread-safe way
                        resultSuccess = localSuccess;
                        resultError = localError;
                        resultOutput = localOutput;
                        
                        dispatch_group_leave(group);
                    });
                    
                    // Wait for execution to complete with timeout
                    uint64_t timeoutNs = executionContext.m_timeout * 1000000ULL;
                    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, timeoutNs);
                    
                    if (dispatch_group_wait(group, timeout) != 0) {
                        resultError = "Script execution timed out in jailbroken mode";
                        resultSuccess = false;
                    }
                }
            }
            
            // Process output
            if (m_outputCallback && !resultOutput.empty()) {
                m_outputCallback(resultOutput);
            }
            
            // Calculate execution time
            auto endTime = std::chrono::high_resolution_clock::now();
            uint64_t executionTime = std::chrono::duration_cast<std::chrono::milliseconds>(endTime - startTime).count();
            
            // Create result
            ExecutionResult result(resultSuccess, resultError, executionTime, resultOutput);
            
            // Call after-execute callbacks
            for (const auto& callback : m_afterCallbacks) {
                callback(script, result);
            }
            
            // Log execution
            LogExecution(script, result);
            
            // Reset executing flag
            m_isExecuting = false;
            
            // Handle auto-retry if enabled and execution failed
            if (!resultSuccess && executionContext.m_autoRetry && m_retryCount < executionContext.m_maxRetries) {
                m_retryCount++;
                std::cout << "ExecutionEngine: Auto-retrying script execution (attempt " << m_retryCount 
                          << " of " << executionContext.m_maxRetries << ")" << std::endl;
                
                // Wait a bit before retrying
                std::this_thread::sleep_for(std::chrono::milliseconds(500 * m_retryCount));
                
                // Retry execution
                return Execute(script, executionContext);
            }
            
            return result;
        } catch (const std::exception& e) {
            // Handle exceptions
            std::cerr << "ExecutionEngine: Exception during execution: " << e.what() << std::endl;
            
            // Reset executing flag
            m_isExecuting = false;
            
            // Calculate execution time
            auto endTime = std::chrono::high_resolution_clock::now();
            uint64_t executionTime = std::chrono::duration_cast<std::chrono::milliseconds>(endTime - startTime).count();
            
            return ExecutionResult(false, std::string("Exception: ") + e.what(), executionTime);
        }
    }
    
    // Execute a script by name from the script manager
    ExecutionEngine::ExecutionResult ExecutionEngine::ExecuteByName(
        const std::string& scriptName, const ExecutionContext& context) {
        
        // Check if script manager is available
        if (!m_scriptManager) {
            return ExecutionResult(false, "Script manager not available");
        }
        
        // Get the script
        ScriptManager::Script script = m_scriptManager->GetScript(scriptName);
        if (script.m_name.empty()) {
            return ExecutionResult(false, "Script not found: " + scriptName);
        }
        
        // Execute the script
        return Execute(script.m_content, context);
    }
    
    // Set the default execution context
    void ExecutionEngine::SetDefaultContext(const ExecutionContext& context) {
        m_defaultContext = context;
    }
    
    // Get the default execution context
    ExecutionEngine::ExecutionContext ExecutionEngine::GetDefaultContext() const {
        return m_defaultContext;
    }
    
    // Register a callback to be called before script execution
    void ExecutionEngine::RegisterBeforeExecuteCallback(const BeforeExecuteCallback& callback) {
        if (callback) {
            m_beforeCallbacks.push_back(callback);
        }
    }
    
    // Register a callback to be called after script execution
    void ExecutionEngine::RegisterAfterExecuteCallback(const AfterExecuteCallback& callback) {
        if (callback) {
            m_afterCallbacks.push_back(callback);
        }
    }
    
    // Set the output callback function
    void ExecutionEngine::SetOutputCallback(const OutputCallback& callback) {
        m_outputCallback = callback;
    }
    
    // Check if the engine is currently executing a script
    bool ExecutionEngine::IsExecuting() const {
        return m_isExecuting;
    }
    
    // Set the script manager
    void ExecutionEngine::SetScriptManager(std::shared_ptr<ScriptManager> scriptManager) {
        m_scriptManager = scriptManager;
    }
    
    // Detect if device is jailbroken
    bool ExecutionEngine::IsJailbroken() {
        // Check common jailbreak indicators
        
        // 1. Check for common jailbreak files
        NSArray* jailbreakFiles = @[
            @"/Applications/Cydia.app",
            @"/Library/MobileSubstrate/MobileSubstrate.dylib",
            @"/bin/bash",
            @"/usr/sbin/sshd",
            @"/etc/apt",
            @"/private/var/lib/apt"
        ];
        
        for (NSString* path in jailbreakFiles) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
                return true;
            }
        }
        
        // 2. Check if we can write to a system location
        NSError* error;
        NSString* testPath = @"/private/jailbreak_test";
        NSString* testString = @"Jailbreak test";
        
        BOOL written = [testString writeToFile:testPath 
                                    atomically:YES 
                                      encoding:NSUTF8StringEncoding 
                                         error:&error];
        
        if (written) {
            // Clean up the test file
            [[NSFileManager defaultManager] removeItemAtPath:testPath error:nil];
            return true;
        }
        
        // 3. Check for URL schemes
        if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"cydia://"]]) {
            return true;
        }
        
        return false;
    }
    
    // Check jailbreak status
    bool ExecutionEngine::CheckJailbreakStatus() {
        return IsJailbroken();
    }
    
    // Obfuscate a script
    std::string ExecutionEngine::ObfuscateScript(const std::string& script) {
        // In a real implementation, you'd use proper obfuscation techniques
        // This is a simple demonstration
        
        // Generate a random key
        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_int_distribution<> dist(1, 255);
        int key = dist(gen);
        
        // Create the obfuscated script
        std::stringstream obfuscated;
        
        // Add a decoding function
        obfuscated << "local function _d(s,k)\n";
        obfuscated << "    local r=''\n";
        obfuscated << "    for i=1,#s do\n";
        obfuscated << "        local c=string.byte(s,i)\n";
        obfuscated << "        r=r..string.char(c~k)\n";
        obfuscated << "    end\n";
        obfuscated << "    return r\n";
        obfuscated << "end\n\n";
        
        // Encrypt the script with XOR
        std::string encrypted;
        for (char c : script) {
            encrypted += static_cast<char>(c ^ key);
        }
        
        // Convert to hex for string literal
        std::stringstream hexStream;
        hexStream << "local _s='";
        for (char c : encrypted) {
            hexStream << std::hex << std::setw(2) << std::setfill('0') << (int)(unsigned char)c;
        }
        hexStream << "'\n";
        
        obfuscated << hexStream.str();
        
        // Add decoding and execution code
        obfuscated << "local _h=''\n";
        obfuscated << "for i=1,#_s,2 do\n";
        obfuscated << "    _h=_h..string.char(tonumber(_s:sub(i,i+1),16))\n";
        obfuscated << "end\n\n";
        obfuscated << "local _decoded=_d(_h," << key << ")\n";
        obfuscated << "local _f=loadstring or load\n";
        obfuscated << "return _f(_decoded)()\n";
        
        return obfuscated.str();
    }
    
    // Prepare a script for execution
    std::string ExecutionEngine::PrepareScript(const std::string& script, const ExecutionContext& context) {
        // Apply various preparation steps based on context settings
        
        std::string preparedScript = script;
        
        // Add environment variables
        std::string envScript = GenerateExecutionEnvironment(context);
        preparedScript = envScript + "\n" + preparedScript;
        
        // Apply obfuscation if enabled
        if (context.m_enableObfuscation) {
            preparedScript = ObfuscateScript(preparedScript);
        }
        
        return preparedScript;
    }
    
    // Process output from script execution
    void ExecutionEngine::ProcessOutput(const std::string& output) {
        if (m_outputCallback && !output.empty()) {
            m_outputCallback(output);
        }
    }
    
    // Setup the bypass environment based on device capabilities
    bool ExecutionEngine::SetupBypassEnvironment(const ExecutionContext& context) {
        // Determine which bypass methods are available based on jailbreak status
        if (context.m_isJailbroken) {
            // More methods available on jailbroken devices
            std::cout << "ExecutionEngine: Setting up jailbroken bypass environment" << std::endl;
            
            // In a real implementation, you would initialize more powerful bypass methods here
        } else {
            // Limited methods available on non-jailbroken devices
            std::cout << "ExecutionEngine: Setting up non-jailbroken bypass environment" << std::endl;
            
            // In a real implementation, you would initialize sandbox-compliant bypass methods
        }
        
        return true;
    }
    
    // Log script execution
    void ExecutionEngine::LogExecution(const std::string& script, const ExecutionResult& result) {
        // Create a log entry
        std::stringstream logEntry;
        logEntry << "======== Script Execution (" << (result.m_success ? "SUCCESS" : "FAILED") << ") ========\n";
        logEntry << "Time: " << result.m_executionTime << " ms\n";
        
        if (!result.m_error.empty()) {
            logEntry << "Error: " << result.m_error << "\n";
        }
        
        if (!result.m_output.empty()) {
            logEntry << "Output:\n" << result.m_output << "\n";
        }
        
        logEntry << "=================================================\n";
        
        // Write to log file if FileSystem is available
        if (!FileUtils::GetLogPath().empty()) {
            // Use direct path construction instead of private CombinePaths method
            std::string logPath = FileUtils::GetLogPath() + 
                                  "/execution_" + std::to_string(time(nullptr)) + ".log";
            
            FileUtils::WriteFile(logPath, logEntry.str());
        }
        
        // Output to console
        std::cout << logEntry.str() << std::endl;
    }
    
    // Generate execution environment with variables and helper functions
    std::string ExecutionEngine::GenerateExecutionEnvironment(const ExecutionContext& context) {
        std::stringstream env;
        
        // Add environment setup code
        env << "-- Environment setup for Executor\n";
        
        // Add game information
        env << "local _gameName = \"" << context.m_gameName << "\"\n";
        env << "local _placeId = \"" << context.m_placeId << "\"\n";
        
        // Add custom environment variables
        for (const auto& pair : context.m_environment) {
            env << "local " << pair.first << " = \"" << pair.second << "\"\n";
        }
        
        // Add helper functions for bypass
        env << "local function _getGameName() return _gameName end\n";
        env << "local function _getPlaceId() return _placeId end\n";
        
        // Wrap the script in a protected call for error handling
        env << "local function _logError(err)\n";
        env << "    print(\"Execution error: \" .. tostring(err))\n";
        env << "end\n\n";
        
        return env.str();
    }
    
    // Get available bypass methods
    std::vector<std::string> ExecutionEngine::GetAvailableBypassMethods() const {
        std::vector<std::string> methods;
        
        // Common methods available on all devices
        methods.push_back("BasicBypass");
        methods.push_back("ScriptObfuscation");
        
        // Methods available only on jailbroken devices
        if (m_defaultContext.m_isJailbroken) {
            methods.push_back("MemoryPatching");
            methods.push_back("FunctionHooking");
            methods.push_back("KernelBypass");
        }
        
        return methods;
    }
    
    // Check if a specific bypass method is available
    bool ExecutionEngine::IsMethodAvailable(const std::string& methodName) const {
        // Get all available methods
        std::vector<std::string> methods = GetAvailableBypassMethods();
        
        // Check if the specified method is in the list
        return std::find(methods.begin(), methods.end(), methodName) != methods.end();
    }
}
