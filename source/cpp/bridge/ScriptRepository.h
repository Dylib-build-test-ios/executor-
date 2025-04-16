/**
 * @file ScriptRepository.h
 * @brief Script repository integration for accessing external script libraries
 * 
 * This system allows the executor to fetch, verify, and manage scripts from 
 * popular script repositories, providing users with easy access to a wide
 * range of pre-made scripts.
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
#include <optional>

namespace ScriptRepo {

/**
 * @brief Script metadata structure
 */
struct ScriptMetadata {
    std::string id;                // Unique identifier
    std::string name;              // Script name
    std::string description;       // Description
    std::string author;            // Author name
    std::string version;           // Version string
    std::vector<std::string> tags; // Categories and tags
    std::chrono::system_clock::time_point created;  // Creation date
    std::chrono::system_clock::time_point updated;  // Last update date
    std::string repositorySource;  // Source repository
    std::string downloadUrl;       // Direct download URL
    size_t downloads;              // Download count
    float rating;                  // User rating (0-5)
    bool verified;                 // Whether the script is verified safe
    bool premium;                  // Whether this is a premium script
    std::string thumbnailUrl;      // URL to script thumbnail
    std::string documentationUrl;  // URL to documentation
    
    // Script requirements and compatibility
    std::string minExecutorVersion;// Minimum executor version required
    std::vector<std::string> gameCompatibility; // Compatible games
    std::vector<std::string> dependencies;      // Script dependencies
};

/**
 * @brief Repository source configuration
 */
struct RepositoryConfig {
    std::string name;              // Repository name
    std::string url;               // Base URL
    std::string apiKey;            // API key (if required)
    bool enabled;                  // Whether this repository is enabled
    int priority;                  // Priority for search results (higher = first)
    std::string apiVersion;        // API version to use
    
    // API endpoints
    std::string searchEndpoint;    // Search endpoint
    std::string downloadEndpoint;  // Download endpoint
    std::string metadataEndpoint;  // Metadata endpoint
    
    // Authentication
    bool requiresAuth;             // Whether authentication is required
    std::string authType;          // Authentication type (token, basic, oauth)
    std::map<std::string, std::string> authHeaders; // Auth headers
};

/**
 * @brief Search result from repositories
 */
struct SearchResult {
    std::vector<ScriptMetadata> scripts;     // Found scripts
    size_t totalResults;                     // Total result count
    std::unordered_map<std::string, int> resultsByRepo; // Results by repository
    bool hasMore;                            // Whether more results are available
    int page;                                // Current page number
    int pageSize;                            // Results per page
};

/**
 * @brief Script content with metadata
 */
struct ScriptContent {
    ScriptMetadata metadata;                 // Script metadata
    std::string content;                     // Actual script content
    std::chrono::system_clock::time_point fetchedTime; // When the script was fetched
    bool cached;                             // Whether this was from cache
};

/**
 * @brief Download status for tracking progress
 */
struct DownloadStatus {
    std::string scriptId;                    // Script being downloaded
    float progress;                          // Progress (0.0-1.0)
    bool completed;                          // Whether download is complete
    bool error;                              // Whether an error occurred
    std::string errorMessage;                // Error message if applicable
};

/**
 * @brief Verification result for script safety
 */
struct VerificationResult {
    bool safe;                               // Whether script is considered safe
    std::vector<std::string> warnings;       // Warnings about potentially unsafe code
    std::vector<std::string> detectedActions; // Actions the script would perform
    int riskLevel;                           // Risk level (0-10)
};

/**
 * @class ScriptRepository
 * @brief Main script repository integration system
 */
class ScriptRepository {
public:
    // Callback types
    using FetchCallback = std::function<void(const ScriptContent&)>;
    using SearchCallback = std::function<void(const SearchResult&)>;
    using ProgressCallback = std::function<void(const DownloadStatus&)>;
    
    /**
     * @brief Get the singleton instance
     * @return Reference to the singleton instance
     */
    static ScriptRepository& GetInstance();
    
