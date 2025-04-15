// FileSystem implementation for iOS
#include "FileSystem.h"
#include <iostream>
#include <fstream>
#include <sstream>
#include <sys/stat.h>
#include <unistd.h>
#include <dirent.h>
#include <ctime>
#include <cstring>

namespace iOS {
    // Initialize static members with explicit iOS namespace
    std::string iOS::FileSystem::m_documentsPath = "";
    std::string iOS::FileSystem::m_workspacePath = "";
    std::string iOS::FileSystem::m_scriptsPath = "";
    std::string iOS::FileSystem::m_logPath = "";
    std::string iOS::FileSystem::m_configPath = "";
    bool iOS::FileSystem::m_initialized = false;
    
    // Initialize the file system
    bool iOS::FileSystem::Initialize(const std::string& appName) {
        if (m_initialized) {
            return true;
        }
        
        try {
            // Get the documents directory
            #ifdef __OBJC__
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            if ([paths count] > 0) {
                NSString *documentsDirectory = [paths objectAtIndex:0];
                m_documentsPath = [documentsDirectory UTF8String];
            } else {
                std::cerr << "FileSystem: Failed to get documents directory" << std::endl;
                return false;
            }
            #else
            // For non-Objective-C builds, use a default path
            m_documentsPath = "/var/mobile/Documents";
            #endif
            
            // Create the workspace directory structure
            m_workspacePath = JoinPaths(m_documentsPath, appName);
            if (!EnsureDirectoryExists(m_workspacePath)) {
                std::cerr << "FileSystem: Failed to create workspace directory" << std::endl;
                return false;
            }
            
            m_scriptsPath = JoinPaths(m_workspacePath, "Scripts");
            if (!EnsureDirectoryExists(m_scriptsPath)) {
                std::cerr << "FileSystem: Failed to create scripts directory" << std::endl;
                return false;
            }
            
            m_logPath = JoinPaths(m_workspacePath, "Logs");
            if (!EnsureDirectoryExists(m_logPath)) {
                std::cerr << "FileSystem: Failed to create logs directory" << std::endl;
                return false;
            }
            
            m_configPath = JoinPaths(m_workspacePath, "Config");
            if (!EnsureDirectoryExists(m_configPath)) {
                std::cerr << "FileSystem: Failed to create config directory" << std::endl;
                return false;
            }
            
            // Create default files
            if (!CreateDefaultScript()) {
                std::cerr << "FileSystem: Failed to create default script" << std::endl;
                return false;
            }
            
            if (!CreateDefaultConfig()) {
                std::cerr << "FileSystem: Failed to create default config" << std::endl;
                return false;
            }
            
            m_initialized = true;
            std::cout << "FileSystem: Initialized successfully" << std::endl;
            return true;
        } catch (const std::exception& e) {
            std::cerr << "FileSystem: Exception during initialization: " << e.what() << std::endl;
            return false;
        }
    }
    
    // Path getters
    std::string iOS::FileSystem::GetDocumentsPath() {
        return m_documentsPath;
    }
    
    std::string iOS::FileSystem::GetWorkspacePath() {
        return m_workspacePath;
    }
    
    std::string iOS::FileSystem::GetScriptsPath() {
        return m_scriptsPath;
    }
    
    std::string iOS::FileSystem::GetLogPath() {
        return m_logPath;
    }
    
    std::string iOS::FileSystem::GetConfigPath() {
        return m_configPath;
    }
    
    // Create a directory
    bool iOS::FileSystem::CreateDirectory(const std::string& path) {
        std::string safePath = SanitizePath(path);
        return CreateDirectoryInternal(safePath);
    }
    
