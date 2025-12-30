local Env = getgenv().PL_Hub
if not Env then return warn("Load Part 1 First!") end

local HttpService = Env.Services.HttpService
local ReplicatedStorage = Env.Services.ReplicatedStorage
local Players = Env.Services.Players
local LocalPlayer = Players.LocalPlayer
local RunService = Env.Services.RunService
local Workspace = game:GetService("Workspace")

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
        if Env.cfg[key] ~= nil then 
            Env.cfg[key] = value 
        end
    end
    if Env.updateEsp then Env.updateEsp() end
    if Env.updateC4Esp then Env.updateC4Esp() end
    updateNoclip()
    return true
end

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
    Name = "Casual Comas",
    LoadingTitle = "Casual Comas Hub",
    LoadingSubtitle = "v" .. Env.Version,
    Theme = customTheme,
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

local CombatTab = Window:CreateTab("Combat", 4483362458)
local VisualsTab = Window:CreateTab("Visuals", 4483362458)
local MovementTab = Window:CreateTab("Movement", 4483362458)
local UtilityTab = Window:CreateTab("Utility", 4483362458)
local ConfigTab = Window:CreateTab("Config", 4483362458)

CombatTab:CreateSection("Silent Aim")
CombatTab:CreateToggle({
    Name = "Enable Silent Aim", 
    CurrentValue = Env.cfg.enabled, 
    Callback = function(v) Env.cfg.enabled = v end
})
CombatTab:CreateSlider({
    Name = "FOV Radius", 
    Range = {10, 500}, 
    Increment = 1, 
    Suffix = "px", 
    CurrentValue = Env.cfg.fov, 
    Callback = function(v) Env.cfg.fov = v end
})
CombatTab:CreateToggle({
    Name = "Show FOV Circle", 
    CurrentValue = Env.cfg.showfov, 
    Callback = function(v) Env.cfg.showfov = v end
})
CombatTab:CreateSlider({
    Name = "Hit Chance", 
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
    Name = "Random Parts", 
    CurrentValue = Env.cfg.randomparts, 
    Callback = function(v) Env.cfg.randomparts = v end
})

CombatTab:CreateSection("Targeting")
CombatTab:CreateToggle({
    Name = "Team Check", 
    CurrentValue = Env.cfg.teamcheck, 
    Callback = function(v) Env.cfg.teamcheck = v end
})
CombatTab:CreateToggle({
    Name = "Wall Check", 
    CurrentValue = Env.cfg.wallcheck, 
    Callback = function(v) Env.cfg.wallcheck = v end
})
CombatTab:CreateToggle({
    Name = "Death Check", 
    CurrentValue = Env.cfg.deathcheck, 
    Callback = function(v) Env.cfg.deathcheck = v end
})
CombatTab:CreateToggle({
    Name = "ForceField Check", 
    CurrentValue = Env.cfg.ffcheck, 
    Callback = function(v) Env.cfg.ffcheck = v end
})
CombatTab:CreateToggle({
    Name = "Vehicle Check", 
    CurrentValue = Env.cfg.vehiclecheck, 
    Callback = function(v) Env.cfg.vehiclecheck = v end
})
CombatTab:CreateToggle({
    Name = "Hostile Check (Guards)", 
    CurrentValue = Env.cfg.hostilecheck, 
    Callback = function(v) Env.cfg.hostilecheck = v end
})
CombatTab:CreateToggle({
    Name = "Trespass Check (Guards)", 
    CurrentValue = Env.cfg.trespasscheck, 
    Callback = function(v) Env.cfg.trespasscheck = v end
})

