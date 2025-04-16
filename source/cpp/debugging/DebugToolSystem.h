/**
 * @file DebugToolSystem.h
 * @brief Advanced debugging tools for script development
 * 
 * This system provides comprehensive debugging tools for script developers,
 * including performance profiling, memory analysis, error tracing, and
 * visualization of script execution.
 */

#pragma once

#include <string>
#include <vector>
#include <map>
#include <unordered_map>
#include <memory>
#include <functional>
#include <chrono>
#include <mutex>
#include <atomic>
#include <stack>

namespace Debugging {

/**
 * @brief Performance profiling result
 */
struct ProfileResult {
    std::string name;           // Name of the profiled section
    double executionTimeMs;     // Execution time in milliseconds
    double percentOfParent;     // Percentage of parent section time
    int callCount;              // Number of times this section was called
    std::vector<ProfileResult> children; // Nested profiling sections
};

/**
 * @brief Memory allocation event for debugging
 */
struct MemoryEvent {
    enum class Type {
        Allocation,
        Deallocation,
        Reallocation
    };
    
    Type type;                  // Event type
    void* address;              // Memory address
    size_t size;                // Size in bytes
    std::string description;    // Optional description
    std::chrono::steady_clock::time_point timestamp; // When the event occurred
    std::string stackTrace;     // Stack trace at time of event
};

/**
 * @brief Script error details
 */
struct ErrorDetails {
    std::string message;         // Error message
    std::string scriptName;      // Script where error occurred
    int lineNumber;              // Line number
    int columnNumber;            // Column number
    std::string stackTrace;      // Full stack trace
    std::string sourceContext;   // Source code surrounding the error
    std::chrono::steady_clock::time_point timestamp; // When the error occurred
    std::string category;        // Error category (syntax, runtime, etc.)
    bool isFatal;                // Whether the error is fatal
    std::string suggestedFix;    // Potential fix suggestion
};

/**
 * @brief Network request debug information
 */
struct NetworkRequest {
    std::string url;             // Request URL
    std::string method;          // HTTP method
    std::map<std::string, std::string> headers; // Headers
    std::string body;            // Request body
    int responseCode;            // HTTP response code
    std::string responseBody;    // Response body
    double latencyMs;            // Request latency in milliseconds
    std::chrono::steady_clock::time_point timestamp; // When the request was made
    bool successful;             // Whether the request succeeded
    std::string errorMessage;    // Error message if failed
};

/**
 * @brief Visualization options for script execution
 */
struct VisualizationOptions {
    bool showMemoryAccess;       // Visualize memory access
    bool showCallGraph;          // Visualize function call graph
    bool showDataFlow;           // Visualize data flow
    bool showLoops;              // Highlight loops and iterations
    bool showConditionals;       // Highlight conditional branches
    bool animate;                // Animate execution steps
    double animationSpeed;       // Animation speed (1.0 = normal)
    bool colorizeByType;         // Colorize elements by data type
    bool showPerformanceHeatmap; // Show performance hotspots
};

/**
 * @class DebugToolSystem
 * @brief Main debugging system implementation
 */
class DebugToolSystem {
public:
    using ErrorCallback = std::function<void(const ErrorDetails&)>;
    using MemoryEventCallback = std::function<void(const MemoryEvent&)>;
    
    /**
     * @brief Get the singleton instance
     * @return Reference to the singleton instance
     */
    static DebugToolSystem& GetInstance();
    
    /**
     * @brief Initialize the debug tool system
     * @param enabled Whether debugging is enabled
     * @return True if initialization succeeded
     */
    bool Initialize(bool enabled = true);
    
    /**
     * @brief Set whether debugging is enabled
     * @param enabled Enable or disable debugging
     */
    void SetEnabled(bool enabled);
    
    /**
     * @brief Check if debugging is enabled
     * @return True if debugging is enabled
     */
    bool IsEnabled() const;
    
    /**
     * @brief Begin a profiling section
     * @param name Name of the section to profile
     */
    void BeginProfile(const std::string& name);
    
    /**
     * @brief End the current profiling section
     */
    void EndProfile();
    
    /**
     * @brief Get profiling results
     * @return Root profiling result with all child sections
     */
    ProfileResult GetProfileResults() const;
    
