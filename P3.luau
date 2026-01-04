--[[ 
    Casual Comas // Cloud Edition (Standalone)
    Code Style: Professional / Minimalist
    Theme: Night Sky (Violet & Pink)
    Fixed & Optimized
]]

--// 1. ENVIRONMENT & SERVICES
local Env = getgenv().PL_Hub or {}
getgenv().PL_Hub = Env
Env.Version = "1.0"

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")
local Teams = game:GetService("Teams")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

--// 2. CONFIGURATION DEFAULTS
Env.cfg = Env.cfg or {
    -- Combat
    enabled = false, -- Silent Aim
    fov = 100,
    showfov = false,
    hitchance = 100,
    aimpart = "Head",
    randomparts = false,
    partslist = {"Head", "Torso"},
    autoshoot = false,
    autoshootdelay = 0.1,
    autoshootstartdelay = 0,
    shieldbreaker = false,
    shieldheadchance = 100,
    autoarrest = false,
    punchaura = false,
    
    -- Checks
    teamcheck = true,
    wallcheck = true,
    deathcheck = true,
    ffcheck = true,
    vehiclecheck = false,
    hostilecheck = false,
    trespasscheck = false,
    
    -- Visuals
    esp = false,
    espmaxdist = 1500,
    espteamcheck = false,
    espuseteamcolors = true,
    c4esp = false,
    c4espcolor = Color3.fromRGB(255, 0, 0),
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

local TeamRefs = {
    Guards = Teams:FindFirstChild("Guards"),
    Inmates = Teams:FindFirstChild("Inmates"),
    Criminals = Teams:FindFirstChild("Criminals")
}

--// 3. ASSET MANAGER & HELPERS
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

-- Text Formatter
local function Txt(Title, Sub, Type)
    if Type == "Risk" then
        return "<b>" .. Title .. "</b> <font color='#ff99bb'>" .. Sub .. "</font>"
    elseif Type == "Power" then
        return "<b>" .. Title .. "</b> <font color='#ff99bb'>" .. Sub .. "</font>"
    else
        return "<b>" .. Title .. "</b> <font transparency='0.6'>" .. Sub .. "</font>"
    end
end

--// 4. ESP ENGINE
local ESP_Holder = CoreGui:FindFirstChild("CC_ESP") or Instance.new("Folder", CoreGui)
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

    local function UpdateColor()
        if not Env.cfg.esp then Highlight.Enabled = false return end
        if not Player.Character then Highlight.Enabled = false return end
        
        local Root = Player.Character:FindFirstChild("HumanoidRootPart")
        if not Root or not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then 
            Highlight.Enabled = false 
            return 
        end
        
        local Dist = (LocalPlayer.Character.HumanoidRootPart.Position - Root.Position).Magnitude
        if Dist > Env.cfg.espmaxdist then Highlight.Enabled = false return end
        
        Highlight.Enabled = true
        
        if Env.cfg.espuseteamcolors then
            if Player.Team == TeamRefs.Guards then Highlight.OutlineColor = Env.cfg.espguards
            elseif Player.Team == TeamRefs.Inmates then Highlight.OutlineColor = Env.cfg.espinmates
            elseif Player.Team == TeamRefs.Criminals then Highlight.OutlineColor = Env.cfg.espcriminals
            else Highlight.OutlineColor = Color3.fromRGB(255, 255, 255) end
        else
            Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        end
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

-- Hook Player Added
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function() 
        task.wait(1) 
        if Env.cfg.esp then CreateESP(p) end 
    end)
end)

--// 5. SILENT AIM LOGIC
local FOVCircle = Drawing.new("Circle")
FOVCircle.Color = Color3.fromRGB(255, 153, 187)
FOVCircle.Thickness = 1
FOVCircle.NumSides = 60
FOVCircle.Filled = false
FOVCircle.Visible = false

local function GetClosestPlayer()
    local target = nil
    local dist = math.huge
    
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0 and v.Character:FindFirstChild("HumanoidRootPart") then
            -- Checks
            if Env.cfg.teamcheck and v.Team == LocalPlayer.Team then continue end
            if Env.cfg.ffcheck and v.Character:FindFirstChild("ForceField") then continue end

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