CombatTab:CreateSection("Automation")
CombatTab:CreateToggle({
    Name = "Auto Shoot", 
    CurrentValue = Env.cfg.autoshoot, 
    Callback = function(v) Env.cfg.autoshoot = v end
})
CombatTab:CreateSlider({
    Name = "Shot Delay", 
    Range = {0.05, 0.5}, 
    Increment = 0.01, 
    Suffix = "s", 
    CurrentValue = Env.cfg.autoshootdelay, 
    Callback = function(v) Env.cfg.autoshootdelay = v end
})
CombatTab:CreateSlider({
    Name = "Start Delay", 
    Range = {0, 1}, 
    Increment = 0.05, 
    Suffix = "s", 
    CurrentValue = Env.cfg.autoshootstartdelay, 
    Callback = function(v) Env.cfg.autoshootstartdelay = v end
})
CombatTab:CreateToggle({
    Name = "Auto Arrest (Guard)", 
    CurrentValue = Env.cfg.autoarrest, 
    Callback = function(v) Env.cfg.autoarrest = v end
})
CombatTab:CreateToggle({
    Name = "Punch Aura", 
    CurrentValue = Env.cfg.punchaura, 
    Callback = function(v) Env.cfg.punchaura = v end
})

CombatTab:CreateSection("Shield Breaker")
CombatTab:CreateToggle({
    Name = "Enable Shield Breaker", 
    CurrentValue = Env.cfg.shieldbreaker, 
    Callback = function(v) Env.cfg.shieldbreaker = v end
})
CombatTab:CreateSlider({
    Name = "Head Shot Chance", 
    Range = {0, 100}, 
    Increment = 1, 
    Suffix = "%", 
    CurrentValue = Env.cfg.shieldheadchance, 
    Callback = function(v) Env.cfg.shieldheadchance = v end
})

VisualsTab:CreateSection("Player ESP")
VisualsTab:CreateToggle({
    Name = "Enable ESP", 
    CurrentValue = Env.cfg.esp, 
    Callback = function(v) Env.cfg.esp = v; Env.updateEsp() end
})
VisualsTab:CreateToggle({
    Name = "Team Check", 
    CurrentValue = Env.cfg.espteamcheck, 
    Callback = function(v) Env.cfg.espteamcheck = v; Env.updateEsp() end
})
VisualsTab:CreateToggle({
    Name = "Use Team Colors", 
    CurrentValue = Env.cfg.espuseteamcolors, 
    Callback = function(v) Env.cfg.espuseteamcolors = v; Env.updateEsp() end
})
VisualsTab:CreateSlider({
    Name = "Max Distance", 
    Range = {50, 1000}, 
    Increment = 10, 
    Suffix = "m", 
    CurrentValue = Env.cfg.espmaxdist, 
    Callback = function(v) Env.cfg.espmaxdist = v; Env.updateEsp() end
})

VisualsTab:CreateSection("Team Colors")
VisualsTab:CreateColorPicker({
    Name = "Guards", 
    Color = Env.cfg.espguards, 
    Callback = function(v) Env.cfg.espguards = v; Env.updateEsp() end
})
VisualsTab:CreateColorPicker({
    Name = "Inmates", 
    Color = Env.cfg.espinmates, 
    Callback = function(v) Env.cfg.espinmates = v; Env.updateEsp() end
})
VisualsTab:CreateColorPicker({
    Name = "Criminals", 
    Color = Env.cfg.espcriminals, 
    Callback = function(v) Env.cfg.espcriminals = v; Env.updateEsp() end
})

VisualsTab:CreateSection("C4 ESP")
VisualsTab:CreateToggle({
    Name = "Enable C4 ESP", 
    CurrentValue = Env.cfg.c4esp, 
    Callback = function(v) Env.cfg.c4esp = v; Env.updateC4Esp() end
})
VisualsTab:CreateColorPicker({
    Name = "C4 Color", 
    Color = Env.cfg.c4espcolor, 
    Callback = function(v) Env.cfg.c4espcolor = v; Env.updateC4Esp() end
})

