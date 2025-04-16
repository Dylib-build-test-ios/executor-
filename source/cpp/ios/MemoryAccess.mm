// MemoryAccess.mm - Production-quality implementation
#include "MemoryAccess.h"
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <mach/vm_region.h>
#include <dlfcn.h>
#include <sys/mman.h>
#include <iostream>

namespace iOS {
    // Implement ReadMemory with robust functionality
    bool MemoryAccess::ReadMemory(void* address, void* buffer, size_t size) {
        if (!address || !buffer || size == 0) {
            std::cerr << "ReadMemory: Invalid parameters" << std::endl;
            return false;
        }
        
        task_t task = mach_task_self();
        vm_size_t bytesRead = 0;
        
        kern_return_t kr = vm_read_overwrite(task, 
                                         (vm_address_t)address, 
                                         size, 
                                         (vm_address_t)buffer, 
                                         &bytesRead);
        
        if (kr != KERN_SUCCESS) {
            std::cerr << "ReadMemory: Failed at address " << address 
                     << ", size " << size << std::endl;
            return false;
        }
        
        return bytesRead == size;
    }
    
    // Implement WriteMemory with robust functionality
    bool MemoryAccess::WriteMemory(void* address, const void* buffer, size_t size) {
        if (!address || !buffer || size == 0) {
            std::cerr << "WriteMemory: Invalid parameters" << std::endl;
            return false;
        }
        
        task_t task = mach_task_self();
        
        // Get current protection - using vm_region instead of vm_region_64 to fix type issues
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
        vm_address_t regionAddress = (vm_address_t)(uintptr_t)address;
        vm_size_t regionSize = 0;
        mach_port_t objectName = MACH_PORT_NULL;
        
        kern_return_t kr = vm_region(task, 
                                  &regionAddress, 
                                  &regionSize, 
                                  VM_REGION_BASIC_INFO_64, 
                                  (vm_region_info_t)&info, 
                                  &infoCount, 
                                  &objectName);
        
        // Ensure memory is writable
        bool protectionChanged = false;
        int originalProtection = VM_PROT_READ | VM_PROT_WRITE;
        
        if (kr == KERN_SUCCESS) {
            originalProtection = info.protection;
            
            if (!(originalProtection & VM_PROT_WRITE)) {
                kr = vm_protect(task, 
                              (vm_address_t)address, 
                              size, 
                              FALSE, 
                              originalProtection | VM_PROT_WRITE);
                
                if (kr == KERN_SUCCESS) {
                    protectionChanged = true;
                }
            }
        }
        
        // Write memory
        kr = vm_write(task, 
                   (vm_address_t)address, 
                   (vm_address_t)buffer, 
                   (mach_msg_type_number_t)size);
        
        // Restore original protection if changed
        if (protectionChanged) {
            vm_protect(task, 
                     (vm_address_t)address, 
                     size, 
                     FALSE, 
                     originalProtection);
        }
        
        if (kr != KERN_SUCCESS) {
            std::cerr << "WriteMemory: Failed at address " << address 
                     << ", size " << size << std::endl;
            return false;
        }
        
        return true;
    }
    
    // Implement GetModuleBase with robust functionality
    uintptr_t MemoryAccess::GetModuleBase(const std::string& moduleName) {
        if (moduleName.empty()) {
            std::cerr << "GetModuleBase: Empty module name" << std::endl;
            return 0;
        }
        
        void* handle = dlopen(moduleName.c_str(), RTLD_NOLOAD);
        if (!handle) {
            // Try with various extensions
            std::vector<std::string> attempts = {
                moduleName + ".dylib",
                moduleName + ".framework/" + moduleName,
                "/usr/lib/" + moduleName,
                "/System/Library/Frameworks/" + moduleName + ".framework/" + moduleName
            };
            
            for (const auto& attempt : attempts) {
                handle = dlopen(attempt.c_str(), RTLD_NOLOAD);
                if (handle) {
                    break;
                }
            }
            
            if (!handle) {
                std::cerr << "GetModuleBase: Module not found: " << moduleName << std::endl;
                return 0;
            }
        }
        
        Dl_info info;
        if (dladdr(handle, &info) == 0) {
            dlclose(handle);
            std::cerr << "GetModuleBase: Failed to get module info for " << moduleName << std::endl;
            return 0;
        }
        
        dlclose(handle);
        return (uintptr_t)info.dli_fbase;
    }
    
    // Implement GetModuleSize with proper Mach-O parsing
    size_t MemoryAccess::GetModuleSize(const std::string& moduleName) {
        uintptr_t moduleBase = GetModuleBase(moduleName);
        if (moduleBase == 0) {
            return 0;
        }
        
        return GetModuleSize(moduleBase);
    }
    
    // Implement GetModuleSize overload with Mach-O header parsing
    size_t MemoryAccess::GetModuleSize(uintptr_t moduleBase) {
        if (moduleBase == 0) {
            return 0;
        }
        
        // Read the Mach-O header
        struct mach_header_64 header;
        if (!ReadMemory((void*)moduleBase, &header, sizeof(header))) {
            std::cerr << "GetModuleSize: Failed to read Mach-O header at " << std::hex << moduleBase << std::endl;
            return 0;
        }
        
        // Verify it's a valid Mach-O file
        if (header.magic != MH_MAGIC_64) {
            std::cerr << "GetModuleSize: Invalid Mach-O magic at " << std::hex << moduleBase << std::endl;
            return 0;
        }
        
        // Parse the load commands to find segments
        size_t totalSize = 0;
        uintptr_t cmdOffset = moduleBase + sizeof(mach_header_64);
        
        for (uint32_t i = 0; i < header.ncmds; i++) {
            struct load_command loadCmd;
            if (!ReadMemory((void*)cmdOffset, &loadCmd, sizeof(loadCmd))) {
                break;
            }
            
            // Check if this is a segment command
            if (loadCmd.cmd == LC_SEGMENT_64) {
                struct segment_command_64 segmentCmd;
                if (ReadMemory((void*)cmdOffset, &segmentCmd, sizeof(segmentCmd))) {
                    // Add the segment size to the total
                    totalSize = std::max(totalSize, (size_t)(segmentCmd.vmaddr + segmentCmd.vmsize - moduleBase));
                }
            }
            
            // Move to the next command
            cmdOffset += loadCmd.cmdsize;
        }
        
        // If we couldn't get the size from segments, use a reasonable default
        if (totalSize == 0) {
            std::cerr << "GetModuleSize: Could not determine size from Mach-O headers, using default" << std::endl;
            totalSize = 16 * 1024 * 1024; // 16MB default as a reasonable estimate
        }
        
        return totalSize;
    }
    
    // Implement ProtectMemory with robust functionality
    bool MemoryAccess::ProtectMemory(void* address, size_t size, int protection) {
        if (!address || size == 0) {
            std::cerr << "ProtectMemory: Invalid parameters" << std::endl;
            return false;
        }
        
        task_t task = mach_task_self();
        
        kern_return_t kr = vm_protect(task, 
                                    (vm_address_t)address, 
                                    size, 
                                    FALSE, 
                                    protection);
        
        if (kr != KERN_SUCCESS) {
            std::cerr << "ProtectMemory: Failed at address " << address 
                     << ", size " << size 
                     << ", protection " << protection << std::endl;
            return false;
        }
        
        std::cout << "ProtectMemory: Successfully changed protection at " << address << std::endl;
        return true;
    }
}
