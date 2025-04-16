--[[
    Auto-Farm Example Script
    ------------------------
    This script demonstrates a configurable auto-farm implementation
    that can be adapted for various Roblox games.
    
    Compatible with iOS Executor v1.0+
]]

-- Configuration (edit these values for your specific game)
local CONFIG = {
    -- General settings
    Enabled = true,           -- Enable/disable the entire script
    Debug = true,             -- Show debug messages
    RefreshRate = 0.5,        -- Update rate in seconds
    
    -- Target settings
    TargetPath = "Workspace.Drops",  -- Path to collectibles folder
    TargetNames = {"Coin", "Gem", "Diamond"},  -- Names of targets to collect
    TargetTag = nil,          -- Optional tag to filter targets
    MaxDistance = 150,        -- Maximum distance to target
    IgnoreY = true,           -- Ignore Y-axis for distance calculation
    
    -- Character settings
    MoveSpeed = 18,           -- Speed multiplier
    JumpPower = 50,           -- Jump power for obstacles
    AutoRespawn = true,       -- Auto respawn if character dies
    PathfindingEnabled = true, -- Use pathfinding to navigate
    
    -- Game-specific settings
    NoclipEnabled = false,     -- Enable noclip (may cause detection)
    TeleportEnabled = false,   -- Enable teleport (may cause detection)
    CollectDistance = 5,      -- Distance to collect items
    
    -- Obstacles
    AvoidObstacles = true,    -- Try to avoid obstacles
    JumpObstacles = true,     -- Jump over obstacles
    ObstacleHeight = 3,       -- Min height of obstacle to trigger jump
    
    -- Visualization
    ShowTarget = true,        -- Show current target
    ShowPath = true,          -- Show path to target
    MarkerColor = Color3.fromRGB(0, 255, 0)  -- Color for markers
}

-- Script variables
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HRP = Character:WaitForChild("HumanoidRootPart")

local AutoFarm = {
    Running = false,
    CurrentTarget = nil,
    Path = nil,
    Waypoints = {},
    CurrentWaypoint = nil,
    Markers = {},
    Connections = {}
}

-- Utility functions
local function Debug(...)
    if CONFIG.Debug then
        print("[Auto-Farm]", ...)
    end
end

local function GetTargetPosition(target)
    if target:IsA("Model") and target:FindFirstChild("HumanoidRootPart") then
        return target.HumanoidRootPart.Position
    elseif target:IsA("BasePart") then
        return target.Position
    else
        -- For other object types, try to find a primary part or any part
        if target.PrimaryPart then
            return target.PrimaryPart.Position
        else
            for _, child in pairs(target:GetChildren()) do
                if child:IsA("BasePart") then
                    return child.Position
                end
            end
        end
    end
    return nil
end

local function GetDistance(position1, position2)
    if CONFIG.IgnoreY then
        -- Ignore Y-axis for distance calculation
        return ((position1.X - position2.X)^2 + (position1.Z - position2.Z)^2)^0.5
    else
        return (position1 - position2).Magnitude
    end
end

local function GetTargets()
    local targets = {}
    local targetFolder = game
    
    -- Parse the target path
    for _, pathPart in ipairs(CONFIG.TargetPath:split(".")) do
        if targetFolder and targetFolder:FindFirstChild(pathPart) then
            targetFolder = targetFolder:FindFirstChild(pathPart)
        else
            Debug("Invalid target path:", CONFIG.TargetPath)
            return {}
        end
    end
    
    -- Get all targets
    local function processChildren(parent)
        for _, child in pairs(parent:GetChildren()) do
            -- Check if the child is a valid target
            local isTarget = false
            
            -- Check by name
            if CONFIG.TargetNames then
                for _, targetName in ipairs(CONFIG.TargetNames) do
                    if child.Name:find(targetName) then
                        isTarget = true
                        break
                    end
                end
            else
                isTarget = true
            end
            
            -- Check by tag if specified
            if CONFIG.TargetTag and isTarget then
                local collectionService = game:GetService("CollectionService")
                isTarget = collectionService:HasTag(child, CONFIG.TargetTag)
            end
            
            if isTarget then
                local position = GetTargetPosition(child)
                if position then
                    local distance = GetDistance(HRP.Position, position)
                    if distance <= CONFIG.MaxDistance then
                        table.insert(targets, {
                            Object = child,
                            Position = position,
                            Distance = distance
                        })
                    end
                end
            end
            
            -- Recursively process children
            if #child:GetChildren() > 0 then
                processChildren(child)
            end
        end
    end
    
    processChildren(targetFolder)
    
    -- Sort targets by distance
    table.sort(targets, function(a, b)
        return a.Distance < b.Distance
    end)
    
    return targets
