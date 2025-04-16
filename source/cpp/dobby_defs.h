/**
 * @file dobby_defs.h
 * @brief Dobby function declarations for production use
 * 
 * This header provides the proper declarations for Dobby functions
 * to ensure compatibility across the project. It directly references
 * the functions defined in the Dobby library.
 */

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Main Dobby API functions - these match the ones in dobby.h
int DobbyHook(void *address, void *replace_call, void **origin_call);
int DobbyDestroy(void *address);

// Optional debug/initialization functions
void DobbyDestroy_All(void);
void DobbyInstrumentation(void *address); 

#ifdef __cplusplus
}
#endif

#define DOBBY_UNHOOK_DEFINED 1
