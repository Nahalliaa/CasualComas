--[[
    Casual Comas // Premium PL Hub
    Theme: Nebula Storm (Deep Space Violets & Electric Pink)
    Logic: PL_Hub Integration
]]

local Env = getgenv().PL_Hub
if not Env then return warn("Load Part 1 First!") end
if not Env.Version then Env.Version = "1.0" end

--// SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

--// ASSET LIBRARY
local Assets = {
    Sounds = {
        Click = "rbxassetid://6895079853",
        Hover = "rbxassetid://6895079775",
        Notification = "rbxassetid://4590662766",
        Success = "rbxassetid://6895079853",
        Error = "rbxassetid://4590657391",
        Whoosh = "rbxassetid://1177785010",
        PowerUp = "rbxassetid://5153734944"
    }
}

--// FX ENGINE
local FX = {
    audioEnabled = true,
    hapticEnabled = true
}

function FX:Sound(id, vol, pitch)
    if not self.audioEnabled then return end
    task.spawn(function()
        local s = Instance.new("Sound")
        s.SoundId = id
        s.Volume = vol or 0.5
        s.PlaybackSpeed = pitch or 1
        s.Parent = SoundService
        s:Play()
        s.Ended:Wait()
        s:Destroy()
    end)
end

function FX:Haptic(type)
    if not self.hapticEnabled then return end
    task.spawn(function()
        pcall(function()
            local h = Instance.new("HapticEffect")
            h.Type = type == "heavy" and Enum.HapticEffectType.GameplayExplosion or Enum.HapticEffectType.Collision
            h.Parent = Workspace
            h:Play()
            task.wait(0.1)
            h:Destroy()
        end)
    end)
end

function FX:Click() self:Sound(Assets.Sounds.Click, 0.4, 1) self:Haptic("light") end
function FX:Hover() self:Sound(Assets.Sounds.Hover, 0.25, 1.3) end
function FX:Success() self:Sound(Assets.Sounds.Success, 0.6, 1.1) self:Haptic("heavy") end
function FX:Notify() self:Sound(Assets.Sounds.Notification, 0.5, 1) self:Haptic("heavy") end

--// STYLING ENGINE
local Style = {}

function Style:Tag(title, desc, mode)
    local colors = {
        info = "#8b9dc3",
        warn = "#ffaa55",
        risk = "#ff6b9d",
        power = "#ff91af",
        good = "#88ffaa"
    }
    
    local color = colors[mode:lower()] or colors.info
    local weight = (mode == "risk" or mode == "power") and "<b>" or ""
    
    return string.format(
        "<b>%s</b> <font color='%s'>%s%s%s</font>",
        title, color, weight, desc, weight ~= "" and "</b>" or ""
    )
end

function Style:Accent(text)
    return "<b><font color='#ff91af'>" .. text .. "</font></b>"
end

--// THEME: NEBULA STORM
local NebulaStorm = {
    TextColor = Color3.fromRGB(245, 240, 255),
    PlaceholderColor = Color3.fromRGB(135, 125, 155),
    
    Background = Color3.fromRGB(10, 8, 18),
    Topbar = Color3.fromRGB(16, 13, 28),
    Shadow = Color3.fromRGB(4, 2, 8),
    
    NotificationBackground = Color3.fromRGB(18, 15, 30),
    NotificationActionsBackground = Color3.fromRGB(26, 22, 40),
    
    TabBackground = Color3.fromRGB(22, 18, 35),
    TabStroke = Color3.fromRGB(55, 45, 75),
    TabBackgroundSelected = Color3.fromRGB(255, 145, 175),
    TabTextColor = Color3.fromRGB(245, 240, 255),
    SelectedTabTextColor = Color3.fromRGB(10, 8, 18),
    
    ElementBackground = Color3.fromRGB(18, 15, 30),
    ElementBackgroundHover = Color3.fromRGB(30, 25, 45),
    SecondaryElementBackground = Color3.fromRGB(14, 11, 24),
    ElementStroke = Color3.fromRGB(65, 55, 90),
    SecondaryElementStroke = Color3.fromRGB(50, 40, 70),
    
    SliderBackground = Color3.fromRGB(28, 24, 42),
    SliderProgress = Color3.fromRGB(255, 145, 175),
    SliderStroke = Color3.fromRGB(75, 65, 100),
    
    ToggleBackground = Color3.fromRGB(18, 15, 30),
    ToggleEnabled = Color3.fromRGB(255, 145, 175),
    ToggleDisabled = Color3.fromRGB(55, 45, 70),
    ToggleEnabledStroke = Color3.fromRGB(255, 165, 195),
    ToggleDisabledStroke = Color3.fromRGB(40, 30, 55),
    ToggleEnabledOuterStroke = Color3.fromRGB(75, 65, 95),
    ToggleDisabledOuterStroke = Color3.fromRGB(32, 22, 48),
    
    DropdownSelected = Color3.fromRGB(32, 27, 48),
    DropdownUnselected = Color3.fromRGB(18, 15, 30),
    
    InputBackground = Color3.fromRGB(18, 15, 30),
    InputStroke = Color3.fromRGB(65, 55, 90)
}

