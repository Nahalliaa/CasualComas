-- [[ PART 3: UI, MECHANICS & EXPLOITS ]] --
local Env = getgenv().PL_Hub
if not Env then return warn("Load Part 1 First!") end

local HttpService = Env.Services.HttpService
local ReplicatedStorage = Env.Services.ReplicatedStorage
local Players = Env.Services.Players
local LocalPlayer = Players.LocalPlayer
local RunService = Env.Services.RunService
local Workspace = game:GetService("Workspace")

-- // 1. INITIALIZE NEW SETTINGS //
-- Auras
if Env.cfg.autoarrest == nil then Env.cfg.autoarrest = false end
if Env.cfg.punchaura == nil then Env.cfg.punchaura = false end
-- Player Mods
if Env.cfg.ws_enabled == nil then Env.cfg.ws_enabled = false end
if Env.cfg.walkspeed == nil then Env.cfg.walkspeed = 16 end
if Env.cfg.jp_enabled == nil then Env.cfg.jp_enabled = false end
if Env.cfg.jumppower == nil then Env.cfg.jumppower = 50 end
if Env.cfg.noclip == nil then Env.cfg.noclip = false end
-- Exploits
if Env.cfg.shootarrested == nil then Env.cfg.shootarrested = false end -- Walk while arrested
if Env.cfg.autograb == nil then Env.cfg.autograb = false end

-- // 2. NOCLIP BYPASS (One-time Hook) //
-- This prevents the game from forcing collisions back on
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

-- // 3. WALK WHILE ARRESTED LOOP //
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

-- // 4. MAIN LOGIC LOOP (Mods, Grab, Auras) //
local grab_dist_sq = 12 * 12
local last_grab = 0
local giver_remote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("GiverPressed")