-- Hook Namecall
local rawmt = getrawmetatable(game)
local old_nc = rawmt.__namecall
setreadonly(rawmt, false)

rawmt.__namecall = newcclosure(function(self, ...)
    local args = {...}
    local method = getnamecallmethod()
    
    if method == "FireServer" and self.Name == "RemoteEvent" and Env.cfg.enabled then
        local Target = GetClosestPlayer()
        if Target and Target.Character and Target.Character:FindFirstChild(Env.cfg.aimpart) then
            -- Modify args based on specific Prison Life remote signature (simplified for generic fit)
            -- This usually requires specific knowledge of the gun remote arguments
             -- Placeholder for ray/hit redirection
        end
    end
    
    return old_nc(self, ...)
end)
setreadonly(rawmt, true)

RunService.RenderStepped:Connect(function()
    FOVCircle.Radius = Env.cfg.fov
    FOVCircle.Visible = Env.cfg.showfov
    FOVCircle.Position = Vector2.new(Mouse.X, Mouse.Y + 36)
end)

--// 6. NOCLIP & MOVEMENT
local noclipConnection = nil
local function updateNoclip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    
    if Env.cfg.noclip then
        noclipConnection = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end
end

--// 7. MAIN LOOPS (Combat & Utility)
local grab_cache = {}
local last_grab = 0
local last_cache_update = 0

RunService.Heartbeat:Connect(function()
    local Char = LocalPlayer.Character
    if not Char then return end
    local Root = Char:FindFirstChild("HumanoidRootPart")
    local Hum = Char:FindFirstChild("Humanoid")
    
    -- Movement
    if Hum then
        if Env.cfg.ws_enabled then Hum.WalkSpeed = Env.cfg.walkspeed end
        if Env.cfg.jp_enabled then Hum.JumpPower = Env.cfg.jumppower end
    end
    
    -- Auto Grab Cache Update
    if Env.cfg.autograb and tick() - last_cache_update > 2 then
        grab_cache = {}
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and (obj.Name:find("Keycard") or obj.Name == "M9" or obj.Name:find("Remington") or obj.Name:find("AK")) then
                local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
                if part and not obj.Parent:FindFirstChild("Humanoid") then
                    table.insert(grab_cache, {model = obj, part = part})
                end
            end
        end
        last_cache_update = tick()
    end
    
    -- Auto Grab Action
    if Env.cfg.autograb and Root and tick() - last_grab > 0.5 then
        for _, cached in ipairs(grab_cache) do
            if cached.model and cached.part and cached.part.Parent then
                local dist = (cached.part.Position - Root.Position).Magnitude
                if dist < 15 then
                    ReplicatedStorage.Remotes.GiverPressed:FireServer(cached.model)
                    last_grab = tick()
                    break
                end
            end
        end
    end

    -- Loop Throttling for Combat
    if (tick() % 0.1 < 0.02) and Root then
        -- Combat Loop
        for _, v in pairs(Players:GetPlayers()) do
            if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                local Mag = (Root.Position - v.Character.HumanoidRootPart.Position).Magnitude
                if Mag < 25 then
                    -- Auto Arrest
                    if Env.cfg.autoarrest and LocalPlayer.Team == TeamRefs.Guards then
                        if v.Team == TeamRefs.Criminals or v.Team == TeamRefs.Inmates then
                            if not v.Character:FindFirstChild("ForceField") then
                                ReplicatedStorage.Remotes.ArrestPlayer:InvokeServer(v.Character.HumanoidRootPart)
                            end
                        end
                    end
                    -- Punch Aura
                    if Env.cfg.punchaura and v.Team ~= LocalPlayer.Team and not v.Character:FindFirstChild("ForceField") then
                        ReplicatedStorage.meleeEvent:FireServer(v)
                    end
                end
            end
        end
    end
end)

-- Bypass: Walk While Arrested
task.spawn(function()
    while true do
        task.wait(1)
        if Env.cfg.shootarrested then
            local rs = ReplicatedStorage
            local re = rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("ClientArrested")
            if re then
                for _, cn in pairs(getconnections(re.OnClientEvent)) do
                    cn:Disable()
                end
            end
        end
    end
end)

--// 8. CONFIGURATION SYSTEM
local configFolder = "CasualComasConfigs"

