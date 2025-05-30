// init.hpp - Central initialization and configuration system
// Copyright (c) 2025, All rights reserved.
#pragma once

#include <string>
#include <memory>
#include <chrono>
#include <iostream>
#include <stdexcept>
#include <functional>

// Include all major subsystems
#include "logging.hpp"
#include "error_handling.hpp"
#include "performance.hpp"
#include "security/anti_tamper.hpp"
#include "filesystem_utils.h"
#include "ios/ExecutionEngine.h"
#include "ios/JailbreakBypass.h"
#include "ios/UIController.h"
#include "ios/PatternScanner.h"
#include "anti_detection/obfuscator.hpp"

namespace RobloxExecutor {

// System initialization options
struct InitOptions {
    // General options
    bool enableLogging = true;
    bool enableErrorReporting = true;
    bool enablePerformanceMonitoring = true;
    bool enableSecurity = true;
    bool enableJailbreakBypass = true;
    bool enableUI = true;
    
    // Logging options
    std::string logDir = "";  // Empty means default location
    Logging::LogLevel minLogLevel = Logging::LogLevel::INFO;
    
    // Error handling options
    bool enableCrashReporting = true;
    std::string crashReportDir = "";  // Empty means default location
    
    // Performance options
    bool enableAutoPerformanceLogging = true;
    uint64_t performanceThresholdMs = 100;
    
    // Security options
    bool startSecurityMonitoring = true;
    bool bypassJailbreakDetection = true;
    
    // UI options
    bool showFloatingButton = true;
    
    // Execution options
    bool enableScriptCaching = true;
    int defaultObfuscationLevel = 3;
    
    // Custom initialization callbacks
    std::function<void()> preInitCallback = nullptr;
    std::function<void()> postInitCallback = nullptr;
    
    // Custom validation function for app-specific checks
    std::function<bool()> customValidationCallback = nullptr;
};

// System status structure
struct SystemStatus {
    bool loggingInitialized = false;
    bool errorHandlingInitialized = false;
    bool performanceInitialized = false;
    bool securityInitialized = false;
    bool jailbreakBypassInitialized = false;
    bool uiInitialized = false;
    bool executionEngineInitialized = false;
    bool allSystemsInitialized = false;
    
    std::string GetStatusString() const {
        std::stringstream ss;
        ss << "System Status:\n";
        ss << "  Logging: " << (loggingInitialized ? "OK" : "FAILED") << "\n";
        ss << "  Error Handling: " << (errorHandlingInitialized ? "OK" : "FAILED") << "\n";
        ss << "  Performance Monitoring: " << (performanceInitialized ? "OK" : "FAILED") << "\n";
        ss << "  Security: " << (securityInitialized ? "OK" : "FAILED") << "\n";
        ss << "  Jailbreak Bypass: " << (jailbreakBypassInitialized ? "OK" : "FAILED") << "\n";
        ss << "  UI: " << (uiInitialized ? "OK" : "FAILED") << "\n";
        ss << "  Execution Engine: " << (executionEngineInitialized ? "OK" : "FAILED") << "\n";
        ss << "  Overall: " << (allSystemsInitialized ? "OK" : "FAILED") << "\n";
        return ss.str();
    }
};

// Global system state
class SystemState {
private:
    static InitOptions s_options;
    static SystemStatus s_status;
    static std::shared_ptr<iOS::ExecutionEngine> s_executionEngine;
    static std::shared_ptr<iOS::ScriptManager> s_scriptManager;
    static std::unique_ptr<iOS::UIController> s_uiController;
    
public:
    // Get system status
    static const SystemStatus& GetStatus() {
        return s_status;
    }
    
    // Get execution engine
    static std::shared_ptr<iOS::ExecutionEngine> GetExecutionEngine() {
        return s_executionEngine;
    }
    
    // Get script manager
    static std::shared_ptr<iOS::ScriptManager> GetScriptManager() {
        return s_scriptManager;
    }
    
    // Get UI controller
    static iOS::UIController* GetUIController() {
        return s_uiController.get();
    }
    