MovementTab:CreateSection("Speed")
MovementTab:CreateToggle({
    Name = "Enable WalkSpeed", 
    CurrentValue = Env.cfg.ws_enabled, 
    Callback = function(v) Env.cfg.ws_enabled = v end
})
MovementTab:CreateSlider({
    Name = "WalkSpeed", 
    Range = {16, 200}, 
    Increment = 1, 
    CurrentValue = Env.cfg.walkspeed, 
    Callback = function(v) Env.cfg.walkspeed = v end
})
MovementTab:CreateToggle({
    Name = "Enable JumpPower", 
    CurrentValue = Env.cfg.jp_enabled, 
    Callback = function(v) Env.cfg.jp_enabled = v end
})
MovementTab:CreateSlider({
    Name = "JumpPower", 
    Range = {50, 500}, 
    Increment = 1, 
    CurrentValue = Env.cfg.jumppower, 
    Callback = function(v) Env.cfg.jumppower = v end
})

MovementTab:CreateSection("Physics")
MovementTab:CreateToggle({
    Name = "Noclip", 
    CurrentValue = Env.cfg.noclip, 
    Callback = function(v) 
        Env.cfg.noclip = v 
        updateNoclip()
    end
})

MovementTab:CreateSection("Teleports")
local function tp(pos) 
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then 
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos) 
    end 
end
MovementTab:CreateButton({
    Name = "Yard", 
    Callback = function() tp(Vector3.new(780, 98, 2470)) end
})
MovementTab:CreateButton({
    Name = "Prison Interior", 
    Callback = function() tp(Vector3.new(913, 100, 2388)) end
})
MovementTab:CreateButton({
    Name = "Armory", 
    Callback = function() tp(Vector3.new(831, 100, 2233)) end
})
MovementTab:CreateButton({
    Name = "Cafeteria", 
    Callback = function() tp(Vector3.new(905, 100, 2316)) end
})
MovementTab:CreateButton({
    Name = "Criminal Base", 
    Callback = function() tp(Vector3.new(-931, 94, 2063)) end
})
MovementTab:CreateButton({
    Name = "Instant Escape", 
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

UtilityTab:CreateSection("Bypass")
UtilityTab:CreateToggle({
    Name = "Walk While Arrested", 
    CurrentValue = Env.cfg.shootarrested, 
    Callback = function(v) Env.cfg.shootarrested = v end
})

UtilityTab:CreateSection("Item Pickup")
UtilityTab:CreateToggle({
    Name = "Auto Grab Items", 
    CurrentValue = Env.cfg.autograb, 
    Callback = function(v) Env.cfg.autograb = v end
})

ConfigTab:CreateSection("Configuration Manager")
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
        if configNameInput == "" then 
            Rayfield:Notify({
                Title = "Config", 
                Content = "Please enter a config name!", 
                Duration = 3
            }) 
            return 
        end 
        if saveConfig(configNameInput) then 
            Rayfield:Notify({
                Title = "Config Saved", 
                Content = "Saved: " .. configNameInput, 
                Duration = 3
            }) 
        else 
            Rayfield:Notify({
                Title = "Config Error", 
                Content = "Failed to save config!", 
                Duration = 3
            }) 
        end 
    end
})
ConfigTab:CreateButton({
    Name = "Load Config", 
    Callback = function() 
        if configNameInput == "" then 
            Rayfield:Notify({
                Title = "Config", 
                Content = "Please enter a config name!", 
                Duration = 3
            }) 
            return 
        end 
        if loadConfig(configNameInput) then 
            Rayfield:Notify({
                Title = "Config Loaded", 
                Content = "Loaded: " .. configNameInput, 
                Duration = 3
            }) 
        else 
            Rayfield:Notify({
                Title = "Config Error", 
                Content = "Config not found!", 
                Duration = 3
            }) 
        end 
    end
})

ConfigTab:CreateSection("Reset")
ConfigTab:CreateButton({
    Name = "Reset to Defaults", 
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
        Rayfield:Notify({
            Title = "Reset Complete", 
            Content = "All settings restored to default", 
            Duration = 3
        }) 
    end
})

Rayfield:Notify({
    Title = "Welcome!", 
    Content = "Casual Comas v" .. Env.Version, 
    Duration = 5
})