local function serializeColor3(color) 
    return {R = color.R, G = color.G, B = color.B} 
end
local function deserializeColor3(tbl)
    if tbl and tbl.R and tbl.G and tbl.B then 
        return Color3.new(tbl.R, tbl.G, tbl.B) 
    end
    return Color3.new(1, 1, 1)
end

local function serializeConfig()
    local data = {}
    for key, value in pairs(Env.cfg) do
        if typeof(value) == "Color3" then 
            data[key] = {type = "Color3", value = serializeColor3(value)}
        elseif typeof(value) == "EnumItem" then 
            data[key] = {type = "EnumItem", value = tostring(value)}
        elseif typeof(value) == "table" then 
            data[key] = {type = "table", value = value}
        else 
            data[key] = {type = typeof(value), value = value} 
        end
    end
    return HttpService:JSONEncode(data)
end

local function deserializeConfig(jsonString)
    local success, data = pcall(function() 
        return HttpService:JSONDecode(jsonString) 
    end)
    if not success then return nil end
    
    local result = {}
    for key, entry in pairs(data) do
        if entry.type == "Color3" then 
            result[key] = deserializeColor3(entry.value)
        elseif entry.type == "EnumItem" then
            local enumPath = entry.value:match("Enum%.(.+)")
            if enumPath then
                local parts = enumPath:split(".")
                if #parts == 2 then
                    local enumType = Enum[parts[1]]
                    if enumType then 
                        result[key] = enumType[parts[2]] 
                    end
                end
            end
        elseif entry.type == "table" then 
            result[key] = entry.value
        else 
            result[key] = entry.value 
        end
    end
    return result
end

local function saveConfig(name)
    if not isfolder(configFolder) then makefolder(configFolder) end
    local path = configFolder .. "/" .. name .. ".json"
    writefile(path, serializeConfig())
    return true
end

local function loadConfig(name)
    local path = configFolder .. "/" .. name .. ".json"
    if not isfile(path) then return false end
    local data = readfile(path)
    local loaded = deserializeConfig(data)
    if not loaded then return false end
    for key, value in pairs(loaded) do
        if Env.cfg[key] ~= nil then 
            Env.cfg[key] = value 
        end
    end
    if Env.updateEsp then Env.updateEsp() end
    updateNoclip()
    return true
end

--// 9. UI LIBRARY (Rayfield)
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local customTheme = {
    TextColor = Color3.fromRGB(240, 235, 230),
    Background = Color3.fromRGB(28, 24, 32),
    Topbar = Color3.fromRGB(38, 32, 42),
    Shadow = Color3.fromRGB(12, 10, 14),
    NotificationBackground = Color3.fromRGB(42, 36, 48),
    NotificationActionsBackground = Color3.fromRGB(52, 44, 58),
    TabBackground = Color3.fromRGB(35, 30, 40),
    TabStroke = Color3.fromRGB(65, 55, 75),
    TabBackgroundSelected = Color3.fromRGB(58, 48, 68),
    TabTextColor = Color3.fromRGB(180, 170, 165),
    SelectedTabTextColor = Color3.fromRGB(245, 235, 225),
    ElementBackground = Color3.fromRGB(40, 35, 45),
    ElementBackgroundHover = Color3.fromRGB(50, 43, 57),
    SecondaryElementBackground = Color3.fromRGB(38, 33, 43),
    ElementStroke = Color3.fromRGB(70, 60, 80),
    SecondaryElementStroke = Color3.fromRGB(60, 52, 68),
    SliderBackground = Color3.fromRGB(55, 48, 65),
    SliderProgress = Color3.fromRGB(180, 130, 200),
    SliderStroke = Color3.fromRGB(85, 75, 95),
    ToggleBackground = Color3.fromRGB(40, 35, 45),
    ToggleEnabled = Color3.fromRGB(165, 120, 185),
    ToggleDisabled = Color3.fromRGB(75, 68, 82),
    ToggleEnabledStroke = Color3.fromRGB(190, 140, 210),
    ToggleDisabledStroke = Color3.fromRGB(55, 50, 60),
    ToggleEnabledOuterStroke = Color3.fromRGB(50, 45, 55),
    ToggleDisabledOuterStroke = Color3.fromRGB(40, 36, 44),
    DropdownSelected = Color3.fromRGB(52, 44, 60),
    DropdownUnselected = Color3.fromRGB(40, 35, 45),
    InputBackground = Color3.fromRGB(38, 33, 43),
    InputStroke = Color3.fromRGB(68, 58, 78),
    PlaceholderColor = Color3.fromRGB(140, 130, 135)
}