--// LOGIC INITIALIZATION (From Script 2)
if Env.cfg.autoarrest == nil then Env.cfg.autoarrest = false end
if Env.cfg.punchaura == nil then Env.cfg.punchaura = false end
if Env.cfg.ws_enabled == nil then Env.cfg.ws_enabled = false end
if Env.cfg.walkspeed == nil then Env.cfg.walkspeed = 16 end
if Env.cfg.jp_enabled == nil then Env.cfg.jp_enabled = false end
if Env.cfg.jumppower == nil then Env.cfg.jumppower = 50 end
if Env.cfg.noclip == nil then Env.cfg.noclip = false end
if Env.cfg.shootarrested == nil then Env.cfg.shootarrested = false end
if Env.cfg.autograb == nil then Env.cfg.autograb = false end

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

-- Anti-Collision Hook
task.spawn(function()
    pcall(function()
        local hook = newcclosure(function() return end)
        for _, obj in getgc(false) do 
            if typeof(obj) == "function" then 
                local source = debug.info(obj, "s")
                if source and source:find("CharacterCollision") then 
                    hookfunction(obj, hook)
                end
            end
        end
    end)
end)

-- Shoot while arrested loop
task.spawn(function()
    while true do
        if Env.cfg.shootarrested then
            local rs = ReplicatedStorage
            local re = rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("ClientArrested")
            if re then
                for _, cn in pairs(getconnections(re.OnClientEvent)) do
                    cn:Disable()
                end
            end
        end
        task.wait(1)
    end
end)

-- Auto Grab Logic
local grab_dist_sq = 12 * 12
local last_grab = 0
local giver_remote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("GiverPressed")
local grab_cache = {}
local cache_update_interval = 2
local last_cache_update = 0

local function updateGrabCache()
    grab_cache = {}
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and (obj.Name:lower():find("keycard") or obj.Name == "M9") then
            local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
            if part then
                local isOwned = false
                local anc = obj.Parent
                while anc and anc ~= Workspace do
                    if anc:FindFirstChild("Humanoid") or anc.Name == "Backpack" then 
                        isOwned = true 
                        break 
                    end
                    anc = anc.Parent
                end
                
                if not isOwned then
                    table.insert(grab_cache, {model = obj, part = part})
                end
            end
        end
    end
end

-- Main Loop (Movement/Combat)
RunService.Heartbeat:Connect(function()
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum = myChar and myChar:FindFirstChild("Humanoid")

    if myHum and myHrp then
        if Env.cfg.ws_enabled then myHum.WalkSpeed = Env.cfg.walkspeed end
        if Env.cfg.jp_enabled then myHum.JumpPower = Env.cfg.jumppower end
    end

    if Env.cfg.autograb and myHrp and giver_remote then
        local now = tick()
        
        if now - last_cache_update > cache_update_interval then
            updateGrabCache()
            last_cache_update = now
        end
        
        if now - last_grab > 0.5 then
            for _, cached in ipairs(grab_cache) do
                if cached.model and cached.part and cached.part.Parent then
                    local distSq = (cached.part.Position - myHrp.Position).Magnitude ^ 2
                    if distSq <= grab_dist_sq then
                        last_grab = now
                        giver_remote:FireServer(cached.model)
                        break
                    end
                end
            end
        end
    end

    if (Env.cfg.autoarrest or Env.cfg.punchaura) and myHrp then
        for _, target in ipairs(Players:GetPlayers()) do
            if target ~= LocalPlayer and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                local targetHrp = target.Character.HumanoidRootPart
                local dist = (targetHrp.Position - myHrp.Position).Magnitude

                if dist <= 25 then
                    if Env.cfg.autoarrest and LocalPlayer.Team == Env.Teams.Guards then
                        if target.Team == Env.Teams.Criminals or target.Team == Env.Teams.Inmates then
                            if not target.Character:FindFirstChild("ForceField") then
                                task.spawn(function()
                                    pcall(function() 
                                        ReplicatedStorage.Remotes.ArrestPlayer:InvokeServer(target.Character.HumanoidRootPart) 
                                    end)
                                end)
                            end
                        end
                    end

                    if Env.cfg.punchaura and target.Team ~= LocalPlayer.Team then
                        if not target.Character:FindFirstChild("ForceField") then
                            ReplicatedStorage.meleeEvent:FireServer(target)
                        end
                    end
                end
            end
        end
    end
end)

