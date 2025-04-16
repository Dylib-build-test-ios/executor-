--[[
    Executor ESP Example Script
    ----------------------------
    This script demonstrates a basic ESP (Extra Sensory Perception) implementation
    for Roblox. It highlights players and important objects with boxes and labels.
    
    Compatible with iOS Executor v1.0+
]]

local ESP = {
    Enabled = true,
    TeamCheck = false,      -- ESP only enemies
    TeamColor = true,       -- Use team color for ESP
    BoxesEnabled = true,    -- Draw boxes around players
    NamesEnabled = true,    -- Show player names
    DistanceEnabled = true, -- Show distance to players
    HealthEnabled = true,   -- Show health bars
    TracersEnabled = false, -- Draw lines to players
    
    -- Visual settings
    BoxColor = Color3.fromRGB(255, 255, 255),
    NameColor = Color3.fromRGB(255, 255, 255),
    DistanceColor = Color3.fromRGB(175, 175, 175),
    TracerColor = Color3.fromRGB(255, 255, 255),
    HealthColor = Color3.fromRGB(0, 255, 0),
    HealthTransparency = 0.5,
    
    -- Performance settings
    RefreshRate = 10,       -- ESP refresh rate (ms)
    MaxDistance = 1000,     -- Max render distance
    
    -- Internal
    Objects = {},
    Connections = {},
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    Camera = workspace.CurrentCamera
}

-- Utility function to create a new drawing
function ESP:NewDrawing(type, properties)
    local drawing = Drawing.new(type)
    for k, v in pairs(properties or {}) do
        drawing[k] = v
    end
    return drawing
end

-- Create ESP elements for a player
function ESP:CreateESP(player)
    if player == ESP.Players.LocalPlayer then return end
    
    local esp = {
        Player = player,
        Character = player.Character,
        Box = ESP:NewDrawing("Square", {
            Thickness = 1,
            Filled = false,
            Transparency = 1,
            Visible = false,
            ZIndex = 1
        }),
        Name = ESP:NewDrawing("Text", {
            Size = 13,
            Center = true,
            Outline = true,
            Transparency = 1,
            Visible = false,
            ZIndex = 2
        }),
        Distance = ESP:NewDrawing("Text", {
            Size = 11,
            Center = true,
            Outline = true,
            Transparency = 1,
            Visible = false,
            ZIndex = 2
        }),
        Tracer = ESP:NewDrawing("Line", {
            Thickness = 1,
            Transparency = 1,
            Visible = false,
            ZIndex = 1
        }),
        HealthBar = ESP:NewDrawing("Square", {
            Thickness = 1,
            Filled = true,
            Transparency = ESP.HealthTransparency,
            Visible = false,
            ZIndex = 1
        }),
        HealthBarOutline = ESP:NewDrawing("Square", {
            Thickness = 1,
            Filled = false,
            Transparency = 1,
            Visible = false,
            ZIndex = 1
        })
    }
    
    -- Update when character changes
    ESP.Connections[#ESP.Connections + 1] = player.CharacterAdded:Connect(function(character)
        esp.Character = character
    end)
    
    -- Add to objects
    ESP.Objects[player] = esp
    return esp
end