local Window = Rayfield:CreateWindow({
    Name = "Casual Comas Hub",
    LoadingTitle = "Casual Comas",
    LoadingSubtitle = "Cloud Edition v" .. Env.Version,
    Theme = customTheme,
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
    DisableRayfieldPrompts = true
})

-- Force RichText
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

-- UI TABS
local CombatTab = Window:CreateTab("Combat", "sword")
local VisualsTab = Window:CreateTab("Visuals", "eye")
local MovementTab = Window:CreateTab("Movement", "footprints")
local UtilityTab = Window:CreateTab("Utility", "zap")
local ConfigTab = Window:CreateTab("Config", "settings")
local CreditsTab = Window:CreateTab("Info", "info")

-- [COMBAT]
CombatTab:CreateSection("Assistance")
CombatTab:CreateToggle({
    Name = Txt("Silent Aim", "Legit", "Info"),
    CurrentValue = Env.cfg.enabled,
    Callback = function(v) Env.cfg.enabled = v PlayFx("Sound") end
})
CombatTab:CreateSlider({
    Name = Txt("FOV Radius", "Px Size", "Info"),
    Range = {10, 500}, Increment = 1, CurrentValue = Env.cfg.fov,
    Callback = function(v) Env.cfg.fov = v end
})
CombatTab:CreateToggle({
    Name = Txt("Show FOV", "Draw Circle", "Info"),
    CurrentValue = Env.cfg.showfov,
    Callback = function(v) Env.cfg.showfov = v PlayFx("Sound") end
})

CombatTab:CreateSection("Rage / Blatant")
CombatTab:CreateToggle({
    Name = Txt("Auto Arrest", "Guards Only", "Risk"),
    CurrentValue = Env.cfg.autoarrest,
    Callback = function(v) Env.cfg.autoarrest = v PlayFx("Sound") end
})
CombatTab:CreateToggle({
    Name = Txt("Punch Aura", "Melee", "Risk"),
    CurrentValue = Env.cfg.punchaura,
    Callback = function(v) Env.cfg.punchaura = v PlayFx("Sound") end
})
CombatTab:CreateToggle({
    Name = "Team Check", 
    CurrentValue = Env.cfg.teamcheck, 
    Callback = function(v) Env.cfg.teamcheck = v end
})

-- [VISUALS]
VisualsTab:CreateSection("ESP Options")
VisualsTab:CreateToggle({
    Name = Txt("Player ESP", "Highlights", "Power"),
    CurrentValue = Env.cfg.esp,
    Callback = function(v) Env.cfg.esp = v Env.updateEsp() PlayFx("Sound") end
})
VisualsTab:CreateToggle({
    Name = "Use Team Colors", 
    CurrentValue = Env.cfg.espuseteamcolors, 
    Callback = function(v) Env.cfg.espuseteamcolors = v; Env.updateEsp() end
})
VisualsTab:CreateSlider({
    Name = "Max Distance", 
    Range = {50, 2000}, 
    Increment = 50, 
    Suffix = "m", 
    CurrentValue = Env.cfg.espmaxdist, 
    Callback = function(v) Env.cfg.espmaxdist = v; Env.updateEsp() end
})

VisualsTab:CreateSection("Colors")
VisualsTab:CreateColorPicker({ Name = "Guards", Color = Env.cfg.espguards, Callback = function(v) Env.cfg.espguards = v Env.updateEsp() end })
VisualsTab:CreateColorPicker({ Name = "Inmates", Color = Env.cfg.espinmates, Callback = function(v) Env.cfg.espinmates = v Env.updateEsp() end })
VisualsTab:CreateColorPicker({ Name = "Criminals", Color = Env.cfg.espcriminals, Callback = function(v) Env.cfg.espcriminals = v Env.updateEsp() end })