-- Config System
local configFolder = "CasualComasConfigs"

local function serializeColor3(color) return {R = color.R, G = color.G, B = color.B} end
local function deserializeColor3(tbl)
    if tbl and tbl.R and tbl.G and tbl.B then return Color3.new(tbl.R, tbl.G, tbl.B) end
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
    local success, data = pcall(function() return HttpService:JSONDecode(jsonString) end)
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
                    if enumType then result[key] = enumType[parts[2]] end
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
    if not isfolder then return false end
    if not isfolder(configFolder) then makefolder(configFolder) end
    local path = configFolder .. "/" .. name .. ".json"
    writefile(path, serializeConfig())
    return true
end

local function loadConfig(name)
    if not isfolder or not isfile then return false end
    local path = configFolder .. "/" .. name .. ".json"
    if not isfile(path) then return false end
    local data = readfile(path)
    local loaded = deserializeConfig(data)
    if not loaded then return false end
    for key, value in pairs(loaded) do
        if Env.cfg[key] ~= nil then Env.cfg[key] = value end
    end
    if Env.updateEsp then Env.updateEsp() end
    if Env.updateC4Esp then Env.updateC4Esp() end
    updateNoclip()
    return true
end

--// LOAD RAYFIELD
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

--// RICHTEXT AUTO-ENABLE & HOVER FX (From Script 1)
local internalEditor
internalEditor = RunService.Heartbeat:Connect(function()
    for _, obj in ipairs(game:GetService("CoreGui"):GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            if not obj.RichText then obj.RichText = true end
            local p = obj.Parent
            if p and p:IsA("Frame") and p.Name:find("Section") then obj.RichText = true end
        end
        
        if obj:IsA("TextButton") and not obj:GetAttribute("Enhanced") then
            obj:SetAttribute("Enhanced", true)
            obj.MouseEnter:Connect(function()
                FX:Hover()
                TweenService:Create(obj, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
                    BackgroundColor3 = NebulaStorm.ElementBackgroundHover
                }):Play()
            end)
            obj.MouseLeave:Connect(function()
                TweenService:Create(obj, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
                    BackgroundColor3 = NebulaStorm.ElementBackground
                }):Play()
            end)
        end
    end
end)

--// NOTIFICATION OVERRIDE (From Script 1)
local originalNotify = Rayfield.Notify
Rayfield.Notify = function(self, options)
    local notif = originalNotify(self, options)
    task.spawn(function()
        task.wait(0.00001)
        local titleTarget = options.Title
        local contentTarget = options.Content
        for _, obj in ipairs(game:GetService("CoreGui"):GetDescendants()) do
            if obj:IsA("TextLabel") then
                if obj.Text == titleTarget or obj.Text == contentTarget then
                    obj.RichText = true
                end
            end
        end
    end)
    
    task.spawn(function()
        task.wait(0.1)
        local notificationVibration = Instance.new("HapticEffect")
        notificationVibration.Name = "Casual Comas Haptic"
        notificationVibration.Type = Enum.HapticEffectType.GameplayExplosion
        notificationVibration.Looped = true
        notificationVibration.Parent = workspace
        notificationVibration:Play()
        task.wait(0.3)
        notificationVibration:Stop()
        notificationVibration.Ended:Connect(function() notificationVibration:Destroy() end)
    end)
    return notif