-- Main update function
function ESP:Update()
    for player, esp in pairs(self.Objects) do
        -- Skip if not enabled
        if not self.Enabled or not player or not player.Character then
            esp.Box.Visible = false
            esp.Name.Visible = false
            esp.Distance.Visible = false
            esp.Tracer.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthBarOutline.Visible = false
            continue
        end
        
        -- Get character root and humanoid
        local character = esp.Character
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChild("Humanoid")
        
        if not rootPart or not humanoid then
            esp.Box.Visible = false
            esp.Name.Visible = false
            esp.Distance.Visible = false
            esp.Tracer.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthBarOutline.Visible = false
            continue
        end
        
        -- Check distance
        local distance = (rootPart.Position - ESP.Camera.CFrame.p).Magnitude
        if distance > ESP.MaxDistance then
            esp.Box.Visible = false
            esp.Name.Visible = false
            esp.Distance.Visible = false
            esp.Tracer.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthBarOutline.Visible = false
            continue
        end
        
        -- Check team
        local team = ESP.TeamCheck and ESP.Players.LocalPlayer.Team
        local playerTeam = player.Team
        if team and playerTeam and team == playerTeam then
            esp.Box.Visible = false
            esp.Name.Visible = false
            esp.Distance.Visible = false
            esp.Tracer.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthBarOutline.Visible = false
            continue
        end
        
        -- Get bounding box positions
        local boxPosition, boxSize = ESP:GetBoxPositionAndSize(character)
        if not boxPosition then
            esp.Box.Visible = false
            esp.Name.Visible = false
            esp.Distance.Visible = false
            esp.Tracer.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthBarOutline.Visible = false
            continue
        end
        
        -- Calculate ESP color
        local espColor = ESP.BoxColor
        if ESP.TeamColor and playerTeam and playerTeam.TeamColor then
            espColor = playerTeam.TeamColor.Color
        end
        
        -- Update box
        esp.Box.Visible = ESP.Enabled and ESP.BoxesEnabled
        esp.Box.Size = boxSize
        esp.Box.Position = boxPosition
        esp.Box.Color = espColor
        
        -- Update name
        esp.Name.Visible = ESP.Enabled and ESP.NamesEnabled
        esp.Name.Text = player.Name
        esp.Name.Position = Vector2.new(boxPosition.X + boxSize.X / 2, boxPosition.Y - 15)
        esp.Name.Color = ESP.NameColor
        
        -- Update distance
        esp.Distance.Visible = ESP.Enabled and ESP.DistanceEnabled
        esp.Distance.Text = math.floor(distance) .. "m"
        esp.Distance.Position = Vector2.new(boxPosition.X + boxSize.X / 2, boxPosition.Y + boxSize.Y + 3)
        esp.Distance.Color = ESP.DistanceColor
        
        -- Update tracer
        esp.Tracer.Visible = ESP.Enabled and ESP.TracersEnabled
        esp.Tracer.From = Vector2.new(ESP.Camera.ViewportSize.X / 2, ESP.Camera.ViewportSize.Y - 35)
        esp.Tracer.To = Vector2.new(boxPosition.X + boxSize.X / 2, boxPosition.Y + boxSize.Y)
        esp.Tracer.Color = ESP.TracerColor
        
        -- Update health bar (if health enabled and humanoid exists)
        if ESP.Enabled and ESP.HealthEnabled and humanoid then
            local health = humanoid.Health
            local maxHealth = humanoid.MaxHealth
            
            -- Calculate health bar dimensions
            local healthBarHeight = boxSize.Y * (health / maxHealth)
            local healthBarPosition = Vector2.new(boxPosition.X - 6, boxPosition.Y)
            local healthBarSize = Vector2.new(3, boxSize.Y)
            local healthFillPosition = Vector2.new(healthBarPosition.X, healthBarPosition.Y + (boxSize.Y - healthBarHeight))
            local healthFillSize = Vector2.new(healthBarSize.X, healthBarHeight)
            
            -- Calculate health color (green to red)
            local healthColor = Color3.fromRGB(
                255 * (1 - health / maxHealth),
                255 * (health / maxHealth),
                0
            )
            
            -- Update health bar outline
            esp.HealthBarOutline.Visible = true
            esp.HealthBarOutline.Position = healthBarPosition
            esp.HealthBarOutline.Size = healthBarSize
            esp.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
            
            -- Update health bar fill
            esp.HealthBar.Visible = true
            esp.HealthBar.Position = healthFillPosition
            esp.HealthBar.Size = healthFillSize
            esp.HealthBar.Color = healthColor
        else
            esp.HealthBar.Visible = false
            esp.HealthBarOutline.Visible = false
        end
    end
end

-- Calculate box position and size for a character
function ESP:GetBoxPositionAndSize(character)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local onScreen = false
    
    -- Parts to check for bounding box
    local partsToCheck = {"Head", "HumanoidRootPart", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}
    -- For R15 rigs
    if character:FindFirstChild("UpperTorso") then
        partsToCheck = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot"}
    end
    
    for _, partName in ipairs(partsToCheck) do
        local part = character:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            local screenPoint = ESP.Camera:WorldToViewportPoint(part.Position)
            
            if screenPoint.Z > 0 then
                onScreen = true
                minX = math.min(minX, screenPoint.X)
                minY = math.min(minY, screenPoint.Y)
                maxX = math.max(maxX, screenPoint.X)
                maxY = math.max(maxY, screenPoint.Y)
            end
        end
    end
    
    if not onScreen then
        return nil
    end
    
    -- Add some padding
    minX = minX - 3
    minY = minY - 3
    maxX = maxX + 3
    maxY = maxY + 3
    
    return Vector2.new(minX, minY), Vector2.new(maxX - minX, maxY - minY)