    // Internal implementation of directory creation
    bool iOS::FileSystem::CreateDirectoryInternal(const std::string& path) {
        #ifdef __OBJC__
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *nsPath = [NSString stringWithUTF8String:path.c_str()];
        
        NSError *error = nil;
        BOOL success = [fileManager createDirectoryAtPath:nsPath
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
        
        if (!success) {
            std::cerr << "FileSystem: Failed to create directory: " 
                      << [[error localizedDescription] UTF8String] << std::endl;
        }
        
        return success;
        #else
        // Fallback implementation for non-Objective-C builds
        return mkdir(path.c_str(), 0755) == 0 || errno == EEXIST;
        #endif
    }
    
    // Ensure a directory exists, creating it if necessary
    bool iOS::FileSystem::EnsureDirectoryExists(const std::string& path) {
        if (Exists(path)) {
            if (GetFileInfo(path).m_type == FileType::Directory) {
                return true;
            }
            std::cerr << "FileSystem: Path exists but is not a directory: " << path << std::endl;
            return false;
        }
        
        return CreateDirectory(path);
    }
    
    // Write data to a file
    bool iOS::FileSystem::WriteFile(const std::string& path, const std::string& content) {
        std::string safePath = SanitizePath(path);
        
        // Make sure the parent directory exists
        std::string dirPath = GetDirectoryName(safePath);
        if (!dirPath.empty() && !EnsureDirectoryExists(dirPath)) {
            std::cerr << "FileSystem: Failed to create parent directory: " << dirPath << std::endl;
            return false;
        }
        
        try {
            std::ofstream file(safePath, std::ios::out | std::ios::binary);
            if (!file.is_open()) {
                std::cerr << "FileSystem: Failed to open file for writing: " << safePath << std::endl;
                return false;
            }
            
            file.write(content.c_str(), content.size());
            bool success = !file.fail();
            file.close();
            
            return success;
        } catch (const std::exception& e) {
            std::cerr << "FileSystem: Exception writing file: " << e.what() << std::endl;
            return false;
        }
    }
    
    // Append data to a file
    bool iOS::FileSystem::AppendToFile(const std::string& path, const std::string& content) {
        std::string safePath = SanitizePath(path);
        
        // Make sure the parent directory exists
        std::string dirPath = GetDirectoryName(safePath);
        if (!dirPath.empty() && !EnsureDirectoryExists(dirPath)) {
            std::cerr << "FileSystem: Failed to create parent directory: " << dirPath << std::endl;
            return false;
        }
        
        try {
            std::ofstream file(safePath, std::ios::out | std::ios::app | std::ios::binary);
            if (!file.is_open()) {
                std::cerr << "FileSystem: Failed to open file for appending: " << safePath << std::endl;
                return false;
            }
            
            file.write(content.c_str(), content.size());
            bool success = !file.fail();
            file.close();
            
            return success;
        } catch (const std::exception& e) {
            std::cerr << "FileSystem: Exception appending to file: " << e.what() << std::endl;
            return false;
        }
    }
    
    // Read the contents of a file
    std::string iOS::FileSystem::ReadFile(const std::string& path) {
        std::string safePath = SanitizePath(path);
        
        if (!FileExists(safePath)) {
            std::cerr << "FileSystem: File does not exist: " << safePath << std::endl;
            return "";
        }
        
        try {
            std::ifstream file(safePath, std::ios::in | std::ios::binary);
            if (!file.is_open()) {
                std::cerr << "FileSystem: Failed to open file for reading: " << safePath << std::endl;
                return "";
            }
            
            // Get file size
            file.seekg(0, std::ios::end);
            size_t size = file.tellg();
            file.seekg(0, std::ios::beg);
            
            // Read the file
            std::string content(size, ' ');
            file.read(&content[0], size);
            file.close();
            
            return content;
        } catch (const std::exception& e) {
            std::cerr << "FileSystem: Exception reading file: " << e.what() << std::endl;
            return "";
        }
    }
    
    // Check if a file exists
    bool iOS::FileSystem::FileExists(const std::string& path) {
        std::string safePath = SanitizePath(path);
        
        if (!Exists(safePath)) {
            return false;
        }
        
        return GetFileInfo(safePath).m_type == FileType::File;
    }
    
    // Check if a directory exists
    bool iOS::FileSystem::DirectoryExists(const std::string& path) {
        std::string safePath = SanitizePath(path);
        
        if (!Exists(safePath)) {
            return false;
        }
        
        return GetFileInfo(safePath).m_type == FileType::Directory;
    }
    
    // Check if a path exists (file or directory)
    bool iOS::FileSystem::Exists(const std::string& path) {
        std::string safePath = SanitizePath(path);
        
        struct stat st;
        return stat(safePath.c_str(), &st) == 0;
    }
    
    // Delete a file
    bool iOS::FileSystem::DeleteFile(const std::string& path) {
        std::string safePath = SanitizePath(path);
        
        if (!FileExists(safePath)) {
            std::cerr << "FileSystem: Cannot delete, file does not exist: " << safePath << std::endl;
            return false;
        }
        
        try {
            #ifdef __OBJC__
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSString *nsPath = [NSString stringWithUTF8String:safePath.c_str()];
            
            NSError *error = nil;
            BOOL success = [fileManager removeItemAtPath:nsPath error:&error];
            
            if (!success) {
                std::cerr << "FileSystem: Failed to delete file: " 
                          << [[error localizedDescription] UTF8String] << std::endl;
            }
            
            return success;
            #else
            // Fallback implementation for non-Objective-C builds
            return remove(safePath.c_str()) == 0;
            #endif
        } catch (const std::exception& e) {
            std::cerr << "FileSystem: Exception deleting file: " << e.what() << std::endl;
            return false;
        }
    }
    
    // Rename a file
    bool iOS::FileSystem::RenameFile(const std::string& oldPath, const std::string& newPath) {
        std::string safeOldPath = SanitizePath(oldPath);
        std::string safeNewPath = SanitizePath(newPath);
        
        if (!Exists(safeOldPath)) {
            std::cerr << "FileSystem: Cannot rename, source does not exist: " << safeOldPath << std::endl;
            return false;
        }
        
        try {
            #ifdef __OBJC__
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSString *nsOldPath = [NSString stringWithUTF8String:safeOldPath.c_str()];
            NSString *nsNewPath = [NSString stringWithUTF8String:safeNewPath.c_str()];
            
            NSError *error = nil;
            BOOL success = [fileManager moveItemAtPath:nsOldPath toPath:nsNewPath error:&error];
            
            if (!success) {
                std::cerr << "FileSystem: Failed to rename file: " 
                          << [[error localizedDescription] UTF8String] << std::endl;
            }
            
            return success;
            #else
            // Fallback implementation for non-Objective-C builds
            return rename(safeOldPath.c_str(), safeNewPath.c_str()) == 0;
            #endif
        } catch (const std::exception& e) {
            std::cerr << "FileSystem: Exception renaming file: " << e.what() << std::endl;
            return false;
        }
    }
    
    // Copy a file
    bool iOS::FileSystem::CopyFile(const std::string& sourcePath, const std::string& destPath) {
        std::string safeSourcePath = SanitizePath(sourcePath);
        std::string safeDestPath = SanitizePath(destPath);
        
        if (!FileExists(safeSourcePath)) {
            std::cerr << "FileSystem: Cannot copy, source file does not exist: " << safeSourcePath << std::endl;
            return false;
        }
        
        try {
            #ifdef __OBJC__
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSString *nsSourcePath = [NSString stringWithUTF8String:safeSourcePath.c_str()];
            NSString *nsDestPath = [NSString stringWithUTF8String:safeDestPath.c_str()];
            
            NSError *error = nil;
            BOOL success = [fileManager copyItemAtPath:nsSourcePath toPath:nsDestPath error:&error];
            
            if (!success) {
                std::cerr << "FileSystem: Failed to copy file: " 
                          << [[error localizedDescription] UTF8String] << std::endl;
            }
            
            return success;
            #else
            // Fallback implementation for non-Objective-C builds
            std::string content = ReadFile(safeSourcePath);
            return WriteFile(safeDestPath, content);
            #endif
        } catch (const std::exception& e) {
            std::cerr << "FileSystem: Exception copying file: " << e.what() << std::endl;
            return false;
        }
    }
    
    // Get information about a file or directory
    FileInfo iOS::FileSystem::GetFileInfo(const std::string& path) {
        std::string safePath = SanitizePath(path);
        
        struct stat st;
        if (stat(safePath.c_str(), &st) != 0) {
            return FileInfo(); // Return default (invalid) file info
        }
        
        FileType type = FileType::File;
        if (S_ISDIR(st.st_mode)) {
            type = FileType::Directory;
        }
        
        bool isReadable = access(safePath.c_str(), R_OK) == 0;
        bool isWritable = access(safePath.c_str(), W_OK) == 0;
        
        return FileInfo(
            safePath,
            type,
            static_cast<size_t>(st.st_size),
            st.st_mtime,
            isReadable,
            isWritable
        );
    }
    
    // Get the file type
    FileType iOS::FileSystem::GetFileType(const std::string& path) {
        return GetFileInfo(path).m_type;
    }
    
    // List the contents of a directory
    std::vector<FileInfo> iOS::FileSystem::ListDirectory(const std::string& path) {
        std::string safePath = SanitizePath(path);
        std::vector<FileInfo> files;
        
        if (!DirectoryExists(safePath)) {
            std::cerr << "FileSystem: Cannot list directory, it does not exist: " << safePath << std::endl;
            return files;
        }
        
        try {
            DIR* dir = opendir(safePath.c_str());
            if (!dir) {
                std::cerr << "FileSystem: Failed to open directory: " << safePath << std::endl;
                return files;
            }
            
            struct dirent* entry;
            while ((entry = readdir(dir)) != nullptr) {
                std::string name = entry->d_name;
                
                // Skip . and ..
                if (name == "." || name == "..") {
                    continue;
                }
                
                std::string fullPath = JoinPaths(safePath, name);
                files.push_back(GetFileInfo(fullPath));
            }
            
            closedir(dir);
            
            return files;
        } catch (const std::exception& e) {
            std::cerr << "FileSystem: Exception listing directory: " << e.what() << std::endl;
            return files;
        }
    }
    
    // Get a unique file path by adding a number if necessary
    std::string iOS::FileSystem::GetUniqueFilePath(const std::string& basePath) {
        std::string safePath = SanitizePath(basePath);
        
        if (!Exists(safePath)) {
            return safePath;
        }
        
        // Split the path into directory, base name, and extension
        std::string dir = GetDirectoryName(safePath);
        std::string fileName = GetFileName(safePath);
        std::string baseName = fileName;
        std::string extension = "";
        
        size_t dotPos = fileName.find_last_of('.');
        if (dotPos != std::string::npos) {
            baseName = fileName.substr(0, dotPos);
            extension = fileName.substr(dotPos);
        }
        
        // Try adding numbers until we find a unique name
        for (int i = 1; i <= 999; i++) {
            std::string newName = baseName + " (" + std::to_string(i) + ")" + extension;
            std::string newPath = JoinPaths(dir, newName);
            
            if (!Exists(newPath)) {
                return newPath;
            }
        }
        
        // If we get here, we couldn't find a unique name
        std::cerr << "FileSystem: Failed to generate a unique file path" << std::endl;
        return "";
    }
    
    // Get a safe absolute path from a potentially relative path
    std::string iOS::FileSystem::GetSafePath(const std::string& relativePath) {
        if (relativePath.empty()) {
            return m_workspacePath;
        }
        
        // If it's already an absolute path, make sure it's within our workspace
        if (relativePath[0] == '/') {
            std::string safePath = SanitizePath(relativePath);
            
            // Only allow paths within the documents directory
            if (safePath.find(m_documentsPath) == 0) {
                return safePath;
            }
            
            // If it's not within the documents directory, use it relative to the workspace
            return JoinPaths(m_workspacePath, safePath);
        }
        
        // It's a relative path, combine it with the workspace path
        return JoinPaths(m_workspacePath, relativePath);
    }
    
    // Check if we have permission to access a file
    bool iOS::FileSystem::HasPermission(const std::string& path, bool requireWrite) {
        std::string safePath = SanitizePath(path);
        
        if (!Exists(safePath)) {
            return false;
        }
        
        // Check read permission
        if (access(safePath.c_str(), R_OK) != 0) {
            return false;
        }
        
        // Check write permission if required
        if (requireWrite && access(safePath.c_str(), W_OK) != 0) {
            return false;
        }
        
        return true;
    }
    
    // Join two paths together
    std::string iOS::FileSystem::JoinPaths(const std::string& path1, const std::string& path2) {
        if (path1.empty()) {
            return path2;
        }
        
        if (path2.empty()) {
            return path1;
        }
        
        char lastChar = path1[path1.length() - 1];
        char firstChar = path2[0];
        
        // Handle cases with and without slashes
        if (lastChar == '/' || lastChar == '\\') {
            if (firstChar == '/' || firstChar == '\\') {
                // Both have slashes, remove one
                return path1 + path2.substr(1);
            } else {
                // Only path1 has a slash
                return path1 + path2;
            }
        } else {
            if (firstChar == '/' || firstChar == '\\') {
                // Only path2 has a slash
                return path1 + path2;
            } else {
                // Neither has a slash, add one
                return path1 + '/' + path2;
            }
        }
    }
    
    // Get just the file name from a path
    std::string iOS::FileSystem::GetFileName(const std::string& path) {
        std::string safePath = SanitizePath(path);
        
        size_t lastSlash = safePath.find_last_of("/\\");
        if (lastSlash == std::string::npos) {
            return safePath;
        }
        
        return safePath.substr(lastSlash + 1);
    }
    
    // Get the file extension
    std::string iOS::FileSystem::GetFileExtension(const std::string& path) {
        std::string fileName = GetFileName(path);
        
        size_t dotPos = fileName.find_last_of('.');
        if (dotPos == std::string::npos || dotPos == 0) {
            return "";
        }
        
        return fileName.substr(dotPos + 1);
    }
    
    // Get the directory part of a path
    std::string iOS::FileSystem::GetDirectoryName(const std::string& path) {
        std::string safePath = SanitizePath(path);
        
        size_t lastSlash = safePath.find_last_of("/\\");
        if (lastSlash == std::string::npos) {
            return "";
        }
        
        return safePath.substr(0, lastSlash);
    }
    
    // Get the documents directory (alias for GetDocumentsPath)
    std::string iOS::FileSystem::GetDocumentsDirectory() {
        return GetDocumentsPath();
    }
    
    // Get the temporary directory
    std::string iOS::FileSystem::GetTempDirectory() {
        #ifdef __OBJC__
        NSString *tempDir = NSTemporaryDirectory();
        return [tempDir UTF8String];
        #else
        return "/tmp";
        #endif
    }
    
    // Get the caches directory
    std::string iOS::FileSystem::GetCachesDirectory() {
        #ifdef __OBJC__
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        if ([paths count] > 0) {
            NSString *cachesDir = [paths objectAtIndex:0];
            return [cachesDir UTF8String];
        }
        return "";
        #else
        return "/var/mobile/Library/Caches";
        #endif
    }
    
    // Sanitize a path by removing trailing slashes
    std::string iOS::FileSystem::SanitizePath(const std::string& path) {
        std::string result = path;
        
        // Remove trailing slashes
        while (!result.empty() && (result.back() == '/' || result.back() == '\\')) {
            result.pop_back();
        }
        
        return result;
    }
    
    // Create a default script file
    bool iOS::FileSystem::CreateDefaultScript() {
        std::string scriptPath = JoinPaths(m_scriptsPath, "WelcomeScript.lua");
        
        if (FileExists(scriptPath)) {
            return true;
        }
        
        std::string content = R"(
-- Welcome to the Roblox Executor
-- This is an example script to get you started

print("Hello from the Roblox Executor!")

-- Example function to change player speed
local function setSpeed(speed)
    local player = game.Players.LocalPlayer
    if player and player.Character then
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = speed
        end
    end
end

-- Example usage: Uncomment the line below to set speed to 50
-- setSpeed(50)

-- Enjoy using the executor!
)";
        
        return WriteFile(scriptPath, content);
    }
    
    // Create a default config file
    bool iOS::FileSystem::CreateDefaultConfig() {
        std::string configPath = JoinPaths(m_configPath, "settings.json");
        
        if (FileExists(configPath)) {
            return true;
        }
        
        std::string content = R"({
    "version": "1.0.0",
    "settings": {
        "autoExecute": false,
        "darkMode": true,
        "fontSize": 14,
        "logExecution": true,
        "maxRecentScripts": 10
    },
    "execution": {
        "timeoutMs": 5000,
        "maxRetries": 3,
        "timeout": 5000,
        "enableObfuscation": true
    },
    "scripts": {
        "autoSave": true,
        "defaultDirectory": "Scripts",
        "maxRecentScripts": 10
    },
    "security": {
        "encryptSavedScripts": true,
        "enableAntiDetection": true,
        "enableVMDetection": true
    }
})";
        
        return WriteFile(configPath, content);
    }
}
