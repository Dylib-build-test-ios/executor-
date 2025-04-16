--[[
    Advanced Aimbot Example Script
    ------------------------------
    This script demonstrates a full-featured aimbot implementation
    with configuration options, FOV circle, and target selection logic.
    
    Compatible with iOS Executor v1.0+
]]

-- Configuration
local CONFIG = {
    -- General Settings
    Enabled = true,               -- Master toggle
    AimKey = Enum.UserInputType.Touch, -- Key to hold for aiming (Touch screen for iOS, change to MouseButton2 for PC)
    TeamCheck = true,             -- Only target enemies
    VisibilityCheck = true,       -- Only target visible players
    AliveCheck = true,            -- Only target alive players
    
    -- Targeting Settings
    TargetPart = "Head",          -- Part to aim at (Head, HumanoidRootPart, Torso)
    TargetPriority = "Distance",  -- Priority method (Distance, Health, Random)
    MaxDistance = 1000,           -- Maximum distance to target
    
    -- Aim Settings
    AimSmoothing = 0.5,           -- Smoothing factor (0 = instant, 1 = very slow)
    AimAccuracy = 0.2,            -- Random aim variation (0 = perfect)
    PredictMovement = true,       -- Predict target movement
    PredictionFactor = 0.165,     -- How much to predict (higher = more)
    
    -- FOV Settings
    FOVEnabled = true,            -- Enable FOV circle
    FOV = 400,                    -- FOV circle radius
    FOVSides = 60,                -- FOV circle sides (higher = smoother)
    FOVTransparency = 0.6,        -- FOV circle transparency
    FOVThickness = 1.0,           -- FOV circle thickness
    FOVColor = Color3.fromRGB(255, 255, 255), -- FOV circle color
    FOVFilled = false,            -- Fill FOV circle
    
    -- Visual Settings
    ShowTargetInfo = true,        -- Show target information
    SnapLines = true,             -- Draw lines to targets
    SnapLineColor = Color3.fromRGB(255, 0, 0), -- Snap line color
    
    -- Whitelist/Blacklist
    Whitelist = {},               -- Usernames to prioritize
    Blacklist = {},               -- Usernames to ignore
    
    -- Advanced Settings
    AimMethodSilent = false,      -- Use silent aim (less detectable)
    RecoilControl = true,         -- Reduce weapon recoil
    RecoilAmount = 0.7,           -- Recoil control amount (0-1)
    AutoShoot = false,            -- Automatically fire when locked on
    AutoShootDelay = 0.1,         -- Delay between auto shots
    WallCheckRaycast = true       -- Use raycasting for wall checks
}

-- Variables
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local Aimbot = {
    Target = nil,                 -- Current target
    IsAiming = false,             -- Whether aimbot is active
    FOVCircle = nil,              -- FOV circle drawing
    SnapLines = {},               -- Snap line drawings
    TargetInfo = nil,             -- Target info drawing
    Connections = {},             -- Event connections
    LastAutoShoot = 0             -- Time of last auto shoot
}

-- Drawing utilities
local function CreateDrawing(type, properties)
    local drawing = Drawing.new(type)
    for k, v in pairs(properties or {}) do
        drawing[k] = v
    end
    return drawing
}

-- Initialize the FOV circle
function Aimbot:InitializeFOV()
    if self.FOVCircle then
        self.FOVCircle:Remove()
    end

    self.FOVCircle = CreateDrawing("Circle", {
        Visible = CONFIG.Enabled and CONFIG.FOVEnabled,
        Radius = CONFIG.FOV,
        Color = CONFIG.FOVColor,
        Thickness = CONFIG.FOVThickness,
        Transparency = CONFIG.FOVTransparency,
        NumSides = CONFIG.FOVSides,
        Filled = CONFIG.FOVFilled
    })
end

