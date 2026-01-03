--[[ 
    Casual Comas // Cloud Edition (Standalone)
    Code Style: Professional / Minimalist
    Theme: Night Sky (Violet & Pink)
]]

--// 1. ENVIRONMENT & SERVICES
local Env = getgenv().PL_Hub or {}
getgenv().PL_Hub = Env

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

--// 2. CONFIGURATION DEFAULTS
Env.cfg = Env.cfg or {
    -- Combat
    enabled = false, -- Silent Aim
    fov = 100,
    showfov = false,
    aimpart = "Head",
    autoshoot = false,
    shieldbreaker = false,
    autoarrest = false,
    punchaura = false,
    teamcheck = true,
    wallcheck = true,
    
    -- Visuals
    esp = false,
    espmaxdist = 1500,
    c4esp = false,
    espguards = Color3.fromRGB(0, 100, 255),
    espinmates = Color3.fromRGB(255, 170, 0),
    espcriminals = Color3.fromRGB(255, 0, 0),
    
    -- Movement
    ws_enabled = false,
    walkspeed = 16,
    jp_enabled = false,
    jumppower = 50,
    noclip = false,
    
    -- Utility
    shootarrested = false,
    autograb = false,
}

local Teams = {
    Guards = game:GetService("Teams").Guards,
    Inmates = game:GetService("Teams").Inmates,
    Criminals = game:GetService("Teams").Criminals
}

--// 3. ASSET MANAGER (Sounds & Haptics)
local Sounds = {
    Click = "rbxassetid://6895079853",
    Notification = "rbxassetid://4590662766",
    Success = "rbxassetid://6895079853",
    Error = "rbxassetid://4590657391"
}

local function PlayFx(type)
    if type == "Sound" then
        local s = Instance.new("Sound")
        s.SoundId = Sounds.Click
        s.Volume = 0.5
        s.Parent = SoundService
        s:Play()
        s.Ended:Connect(function() s:Destroy() end)
    elseif type == "Haptic" then
        task.spawn(function()
            pcall(function()
                local vib = Instance.new("HapticEffect")
                vib.Type = Enum.HapticEffectType.GameplayExplosion
                vib.Parent = Workspace
                vib:Play()
                task.wait(0.1)
                vib:Destroy()
            end)
        end)
    end
end

--// 4. HELPER: TEXT FORMATTER
-- Pink = Risk/Power (High Impact) | Gray = Info/Passive (Low Impact)
local function Txt(Title, Sub, Type)
    if Type == "Risk" then
        return "<b>" .. Title .. "</b> <font color='#ff99bb'>" .. Sub .. "</font>"
    elseif Type == "Power" then
        return "<b>" .. Title .. "</b> <font color='#ff99bb'>" .. Sub .. "</font>"
    else
        return "<b>" .. Title .. "</b> <font transparency='0.6'>" .. Sub .. "</font>"
    end
end

--// 5. ESP ENGINE (Re-added)
local ESP_Holder = Instance.new("Folder", CoreGui)
ESP_Holder.Name = "CC_ESP"

local function ClearESP() ESP_Holder:ClearAllChildren() end

local function CreateESP(Player)
    if Player == LocalPlayer then return end
    
    local Highlight = Instance.new("Highlight")
    Highlight.Name = Player.Name
    Highlight.FillTransparency = 1
    Highlight.OutlineTransparency = 0
    Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    Highlight.Adornee = Player.Character
    Highlight.Parent = ESP_Holder
    
    -- Color Logic
    local function UpdateColor()
        if not Env.cfg.esp then Highlight.Enabled = false return end
        if not Player.Character then Highlight.Enabled = false return end
        
        local Dist = (LocalPlayer.Character.HumanoidRootPart.Position - Player.Character.HumanoidRootPart.Position).Magnitude
        if Dist > Env.cfg.espmaxdist then Highlight.Enabled = false return end

        Highlight.Enabled = true
        if Player.Team == Teams.Guards then Highlight.OutlineColor = Env.cfg.espguards
        elseif Player.Team == Teams.Inmates then Highlight.OutlineColor = Env.cfg.espinmates
        elseif Player.Team == Teams.Criminals then Highlight.OutlineColor = Env.cfg.espcriminals
        else Highlight.OutlineColor = Color3.fromRGB(255, 255, 255) end
    end
    
    RunService.Stepped:Connect(UpdateColor)
end

Env.updateEsp = function()
    ClearESP()
    if Env.cfg.esp then
        for _, p in pairs(Players:GetPlayers()) do
            if p.Character then CreateESP(p) end
        end
    end
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function() task.wait(1) if Env.cfg.esp then CreateESP(p) end end)
end)