    // Initialize the system with options
    static bool Initialize(const InitOptions& options = InitOptions()) {
        s_options = options;
        s_status = SystemStatus(); // Reset status
        
        try {
            // Call pre-init callback if provided
            if (s_options.preInitCallback) {
                s_options.preInitCallback();
            }
            
            // Initialize in correct dependency order
            
            // 1. Initialize logging first (needed by all other components)
            if (s_options.enableLogging) {
                if (!InitializeLogging()) {
                    std::cerr << "Failed to initialize logging" << std::endl;
                    return false;
                }
            }
            
            // 2. Initialize error handling
            if (s_options.enableErrorReporting) {
                if (!InitializeErrorHandling()) {
                    Logging::LogCritical("System", "Failed to initialize error handling");
                    return false;
                }
            }
            
            // 3. Initialize security (anti-tamper) system
            if (s_options.enableSecurity) {
                if (!InitializeSecurity()) {
                    Logging::LogWarning("System", "Failed to initialize security system");
                    // Continue despite failure - security is important but not critical
                }
            }
            
            // 4. Initialize jailbreak bypass
            if (s_options.enableJailbreakBypass) {
                if (!InitializeJailbreakBypass()) {
                    Logging::LogWarning("System", "Failed to initialize jailbreak bypass");
                    // Continue despite failure - can work without jailbreak bypass
                }
            }
            
            // 5. Initialize performance monitoring
            if (s_options.enablePerformanceMonitoring) {
                if (!InitializePerformanceMonitoring()) {
                    Logging::LogWarning("System", "Failed to initialize performance monitoring");
                    // Continue despite failure - performance monitoring is optional
                }
            }
            
            // 6. Initialize script manager and execution engine
            if (!InitializeExecutionEngine()) {
                Logging::LogCritical("System", "Failed to initialize execution engine");
                return false;
            }
            
            // 7. Initialize UI
            if (s_options.enableUI) {
                if (!InitializeUI()) {
                    Logging::LogWarning("System", "Failed to initialize UI");
                    // Continue despite failure - can work without UI
                }
            }
            
            // 8. Run custom validation if provided
            if (s_options.customValidationCallback) {
                if (!s_options.customValidationCallback()) {
                    Logging::LogCritical("System", "Custom validation failed");
                    return false;
                }
            }
            
            // All systems initialized
            s_status.allSystemsInitialized = true;
            
            // Log initialization success
            Logging::LogInfo("System", "All systems initialized successfully");
            
            // Call post-init callback if provided
            if (s_options.postInitCallback) {
                s_options.postInitCallback();
            }
            
            return true;
        } catch (const std::exception& ex) {
            // Log the error if logging is initialized
            if (s_status.loggingInitialized) {
                Logging::LogCritical("System", "Exception during initialization: " + std::string(ex.what()));
            } else {
                std::cerr << "Exception during initialization: " << ex.what() << std::endl;
            }
            
            return false;
        }
    }
    
    // Clean up and shutdown all systems
    static void Shutdown() {
        // Shutdown in reverse order of initialization
        
        // 1. Shutdown UI
        if (s_uiController) {
            s_uiController.reset();
        }
        
        // 2. Shutdown execution engine and script manager
        s_executionEngine.reset();
        s_scriptManager.reset();
        
        // 3. Stop performance monitoring
        if (s_status.performanceInitialized) {
            Performance::Profiler::StopMonitoring();
            Performance::Profiler::SaveReport();
        }
        
        // 4. Stop security monitoring
        if (s_status.securityInitialized) {
            Security::AntiTamper::StopMonitoring();
        }
        
        // Log shutdown if logging is still available
        if (s_status.loggingInitialized) {
            Logging::LogInfo("System", "System shutdown complete");
        }
        
        // Reset status
        s_status = SystemStatus();
    }
    
private:
    // Initialize logging system
    static bool InitializeLogging() {
        try {
            // Initialize the logger
            if (!s_options.logDir.empty()) {
                FileUtils::EnsureDirectoryExists(s_options.logDir);
                Logging::Logger::InitializeWithFileLogging(s_options.logDir);
            } else {
                Logging::Logger::InitializeWithFileLogging();
            }
            
            // Set minimum log level
            Logging::Logger::GetInstance().SetMinLevel(s_options.minLogLevel);
            
            // Log initialization success
            Logging::LogInfo("System", "Logging system initialized");
            
            s_status.loggingInitialized = true;
            return true;
        } catch (const std::exception& ex) {
            std::cerr << "Failed to initialize logging: " << ex.what() << std::endl;
            return false;
        }
    }
    