end

-- Clear all visual markers
function AutoFarm:ClearMarkers()
    for _, marker in pairs(self.Markers) do
        if marker and marker.Parent then
            marker:Destroy()
        end
    end
    self.Markers = {}
end

-- Create a marker at a position
function AutoFarm:CreateMarker(position, size, color)
    local marker = Instance.new("Part")
    marker.Size = size or Vector3.new(0.5, 0.5, 0.5)
    marker.Position = position
    marker.Anchored = true
    marker.CanCollide = false
    marker.Material = Enum.Material.Neon
    marker.Color = color or CONFIG.MarkerColor
    marker.Transparency = 0.5
    marker.Parent = workspace
    
    table.insert(self.Markers, marker)
    return marker
end

-- Visualize the path to the target
function AutoFarm:VisualizePath()
    self:ClearMarkers()
    
    -- Create target marker
    if self.CurrentTarget and CONFIG.ShowTarget then
        self:CreateMarker(self.CurrentTarget.Position, Vector3.new(1, 1, 1), Color3.fromRGB(255, 0, 0))
    end
    
    -- Create path markers
    if self.Waypoints and CONFIG.ShowPath then
        for _, waypoint in ipairs(self.Waypoints) do
            local color = waypoint == self.CurrentWaypoint 
                and Color3.fromRGB(255, 255, 0) 
                or CONFIG.MarkerColor
            self:CreateMarker(waypoint.Position, Vector3.new(0.5, 0.5, 0.5), color)
        end
    end
end

-- Calculate a path to the target
function AutoFarm:CalculatePath(target)
    if not target or not target.Position then
        Debug("Invalid target for pathfinding")
        return false
    end
    
    if not CONFIG.PathfindingEnabled then
        -- Simple direct path
        self.Waypoints = {
            { Position = target.Position, Action = Enum.PathWaypointAction.Walk }
        }
        self.CurrentWaypoint = self.Waypoints[1]
        return true
    end
    
    -- Use PathfindingService for more complex navigation
    local path = PathfindingService:CreatePath({
        AgentCanJump = true,
        AgentHeight = 5,
        AgentRadius = 2,
        AgentCanClimb = false,
        Costs = {
            Water = 20,
            Door = 5,
            ObstacleSmall = 10,
            ObstacleLarge = 1000,
        }
    })
    
    -- Compute the path
    local success, errorMessage = pcall(function()
        path:ComputeAsync(HRP.Position, target.Position)
    end)
    
    if success and path.Status == Enum.PathStatus.Success then
        self.Waypoints = path:GetWaypoints()
        self.CurrentWaypoint = self.Waypoints[2] -- First point is starting position
        return true
    else
        Debug("Pathfinding failed:", errorMessage or "unknown error")
        -- Fallback to direct path
        self.Waypoints = {
            { Position = target.Position, Action = Enum.PathWaypointAction.Walk }
        }
        self.CurrentWaypoint = self.Waypoints[1]
        return true
    end
end