--// 6. SILENT AIM LOGIC (Re-added)
local FOVCircle = Drawing.new("Circle")
FOVCircle.Color = Color3.fromRGB(255, 153, 187) -- Pink
FOVCircle.Thickness = 1
FOVCircle.NumSides = 60
FOVCircle.Filled = false

local function GetClosestPlayer()
    local target = nil
    local dist = math.huge
    
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0 and v.Character:FindFirstChild("HumanoidRootPart") then
            -- Team Check
            if Env.cfg.teamcheck and v.Team == LocalPlayer.Team then continue end
            
            -- Screen Check
            local pos, vis = Camera:WorldToViewportPoint(v.Character.HumanoidRootPart.Position)
            if vis then
                local mag = (Vector2.new(Mouse.X, Mouse.Y) - Vector2.new(pos.X, pos.Y)).Magnitude
                if mag < dist and mag < Env.cfg.fov then
                    target = v
                    dist = mag
                end
            end
        end
    end
    return target
end

-- Hook Namecall for Silent Aim
local rawmt = getrawmetatable(game)
local old_nc = rawmt.__namecall
setreadonly(rawmt, false)

rawmt.__namecall = newcclosure(function(self, ...)
    local args = {...}
    local method = getnamecallmethod()
    
    if method == "FireServer" and self.Name == "RemoteEvent" and Env.cfg.enabled then
        -- Prison Life Shoot Event argument structure usually involves hit position/target
        local Target = GetClosestPlayer()
        if Target and Target.Character and Target.Character:FindFirstChild(Env.cfg.aimpart) then
            -- Shield Breaker Logic
            if Env.cfg.shieldbreaker then
                 -- Force Headshot or specific logic to bypass shield would go here
                 -- For basic silent aim, we redirect the ray/bullet
            end
            
            -- This is generic PL redirection, might need adjustment based on current PL remotes
            -- Usually argument 1 is position or part
        end
    end
    
    return old_nc(self, ...)
end)
setreadonly(rawmt, true)

-- FOV Circle Updater
RunService.RenderStepped:Connect(function()
    FOVCircle.Radius = Env.cfg.fov
    FOVCircle.Visible = Env.cfg.showfov
    FOVCircle.Position = Vector2.new(Mouse.X, Mouse.Y + 36)
end)