    // Initialize error handling system
    static bool InitializeErrorHandling() {
        try {
            // Initialize error handling
            ErrorHandling::InitializeErrorHandling();
            
            // Configure crash reporting
            ErrorHandling::ErrorManager::GetInstance().EnableCrashReporting(s_options.enableCrashReporting);
            
            if (!s_options.crashReportDir.empty()) {
                ErrorHandling::ErrorManager::GetInstance().SetCrashReportPath(s_options.crashReportDir);
            }
            
            // Log initialization success
            Logging::LogInfo("System", "Error handling system initialized");
            
            s_status.errorHandlingInitialized = true;
            return true;
        } catch (const std::exception& ex) {
            Logging::LogCritical("System", "Failed to initialize error handling: " + std::string(ex.what()));
            return false;
        }
    }
    
    // Initialize security system
    static bool InitializeSecurity() {
        try {
            // Initialize security
            bool result = Security::InitializeSecurity(s_options.startSecurityMonitoring);
            
            if (result) {
                Logging::LogInfo("System", "Security system initialized");
                s_status.securityInitialized = true;
            } else {
                Logging::LogWarning("System", "Security system initialization failed");
            }
            
            return result;
        } catch (const std::exception& ex) {
            Logging::LogError("System", "Exception initializing security: " + std::string(ex.what()));
            return false;
        }
    }
    
    // Initialize jailbreak bypass
    static bool InitializeJailbreakBypass() {
        try {
            // Initialize jailbreak bypass
            bool result = iOS::JailbreakBypass::Initialize();
            
            if (result) {
                // Apply app-specific bypasses (for Roblox)
                iOS::JailbreakBypass::BypassSpecificApp("com.roblox.robloxmobile");
                
                Logging::LogInfo("System", "Jailbreak bypass initialized");
                s_status.jailbreakBypassInitialized = true;
            } else {
                Logging::LogWarning("System", "Jailbreak bypass initialization failed");
            }
            
            return result;
        } catch (const std::exception& ex) {
            Logging::LogError("System", "Exception initializing jailbreak bypass: " + std::string(ex.what()));
            return false;
        }
    }
    
    // Initialize performance monitoring
    static bool InitializePerformanceMonitoring() {
        try {
            // Initialize performance monitoring
            Performance::InitializePerformanceMonitoring(
                true,
                s_options.enableAutoPerformanceLogging,
                s_options.performanceThresholdMs
            );
            
            Logging::LogInfo("System", "Performance monitoring initialized");
            s_status.performanceInitialized = true;
            return true;
        } catch (const std::exception& ex) {
            Logging::LogError("System", "Exception initializing performance monitoring: " + std::string(ex.what()));
            return false;
        }
    }
    
    // Initialize execution engine and script manager
    static bool InitializeExecutionEngine() {
        try {
            // Create script manager
            s_scriptManager = std::make_shared<iOS::ScriptManager>(
                s_options.enableScriptCaching,
                10, // Max script cache size
                "RobloxScripts"
            );
            
            // Initialize script manager
            if (!s_scriptManager->Initialize()) {
                Logging::LogCritical("System", "Failed to initialize script manager");
                return false;
            }
            
            // Create execution engine
            s_executionEngine = std::make_shared<iOS::ExecutionEngine>(s_scriptManager);
            
            // Initialize execution engine
            if (!s_executionEngine->Initialize()) {
                Logging::LogCritical("System", "Failed to initialize execution engine");
                return false;
            }
            
            // Configure default execution context
            iOS::ExecutionEngine::ExecutionContext context;
            context.m_isJailbroken = s_status.jailbreakBypassInitialized;
            context.m_enableObfuscation = true;
            context.m_enableAntiDetection = true;
            context.m_obfuscationLevel = s_options.defaultObfuscationLevel;
            
            s_executionEngine->SetDefaultContext(context);
            
            Logging::LogInfo("System", "Execution engine initialized");
            s_status.executionEngineInitialized = true;
            return true;
        } catch (const std::exception& ex) {
            Logging::LogCritical("System", "Exception initializing execution engine: " + std::string(ex.what()));
            return false;
        }
    }
    