-- Update FOV circle position
function Aimbot:UpdateFOV()
    if self.FOVCircle then
        self.FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        self.FOVCircle.Radius = CONFIG.FOV
        self.FOVCircle.NumSides = CONFIG.FOVSides
        self.FOVCircle.Thickness = CONFIG.FOVThickness
        self.FOVCircle.Transparency = CONFIG.FOVTransparency
        self.FOVCircle.Color = CONFIG.FOVColor
        self.FOVCircle.Filled = CONFIG.FOVFilled
        self.FOVCircle.Visible = CONFIG.Enabled and CONFIG.FOVEnabled
    end
end

-- Initialize target info display
function Aimbot:InitializeTargetInfo()
    if self.TargetInfo then
        self.TargetInfo:Remove()
    end
    
    self.TargetInfo = CreateDrawing("Text", {
        Visible = false,
        Size = 18,
        Center = true,
        Outline = true,
        OutlineColor = Color3.new(0, 0, 0),
        Color = Color3.new(1, 1, 1),
        Font = 2,
    })
end

-- Clean up snap lines
function Aimbot:ClearSnapLines()
    for _, line in pairs(self.SnapLines) do
        if line then
            line:Remove()
        end
    end
    self.SnapLines = {}
end

-- Update target info display
function Aimbot:UpdateTargetInfo()
    if not self.TargetInfo then return end
    
    if self.Target and CONFIG.ShowTargetInfo then
        local targetHumanoid = self.Target.Character:FindFirstChildOfClass("Humanoid")
        local health = targetHumanoid and math.floor(targetHumanoid.Health) or "?"
        local maxHealth = targetHumanoid and math.floor(targetHumanoid.MaxHealth) or "?"
        
        self.TargetInfo.Text = string.format(
            "Target: %s\nHealth: %s/%s\nDistance: %d",
            self.Target.Name,
            health,
            maxHealth,
            (Camera.CFrame.Position - self.Target.Character[CONFIG.TargetPart].Position).Magnitude
        )
        
        self.TargetInfo.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y - 100)
        self.TargetInfo.Visible = true
    else
        self.TargetInfo.Visible = false
    end
end

-- Update snap lines
function Aimbot:UpdateSnapLines()
    -- Clear existing lines
    self:ClearSnapLines()
    
    -- If disabled or no targets, return
    if not CONFIG.Enabled or not CONFIG.SnapLines then
        return
    end
    
    -- Find valid targets
    local validTargets = self:GetValidTargets()
    
    -- Create lines for each target
    for _, target in pairs(validTargets) do
        local screenPos, onScreen = Camera:WorldToViewportPoint(target.Position)
        
        if onScreen then
            local line = CreateDrawing("Line", {
                Visible = true,
                From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y),
                To = Vector2.new(screenPos.X, screenPos.Y),
                Color = target.Player == self.Target and Color3.fromRGB(255, 0, 0) or CONFIG.SnapLineColor,
                Thickness = 1,
                Transparency = 0.6
            })
            
            table.insert(self.SnapLines, line)
        end
    end
end

-- Check if player is on our team
function Aimbot:IsTeammate(player)
    if not CONFIG.TeamCheck then
        return false
    end
    
    -- Different team check methods depending on game
    local playerTeam = player.Team
    local localTeam = LocalPlayer.Team
    
    -- Basic team check
    if playerTeam and localTeam then
        return playerTeam == localTeam
    end
    
    -- Try team color check
    if playerTeam and playerTeam.TeamColor and localTeam and localTeam.TeamColor then
        return playerTeam.TeamColor == localTeam.TeamColor
    end
    
    -- Try checking friendly fire in team settings
    local teamService = game:GetService("Teams")
    if teamService and teamService:FindFirstChild("FriendlyFire") then
        return not teamService.FriendlyFire.Value
    end
    
    return false
end