RunService.Heartbeat:Connect(function()
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum = myChar and myChar:FindFirstChild("Humanoid")

    -- [Player Mods]
    if myHum and myHrp then
        if Env.cfg.ws_enabled then myHum.WalkSpeed = Env.cfg.walkspeed end
        if Env.cfg.jp_enabled then myHum.JumpPower = Env.cfg.jumppower end
        
        if Env.cfg.noclip then
            for _, part in pairs(myChar:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end

    -- [Auto Grab Tools]
    if Env.cfg.autograb and myHrp and giver_remote then
        local now = tick()
        if now - last_grab > 0.5 then
            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj:IsA("Model") and (obj.Name:lower():find("keycard") or obj.Name == "M9") then
                    local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
                    if part then
                        local distSq = (part.Position - myHrp.Position).Magnitude ^ 2
                        if distSq <= grab_dist_sq then
                            -- Check if not owned (no humanoid parent)
                            local isOwned = false
                            local anc = obj.Parent
                            while anc and anc ~= Workspace do
                                if anc:FindFirstChild("Humanoid") or anc.Name == "Backpack" then isOwned = true break end
                                anc = anc.Parent
                            end
                            
                            if not isOwned then
                                last_grab = now
                                giver_remote:FireServer(obj)
                            end
                        end
                    end
                end
            end
        end
    end

    -- [Combat Auras]
    if (Env.cfg.autoarrest or Env.cfg.punchaura) and myHrp then
        for _, target in ipairs(Players:GetPlayers()) do
            if target ~= LocalPlayer and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                local targetHrp = target.Character.HumanoidRootPart
                local dist = (targetHrp.Position - myHrp.Position).Magnitude

                if dist <= 25 then
                    -- Auto Arrest
                    if Env.cfg.autoarrest and LocalPlayer.Team == Env.Teams.Guards then
                        if target.Team == Env.Teams.Criminals or target.Team == Env.Teams.Inmates then
                            if not target.Character:FindFirstChild("ForceField") then
                                task.spawn(function()
                                    pcall(function() ReplicatedStorage.Remotes.ArrestPlayer:InvokeServer(target.Character.HumanoidRootPart) end)
                                end)
                            end
                        end
                    end

                    -- Punch Aura
                    if Env.cfg.punchaura and target.Team ~= LocalPlayer.Team then
                        if not target.Character:FindFirstChild("ForceField") then
                            local args = { [1] = target }
                            ReplicatedStorage.meleeEvent:FireServer(unpack(args))
                        end
                    end
                end
            end
        end
    end
end)

-- // 5. CONFIGURATION SYSTEM //
local configFolder = "SilentAimConfigs"
local function serializeColor3(color) return {R = color.R, G = color.G, B = color.B} end
local function deserializeColor3(tbl)
    if tbl and tbl.R and tbl.G and tbl.B then return Color3.new(tbl.R, tbl.G, tbl.B) end
    return Color3.new(1, 1, 1)
end

local function serializeConfig()
    local data = {}
    for key, value in pairs(Env.cfg) do
        if typeof(value) == "Color3" then data[key] = {type = "Color3", value = serializeColor3(value)}
        elseif typeof(value) == "EnumItem" then data[key] = {type = "EnumItem", value = tostring(value)}
        elseif typeof(value) == "table" then data[key] = {type = "table", value = value}
        else data[key] = {type = typeof(value), value = value} end
    end
    return HttpService:JSONEncode(data)
end

local function deserializeConfig(jsonString)
    local success, data = pcall(function() return HttpService:JSONDecode(jsonString) end)
    if not success then return nil end
    local result = {}
    for key, entry in pairs(data) do
        if entry.type == "Color3" then result[key] = deserializeColor3(entry.value)
        elseif entry.type == "EnumItem" then
            local enumPath = entry.value:match("Enum%.(.+)")
            if enumPath then
                local parts = enumPath:split(".")
                if #parts == 2 then
                    local enumType = Enum[parts[1]]
                    if enumType then result[key] = enumType[parts[2]] end
                end
            end
        elseif entry.type == "table" then result[key] = entry.value
        else result[key] = entry.value end
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
    return true
end

-- // 6. RAYFIELD UI SETUP //
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local customTheme = {
    TextColor = Color3.fromRGB(255, 255, 255),
    Background = Color3.fromRGB(20, 20, 35),
    Topbar = Color3.fromRGB(25, 25, 45),
    Shadow = Color3.fromRGB(10, 10, 20),
    NotificationBackground = Color3.fromRGB(25, 25, 45),
    NotificationActionsBackground = Color3.fromRGB(40, 40, 60),
    TabBackground = Color3.fromRGB(35, 35, 55),
    TabStroke = Color3.fromRGB(60, 60, 90),
    TabBackgroundSelected = Color3.fromRGB(50, 50, 80),
    TabTextColor = Color3.fromRGB(200, 200, 200),
    SelectedTabTextColor = Color3.fromRGB(255, 255, 255),
    ElementBackground = Color3.fromRGB(30, 30, 50),
    ElementBackgroundHover = Color3.fromRGB(40, 40, 60),
    SecondaryElementBackground = Color3.fromRGB(35, 35, 55),
    ElementStroke = Color3.fromRGB(60, 60, 90),
    SecondaryElementStroke = Color3.fromRGB(50, 50, 80),
    SliderBackground = Color3.fromRGB(60, 60, 100),
    SliderProgress = Color3.fromRGB(120, 80, 255),
    SliderStroke = Color3.fromRGB(80, 80, 120),
    ToggleBackground = Color3.fromRGB(30, 30, 50),
    ToggleEnabled = Color3.fromRGB(120, 80, 255),
    ToggleDisabled = Color3.fromRGB(80, 80, 80),
    ToggleEnabledStroke = Color3.fromRGB(150, 100, 255),
    ToggleDisabledStroke = Color3.fromRGB(60, 60, 60),
    ToggleEnabledOuterStroke = Color3.fromRGB(50, 50, 50),
    ToggleDisabledOuterStroke = Color3.fromRGB(40, 40, 40),
    DropdownSelected = Color3.fromRGB(40, 40, 60),
    DropdownUnselected = Color3.fromRGB(30, 30, 50),
    InputBackground = Color3.fromRGB(30, 30, 50),
    InputStroke = Color3.fromRGB(60, 60, 90),
    PlaceholderColor = Color3.fromRGB(150, 150, 150)
}

local Window = Rayfield:CreateWindow({
    Name = "Prison Life Silent Aim",
    LoadingTitle = "Prison Life Utils",
    LoadingSubtitle = "by Version " .. Env.Version,
    Theme = customTheme,
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

-- // TABS //
local AimbotTab = Window:CreateTab("Aimbot", 4483362458)
local ESPTab = Window:CreateTab("ESP", 4483362458)
local AutoshootTab = Window:CreateTab("Autoshoot", 4483362458)
local ModsTab = Window:CreateTab("Mods", 4483362458) -- NEW
local TeleportsTab = Window:CreateTab("Teleports", 4483362458) -- NEW
local ExploitsTab = Window:CreateTab("Exploits", 4483362458) -- NEW
local SettingsTab = Window:CreateTab("Settings", 4483362458)

-- // AIMBOT //
local MainAimSection = AimbotTab:CreateSection("Main")
AimbotTab:CreateToggle({Name = "Silent Aim", CurrentValue = Env.cfg.enabled, Flag = "SilentAim", Callback = function(v) Env.cfg.enabled = v end})
AimbotTab:CreateToggle({Name = "Team Check", CurrentValue = Env.cfg.teamcheck, Callback = function(v) Env.cfg.teamcheck = v end})
AimbotTab:CreateToggle({Name = "Wall Check", CurrentValue = Env.cfg.wallcheck, Callback = function(v) Env.cfg.wallcheck = v end})
AimbotTab:CreateToggle({Name = "Death Check", CurrentValue = Env.cfg.deathcheck, Callback = function(v) Env.cfg.deathcheck = v end})
local ChecksSection = AimbotTab:CreateSection("Checks")
AimbotTab:CreateToggle({Name = "Hostile Check (Guards)", CurrentValue = Env.cfg.hostilecheck, Callback = function(v) Env.cfg.hostilecheck = v end})
AimbotTab:CreateToggle({Name = "Trespass Check (Guards)", CurrentValue = Env.cfg.trespasscheck, Callback = function(v) Env.cfg.trespasscheck = v end})
AimbotTab:CreateToggle({Name = "Vehicle Check", CurrentValue = Env.cfg.vehiclecheck, Callback = function(v) Env.cfg.vehiclecheck = v end})
AimbotTab:CreateToggle({Name = "FF Check", CurrentValue = Env.cfg.ffcheck, Callback = function(v) Env.cfg.ffcheck = v end})
local SettingsAimSection = AimbotTab:CreateSection("Settings")
AimbotTab:CreateSlider({Name = "FOV Radius", Range = {10, 500}, Increment = 1, Suffix = "px", CurrentValue = Env.cfg.fov, Flag = "FOV", Callback = function(v) Env.cfg.fov = v end})
AimbotTab:CreateToggle({Name = "Show FOV", CurrentValue = Env.cfg.showfov, Callback = function(v) Env.cfg.showfov = v end})
AimbotTab:CreateSlider({Name = "Hit Chance", Range = {0, 100}, Increment = 1, Suffix = "%", CurrentValue = Env.cfg.hitchance, Callback = function(v) Env.cfg.hitchance = v end})
AimbotTab:CreateDropdown({Name = "Aim Part", Options = Env.cfg.partslist, CurrentOption = {Env.cfg.aimpart}, MultipleOptions = false, Callback = function(o) Env.cfg.aimpart = o[1] end})
AimbotTab:CreateToggle({Name = "Random Parts", CurrentValue = Env.cfg.randomparts, Callback = function(v) Env.cfg.randomparts = v end})
local ShieldSection = AimbotTab:CreateSection("Shield Breaker")
AimbotTab:CreateToggle({Name = "Shield Breaker", CurrentValue = Env.cfg.shieldbreaker, Callback = function(v) Env.cfg.shieldbreaker = v end})
AimbotTab:CreateSlider({Name = "Shield Head Chance", Range = {0, 100}, Increment = 1, Suffix = "%", CurrentValue = Env.cfg.shieldheadchance, Callback = function(v) Env.cfg.shieldheadchance = v end})

-- // ESP //
local ESPMainSection = ESPTab:CreateSection("Main")
ESPTab:CreateToggle({Name = "Enable ESP", CurrentValue = Env.cfg.esp, Callback = function(v) Env.cfg.esp = v; Env.updateEsp() end})
ESPTab:CreateToggle({Name = "Team Check", CurrentValue = Env.cfg.espteamcheck, Callback = function(v) Env.cfg.espteamcheck = v; Env.updateEsp() end})
ESPTab:CreateToggle({Name = "Use Team Colors", CurrentValue = Env.cfg.espuseteamcolors, Callback = function(v) Env.cfg.espuseteamcolors = v; Env.updateEsp() end})
ESPTab:CreateSlider({Name = "Max Distance", Range = {50, 1000}, Increment = 10, Suffix = "m", CurrentValue = Env.cfg.espmaxdist, Callback = function(v) Env.cfg.espmaxdist = v; Env.updateEsp() end})
local ESPColorsSection = ESPTab:CreateSection("Colors")
ESPTab:CreateColorPicker({Name = "Guards Color", Color = Env.cfg.espguards, Callback = function(v) Env.cfg.espguards = v; Env.updateEsp() end})
ESPTab:CreateColorPicker({Name = "Inmates Color", Color = Env.cfg.espinmates, Callback = function(v) Env.cfg.espinmates = v; Env.updateEsp() end})
ESPTab:CreateColorPicker({Name = "Criminals Color", Color = Env.cfg.espcriminals, Callback = function(v) Env.cfg.espcriminals = v; Env.updateEsp() end})
local C4Section = ESPTab:CreateSection("C4 ESP")
ESPTab:CreateToggle({Name = "C4 ESP", CurrentValue = Env.cfg.c4esp, Callback = function(v) Env.cfg.c4esp = v; Env.updateC4Esp() end})
ESPTab:CreateColorPicker({Name = "C4 Color", Color = Env.cfg.c4espcolor, Callback = function(v) Env.cfg.c4espcolor = v; Env.updateC4Esp() end})

-- // AUTOSHOOT //
local AutoShootSection = AutoshootTab:CreateSection("Configuration")
AutoshootTab:CreateToggle({Name = "Enabled", CurrentValue = Env.cfg.autoshoot, Callback = function(v) Env.cfg.autoshoot = v end})
AutoshootTab:CreateSlider({Name = "Shot Delay", Range = {0.05, 0.5}, Increment = 0.01, Suffix = "s", CurrentValue = Env.cfg.autoshootdelay, Callback = function(v) Env.cfg.autoshootdelay = v end})
AutoshootTab:CreateSlider({Name = "Start Delay", Range = {0, 1}, Increment = 0.05, Suffix = "s", CurrentValue = Env.cfg.autoshootstartdelay, Callback = function(v) Env.cfg.autoshootstartdelay = v end})

-- // PLAYER MODS //
ModsTab:CreateSection("Movement")
ModsTab:CreateToggle({Name = "Enable WalkSpeed", CurrentValue = Env.cfg.ws_enabled, Callback = function(v) Env.cfg.ws_enabled = v end})
ModsTab:CreateSlider({Name = "Speed Amount", Range = {16, 200}, Increment = 1, CurrentValue = Env.cfg.walkspeed, Callback = function(v) Env.cfg.walkspeed = v end})
ModsTab:CreateToggle({Name = "Enable JumpPower", CurrentValue = Env.cfg.jp_enabled, Callback = function(v) Env.cfg.jp_enabled = v end})
ModsTab:CreateSlider({Name = "Jump Amount", Range = {50, 500}, Increment = 1, CurrentValue = Env.cfg.jumppower, Callback = function(v) Env.cfg.jumppower = v end})
ModsTab:CreateSection("Character")
ModsTab:CreateToggle({Name = "Noclip", CurrentValue = Env.cfg.noclip, Callback = function(v) Env.cfg.noclip = v end})

-- // TELEPORTS //
TeleportsTab:CreateSection("Escapes")
TeleportsTab:CreateButton({Name = "Instant Escape", Callback = function()
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    if h then
        -- Teleport to criminal base spawn area container
        local containers = Workspace:FindFirstChild("Shippingcontainers")
        if containers then
             -- Try to find a safe spot or use hardcoded vector if heirarchy fails
            pcall(function()
                 h.CFrame = containers:GetChildren()[6]:GetChildren()[2].CFrame
            end)
        else
            h.CFrame = CFrame.new(-931, 94, 2063) -- Fallback
        end
        task.wait(0.5)
        local hum = c:FindFirstChild("Humanoid")
        if hum then hum.Health = 0 end -- Suicide to respawn as crim
    end
end})
TeleportsTab:CreateSection("Locations")
local function tp(pos) if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos) end end
TeleportsTab:CreateButton({Name = "Yard", Callback = function() tp(Vector3.new(780, 98, 2470)) end})
TeleportsTab:CreateButton({Name = "Prison", Callback = function() tp(Vector3.new(913, 100, 2388)) end})
TeleportsTab:CreateButton({Name = "Armory", Callback = function() tp(Vector3.new(831, 100, 2233)) end})
TeleportsTab:CreateButton({Name = "Cafeteria", Callback = function() tp(Vector3.new(905, 100, 2316)) end})
TeleportsTab:CreateButton({Name = "Crim Base", Callback = function() tp(Vector3.new(-931, 94, 2063)) end})

-- // EXPLOITS //
local ExploitsSection = ExploitsTab:CreateSection("Auras")
ExploitsTab:CreateToggle({Name = "Auto Arrest (Guards Only)", CurrentValue = Env.cfg.autoarrest, Callback = function(v) Env.cfg.autoarrest = v end})
ExploitsTab:CreateToggle({Name = "Punch Aura (25 Studs)", CurrentValue = Env.cfg.punchaura, Callback = function(v) Env.cfg.punchaura = v end})
ExploitsTab:CreateSection("Utils")
ExploitsTab:CreateToggle({Name = "Walk While Arrested", CurrentValue = Env.cfg.shootarrested, Callback = function(v) Env.cfg.shootarrested = v end})
ExploitsTab:CreateToggle({Name = "Auto Grab Items (M9/Key)", CurrentValue = Env.cfg.autograb, Callback = function(v) Env.cfg.autograb = v end})

-- // SETTINGS //
local configNameInput = ""
SettingsTab:CreateInput({Name = "Config Name", PlaceholderText = "Enter config name...", RemoveTextAfterFocusLost = false, Callback = function(t) configNameInput = t end})
SettingsTab:CreateButton({Name = "Save Config", Callback = function() if configNameInput == "" then Rayfield:Notify({Title = "Config", Content = "Please enter a config name!", Duration = 3}) return end if saveConfig(configNameInput) then Rayfield:Notify({Title = "Config", Content = "Saved config: " .. configNameInput, Duration = 3}) else Rayfield:Notify({Title = "Config", Content = "Failed to save config!", Duration = 3}) end end})
SettingsTab:CreateButton({Name = "Load Config", Callback = function() if configNameInput == "" then Rayfield:Notify({Title = "Config", Content = "Please enter a config name!", Duration = 3}) return end if loadConfig(configNameInput) then Rayfield:Notify({Title = "Config", Content = "Loaded config: " .. configNameInput, Duration = 3}) else Rayfield:Notify({Title = "Config", Content = "Config not found!", Duration = 3}) end end})
SettingsTab:CreateButton({Name = "Reset Defaults", Callback = function() 
    Env.cfg.enabled = true Env.cfg.teamcheck = false Env.cfg.esp = false Env.cfg.autoarrest = false Env.cfg.punchaura = false 
    Env.cfg.noclip = false Env.cfg.shootarrested = false Env.cfg.autograb = false Env.updateEsp() 
    Rayfield:Notify({Title = "Config", Content = "Reset to defaults", Duration = 3}) 
end})

Rayfield:Notify({Title = "Loaded", Content = "NaphtaHub v" .. Env.Version .. " Welcome!", Duration = 5})
