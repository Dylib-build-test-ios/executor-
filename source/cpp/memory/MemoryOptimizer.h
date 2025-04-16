/**
 * @file MemoryOptimizer.h
 * @brief Memory optimization system for iOS performance
 * 
 * This system manages memory usage efficiently to prevent crashes and 
 * optimize performance on iOS devices with limited resources.
 */

#pragma once

#include <unordered_map>
#include <string>
#include <vector>
#include <memory>
#include <mutex>
#include <functional>
#include <chrono>
#include <atomic>

namespace Memory {

/**
 * @brief Memory usage statistics
 */
struct MemoryStats {
    size_t totalAllocated;     // Total bytes allocated
    size_t peakUsage;          // Peak memory usage in bytes
    size_t currentUsage;       // Current memory usage in bytes
    size_t allocCount;         // Number of allocations
    size_t freeCount;          // Number of deallocations
    size_t cacheSize;          // Size of cached objects in bytes
    size_t poolSize;           // Size of memory pools in bytes
};

/**
 * @brief Memory allocation tracking entry
 */
struct AllocationEntry {
    void* address;             // Memory address
    size_t size;               // Size in bytes
    std::string tag;           // Optional tag for identification
    std::chrono::steady_clock::time_point timestamp; // Allocation time
};

/**
 * @brief Memory usage thresholds
 */
struct MemoryThresholds {
    float warningThreshold;    // Warning threshold (0.0-1.0)
    float criticalThreshold;   // Critical threshold (0.0-1.0)
    size_t maxAllocationSize;  // Maximum single allocation size
    size_t maxTotalUsage;      // Maximum total memory usage
};

/**
 * @brief Memory optimization strategy
 */
enum class OptimizationStrategy {
    Aggressive,    // Aggressive memory cleanup, minimal caching
    Balanced,      // Balanced approach between performance and memory usage
    Performance,   // Focus on performance, more caching
    Custom         // Custom strategy with user-defined parameters
};

/**
 * @brief Memory pool for efficient small object allocation
 */
class MemoryPool {
public:
    /**
     * @brief Initialize a memory pool with specified block size
     * @param blockSize Size of each memory block
     * @param initialBlocks Initial number of blocks to allocate
     */
    MemoryPool(size_t blockSize, size_t initialBlocks = 16);
    
    /**
     * @brief Destructor
     */
    ~MemoryPool();
    
    /**
     * @brief Allocate memory from the pool
     * @return Pointer to allocated memory
     */
    void* Allocate();
    
    /**
     * @brief Free memory back to the pool
     * @param ptr Pointer to memory previously allocated from this pool
     * @return True if memory was returned to the pool
     */
    bool Free(void* ptr);
    
    /**
     * @brief Get the block size for this pool
     * @return Block size in bytes
     */
    size_t GetBlockSize() const { return m_blockSize; }
    
    /**
     * @brief Get the number of free blocks
     * @return Number of available blocks
     */
    size_t GetFreeBlockCount() const { return m_freeBlocks.size(); }
    
    /**
     * @brief Get the total number of blocks
     * @return Total number of blocks in the pool
     */
    size_t GetTotalBlockCount() const { return m_totalBlocks; }
    
    /**
     * @brief Expand the pool with additional blocks
     * @param additionalBlocks Number of blocks to add
     */
    void Expand(size_t additionalBlocks);
    
    /**
     * @brief Shrink the pool by releasing unused blocks
     * @param targetFreeRatio Target ratio of free blocks to keep (0.0-1.0)
     * @return Number of bytes freed
     */
    size_t Shrink(float targetFreeRatio = 0.25f);

private:
    struct MemoryBlock {
        void* address;
        bool isAllocated;
    };
    
    size_t m_blockSize;            // Size of each memory block
    size_t m_totalBlocks;          // Total number of blocks
    std::vector<void*> m_freeBlocks; // Available blocks
    std::unordered_map<void*, size_t> m_allocatedBlocks; // Map of allocated blocks to their indices
    void* m_storage;               // Main storage pointer
    std::mutex m_mutex;            // Thread safety mutex
};

/**
 * @class MemoryOptimizer
 * @brief Main memory optimization system
 */
class MemoryOptimizer {
public:
    using MemoryWarningCallback = std::function<void(float usageRatio, const std::string& message)>;
    
