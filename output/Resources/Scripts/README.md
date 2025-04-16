# Roblox Executor Script Examples

This directory contains example scripts for the iOS Roblox Executor. These scripts demonstrate the capabilities of the executor and serve as examples for creating your own scripts.

## Usage

To use these scripts:

1. Open the executor UI by tapping the floating button
2. Navigate to the "Editor" tab
3. Copy and paste a script into the editor
4. Tap "Execute" to run the script
5. Alternatively, save scripts for later use with the "Save" button

## Example Scripts

### ESP (`examples/esp.lua`)

A visual player highlighting system with customizable features:

- **Boxes**: Draw boxes around players
- **Name Tags**: Display player names above their characters
- **Distance**: Show distance to other players
- **Health Bars**: Visual health indicators with gradient colors
- **Tracers**: Lines pointing to players from the screen center
- **Team Check**: Only highlight enemies
- **UI Controls**: Toggle individual features on/off

```lua
-- Load and execute the ESP script
local ESP = loadstring(readfile("executor/Scripts/examples/esp.lua"))()

-- Configure ESP after loading (optional)
ESP.TeamColor = true      -- Use team colors for ESP
ESP.BoxesEnabled = true   -- Enable boxes
ESP.TracersEnabled = true -- Enable tracer lines

-- Toggle ESP on/off
ESP:Toggle()
```

### Auto-Farm (`examples/auto_farm.lua`)

Automated resource collection with advanced pathfinding:

- **Intelligent Navigation**: Finds optimal paths to targets
- **Obstacle Avoidance**: Jumps over or navigates around obstacles
- **Target Prioritization**: Collects closest items first
- **Visualization**: Shows pathfinding in real-time
- **Custom Targeting**: Easily configurable for different games
- **UI Controls**: Full control panel with status tracking

```lua
-- Load and execute the Auto-Farm script
local AutoFarm = loadstring(readfile("executor/Scripts/examples/auto_farm.lua"))()

-- Configure auto-farm settings (optional)
AutoFarm.CONFIG.TargetPath = "Workspace.Collectibles" -- Change target folder
AutoFarm.CONFIG.TargetNames = {"Coin", "Gem"}         -- Change target names
AutoFarm.CONFIG.NoclipEnabled = true                  -- Enable noclip

-- Start/stop the auto-farm
AutoFarm:Start() -- Start auto-farming
AutoFarm:Stop()  -- Stop auto-farming
```

### Aimbot (`examples/aimbot.lua`)

Precision targeting system with extensive configuration:

- **FOV Circle**: Visual representation of targeting range
- **Target Selection**: Prioritizes by distance, health, or custom criteria
- **Movement Prediction**: Leads shots for moving targets
- **Team Check**: Only targets enemies
- **Visibility Check**: Only targets visible players
- **Smoothing**: Adjustable aim speed and precision
- **Settings UI**: Comprehensive configuration panel

```lua
-- Load and execute the Aimbot script
local Aimbot = loadstring(readfile("executor/Scripts/examples/aimbot.lua"))()

-- Configure aimbot settings (optional)
Aimbot.CONFIG.FOV = 300                  -- Adjust FOV size
Aimbot.CONFIG.AimSmoothing = 0.3         -- Adjust aim smoothness
Aimbot.CONFIG.TargetPart = "Head"        -- Target the head
Aimbot.CONFIG.AutoShoot = false          -- Disable auto-shooting

-- Toggle aimbot on/off
Aimbot:Toggle()
```

## Creating Your Own Scripts

These examples serve as a foundation for creating your own scripts:

1. Study the example scripts to understand their structure
2. Use the same patterns for UI creation, error handling, and cleanup
3. Test scripts incrementally, starting with basic functionality
4. Use the console to debug issues (`print()` statements appear in the Console tab)
5. Save working scripts for future use

## Script Guidelines

For best results and to avoid detection:

- **Avoid Excessive Teleportation**: Rapid teleportation can trigger anti-cheat
- **Use Smoothing**: Add smooth transitions for character movement and camera changes
- **Implement Delays**: Add delays between actions to appear more human-like
- **Clean Up Resources**: Always clean up created instances when your script stops
- **Handle Errors**: Use pcall() to prevent your script from crashing the game
- **Optimize Performance**: Minimize the use of expensive operations in loops

## Advanced Features

The executor supports these advanced features in your scripts:

- **File System Access**: Read/write files with `readfile()` and `writefile()`
- **HTTP Requests**: Make web requests with `http.request()`
- **Drawing Library**: Create persistent UI elements with the Drawing library
- **Memory Manipulation**: Access and modify game memory with the provided APIs
- **Function Hooking**: Hook game functions to modify their behavior

For more examples and script requests, visit our community forums or Discord server.