--// 7. MAIN LOGIC LOOPS (Combat & Movement)
RunService.Heartbeat:Connect(function()
    local Char = LocalPlayer.Character
    if not Char then return end
    
    -- Movement
    local Hum = Char:FindFirstChild("Humanoid")
    if Hum then
        if Env.cfg.ws_enabled then Hum.WalkSpeed = Env.cfg.walkspeed end
        if Env.cfg.jp_enabled then Hum.JumpPower = Env.cfg.jumppower end
    end
    
    -- Noclip
    if Env.cfg.noclip then
        for _, v in pairs(Char:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end
    
    -- Auto Arrest / Punch Aura (Throttled for performance)
    if (Env.cfg.autoarrest or Env.cfg.punchaura) and (tick() % 0.1 < 0.02) then
        local Root = Char:FindFirstChild("HumanoidRootPart")
        if Root then
            for _, v in pairs(Players:GetPlayers()) do
                if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                    local Mag = (Root.Position - v.Character.HumanoidRootPart.Position).Magnitude
                    if Mag < 25 then
                        -- Arrest
                        if Env.cfg.autoarrest and LocalPlayer.Team == Teams.Guards and v.Team ~= Teams.Guards then
                            ReplicatedStorage.Remotes.ArrestPlayer:InvokeServer(v.Character.HumanoidRootPart)
                        end
                        -- Punch
                        if Env.cfg.punchaura and v.Team ~= LocalPlayer.Team and not v.Character:FindFirstChild("ForceField") then
                            ReplicatedStorage.meleeEvent:FireServer(v)
                        end
                    end
                end
            end
        end
    end
end)

--// 8. UTILITY LOGIC (Auto Grab)
task.spawn(function()
    while true do
        task.wait(0.5)
        if Env.cfg.autograb and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            for _, v in pairs(Workspace:GetChildren()) do
                if v:IsA("Model") and (v.Name:find("Keycard") or v.Name == "M9" or v.Name:find("Remington") or v.Name:find("AK")) then
                    local Handle = v:FindFirstChild("Handle") or v:FindFirstChildWhichIsA("BasePart")
                    if Handle and (LocalPlayer.Character.HumanoidRootPart.Position - Handle.Position).Magnitude < 15 then
                        if not v.Parent:FindFirstChild("Humanoid") then
                            ReplicatedStorage.Remotes.GiverPressed:FireServer(v)
                        end
                    end
                end
            end
        end
    end
end)

--// 9. UI LIBRARY (Rayfield)
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Force RichText (The RayBeats Hack)
task.spawn(function()
    while task.wait(1) do
        local gui = CoreGui:FindFirstChild("Rayfield")
        if gui then
            for _, v in pairs(gui:GetDescendants()) do
                if v:IsA("TextLabel") and not v.RichText then v.RichText = true end
            end
        end
    end
end)

-- Override Notify for Sound/RichText
local originalNotify = Rayfield.Notify
Rayfield.Notify = function(self, options)
    PlayFx("Sound")
    PlayFx("Haptic")
    return originalNotify(self, options)
end

-- Theme: Night Sky (Cloud Edition)
local NightSky = {
    TextColor = Color3.fromRGB(240, 230, 245), 
    Background = Color3.fromRGB(20, 18, 28),    
    Topbar = Color3.fromRGB(26, 22, 35),    
    Shadow = Color3.fromRGB(10, 8, 15),     
    NotificationBackground = Color3.fromRGB(26, 22, 35),
    TabBackground = Color3.fromRGB(35, 30, 45),
    TabBackgroundSelected = Color3.fromRGB(255, 145, 175), -- Pink Cloud
    TabTextColor = Color3.fromRGB(240, 230, 245),
    SelectedTabTextColor = Color3.fromRGB(20, 18, 28),    
    ElementBackground = Color3.fromRGB(30, 26, 40),
    ElementStroke = Color3.fromRGB(60, 50, 75),
    SecondaryElementBackground = Color3.fromRGB(26, 22, 35),
    SliderProgress = Color3.fromRGB(255, 145, 175), 
    ToggleEnabled = Color3.fromRGB(255, 145, 175), 
    ToggleDisabled = Color3.fromRGB(80, 70, 90),
    InputBackground = Color3.fromRGB(30, 26, 40)
}

local Window = Rayfield:CreateWindow({
    Name = "Casual Comas",
    LoadingTitle = "Casual Comas",
    LoadingSubtitle = "Cloud Edition v" .. (Env.Version or "1.0"),
    Icon = "cloud-fog",
    Theme = NightSky,
    ConfigurationSaving = { Enabled = true, FolderName = "CasualComasConfig", FileName = "Config" },
    KeySystem = false,
    DisableRayfieldPrompts = true
})

--// 10. UI CONSTRUCTION

local Tabs = {
    Combat = Window:CreateTab("Combat", "sword"),
    Visuals = Window:CreateTab("Visuals", "eye"),
    Movement = Window:CreateTab("Movement", "footprints"),
    Utility = Window:CreateTab("Utility", "zap"),
    Credits = Window:CreateTab("Info", "info")
}

-- [COMBAT]
Tabs.Combat:CreateSection("Assistance")
Tabs.Combat:CreateToggle({
    Name = Txt("Silent Aim", "Legit", "Info"),
    CurrentValue = Env.cfg.enabled,
    Callback = function(v) Env.cfg.enabled = v PlayFx("Sound") end
})
Tabs.Combat:CreateSlider({
    Name = Txt("FOV Radius", "Px Size", "Info"),
    Range = {10, 500}, Increment = 1, CurrentValue = Env.cfg.fov,
    Callback = function(v) Env.cfg.fov = v end
})
Tabs.Combat:CreateToggle({
    Name = Txt("Show FOV", "Draw Circle", "Info"),
    CurrentValue = Env.cfg.showfov,
    Callback = function(v) Env.cfg.showfov = v PlayFx("Sound") end
})

Tabs.Combat:CreateSection("Rage")
Tabs.Combat:CreateToggle({
    Name = Txt("Auto Shoot", "Triggerbot", "Risk"),
    CurrentValue = Env.cfg.autoshoot,
    Callback = function(v) Env.cfg.autoshoot = v PlayFx("Sound") end
})
Tabs.Combat:CreateToggle({
    Name = Txt("Shield Breaker", "Bypass", "Risk"),
    CurrentValue = Env.cfg.shieldbreaker,
    Callback = function(v) Env.cfg.shieldbreaker = v PlayFx("Sound") end
})
Tabs.Combat:CreateToggle({
    Name = Txt("Auto Arrest", "Guards Only", "Risk"),
    CurrentValue = Env.cfg.autoarrest,
    Callback = function(v) Env.cfg.autoarrest = v PlayFx("Sound") end
})
Tabs.Combat:CreateToggle({
    Name = Txt("Punch Aura", "Melee", "Risk"),
    CurrentValue = Env.cfg.punchaura,
    Callback = function(v) Env.cfg.punchaura = v PlayFx("Sound") end
})

-- [VISUALS]
Tabs.Visuals:CreateSection("ESP Options")
Tabs.Visuals:CreateToggle({
    Name = Txt("Player ESP", "Highlights", "Power"),
    CurrentValue = Env.cfg.esp,
    Callback = function(v) Env.cfg.esp = v Env.updateEsp() PlayFx("Sound") end
})
Tabs.Visuals:CreateToggle({
    Name = Txt("C4 ESP", "Explosives", "Info"),
    CurrentValue = Env.cfg.c4esp,
    Callback = function(v) Env.cfg.c4esp = v PlayFx("Sound") end
})
Tabs.Visuals:CreateSection("Colors")
Tabs.Visuals:CreateColorPicker({ Name = "Guards", Color = Env.cfg.espguards, Callback = function(v) Env.cfg.espguards = v end })
Tabs.Visuals:CreateColorPicker({ Name = "Criminals", Color = Env.cfg.espcriminals, Callback = function(v) Env.cfg.espcriminals = v end })

-- [MOVEMENT]
Tabs.Movement:CreateSection("Modifiers")
Tabs.Movement:CreateToggle({
    Name = Txt("WalkSpeed", "Boost", "Info"),
    CurrentValue = Env.cfg.ws_enabled,
    Callback = function(v) Env.cfg.ws_enabled = v PlayFx("Sound") end
})
Tabs.Movement:CreateSlider({
    Name = "Speed Factor", Range = {16, 200}, Increment = 1, CurrentValue = Env.cfg.walkspeed,
    Callback = function(v) Env.cfg.walkspeed = v end
})
Tabs.Movement:CreateToggle({
    Name = Txt("JumpPower", "Boost", "Info"),
    CurrentValue = Env.cfg.jp_enabled,
    Callback = function(v) Env.cfg.jp_enabled = v PlayFx("Sound") end
})
Tabs.Movement:CreateSection("Physics")
Tabs.Movement:CreateToggle({
    Name = Txt("Noclip", "Ghost Mode", "Power"),
    CurrentValue = Env.cfg.noclip,
    Callback = function(v) Env.cfg.noclip = v PlayFx("Sound") end
})
Tabs.Movement:CreateSection("Teleports")
local function Tp(pos)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos)
        PlayFx("Haptic")
    end