end

--// GLOBAL CLICK FEEDBACK
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local gui = game:GetService("CoreGui"):FindFirstChild("Rayfield")
        if gui then
            local mouse = Players.LocalPlayer:GetMouse()
            if mouse.Target and mouse.Target:IsDescendantOf(gui) then
                FX:Click()
            end
        end
    end
end)

--// CREATE WINDOW
local Window = Rayfield:CreateWindow({
    Name = "Casual Comas",
    LoadingTitle = "Casual Comas Hub",
    LoadingSubtitle = "Nebula Storm v" .. Env.Version,
    Icon = "cloud-lightning",
    Theme = NebulaStorm,
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
    DisableRayfieldPrompts = true,
})

--// TABS
local CombatTab = Window:CreateTab("Combat", "crosshair")
local VisualsTab = Window:CreateTab("Visuals", "eye")
local MovementTab = Window:CreateTab("Movement", "wind")
local UtilityTab = Window:CreateTab("Utility", "box")
local ConfigTab = Window:CreateTab("Config", "settings")

--// COMBAT
CombatTab:CreateSection("Silent Aim")

CombatTab:CreateToggle({
    Name = Style:Tag("Silent Aim", "Legit Mode", "power"), 
    CurrentValue = Env.cfg.enabled, 
    Callback = function(v) 
        Env.cfg.enabled = v 
        if v then FX:Success() end
    end
})

CombatTab:CreateSlider({
    Name = Style:Tag("FOV Radius", "Target Area", "info"), 
    Range = {10, 500}, 
    Increment = 1, 
    Suffix = "px", 
    CurrentValue = Env.cfg.fov, 
    Callback = function(v) Env.cfg.fov = v end
})

CombatTab:CreateToggle({
    Name = Style:Tag("Show FOV", "Draw Circle", "info"), 
    CurrentValue = Env.cfg.showfov, 
    Callback = function(v) Env.cfg.showfov = v end
})

CombatTab:CreateSlider({
    Name = Style:Tag("Hit Chance", "Accuracy", "risk"), 
    Range = {0, 100}, 
    Increment = 1, 
    Suffix = "%", 
    CurrentValue = Env.cfg.hitchance, 
    Callback = function(v) Env.cfg.hitchance = v end
})

CombatTab:CreateDropdown({
    Name = "Target Part", 
    Options = Env.cfg.partslist, 
    CurrentOption = {Env.cfg.aimpart}, 
    MultipleOptions = false, 
    Callback = function(o) Env.cfg.aimpart = o[1] end
})

CombatTab:CreateToggle({
    Name = Style:Tag("Random Parts", "Humanize Aim", "info"), 
    CurrentValue = Env.cfg.randomparts, 
    Callback = function(v) Env.cfg.randomparts = v end
})

CombatTab:CreateSection("Checks")

CombatTab:CreateToggle({
    Name = Style:Tag("Team Check", "Ignore Allies", "good"), 
    CurrentValue = Env.cfg.teamcheck, 
    Callback = function(v) Env.cfg.teamcheck = v end
})

CombatTab:CreateToggle({
    Name = Style:Tag("Wall Check", "Visible Only", "good"), 
    CurrentValue = Env.cfg.wallcheck, 
    Callback = function(v) Env.cfg.wallcheck = v end
})

CombatTab:CreateSection("Automation")

CombatTab:CreateToggle({
    Name = Style:Tag("Auto Shoot", "Trigger Bot", "power"), 
    CurrentValue = Env.cfg.autoshoot, 
    Callback = function(v) Env.cfg.autoshoot = v end
})

CombatTab:CreateToggle({
    Name = Style:Tag("Auto Arrest", "Guard Only", "risk"), 
    CurrentValue = Env.cfg.autoarrest, 
    Callback = function(v) Env.cfg.autoarrest = v end
})

CombatTab:CreateToggle({
    Name = Style:Tag("Punch Aura", "Melee Aura", "risk"), 
    CurrentValue = Env.cfg.punchaura, 
    Callback = function(v) Env.cfg.punchaura = v end
})

CombatTab:CreateSection("Shield Breaker")