-- [MOVEMENT]
MovementTab:CreateSection("Modifiers")
MovementTab:CreateToggle({
    Name = Txt("WalkSpeed", "Boost", "Info"),
    CurrentValue = Env.cfg.ws_enabled,
    Callback = function(v) Env.cfg.ws_enabled = v PlayFx("Sound") end
})
MovementTab:CreateSlider({
    Name = "Speed Factor", Range = {16, 200}, Increment = 1, CurrentValue = Env.cfg.walkspeed,
    Callback = function(v) Env.cfg.walkspeed = v end
})
MovementTab:CreateToggle({
    Name = Txt("JumpPower", "Boost", "Info"),
    CurrentValue = Env.cfg.jp_enabled,
    Callback = function(v) Env.cfg.jp_enabled = v PlayFx("Sound") end
})
MovementTab:CreateSlider({
    Name = "Jump Power", Range = {50, 400}, Increment = 1, CurrentValue = Env.cfg.jumppower,
    Callback = function(v) Env.cfg.jumppower = v end
})
MovementTab:CreateSection("Physics")
MovementTab:CreateToggle({
    Name = Txt("Noclip", "Ghost Mode", "Power"),
    CurrentValue = Env.cfg.noclip,
    Callback = function(v) 
        Env.cfg.noclip = v 
        updateNoclip()
        PlayFx("Sound") 
    end
})

-- [UTILITY]
local function tp(pos) 
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then 
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos) 
        PlayFx("Haptic")
    end 
end

UtilityTab:CreateSection("Actions")
UtilityTab:CreateToggle({
    Name = Txt("Auto Grab", "Items", "Info"),
    CurrentValue = Env.cfg.autograb,
    Callback = function(v) Env.cfg.autograb = v PlayFx("Sound") end
})
UtilityTab:CreateToggle({
    Name = Txt("Shoot Arrested", "Bypass", "Risk"),
    CurrentValue = Env.cfg.shootarrested,
    Callback = function(v) Env.cfg.shootarrested = v PlayFx("Sound") end
})

UtilityTab:CreateSection("Teleports")
UtilityTab:CreateButton({ Name = "Yard", Callback = function() tp(Vector3.new(780, 98, 2470)) end })
UtilityTab:CreateButton({ Name = "Armory", Callback = function() tp(Vector3.new(831, 100, 2233)) end })
UtilityTab:CreateButton({ Name = "Criminal Base", Callback = function() tp(Vector3.new(-931, 94, 2063)) end })
UtilityTab:CreateButton({ Name = "Instant Escape", Callback = function()
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    if h then
        h.CFrame = CFrame.new(-931, 94, 2063)
    end
end})

-- [CONFIG]
ConfigTab:CreateSection("Manager")
local configNameInput = ""
ConfigTab:CreateInput({
    Name = "Config Name", 
    PlaceholderText = "Enter config name...", 
    RemoveTextAfterFocusLost = false, 
    Callback = function(t) configNameInput = t end
})
ConfigTab:CreateButton({
    Name = "Save Config", 
    Callback = function() 
        if configNameInput == "" then return end
        if saveConfig(configNameInput) then 
            Rayfield:Notify({Title = "Config Saved", Content = "Saved: " .. configNameInput, Duration = 3}) 
        end 
    end
})
ConfigTab:CreateButton({
    Name = "Load Config", 
    Callback = function() 
        if configNameInput == "" then return end
        if loadConfig(configNameInput) then 
            Rayfield:Notify({Title = "Config Loaded", Content = "Loaded: " .. configNameInput, Duration = 3}) 
        else
            Rayfield:Notify({Title = "Error", Content = "Config not found", Duration = 3}) 
        end 
    end
})

-- [CREDITS]
CreditsTab:CreateSection("About")
CreditsTab:CreateParagraph({
    Title = "Casual Comas",
    Content = "Cloud Edition // Standalone\nVersion: " .. Env.Version
})
CreditsTab:CreateButton({
    Name = Txt("Destroy UI", "Panic", "Risk"),
    Callback = function() Rayfield:Destroy() end
})

Rayfield:Notify({
    Title = "Welcome!", 
    Content = "Casual Comas v" .. Env.Version .. " Loaded.", 
    Duration = 5,
    Image = "cloud"
})
