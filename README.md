# iOS Roblox Executor

A comprehensive, production-grade dynamic library for enhancing Roblox on iOS devices, featuring advanced script execution, UI integration, and AI-powered features.

![Version](https://img.shields.io/badge/Version-1.0.0-blue)
![Platform](https://img.shields.io/badge/Platform-iOS%2015.0+-lightgrey)
![Architecture](https://img.shields.io/badge/Architecture-arm64-green)

## Features

### Core Features
- **Advanced Script Execution**: Run Lua/Luau scripts within Roblox with support for `loadstring`
- **Memory Manipulation**: Read and write memory with pattern scanning capabilities
- **Function Hooking**: Intercept Roblox functions using Dobby integration
- **Jailbreak Detection Bypass**: Multiple bypass methods with fallback chains

### User Interface
- **Modern UI**: Complete UI with script editor, script management, console, and settings
- **Floating Button**: Persistent access button with LED effects and draggable positioning
- **Visual Effects**: Professional LED glow effects and smooth animations
- **Touch Optimized**: Designed specifically for iOS touch interactions

### Advanced Features
- **AI Assistance**: Script generation, debugging, and optimization with AI integration
- **Multi-Method Execution**: Different execution methods with automatic selection
- **Anti-Detection**: Advanced techniques to avoid detection
- **HTTP Integration**: Support for HTTP requests within scripts

## Getting Started

### Prerequisites
- macOS with Xcode installed (for building)
- iOS device with iOS 15.0 or higher
- For development: CMake 3.13+

### Building from Source

#### Quick Build
Use the provided build script:

```bash
# Clone the repository
git clone https://github.com/your-username/ios-roblox-executor.git
cd ios-roblox-executor

# Build using the script
./build_ios_dylib.sh
```

#### Manual Build
For more control over the build process:

```bash
# Create build directory
mkdir -p build
cd build

# Configure with CMake
cmake .. \
  -DCMAKE_OSX_ARCHITECTURES="arm64" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="15.0" \
  -DCMAKE_BUILD_TYPE=Release

# Build
cmake --build . --config Release

# Output will be in build/lib/libmylibrary.dylib
```

#### GitHub Actions
This project includes GitHub Actions workflows for CI/CD. You can use the "Production iOS Dylib Build" workflow for creating release-ready builds.

### Installation on iOS Device

#### Jailbroken Devices
1. Transfer `libmylibrary.dylib` to your device via SSH or any file manager
2. Use a tweak like Choicy or TweakManager to inject the dylib into Roblox
3. Alternatively, use a dynamic library injection tool

#### Non-Jailbroken Devices
1. Use a sideloading tool that supports dynamic library injection
2. Add `libmylibrary.dylib` to the injection list for Roblox
3. Ensure you have the necessary entitlements

## Usage Guide

### Basic Usage
1. Launch Roblox after injection
2. Look for the floating button on the screen
3. Tap the button to open the executor interface
4. Use the script editor to write or paste your script
5. Press the "Execute" button to run the script

### Advanced Features
- **Script Management**: Save and organize scripts in different categories
- **Console Output**: View script output and error messages in the console tab
- **Settings**: Customize appearance, behavior, and performance options
- **AI Assistance**: Use the AI button to get help with script creation and debugging

## Architecture

### Directory Structure
- `source/` - Source code
  - `source/cpp/` - C++ implementation
  - `source/cpp/ios/` - iOS-specific code
  - `source/cpp/hooks/` - Function hooking implementation
  - `source/cpp/memory/` - Memory manipulation utilities
  - `source/cpp/luau/` - Luau VM implementation
  - `source/cpp/ios/ui/` - UI components
  - `source/cpp/ios/ai_features/` - AI integration
  - `source/cpp/ios/advanced_bypass/` - Anti-detection systems
- `external/` - External dependencies
- `output/` - Build output directory
  - `output/Resources/` - Resource files
- `cmake/` - CMake modules and utilities
- `.github/workflows/` - CI/CD workflows

### Key Components
- **ExecutionEngine**: Handles script execution with various methods
- **UIController**: Manages the user interface components
- **HookEngine**: Provides function interception capabilities
- **AIIntegration**: Controls AI-assisted features
- **AdvancedBypass**: Implements anti-detection techniques

## API Reference

### ExecutionEngine
The core component for script execution:

```cpp
namespace iOS {
    class ExecutionEngine {
    public:
        // Execute a script with the given context
        ExecutionResult Execute(const std::string& script, const ExecutionContext& context = ExecutionContext());
        
        // Execute a named script from the script manager
        ExecutionResult ExecuteByName(const std::string& scriptName, const ExecutionContext& context = ExecutionContext());
        
        // Other methods...
    };
}
```

### UIController
Manages the UI interface:

```cpp
namespace iOS {
    class UIController {
    public:
        // Show/hide the interface
        void Show();
        void Hide();
        
        // Execute current script in editor
        bool ExecuteCurrentScript();
        
        // Other methods...
    };
}
```

### HookEngine
Provides function hooking capabilities:

```cpp
namespace Hooks {
    class HookEngine {
    public:
        // Register a hook
        static bool RegisterHook(void* targetAddr, void* hookAddr, void** originalAddr);
        
        // Unregister a hook
        static bool UnregisterHook(void* targetAddr);
        
        // Other methods...
    };
}
```

## Troubleshooting

### Common Issues
- **Dylib Not Loading**: Ensure the library is properly signed and has the correct entitlements
- **Script Execution Fails**: Try different execution methods in settings
- **UI Not Appearing**: Check if the app has proper UIKit permissions
- **Performance Issues**: Adjust memory optimization settings

### Debug Logging
Enable debug logging in settings to get more detailed information about errors. Logs are stored in the app's Documents directory.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- [Dobby](https://github.com/jmpews/Dobby) for function hooking
- [Luau](https://github.com/Roblox/luau) for the Lua implementation
- All contributors and testers who made this project possible