    /**
     * @brief Initialize the script repository system
     * @param configPath Path to repository configuration file
     * @return True if initialization succeeded
     */
    bool Initialize(const std::string& configPath = "");
    
    /**
     * @brief Add a repository configuration
     * @param config Repository configuration to add
     * @return True if added successfully
     */
    bool AddRepository(const RepositoryConfig& config);
    
    /**
     * @brief Remove a repository by name
     * @param name Name of the repository to remove
     * @return True if removed successfully
     */
    bool RemoveRepository(const std::string& name);
    
    /**
     * @brief Enable or disable a repository
     * @param name Repository name
     * @param enabled Whether to enable or disable
     * @return True if successful
     */
    bool SetRepositoryEnabled(const std::string& name, bool enabled);
    
    /**
     * @brief Get list of configured repositories
     * @return Vector of repository configurations
     */
    std::vector<RepositoryConfig> GetRepositories() const;
    
    /**
     * @brief Search for scripts across all enabled repositories
     * @param query Search query string
     * @param callback Callback for search results
     * @param tags Optional tags to filter by
     * @param page Page number for pagination
     * @param pageSize Results per page
     * @param repository Optional specific repository to search
     */
    void SearchScripts(const std::string& query, 
                      SearchCallback callback,
                      const std::vector<std::string>& tags = {},
                      int page = 1, 
                      int pageSize = 20,
                      const std::string& repository = "");
    
    /**
     * @brief Fetch script content by ID
     * @param scriptId Script ID to fetch
     * @param callback Callback for script content
     * @param forceRefresh Whether to bypass cache
     */
    void FetchScript(const std::string& scriptId, 
                    FetchCallback callback,
                    bool forceRefresh = false);
    
    /**
     * @brief Get script metadata without content
     * @param scriptId Script ID
     * @return Optional script metadata
     */
    std::optional<ScriptMetadata> GetScriptMetadata(const std::string& scriptId);
    
    /**
     * @brief Get cached scripts
     * @return Vector of script metadata for cached scripts
     */
    std::vector<ScriptMetadata> GetCachedScripts();
    
    /**
     * @brief Clear the script cache
     * @param olderThanDays Only clear scripts older than this many days (0 = all)
     * @return Number of scripts cleared
     */
    int ClearCache(int olderThanDays = 0);
    
    /**
     * @brief Verify a script for safety
     * @param scriptContent Script content to verify
     * @return Verification result
     */
    VerificationResult VerifyScript(const std::string& scriptContent);
    
    /**
     * @brief Download script to local storage
     * @param scriptId Script ID to download
     * @param destinationPath Path to save the script
     * @param progressCallback Callback for download progress
     * @return True if download completed successfully
     */
    bool DownloadScript(const std::string& scriptId, 
                       const std::string& destinationPath,
                       ProgressCallback progressCallback = nullptr);
    
    /**
     * @brief Get popular scripts across repositories
     * @param count Number of scripts to retrieve
     * @param callback Callback for results
     */
    void GetPopularScripts(int count, SearchCallback callback);
    
    /**
     * @brief Get recently updated scripts
     * @param count Number of scripts to retrieve
     * @param callback Callback for results
     */
    void GetRecentScripts(int count, SearchCallback callback);
    
    /**
     * @brief Submit user rating for a script
     * @param scriptId Script ID
     * @param rating Rating (0-5)
     * @return True if rating was submitted
     */
    bool SubmitRating(const std::string& scriptId, float rating);
    
    /**
     * @brief Get updates for cached scripts
     * @param callback Callback for scripts with updates available
     */
    void CheckForUpdates(SearchCallback callback);
    
    /**
     * @brief Configure network proxy for repository connections
     * @param proxyUrl Proxy URL (empty to disable)
     * @param username Optional proxy username
     * @param password Optional proxy password
     * @return True if proxy configured successfully
     */
    bool ConfigureProxy(const std::string& proxyUrl, 
                      const std::string& username = "",
                      const std::string& password = "");
    