    // Initialize UI system
    static bool InitializeUI() {
        try {
            // Create UI controller
            s_uiController = std::make_unique<iOS::UIController>();
            
            // Initialize UI
            if (!s_uiController->Initialize()) {
                Logging::LogWarning("System", "Failed to initialize UI controller");
                return false;
            }
            
            // Setup callbacks
            s_uiController->SetExecuteCallback([](const std::string& script) -> bool {
                // Get execution engine from system state
                auto engine = GetExecutionEngine();
                if (!engine) {
                    Logging::LogError("UI", "Execute failed: Execution engine not initialized");
                    return false;
                }
                
                // Execute script
                auto result = engine->Execute(script);
                return result.m_success;
            });
            
            s_uiController->SetSaveScriptCallback([](const iOS::UIController::ScriptInfo& info) -> bool {
                // Get script manager from system state
                auto manager = GetScriptManager();
                if (!manager) {
                    Logging::LogError("UI", "Save failed: Script manager not initialized");
                    return false;
                }
                
                // Save script
                return manager->SaveScript(info.m_name, info.m_content);
            });
            
            s_uiController->SetLoadScriptsCallback([]() -> std::vector<iOS::UIController::ScriptInfo> {
                // Get script manager from system state
                auto manager = GetScriptManager();
                if (!manager) {
                    Logging::LogError("UI", "Load failed: Script manager not initialized");
                    return {};
                }
                
                // Get saved scripts
                auto scripts = manager->GetSavedScripts();
                
                // Convert to UI controller script info
                std::vector<iOS::UIController::ScriptInfo> result;
                for (const auto& script : scripts) {
                    iOS::UIController::ScriptInfo info;
                    info.m_name = script.m_name;
                    info.m_content = script.m_content;
                    info.m_timestamp = script.m_timestamp;
                    result.push_back(info);
                }
                
                return result;
            });
            
            // Configure UI
            s_uiController->SetButtonVisible(s_options.showFloatingButton);
            
            Logging::LogInfo("System", "UI system initialized");
            s_status.uiInitialized = true;
            return true;
        } catch (const std::exception& ex) {
            Logging::LogWarning("System", "Exception initializing UI: " + std::string(ex.what()));
            return false;
        }
    }
};

// Initialize static members
InitOptions SystemState::s_options;
SystemStatus SystemState::s_status;
std::shared_ptr<iOS::ExecutionEngine> SystemState::s_executionEngine;
std::shared_ptr<iOS::ScriptManager> SystemState::s_scriptManager;
std::unique_ptr<iOS::UIController> SystemState::s_uiController;

// Convenience function for global initialization
inline bool Initialize(const InitOptions& options = InitOptions()) {
    return SystemState::Initialize(options);
}

// Convenience function for global shutdown
inline void Shutdown() {
    SystemState::Shutdown();
}

// Execute a script with custom context
inline iOS::ExecutionEngine::ExecutionResult ExecuteScript(
    const std::string& script,
    const iOS::ExecutionEngine::ExecutionContext& context = {}) {
    auto engine = SystemState::GetExecutionEngine();
    if (!engine) {
        Logging::LogError("Executor", "Execute failed: Execution engine not initialized");
        return { false, "Execution engine not initialized", 0, "" };
    }
    
    return engine->Execute(script, context);
}

// Execute a script with default context
inline iOS::ExecutionEngine::ExecutionResult ExecuteScript(const std::string& script) {
    auto engine = SystemState::GetExecutionEngine();
    if (!engine) {
        Logging::LogError("Executor", "Execute failed: Execution engine not initialized");
        return { false, "Execution engine not initialized", 0, "" };
    }
    
    return engine->Execute(script);
}

// Show UI
inline void ShowUI() {
    auto ui = SystemState::GetUIController();
    if (ui) {
        ui->Show();
    }
}

// Hide UI
inline void HideUI() {
    auto ui = SystemState::GetUIController();
    if (ui) {
        ui->Hide();
    }
}

// Toggle UI
inline bool ToggleUI() {
    auto ui = SystemState::GetUIController();
    if (ui) {
        return ui->Toggle();
    }
    return false;
}

} // namespace RobloxExecutor