-- Navigate to the current waypoint
function AutoFarm:NavigateToWaypoint()
    if not self.CurrentWaypoint then
        return false
    end
    
    local position = self.CurrentWaypoint.Position
    local distance = GetDistance(HRP.Position, position)
    
    -- Check if we reached the waypoint
    if distance < 5 then
        local waypointIndex = table.find(self.Waypoints, self.CurrentWaypoint)
        if waypointIndex and waypointIndex < #self.Waypoints then
            self.CurrentWaypoint = self.Waypoints[waypointIndex + 1]
            Debug("Moving to next waypoint")
            return true
        else
            Debug("Reached final waypoint")
            return false
        end
    end
    
    -- Move toward the waypoint
    local moveDirection = (position - HRP.Position).Unit
    Humanoid:Move(Vector3.new(moveDirection.X, 0, moveDirection.Z) * CONFIG.MoveSpeed)
    
    -- Check for obstacles
    if CONFIG.AvoidObstacles then
        local ray = Ray.new(HRP.Position, moveDirection * 5)
        local hit, hitPosition = workspace:FindPartOnRayWithIgnoreList(ray, {Character})
        
        if hit and hit.CanCollide then
            -- Check if we should jump over the obstacle
            if CONFIG.JumpObstacles and hit.Size.Y <= CONFIG.ObstacleHeight then
                Humanoid.Jump = true
            end
        end
    end
    
    -- Handle waypoint action
    if self.CurrentWaypoint.Action == Enum.PathWaypointAction.Jump then
        Humanoid.Jump = true
    end
    
    return true
end

-- Check if we're close enough to collect the target
function AutoFarm:TryCollect()
    if not self.CurrentTarget or not self.CurrentTarget.Object then
        return false
    end
    
    local distance = GetDistance(HRP.Position, self.CurrentTarget.Position)
    
    -- If close enough, collect the target
    if distance <= CONFIG.CollectDistance then
        Debug("Collecting target:", self.CurrentTarget.Object.Name)
        
        if CONFIG.TeleportEnabled then
            -- Teleport to the target (may be detected by anti-cheat)
            HRP.CFrame = CFrame.new(self.CurrentTarget.Position)
        end
        
        -- Try to fire touch events by touching the target
        local targetPart = self.CurrentTarget.Object
        if not targetPart:IsA("BasePart") then
            -- Find a part to touch
            if targetPart:IsA("Model") and targetPart.PrimaryPart then
                targetPart = targetPart.PrimaryPart
            else
                for _, child in pairs(targetPart:GetChildren()) do
                    if child:IsA("BasePart") then
                        targetPart = child
                        break
                    end
                end
            end
        end
        
        -- Create a temporary part to force a touch event
        if targetPart and targetPart:IsA("BasePart") then
            local tempPart = Instance.new("Part")
            tempPart.Size = Vector3.new(0.1, 0.1, 0.1)
            tempPart.Transparency = 1
            tempPart.CanCollide = false
            tempPart.CFrame = targetPart.CFrame
            tempPart.Parent = workspace
            tempPart.CFrame = HRP.CFrame
            tempPart.CFrame = targetPart.CFrame
            
            -- Remove the temporary part after a short delay
            spawn(function()
                wait(0.5)
                if tempPart and tempPart.Parent then
                    tempPart:Destroy()
                end
            end)
        end
        
        return true
    end
    
    return false
end