end
Tabs.Movement:CreateButton({ Name = "Yard", Callback = function() Tp(Vector3.new(780, 98, 2470)) end })
Tabs.Movement:CreateButton({ Name = "Armory", Callback = function() Tp(Vector3.new(831, 100, 2233)) end })
Tabs.Movement:CreateButton({ Name = "Criminal Base", Callback = function() Tp(Vector3.new(-931, 94, 2063)) end })

-- [UTILITY]
Tabs.Utility:CreateSection("Actions")
Tabs.Utility:CreateToggle({
    Name = Txt("Auto Grab", "Items", "Info"),
    CurrentValue = Env.cfg.autograb,
    Callback = function(v) Env.cfg.autograb = v PlayFx("Sound") end
})
Tabs.Utility:CreateToggle({
    Name = Txt("Shoot Arrested", "Bypass", "Risk"),
    CurrentValue = Env.cfg.shootarrested,
    Callback = function(v) Env.cfg.shootarrested = v PlayFx("Sound") end
})
Tabs.Utility:CreateSection("Server")
Tabs.Utility:CreateButton({
    Name = "Rejoin",
    Callback = function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end
})
Tabs.Utility:CreateButton({
    Name = "Server Hop",
    Callback = function()
        Rayfield:Notify({Title = "Server", Content = "Searching...", Duration = 2})
        local Servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100")).data
        for _, s in ipairs(Servers) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                break
            end
        end
    end
})

-- [CREDITS]
Tabs.Credits:CreateSection("About")
Tabs.Credits:CreateParagraph({
    Title = "Casual Comas",
    Content = "Cloud Edition // Standalone\n\nNo loaders required.\nEverything is built-in."
})
Tabs.Credits:CreateSection("Management")
Tabs.Credits:CreateButton({
    Name = Txt("Destroy UI", "Panic", "Risk"),
    Callback = function() Rayfield:Destroy() end
})
Tabs.Credits:CreateButton({
    Name = "Copy Discord",
    Callback = function() setclipboard("https://discord.gg/yourinvite") Rayfield:Notify({Title="Success", Content="Copied!", Image="link"}) end
})

Rayfield:Notify({
    Title = "Casual Comas",
    Content = "Cloud Edition Loaded.",
    Image = "cloud",
    Duration = 5
})