-- Check if target is visible
function Aimbot:IsVisible(targetPart)
    if not CONFIG.VisibilityCheck then
        return true
    end
    
    if not CONFIG.WallCheckRaycast then
        return true
    end
    
    local character = LocalPlayer.Character
    if not character then return false end
    
    local head = character:FindFirstChild("Head")
    if not head then return false end
    
    local ray = Ray.new(head.Position, targetPart.Position - head.Position)
    local hit, _ = workspace:FindPartOnRayWithIgnoreList(ray, {character, targetPart.Parent})
    
    return hit == nil or hit:IsDescendantOf(targetPart.Parent)
end

-- Check if player is alive
function Aimbot:IsAlive(player)
    if not CONFIG.AliveCheck then
        return true
    end
    
    local character = player.Character
    if not character then return false end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    
    return humanoid.Health > 0
end

-- Check if player is in FOV
function Aimbot:IsInFOV(targetPosition)
    local screenPosition, onScreen = Camera:WorldToViewportPoint(targetPosition)
    
    if not onScreen then
        return false
    end
    
    if not CONFIG.FOVEnabled then
        return true
    end
    
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local distance = (Vector2.new(screenPosition.X, screenPosition.Y) - center).Magnitude
    
    return distance <= CONFIG.FOV
end

-- Get valid targets
function Aimbot:GetValidTargets()
    local targets = {}
    
    for _, player in pairs(Players:GetPlayers()) do
        -- Skip self
        if player == LocalPlayer then continue end
        
        -- Skip blacklisted players
        if table.find(CONFIG.Blacklist, player.Name) then continue end
        
        -- Check if player is on our team
        if self:IsTeammate(player) then continue end
        
        -- Check if player is alive
        if not self:IsAlive(player) then continue end
        
        -- Check if character exists
        local character = player.Character
        if not character then continue end
        
        -- Check if target part exists
        local targetPart = character:FindFirstChild(CONFIG.TargetPart)
        if not targetPart then continue end
        
        -- Check if target is visible
        if not self:IsVisible(targetPart) then continue end
        
        -- Check distance
        local distance = (Camera.CFrame.Position - targetPart.Position).Magnitude
        if distance > CONFIG.MaxDistance then continue end
        
        -- Check if target is in FOV
        if not self:IsInFOV(targetPart.Position) then continue end
        
        -- Get priority value based on targeting method
        local priorityValue = 0
        
        if CONFIG.TargetPriority == "Distance" then
            priorityValue = -distance  -- Negative so closer = higher priority
        elseif CONFIG.TargetPriority == "Health" then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            priorityValue = humanoid and -humanoid.Health or 0  -- Negative so lower health = higher priority
        elseif CONFIG.TargetPriority == "Random" then
            priorityValue = math.random()
        end
        
        -- Boost priority for whitelisted players
        if table.find(CONFIG.Whitelist, player.Name) then
            priorityValue = priorityValue + 1000000  -- Essentially guarantees top priority
        end
        
        -- Add valid target
        table.insert(targets, {
            Player = player,
            Position = targetPart.Position,
            Part = targetPart,
            Distance = distance,
            Priority = priorityValue
        })
    end
    
    -- Sort by priority
    table.sort(targets, function(a, b)
        return a.Priority > b.Priority
    end)
    
    return targets
end

-- Predict target movement
function Aimbot:PredictTargetPosition(targetPart)
    if not CONFIG.PredictMovement then
        return targetPart.Position
    end
    
    -- Basic velocity-based prediction
    local velocity = targetPart.Velocity
    local prediction = targetPart.Position + (velocity * CONFIG.PredictionFactor)
    
    return prediction
end

-- Get aim position with accuracy variation
function Aimbot:GetAimPosition(targetPos)
    if CONFIG.AimAccuracy <= 0 then
        return targetPos
    end
    
    -- Add slight random variation to aim
    local spread = Vector3.new(
        (math.random() - 0.5) * CONFIG.AimAccuracy,
        (math.random() - 0.5) * CONFIG.AimAccuracy,
        (math.random() - 0.5) * CONFIG.AimAccuracy
    )
    
    return targetPos + spread
end