CombatTab:CreateToggle({
    Name = Style:Tag("Shield Breaker", "Bypass Forcefield", "power"), 
    CurrentValue = Env.cfg.shieldbreaker, 
    Callback = function(v) Env.cfg.shieldbreaker = v end
})

--// VISUALS
VisualsTab:CreateSection("ESP System")

VisualsTab:CreateToggle({
    Name = Style:Tag("Player ESP", "Wallhack", "power"), 
    CurrentValue = Env.cfg.esp, 
    Callback = function(v) Env.cfg.esp = v; Env.updateEsp() end
})

VisualsTab:CreateToggle({
    Name = Style:Tag("Team Check", "Hide Allies", "info"), 
    CurrentValue = Env.cfg.espteamcheck, 
    Callback = function(v) Env.cfg.espteamcheck = v; Env.updateEsp() end
})

VisualsTab:CreateToggle({
    Name = Style:Tag("Team Colors", "Use Team Color", "info"), 
    CurrentValue = Env.cfg.espuseteamcolors, 
    Callback = function(v) Env.cfg.espuseteamcolors = v; Env.updateEsp() end
})

VisualsTab:CreateSection("Colors")

VisualsTab:CreateColorPicker({
    Name = "Guards Color", 
    Color = Env.cfg.espguards, 
    Callback = function(v) Env.cfg.espguards = v; Env.updateEsp() end
})

VisualsTab:CreateColorPicker({
    Name = "Inmates Color", 
    Color = Env.cfg.espinmates, 
    Callback = function(v) Env.cfg.espinmates = v; Env.updateEsp() end
})

VisualsTab:CreateColorPicker({
    Name = "Criminals Color", 
    Color = Env.cfg.espcriminals, 
    Callback = function(v) Env.cfg.espcriminals = v; Env.updateEsp() end
})

VisualsTab:CreateSection("Items")

VisualsTab:CreateToggle({
    Name = Style:Tag("C4 ESP", "Explosives", "warn"), 
    CurrentValue = Env.cfg.c4esp, 
    Callback = function(v) Env.cfg.c4esp = v; Env.updateC4Esp() end
})

--// MOVEMENT
MovementTab:CreateSection("Character")

MovementTab:CreateToggle({
    Name = Style:Tag("Walk Speed", "Modify Speed", "power"), 
    CurrentValue = Env.cfg.ws_enabled, 
    Callback = function(v) Env.cfg.ws_enabled = v end
})

MovementTab:CreateSlider({
    Name = "Speed Value", 
    Range = {16, 200}, 
    Increment = 1, 
    CurrentValue = Env.cfg.walkspeed, 
    Callback = function(v) Env.cfg.walkspeed = v end
})

MovementTab:CreateToggle({
    Name = Style:Tag("Jump Power", "Modify Jump", "power"), 
    CurrentValue = Env.cfg.jp_enabled, 
    Callback = function(v) Env.cfg.jp_enabled = v end
})

MovementTab:CreateSlider({
    Name = "Jump Value", 
    Range = {50, 500}, 
    Increment = 1, 
    CurrentValue = Env.cfg.jumppower, 
    Callback = function(v) Env.cfg.jumppower = v end
})

MovementTab:CreateSection("Physics")

MovementTab:CreateToggle({
    Name = Style:Tag("No Clip", "Walk Through Walls", "risk"), 
    CurrentValue = Env.cfg.noclip, 
    Callback = function(v) 
        Env.cfg.noclip = v 
        updateNoclip()
        if v then FX:Sound(Assets.Sounds.Whoosh, 0.6, 0.8) end
    end
})

MovementTab:CreateSection("Teleports")

local function tp(pos) 
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then 
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos) 
        FX:Sound(Assets.Sounds.Whoosh, 0.5, 1.2)
    end 
end

MovementTab:CreateButton({ Name = "Yard", Callback = function() tp(Vector3.new(780, 98, 2470)) end })
MovementTab:CreateButton({ Name = "Prison Interior", Callback = function() tp(Vector3.new(913, 100, 2388)) end })
MovementTab:CreateButton({ Name = "Armory", Callback = function() tp(Vector3.new(831, 100, 2233)) end })
MovementTab:CreateButton({ Name = "Cafeteria", Callback = function() tp(Vector3.new(905, 100, 2316)) end })
MovementTab:CreateButton({ Name = "Criminal Base", Callback = function() tp(Vector3.new(-931, 94, 2063)) end })