end

-- Initialize ESP
function ESP:Initialize()
    -- Clean up any existing connections
    for _, connection in pairs(self.Connections) do
        connection:Disconnect()
    end
    self.Connections = {}
    
    -- Clean up any existing objects
    for _, object in pairs(self.Objects) do
        for _, drawing in pairs(object) do
            if typeof(drawing) == "table" and drawing.Remove then
                drawing:Remove()
            end
        end
    end
    self.Objects = {}
    
    -- Create ESP for existing players
    for _, player in pairs(self.Players:GetPlayers()) do
        if player ~= self.Players.LocalPlayer then
            self:CreateESP(player)
        end
    end
    
    -- Connect player added event
    self.Connections[#self.Connections + 1] = self.Players.PlayerAdded:Connect(function(player)
        self:CreateESP(player)
    end)
    
    -- Connect player removing event
    self.Connections[#self.Connections + 1] = self.Players.PlayerRemoving:Connect(function(player)
        if self.Objects[player] then
            for _, drawing in pairs(self.Objects[player]) do
                if typeof(drawing) == "table" and drawing.Remove then
                    drawing:Remove()
                end
            end
            self.Objects[player] = nil
        end
    end)
    
    -- Connect render stepped
    self.Connections[#self.Connections + 1] = self.RunService.RenderStepped:Connect(function()
        self:Update()
    end)
    
    print("ESP initialized successfully!")
end

-- Toggle ESP on/off
function ESP:Toggle()
    self.Enabled = not self.Enabled
    print("ESP " .. (self.Enabled and "enabled" or "disabled"))
end

-- Toggle ESP features
function ESP:ToggleFeature(feature)
    if self[feature] ~= nil then
        self[feature] = not self[feature]
        print(feature .. " " .. (self[feature] and "enabled" or "disabled"))
    end
end

-- Set ESP color
function ESP:SetColor(colorType, color)
    if self[colorType] ~= nil then
        self[colorType] = color
        print(colorType .. " set to " .. tostring(color))
    end
end

-- Start ESP
ESP:Initialize()

-- Create a simple GUI for controlling the ESP
local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ESP_Control"
    
    local frame = Instance.new("Frame")
    frame.Name = "ControlPanel"
    frame.Size = UDim2.new(0, 200, 0, 220)
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    title.BorderSizePixel = 0
    title.Text = "ESP Controls"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 16
    title.Font = Enum.Font.SourceSansBold
    title.Parent = frame
    
    local createToggle = function(name, property, yPos)
        local toggle = Instance.new("TextButton")
        toggle.Name = name .. "Toggle"
        toggle.Size = UDim2.new(0.9, 0, 0, 25)
        toggle.Position = UDim2.new(0.05, 0, 0, yPos)
        toggle.BackgroundColor3 = ESP[property] and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
        toggle.BorderSizePixel = 0
        toggle.Text = name .. ": " .. (ESP[property] and "ON" or "OFF")
        toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggle.TextSize = 14
        toggle.Font = Enum.Font.SourceSans
        toggle.Parent = frame
        
        toggle.MouseButton1Click:Connect(function()
            ESP:ToggleFeature(property)
            toggle.BackgroundColor3 = ESP[property] and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
            toggle.Text = name .. ": " .. (ESP[property] and "ON" or "OFF")
        end)
    end
    
    createToggle("ESP", "Enabled", 40)
    createToggle("Boxes", "BoxesEnabled", 70)
    createToggle("Names", "NamesEnabled", 100)
    createToggle("Distance", "DistanceEnabled", 130)
    createToggle("Health", "HealthEnabled", 160)
    createToggle("Tracers", "TracersEnabled", 190)
    
    -- Add GUI to the player's GUI
    screenGui.Parent = game:GetService("CoreGui")
end

-- Create GUI with error handling
pcall(createGUI)

-- Return the ESP API for script users
return ESP