-- Perform aiming
function Aimbot:AimAt(targetPos)
    local currentCameraCFrame = Camera.CFrame
    local targetCFrame = CFrame.new(currentCameraCFrame.Position, targetPos)
    
    if CONFIG.AimMethodSilent then
        -- Implementation of silent aim would depend on the game
        -- This is just a placeholder
        -- Real silent aim requires hooking into the game's aiming system
        return targetCFrame
    else
        -- Calculate the difference in rotation
        local rotDifference = currentCameraCFrame.Rotation:Inverse() * targetCFrame.Rotation
        
        -- Convert to angles
        local x, y, z = rotDifference:ToEulerAnglesXYZ()
        
        -- Apply smoothing
        local smoothingFactor = math.clamp(1 - CONFIG.AimSmoothing, 0, 1)
        local smoothedRotation = currentCameraCFrame.Rotation * CFrame.Angles(
            x * smoothingFactor,
            y * smoothingFactor,
            z * smoothingFactor
        )
        
        -- Set new camera CFrame
        Camera.CFrame = CFrame.new(currentCameraCFrame.Position) * smoothedRotation
    end
    
    return nil -- Normal aiming doesn't need to return anything
end

-- Attempt auto shooting
function Aimbot:TryAutoShoot()
    if not CONFIG.AutoShoot or not self.Target then
        return
    end
    
    local time = tick()
    if time - self.LastAutoShoot < CONFIG.AutoShootDelay then
        return
    end
    
    -- Simulate mouse click
    mouse1click()
    self.LastAutoShoot = time
end

-- Main aimbot update function
function Aimbot:Update()
    -- Update FOV circle
    self:UpdateFOV()
    
    -- Check if aimbot is enabled
    if not CONFIG.Enabled then
        self.Target = nil
        self:UpdateTargetInfo()
        self:ClearSnapLines()
        return
    end
    
    -- Check if aiming key is pressed
    if not self.IsAiming and not CONFIG.AimMethodSilent then
        self.Target = nil
        self:UpdateTargetInfo()
        self:UpdateSnapLines()
        return
    end
    
    -- Get valid targets
    local targets = self:GetValidTargets()
    
    -- Set best target
    self.Target = targets[1] and targets[1].Player or nil
    
    -- Update target info
    self:UpdateTargetInfo()
    
    -- Update snap lines
    self:UpdateSnapLines()
    
    -- If no target, return
    if not self.Target then
        return
    end
    
    -- Get target part
    local character = self.Target.Character
    if not character then return end
    
    local targetPart = character:FindFirstChild(CONFIG.TargetPart)
    if not targetPart then return end
    
    -- Predict target position
    local predictedPos = self:PredictTargetPosition(targetPart)
    
    -- Add accuracy variation
    local aimPos = self:GetAimPosition(predictedPos)
    
    -- Aim at target
    self:AimAt(aimPos)
    
    -- Try auto shoot
    self:TryAutoShoot()
end

-- Initialize aimbot
function Aimbot:Initialize()
    print("Initializing aimbot...")
    
    -- Initialize FOV circle
    self:InitializeFOV()
    
    -- Initialize target info
    self:InitializeTargetInfo()
    
    -- Connect input events
    table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == CONFIG.AimKey then
            self.IsAiming = true
        end
    end))
    
    table.insert(self.Connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == CONFIG.AimKey then
            self.IsAiming = false
        end
    end))
    
    -- Connect render stepped for smooth updates
    table.insert(self.Connections, RunService.RenderStepped:Connect(function()
        self:Update()
    end))
    
    -- Connect window resize event
    table.insert(self.Connections, Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        self:UpdateFOV()
    end))
    
    print("Aimbot initialized successfully!")
end

-- Cleanup aimbot
function Aimbot:Cleanup()
    print("Cleaning up aimbot...")
    
    -- Remove FOV circle
    if self.FOVCircle then
        self.FOVCircle:Remove()
        self.FOVCircle = nil
    end
    
    -- Remove target info
    if self.TargetInfo then
        self.TargetInfo:Remove()
        self.TargetInfo = nil
    end
    
    -- Clear snap lines
    self:ClearSnapLines()
    
    -- Disconnect all connections
    for _, connection in pairs(self.Connections) do
        connection:Disconnect()
    end
    self.Connections = {}
    
    print("Aimbot cleaned up successfully!")