    /**
     * @brief Clear all profiling data
     */
    void ClearProfileData();
    
    /**
     * @brief Log a memory allocation event
     * @param type Event type (allocation, deallocation, etc.)
     * @param address Memory address
     * @param size Size in bytes
     * @param description Optional description
     */
    void LogMemoryEvent(MemoryEvent::Type type, void* address, size_t size, const std::string& description = "");
    
    /**
     * @brief Get memory events
     * @return Vector of all memory events
     */
    std::vector<MemoryEvent> GetMemoryEvents() const;
    
    /**
     * @brief Register an error callback
     * @param callback Function to call when errors occur
     * @return ID of the registered callback
     */
    int RegisterErrorCallback(const ErrorCallback& callback);
    
    /**
     * @brief Unregister an error callback
     * @param id ID of the callback to unregister
     * @return True if callback was unregistered
     */
    bool UnregisterErrorCallback(int id);
    
    /**
     * @brief Register a memory event callback
     * @param callback Function to call for memory events
     * @return ID of the registered callback
     */
    int RegisterMemoryEventCallback(const MemoryEventCallback& callback);
    
    /**
     * @brief Unregister a memory event callback
     * @param id ID of the callback to unregister
     * @return True if callback was unregistered
     */
    bool UnregisterMemoryEventCallback(int id);
    
    /**
     * @brief Report an error
     * @param details Error details
     */
    void ReportError(const ErrorDetails& details);
    
    /**
     * @brief Log a network request
     * @param request Network request details
     */
    void LogNetworkRequest(const NetworkRequest& request);
    
    /**
     * @brief Get network request logs
     * @return Vector of network requests
     */
    std::vector<NetworkRequest> GetNetworkRequests() const;
    
    /**
     * @brief Set visualization options
     * @param options Visualization options
     */
    void SetVisualizationOptions(const VisualizationOptions& options);
    
    /**
     * @brief Get current visualization options
     * @return Current visualization options
     */
    VisualizationOptions GetVisualizationOptions() const;
    
    /**
     * @brief Create a visualization of script execution
     * @param script Script to visualize
     * @return HTML visualization content
     */
    std::string CreateVisualization(const std::string& script);
    
    /**
     * @brief Find potential performance bottlenecks
     * @return Map of bottlenecks with suggested improvements
     */
    std::map<std::string, std::string> AnalyzeBottlenecks();
    
    /**
     * @brief Generate a performance report
     * @return HTML performance report
     */
    std::string GeneratePerformanceReport();
    
    /**
     * @brief Generate a memory usage report
     * @return HTML memory usage report
     */
    std::string GenerateMemoryReport();
    
    /**
     * @brief Create a call graph visualization
     * @return SVG call graph visualization
     */
    std::string CreateCallGraph();
    
    /**
     * @brief Get the last error
     * @return Details of the last error
     */
    ErrorDetails GetLastError() const;
    
    /**
     * @brief Export debug data to a file
     * @param filepath Path to export data to
     * @return True if export succeeded
     */
    bool ExportDebugData(const std::string& filepath);
    
    /**
     * @brief Import debug data from a file
     * @param filepath Path to import data from
     * @return True if import succeeded
     */
    bool ImportDebugData(const std::string& filepath);
    
    /**
     * @brief Create interactive debugger UI
     * @return True if UI was created successfully
     */
    bool CreateDebuggerUI();
    
    /**
     * @brief Set breakpoint in script
     * @param scriptName Script name
     * @param lineNumber Line number for breakpoint
     * @param condition Optional condition for conditional breakpoint
     * @return Breakpoint ID
     */
    int SetBreakpoint(const std::string& scriptName, int lineNumber, const std::string& condition = "");
    
    /**
     * @brief Remove a breakpoint
     * @param id Breakpoint ID
     * @return True if breakpoint was removed
     */
    bool RemoveBreakpoint(int id);
    
    /**
     * @brief Enable or disable all breakpoints
     * @param enabled Whether breakpoints should be enabled
     */
    void EnableBreakpoints(bool enabled);
    
    /**
     * @brief Continue execution after a breakpoint
     */
    void Continue();
    