-- Enable noclip
function AutoFarm:EnableNoclip()
    if CONFIG.NoclipEnabled then
        -- Create noclip connection if it doesn't exist
        if not self.NoclipConnection then
            self.NoclipConnection = RunService.Stepped:Connect(function()
                if Character and Character:IsDescendantOf(workspace) then
                    for _, part in pairs(Character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end)
            Debug("Noclip enabled")
        end
    end
end

-- Disable noclip
function AutoFarm:DisableNoclip()
    if self.NoclipConnection then
        self.NoclipConnection:Disconnect()
        self.NoclipConnection = nil
        Debug("Noclip disabled")
    end
end

-- Main update loop
function AutoFarm:Update()
    -- Check if character is alive
    if not Character or not Character:IsDescendantOf(workspace) or not Humanoid or Humanoid.Health <= 0 then
        if CONFIG.AutoRespawn then
            Debug("Character died, waiting for respawn")
            Character = nil
            
            -- Wait for character to respawn
            self.Connections[#self.Connections + 1] = LocalPlayer.CharacterAdded:Connect(function(newCharacter)
                Character = newCharacter
                Humanoid = Character:WaitForChild("Humanoid")
                HRP = Character:WaitForChild("HumanoidRootPart")
                Debug("Character respawned")
                self.Connections[#self.Connections]:Disconnect()
                self.Connections[#self.Connections] = nil
            end)
        else
            Debug("Character died, stopping auto-farm")
            self:Stop()
            return
        end
    end
    
    -- Find a new target if we don't have one
    if not self.CurrentTarget then
        local targets = GetTargets()
        if #targets > 0 then
            self.CurrentTarget = targets[1]
            Debug("New target:", self.CurrentTarget.Object.Name, "Distance:", self.CurrentTarget.Distance)
            if not self:CalculatePath(self.CurrentTarget) then
                Debug("Failed to calculate path to target")
                self.CurrentTarget = nil
                return
            end
        else
            Debug("No targets found")
            return
        end
    end
    
    -- Try to collect the target if we're close enough
    if self:TryCollect() then
        Debug("Target collected, finding new target")
        self.CurrentTarget = nil
        return
    end
    
    -- Update path visualization
    if CONFIG.ShowPath or CONFIG.ShowTarget then
        self:VisualizePath()
    end
    
    -- Navigate to the target
    if not self:NavigateToWaypoint() then
        Debug("Failed to navigate to waypoint, finding new target")
        self.CurrentTarget = nil
    end
end

-- Start auto-farm
function AutoFarm:Start()
    if self.Running then
        Debug("Auto-farm already running")
        return
    end
    
    Debug("Starting auto-farm")
    self.Running = true
    
    -- Set jump power
    Humanoid.JumpPower = CONFIG.JumpPower
    
    -- Enable noclip if configured
    self:EnableNoclip()
    
    -- Connect main update loop
    self.UpdateConnection = RunService.Heartbeat:Connect(function()
        if not self.Running then return end
        pcall(function()
            self:Update()
        end)
    end)
    
    -- Connect character died event for auto-respawn
    if CONFIG.AutoRespawn then
        self.DeathConnection = Humanoid.Died:Connect(function()
            Debug("Character died")
            if CONFIG.AutoRespawn then
                Debug("Auto-respawn enabled, waiting for respawn")
            else
                self:Stop()
            end
        end)
    end
end

-- Stop auto-farm
function AutoFarm:Stop()
    if not self.Running then
        Debug("Auto-farm not running")
        return
    end
    
    Debug("Stopping auto-farm")
    self.Running = false
    
    -- Disconnect update loop
    if self.UpdateConnection then
        self.UpdateConnection:Disconnect()
        self.UpdateConnection = nil
    end
    
    -- Disconnect death connection
    if self.DeathConnection then
        self.DeathConnection:Disconnect()
        self.DeathConnection = nil
    end
    
    -- Disable noclip
    self:DisableNoclip()
    
    -- Clear visual markers
    self:ClearMarkers()
    
    -- Reset current target
    self.CurrentTarget = nil
    self.Waypoints = {}
    self.CurrentWaypoint = nil
    
    -- Reset humanoid movement
    if Humanoid then
        Humanoid:Move(Vector3.new(0, 0, 0))
        Humanoid.JumpPower = 50
    end
    
    -- Disconnect all connections
    for _, connection in pairs(self.Connections) do
        if connection.Connected then
            connection:Disconnect()
        end
    end
    self.Connections = {}
end

-- Toggle auto-farm on/off
function AutoFarm:Toggle()
    if self.Running then
        self:Stop()
    else
        self:Start()
    end
    return self.Running
end

-- Create UI for controls
function AutoFarm:CreateUI()
    -- Check if the UI already exists
    if game:GetService("CoreGui"):FindFirstChild("AutoFarmUI") then
        game:GetService("CoreGui"):FindFirstChild("AutoFarmUI"):Destroy()
    end
    
    -- Create ScreenGui
    local gui = Instance.new("ScreenGui")
    gui.Name = "AutoFarmUI"
    gui.ResetOnSpawn = false
    
    -- Set parent based on CoreGui availability
    pcall(function()
        gui.Parent = game:GetService("CoreGui")
    end)
    
    if not gui.Parent then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    
    -- Create main frame
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 220)
    frame.Position = UDim2.new(0, 10, 0.5, -110)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    
    -- Add drag functionality
    local dragging = false
    local dragInput
    local dragStart
    local startPos
    
    local function updateDrag(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            updateDrag(input)
        end
    end)
    
    -- Create title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = frame
    
    -- Add title text
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -30, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Auto-Farm"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 16
    title.Font = Enum.Font.SourceSansBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    -- Add close button
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 20, 0, 20)
    closeButton.Position = UDim2.new(1, -25, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Font = Enum.Font.SourceSansBold
    closeButton.TextSize = 14
    closeButton.Parent = titleBar
    
    closeButton.MouseButton1Click:Connect(function()
        gui:Destroy()
    end)
    
    -- Create content area
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, 0, 1, -30)
    content.Position = UDim2.new(0, 0, 0, 30)
    content.BackgroundTransparency = 1
    content.Parent = frame
    
    -- Add toggle button
    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(0.9, 0, 0, 40)
    toggleButton.Position = UDim2.new(0.05, 0, 0, 10)
    toggleButton.BackgroundColor3 = self.Running and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(180, 0, 0)
    toggleButton.Text = self.Running and "STOP AUTO-FARM" or "START AUTO-FARM"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.Font = Enum.Font.SourceSansBold
    toggleButton.TextSize = 16
    toggleButton.Parent = content
    
    toggleButton.MouseButton1Click:Connect(function()
        local running = self:Toggle()
        toggleButton.Text = running and "STOP AUTO-FARM" or "START AUTO-FARM"
        toggleButton.BackgroundColor3 = running and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(180, 0, 0)
    end)
    
    -- Create settings section
    local settingsLabel = Instance.new("TextLabel")
    settingsLabel.Size = UDim2.new(1, 0, 0, 20)
    settingsLabel.Position = UDim2.new(0, 0, 0, 60)
    settingsLabel.BackgroundTransparency = 1
    settingsLabel.Text = "Settings"
    settingsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    settingsLabel.TextSize = 14
    settingsLabel.Font = Enum.Font.SourceSansBold
    settingsLabel.Parent = content
    
    -- Helper function to create toggle settings
    local function createToggle(name, property, yPos)
        local toggle = Instance.new("TextButton")
        toggle.Size = UDim2.new(0.9, 0, 0, 25)
        toggle.Position = UDim2.new(0.05, 0, 0, yPos)
        toggle.BackgroundColor3 = CONFIG[property] and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(120, 0, 0)
        toggle.Text = name .. ": " .. (CONFIG[property] and "ON" or "OFF")
        toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggle.TextSize = 14
        toggle.Font = Enum.Font.SourceSans
        toggle.Parent = content
        
        toggle.MouseButton1Click:Connect(function()
            CONFIG[property] = not CONFIG[property]
            toggle.BackgroundColor3 = CONFIG[property] and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(120, 0, 0)
            toggle.Text = name .. ": " .. (CONFIG[property] and "ON" or "OFF")
            
            -- Special case for noclip
            if property == "NoclipEnabled" then
                if CONFIG[property] then
                    self:EnableNoclip()
                else
                    self:DisableNoclip()
                end
            end
        end)
    end
    
    -- Create toggle buttons
    createToggle("Show Path", "ShowPath", 90)
    createToggle("Noclip", "NoclipEnabled", 120)
    createToggle("Pathfinding", "PathfindingEnabled", 150)
    
    -- Add status indicator
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0.9, 0, 0, 20)
    statusLabel.Position = UDim2.new(0.05, 0, 1, -25)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Status: " .. (self.Running and "Running" or "Stopped")
    statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    statusLabel.TextSize = 14
    statusLabel.Font = Enum.Font.SourceSans
    statusLabel.Parent = content
    
    -- Update status periodically
    spawn(function()
        while gui and gui.Parent do
            if statusLabel and statusLabel.Parent then
                statusLabel.Text = "Status: " .. (self.Running and "Running" or "Stopped")
                if self.CurrentTarget then
                    statusLabel.Text = statusLabel.Text .. " | Target: " .. self.CurrentTarget.Object.Name
                end
            else
                break
            end
            wait(0.5)
        end
    end)
    
    return gui
end

-- Initialize the auto-farm
AutoFarm:CreateUI()
if CONFIG.Enabled then
    AutoFarm:Start()
end

-- Return the auto-farm API for external control
return AutoFarm