end

-- Create aimbot settings UI
function Aimbot:CreateUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AimbotUI"
    
    -- Try to put it in CoreGui
    pcall(function()
        screenGui.Parent = game:GetService("CoreGui")
    end)
    
    if not screenGui.Parent then
        screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
    
    -- Create main frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 250, 0, 350)
    mainFrame.Position = UDim2.new(1, -260, 0.5, -175)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui
    
    -- Create title bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    -- Create title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -30, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Aimbot Settings"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 16
    title.Font = Enum.Font.SourceSansBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    -- Create close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 20, 0, 20)
    closeButton.Position = UDim2.new(1, -25, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Font = Enum.Font.SourceSansBold
    closeButton.TextSize = 14
    closeButton.Parent = titleBar
    
    closeButton.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    -- Create scroll frame for settings
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "SettingsScroll"
    scrollFrame.Size = UDim2.new(1, -20, 1, -40)
    scrollFrame.Position = UDim2.new(0, 10, 0, 35)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 600) -- Will be adjusted
    scrollFrame.Parent = mainFrame
    
    -- Helper function to create settings
    local yOffset = 10
    local function createToggle(name, property)
        local toggle = Instance.new("Frame")
        toggle.Name = name.."Toggle"
        toggle.Size = UDim2.new(1, 0, 0, 30)
        toggle.Position = UDim2.new(0, 0, 0, yOffset)
        toggle.BackgroundTransparency = 1
        toggle.Parent = scrollFrame
        
        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.Size = UDim2.new(0.7, 0, 1, 0)
        label.Position = UDim2.new(0, 0, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextSize = 14
        label.Font = Enum.Font.SourceSans
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = toggle
        
        local button = Instance.new("TextButton")
        button.Name = "Button"
        button.Size = UDim2.new(0.3, 0, 0.8, 0)
        button.Position = UDim2.new(0.7, 0, 0.1, 0)
        button.BackgroundColor3 = CONFIG[property] and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
        button.Text = CONFIG[property] and "ON" or "OFF"
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.Font = Enum.Font.SourceSansBold
        button.TextSize = 14
        button.Parent = toggle
        
        button.MouseButton1Click:Connect(function()
            CONFIG[property] = not CONFIG[property]
            button.BackgroundColor3 = CONFIG[property] and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
            button.Text = CONFIG[property] and "ON" or "OFF"
        end)
        
        yOffset = yOffset + 35
        return toggle
    end
    
    -- Create settings
    createToggle("Enabled", "Enabled")
    createToggle("Team Check", "TeamCheck")
    createToggle("Visibility Check", "VisibilityCheck")
    createToggle("Alive Check", "AliveCheck")
    createToggle("Predict Movement", "PredictMovement")
    createToggle("FOV Circle", "FOVEnabled")
    createToggle("Show Target Info", "ShowTargetInfo")
    createToggle("Snap Lines", "SnapLines")
    createToggle("Silent Aim", "AimMethodSilent")
    createToggle("Auto Shoot", "AutoShoot")
    
    -- Adjust canvas size
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset + 10)
    
    return screenGui
end

-- Toggle aimbot on/off
function Aimbot:Toggle()
    CONFIG.Enabled = not CONFIG.Enabled
    print("Aimbot " .. (CONFIG.Enabled and "enabled" or "disabled"))
    
    if self.FOVCircle then
        self.FOVCircle.Visible = CONFIG.Enabled and CONFIG.FOVEnabled
    end
    
    return CONFIG.Enabled
end

-- Initialize aimbot on script execution
Aimbot:Initialize()
Aimbot:CreateUI()

-- Return the aimbot API for external access
return Aimbot