    /**
     * @brief Set authentication for a repository
     * @param repositoryName Repository name
     * @param apiKey API key
     * @return True if authentication was set
     */
    bool SetAuthentication(const std::string& repositoryName, const std::string& apiKey);
    
    /**
     * @brief Export user scripts to a repository
     * @param scriptPath Local script path
     * @param metadata Metadata for the script
     * @param repositoryName Target repository
     * @param privateScript Whether to mark as private
     * @return True if script was exported successfully
     */
    bool ExportScript(const std::string& scriptPath, 
                    const ScriptMetadata& metadata,
                    const std::string& repositoryName,
                    bool privateScript = false);

private:
    // Private constructor for singleton
    ScriptRepository();
    ~ScriptRepository();
    
    // Delete copy/move constructors and assignment operators
    ScriptRepository(const ScriptRepository&) = delete;
    ScriptRepository& operator=(const ScriptRepository&) = delete;
    ScriptRepository(ScriptRepository&&) = delete;
    ScriptRepository& operator=(ScriptRepository&&) = delete;
    
    // Helper methods
    void LoadRepositoriesFromConfig(const std::string& configPath);
    void SaveRepositoriesToConfig(const std::string& configPath);
    bool FetchFromRepository(const std::string& scriptId, 
                           const std::string& repositoryName,
                           FetchCallback callback);
    void CacheScript(const ScriptContent& script);
    std::optional<ScriptContent> GetFromCache(const std::string& scriptId);
    VerificationResult PerformScriptSafetyCheck(const std::string& content);
    std::string SendHttpRequest(const std::string& url, 
                             const std::string& method,
                             const std::map<std::string, std::string>& headers,
                             const std::string& body);
    
    // Member variables
    std::map<std::string, RepositoryConfig> m_repositories;
    std::map<std::string, ScriptContent> m_scriptCache;
    std::map<std::string, ScriptMetadata> m_metadataCache;
    std::string m_cachePath;
    std::string m_configPath;
    std::string m_proxyUrl;
    std::string m_proxyUsername;
    std::string m_proxyPassword;
    std::chrono::seconds m_cacheExpiry;
    int m_maxCacheEntries;
    bool m_initialized;
    
    // Thread safety
    mutable std::mutex m_repositoryMutex;
    mutable std::mutex m_cacheMutex;
    
    // Singleton instance
    static std::unique_ptr<ScriptRepository> s_instance;
    static std::once_flag s_onceFlag;
};

/**
 * @brief Helper class for repository script browsing UI
 */
class ScriptBrowser {
public:
    /**
     * @brief Initialize the browser
     * @param repositoryName Optional repository to limit browsing to
     */
    explicit ScriptBrowser(const std::string& repositoryName = "");
    
    /**
     * @brief Create and show the browser UI
     * @return Selected script ID if a script was selected
     */
    std::optional<std::string> ShowBrowser();
    
    /**
     * @brief Set initial search query
     * @param query Search query to start with
     */
    void SetInitialQuery(const std::string& query);
    
    /**
     * @brief Set tag filter
     * @param tags Tags to filter by
     */
    void SetTagFilter(const std::vector<std::string>& tags);
    
    /**
     * @brief Set script selection callback
     * @param callback Function to call when a script is selected
     */
    void SetSelectionCallback(std::function<void(const ScriptMetadata&)> callback);
    
private:
    std::string m_repositoryName;
    std::string m_initialQuery;
    std::vector<std::string> m_tagFilter;
    std::function<void(const ScriptMetadata&)> m_selectionCallback;
    SearchResult m_currentResults;
    int m_currentPage;
    
    // UI helper methods
    void PerformSearch();
    void RenderScriptList();
    void RenderScriptDetails(const ScriptMetadata& script);
    void HandlePagination();
};

} // namespace ScriptRepo