    /**
     * @brief Step over to next line
     */
    void StepOver();
    
    /**
     * @brief Step into function
     */
    void StepInto();
    
    /**
     * @brief Step out of current function
     */
    void StepOut();

private:
    // Private constructor for singleton
    DebugToolSystem();
    ~DebugToolSystem();
    
    // Delete copy/move constructors and assignment operators
    DebugToolSystem(const DebugToolSystem&) = delete;
    DebugToolSystem& operator=(const DebugToolSystem&) = delete;
    DebugToolSystem(DebugToolSystem&&) = delete;
    DebugToolSystem& operator=(DebugToolSystem&&) = delete;
    
    // Helper methods
    std::string CaptureStackTrace();
    void UpdateProfileTree();
    std::string FormatMemorySize(size_t bytes) const;
    std::string GenerateHTMLHeader() const;
    std::string GenerateHTMLFooter() const;
    
    // Profiling section stack
    struct ProfileSection {
        std::string name;
        std::chrono::steady_clock::time_point startTime;
        std::chrono::steady_clock::time_point endTime;
        std::vector<ProfileSection> children;
        ProfileSection* parent;
        int callCount;
    };
    
    // Breakpoint information
    struct Breakpoint {
        int id;
        std::string scriptName;
        int lineNumber;
        std::string condition;
        bool enabled;
    };
    
    // Member variables
    bool m_enabled;
    std::atomic<int> m_nextCallbackId;
    std::atomic<int> m_nextBreakpointId;
    ProfileSection m_rootProfileSection;
    ProfileSection* m_currentProfileSection;
    std::vector<MemoryEvent> m_memoryEvents;
    std::vector<NetworkRequest> m_networkRequests;
    std::unordered_map<int, ErrorCallback> m_errorCallbacks;
    std::unordered_map<int, MemoryEventCallback> m_memoryEventCallbacks;
    ErrorDetails m_lastError;
    VisualizationOptions m_visualizationOptions;
    std::vector<Breakpoint> m_breakpoints;
    bool m_breakpointsEnabled;
    
    // Thread safety
    mutable std::mutex m_profileMutex;
    mutable std::mutex m_memoryMutex;
    mutable std::mutex m_networkMutex;
    mutable std::mutex m_errorMutex;
    mutable std::mutex m_callbackMutex;
    mutable std::mutex m_breakpointMutex;
    
    // Singleton instance
    static std::unique_ptr<DebugToolSystem> s_instance;
    static std::once_flag s_onceFlag;
};

/**
 * @brief Auto-profiler for scope-based profiling
 */
class ScopedProfiler {
public:
    /**
     * @brief Constructor starts profiling a named section
     * @param name Section name
     */
    explicit ScopedProfiler(const std::string& name);
    
    /**
     * @brief Destructor ends profiling
     */
    ~ScopedProfiler();
    
private:
    bool m_enabled;
};

/**
 * @brief Helper for visualizing script execution
 */
class ScriptVisualizer {
public:
    /**
     * @brief Initialize the visualizer
     * @param script Script to visualize
     * @param options Visualization options
     */
    ScriptVisualizer(const std::string& script, const VisualizationOptions& options);
    
    /**
     * @brief Generate visualization
     * @return HTML visualization content
     */
    std::string Generate();
    
    /**
     * @brief Add a data point to the visualization
     * @param type Data point type
     * @param data Data point information
     */
    void AddDataPoint(const std::string& type, const std::string& data);
    
    /**
     * @brief Clear all data points
     */
    void Clear();
    
private:
    std::string m_script;
    VisualizationOptions m_options;
    std::vector<std::pair<std::string, std::string>> m_dataPoints;
    std::mutex m_mutex;
};

} // namespace Debugging

// Profiling macro for easy use
#define PROFILE_SCOPE(name) Debugging::ScopedProfiler profiler##__LINE__(name)
#define PROFILE_FUNCTION() PROFILE_SCOPE(__FUNCTION__)

// Error reporting macro
#define REPORT_ERROR(message, line, col) \
    Debugging::DebugToolSystem::GetInstance().ReportError({ \
        message, __FILE__, line, col, "", "", std::chrono::steady_clock::now(), \
        "runtime", false, "" \
    })