    /**
     * @brief Get the singleton instance
     * @return Reference to the singleton instance
     */
    static MemoryOptimizer& GetInstance();
    
    /**
     * @brief Initialize the memory optimizer
     * @param strategy Optimization strategy to use
     * @return True if initialization succeeded
     */
    bool Initialize(OptimizationStrategy strategy = OptimizationStrategy::Balanced);
    
    /**
     * @brief Allocate memory with tracking
     * @param size Size in bytes to allocate
     * @param tag Optional tag for tracking
     * @return Pointer to allocated memory
     */
    void* Allocate(size_t size, const std::string& tag = "");
    
    /**
     * @brief Free tracked memory
     * @param ptr Pointer to memory previously allocated
     * @return True if memory was freed
     */
    bool Free(void* ptr);
    
    /**
     * @brief Use memory pools for allocation if appropriate
     * @param size Size in bytes to allocate
     * @param tag Optional tag for tracking
     * @return Pointer to allocated memory
     */
    void* AllocateFromPool(size_t size, const std::string& tag = "");
    
    /**
     * @brief Free memory that was allocated from a pool
     * @param ptr Pointer to memory previously allocated from a pool
     * @return True if memory was freed
     */
    bool FreeToPool(void* ptr);
    
    /**
     * @brief Register an object to be cached
     * @param key Cache key
     * @param object Shared pointer to the object
     * @param ttlMs Time-to-live in milliseconds (0 = no expiration)
     */
    template<typename T>
    void CacheObject(const std::string& key, std::shared_ptr<T> object, uint64_t ttlMs = 0) {
        std::lock_guard<std::mutex> lock(m_cacheMutex);
        
        // Store in cache
        m_objectCache[key] = CacheEntry{
            std::static_pointer_cast<void>(object),
            ttlMs == 0 ? std::chrono::steady_clock::time_point::max() 
                       : std::chrono::steady_clock::now() + std::chrono::milliseconds(ttlMs),
            sizeof(T) // Approximate size
        };
        
        // Update cache size
        m_stats.cacheSize += sizeof(T);
        
        // Clean cache if it's growing too large
        if (m_stats.cacheSize > m_maxCacheSize) {
            CleanCache(0.5f); // Reduce cache by 50%
        }
    }
    
    /**
     * @brief Retrieve a cached object
     * @param key Cache key
     * @return Shared pointer to the object or nullptr if not found
     */
    template<typename T>
    std::shared_ptr<T> GetCachedObject(const std::string& key) {
        std::lock_guard<std::mutex> lock(m_cacheMutex);
        
        auto it = m_objectCache.find(key);
        if (it == m_objectCache.end()) {
            return nullptr;
        }
        
        // Check if expired
        if (it->second.expiration != std::chrono::steady_clock::time_point::max() &&
            it->second.expiration < std::chrono::steady_clock::now()) {
            // Remove expired entry
            m_stats.cacheSize -= it->second.size;
            m_objectCache.erase(it);
            return nullptr;
        }
        
        // Cast back to the original type
        return std::static_pointer_cast<T>(it->second.object);
    }
    
    /**
     * @brief Remove a cached object
     * @param key Cache key
     * @return True if object was in cache and removed
     */
    bool RemoveFromCache(const std::string& key);
    
    /**
     * @brief Clean the cache to reduce memory usage
     * @param percentToRemove Percentage of cache to remove (0.0-1.0)
     * @return Number of bytes freed
     */
    size_t CleanCache(float percentToRemove = 1.0f);
    
    /**
     * @brief Register a callback for memory warnings
     * @param callback Function to call when memory usage exceeds thresholds
     * @return ID of registered callback
     */
    int RegisterWarningCallback(const MemoryWarningCallback& callback);
    
    /**
     * @brief Unregister a memory warning callback
     * @param id ID of the callback to unregister
     * @return True if callback was unregistered
     */
    bool UnregisterWarningCallback(int id);
    