MovementTab:CreateButton({
    Name = Style:Tag("Instant Escape", "Become Criminal", "risk"), 
    Callback = function()
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        if h then
            local containers = Workspace:FindFirstChild("Shippingcontainers")
            if containers then
                pcall(function()
                    h.CFrame = containers:GetChildren()[6]:GetChildren()[2].CFrame
                end)
            else
                h.CFrame = CFrame.new(-931, 94, 2063)
            end
            task.wait(0.5)
            local hum = c:FindFirstChild("Humanoid")
            if hum then hum.Health = 0 end
        end
    end
})

--// UTILITY
UtilityTab:CreateSection("Bypass")

UtilityTab:CreateToggle({
    Name = Style:Tag("Arrest Bypass", "Shoot While Arrested", "risk"), 
    CurrentValue = Env.cfg.shootarrested, 
    Callback = function(v) Env.cfg.shootarrested = v end
})

UtilityTab:CreateSection("Items")

UtilityTab:CreateToggle({
    Name = Style:Tag("Auto Grab", "Keycards & Guns", "good"), 
    CurrentValue = Env.cfg.autograb, 
    Callback = function(v) Env.cfg.autograb = v end
})

--// CONFIG
ConfigTab:CreateSection("Manager")

local configNameInput = ""
ConfigTab:CreateInput({
    Name = "Config Name", 
    PlaceholderText = "Enter config name...", 
    RemoveTextAfterFocusLost = false, 
    Callback = function(t) configNameInput = t end
})

ConfigTab:CreateButton({
    Name = Style:Tag("Save Config", "Write to File", "info"), 
    Callback = function() 
        if configNameInput == "" then 
            Rayfield:Notify({Title = "Config", Content = "Please enter a config name!", Duration = 3, Image = "alert-circle"}) 
            return 
        end 
        if saveConfig(configNameInput) then 
            FX:Success()
            Rayfield:Notify({Title = "Saved", Content = "Config saved successfully", Duration = 3, Image = "check"}) 
        else 
            FX:Sound(Assets.Sounds.Error, 0.6, 1)
            Rayfield:Notify({Title = "Error", Content = "Failed to save config!", Duration = 3, Image = "x-circle"}) 
        end 
    end
})

ConfigTab:CreateButton({
    Name = Style:Tag("Load Config", "Read from File", "info"), 
    Callback = function() 
        if configNameInput == "" then 
            Rayfield:Notify({Title = "Config", Content = "Please enter a config name!", Duration = 3, Image = "alert-circle"}) 
            return 
        end 
        if loadConfig(configNameInput) then 
            FX:Sound(Assets.Sounds.PowerUp, 0.6, 1)
            Rayfield:Notify({Title = "Loaded", Content = "Config loaded successfully", Duration = 3, Image = "check"}) 
        else 
            FX:Sound(Assets.Sounds.Error, 0.6, 1)
            Rayfield:Notify({Title = "Error", Content = "Config not found!", Duration = 3, Image = "x-circle"}) 
        end 
    end
})

ConfigTab:CreateSection("Danger Zone")

ConfigTab:CreateButton({
    Name = Style:Tag("Reset Defaults", "Clear Settings", "risk"), 
    Callback = function() 
        Env.cfg.enabled = true
        Env.cfg.teamcheck = false
        Env.cfg.esp = false
        Env.cfg.autoarrest = false
        Env.cfg.punchaura = false
        Env.cfg.noclip = false
        Env.cfg.shootarrested = false
        Env.cfg.autograb = false
        Env.cfg.ws_enabled = false
        Env.cfg.jp_enabled = false
        updateNoclip()
        Env.updateEsp() 
        FX:Sound(Assets.Sounds.Whoosh, 0.6, 1)
        Rayfield:Notify({Title = "Reset", Content = "Settings restored to default", Duration = 3, Image = "refresh-cw"}) 
    end
})

--// STARTUP
task.wait(0.3)
FX:Sound(Assets.Sounds.PowerUp, 0.7, 1)
FX:Haptic("heavy")

Rayfield:Notify({
    Title = "Casual Comas",
    Content = "Premium Hub Loaded\nNebula Storm Edition",
    Duration = 4,
    Image = "zap"
})