    /**
     * @brief Get current memory statistics
     * @return Current memory statistics
     */
    MemoryStats GetMemoryStats() const;
    
    /**
     * @brief Set memory usage thresholds
     * @param thresholds New threshold values
     */
    void SetThresholds(const MemoryThresholds& thresholds);
    
    /**
     * @brief Get current memory thresholds
     * @return Current threshold values
     */
    MemoryThresholds GetThresholds() const;
    
    /**
     * @brief Force garbage collection to free unused memory
     * @param aggressive If true, more aggressive cleanup is performed
     * @return Number of bytes freed
     */
    size_t ForceGarbageCollection(bool aggressive = false);
    
    /**
     * @brief Optimize memory usage based on current conditions
     * @return Number of bytes optimized
     */
    size_t OptimizeMemoryUsage();
    
    /**
     * @brief Set the optimization strategy
     * @param strategy New strategy to use
     */
    void SetOptimizationStrategy(OptimizationStrategy strategy);
    
    /**
     * @brief Get the current optimization strategy
     * @return Current strategy in use
     */
    OptimizationStrategy GetOptimizationStrategy() const;
    
private:
    // Private constructor for singleton
    MemoryOptimizer();
    ~MemoryOptimizer();
    
    // Delete copy/move constructors and assignment operators
    MemoryOptimizer(const MemoryOptimizer&) = delete;
    MemoryOptimizer& operator=(const MemoryOptimizer&) = delete;
    MemoryOptimizer(MemoryOptimizer&&) = delete;
    MemoryOptimizer& operator=(MemoryOptimizer&&) = delete;
    
    // Helper methods
    void UpdateMemoryStats();
    void CheckMemoryThresholds();
    MemoryPool* FindPoolForSize(size_t size);
    void CreateMemoryPools();
    
    // Cached object entry
    struct CacheEntry {
        std::shared_ptr<void> object;
        std::chrono::steady_clock::time_point expiration;
        size_t size;
    };
    
    // Member variables
    OptimizationStrategy m_strategy;
    MemoryStats m_stats;
    MemoryThresholds m_thresholds;
    std::vector<std::unique_ptr<MemoryPool>> m_pools;
    std::unordered_map<std::string, CacheEntry> m_objectCache;
    std::unordered_map<void*, AllocationEntry> m_allocations;
    std::unordered_map<int, MemoryWarningCallback> m_warningCallbacks;
    size_t m_maxCacheSize;
    int m_nextCallbackId;
    std::atomic<bool> m_isOptimizing;
    
    // Mutexes for thread safety
    mutable std::mutex m_statsMutex;
    mutable std::mutex m_poolMutex;
    mutable std::mutex m_cacheMutex;
    mutable std::mutex m_allocMutex;
    mutable std::mutex m_callbackMutex;
    
    // Singleton instance
    static std::unique_ptr<MemoryOptimizer> s_instance;
    static std::once_flag s_onceFlag;
};

/**
 * @brief Convert optimization strategy to string
 * @param strategy Strategy to convert
 * @return String representation
 */
std::string StrategyToString(OptimizationStrategy strategy);

/**
 * @brief Automated memory tracking helper
 */
class ScopedMemoryTracker {
public:
    /**
     * @brief Constructor with tag for tracking
     * @param tag Tag to identify the memory usage
     */
    explicit ScopedMemoryTracker(const std::string& tag);
    
    /**
     * @brief Destructor that reports memory usage
     */
    ~ScopedMemoryTracker();
    
private:
    std::string m_tag;
    size_t m_startUsage;
    std::chrono::steady_clock::time_point m_startTime;
};

} // namespace Memory

// Helper macro for tracking memory usage in a scope
#define TRACK_MEMORY_USAGE(tag) Memory::ScopedMemoryTracker _memTracker(tag)

// Helper macro for allocation with tracking
#define OPTIMIZED_ALLOC(size, tag) Memory::MemoryOptimizer::GetInstance().Allocate(size, tag)

// Helper macro for freeing tracked memory
#define OPTIMIZED_FREE(ptr) Memory::MemoryOptimizer::GetInstance().Free(ptr)
