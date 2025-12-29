-- [[ PART 3: UI, LOGIC & EXPLOITS ]] --
local Env = getgenv().PL_Hub
if not Env then return warn("Load Part 1 First!") end

-- // SERVICES //
local HttpService = Env.Services.HttpService
local ReplicatedStorage = Env.Services.ReplicatedStorage
local Players = Env.Services.Players
local LocalPlayer = Players.LocalPlayer
local RunService = Env.Services.RunService
local Workspace = game:GetService("Workspace")
local StarterGui = Env.Services.StarterGui

-- // 1. INITIALIZE SETTINGS //
local defaults = {
    autoarrest = false,
    punchaura = false,
    shootarrested = false,
    autograb = false,
    antitaser = false,
    noclip = false,
    walkspeed = 16,
    jumppower = 50,
    ws_enabled = false,
    jp_enabled = false
}

for k, v in pairs(defaults) do
    if Env.cfg[k] == nil then Env.cfg[k] = v end
end

-- // 2. LOGIC FUNCTIONS & LOOPS //

-- [Shoot While Arrested Logic]
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

-- [Auto Grab Logic Variables]
local grab_dist_sq = 12 * 12
local last_grab = 0
local giver_remote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("GiverPressed")

-- [Main Loop]
RunService.Heartbeat:Connect(function()
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum = myChar and myChar:FindFirstChild("Humanoid")

    -- 1. Player Mods (Speed/Jump/Noclip)
    if myHum and myHrp then
        if Env.cfg.ws_enabled then myHum.WalkSpeed = Env.cfg.walkspeed end
        if Env.cfg.jp_enabled then myHum.JumpPower = Env.cfg.jumppower end
        
        if Env.cfg.noclip then
            for _, part in pairs(myChar:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end

    -- 2. Anti-Taser (Simple Loop)
    if Env.cfg.antitaser and myHum then
        if myHum.WalkSpeed < 16 and not Env.cfg.ws_enabled then
            myHum.WalkSpeed = 16 
        end
        if myHum.JumpPower < 50 and not Env.cfg.jp_enabled then 
            myHum.JumpPower = 50 
        end
        -- Force unsit if tased
        if myHum.Sit and not Env.isInVehicle(LocalPlayer) then
            myHum.Sit = false
        end
    end

    -- 3. Auto Grab Tools
    if Env.cfg.autograb and myHrp and giver_remote then
        local now = tick()
        if now - last_grab > 0.5 then
            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj:IsA("Model") and (obj.Name:lower():find("keycard") or obj.Name == "M9") then
                    local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
                    if part then
                        local distSq = (part.Position - myHrp.Position).Magnitude ^ 2
                        if distSq <= grab_dist_sq then
                            -- Check if not owned
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

    -- 4. Combat Auras
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
                                    pcall(function() ReplicatedStorage.Remotes.ArrestPlayer:InvokeServer(target) end)
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

-- // 3. CONFIG SAVING SYSTEM //
local configFolder = "SilentAimConfigs"
local function serializeColor3(color) return {R = color.R, G = color.G, B = color.B} end
local function deserializeColor3(tbl) if tbl and tbl.R then return Color3.new(tbl.R, tbl.G, tbl.B) end return Color3.new(1,1,1) end

local function serializeConfig()
    local data = {}
    for key, value in pairs(Env.cfg) do
        if typeof(value) == "Color3" then data[key] = {type = "Color3", value = serializeColor3(value)}
        elseif typeof(value) == "EnumItem" then data[key] = {type = "EnumItem", value = tostring(value)}
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
        elseif entry.type == "EnumItem" then result[key] = entry.value -- Simplified enum loading
        else result[key] = entry.value end
    end
    return result
end

local function saveConfig(name)
    if not isfolder(configFolder) then makefolder(configFolder) end
    writefile(configFolder .. "/" .. name .. ".json", serializeConfig())
    return true
end

local function loadConfig(name)
    local path = configFolder .. "/" .. name .. ".json"
    if not isfile(path) then return false end
    local loaded = deserializeConfig(readfile(path))
    if loaded then
        for k,v in pairs(loaded) do if Env.cfg[k] ~= nil then Env.cfg[k] = v end end
        if Env.updateEsp then Env.updateEsp() end
        if Env.updateC4Esp then Env.updateC4Esp() end
        return true
    end
    return false
end

-- // 4. RAYFIELD UI SETUP //
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local customTheme = {
    TextColor = Color3.fromRGB(255, 255, 255),
    Background = Color3.fromRGB(20, 20, 35),
    Topbar = Color3.fromRGB(25, 25, 45),
    Shadow = Color3.fromRGB(10, 10, 20),
    NotificationBackground = Color3.fromRGB(25, 25, 45),
    TabBackground = Color3.fromRGB(35, 35, 55),
    TabStroke = Color3.fromRGB(60, 60, 90),
    TabBackgroundSelected = Color3.fromRGB(50, 50, 80),
    TabTextColor = Color3.fromRGB(200, 200, 200),
    SelectedTabTextColor = Color3.fromRGB(255, 255, 255),
    ElementBackground = Color3.fromRGB(30, 30, 50),
    ElementStroke = Color3.fromRGB(60, 60, 90),
    SliderBackground = Color3.fromRGB(60, 60, 100),
    SliderProgress = Color3.fromRGB(120, 80, 255),
    SliderStroke = Color3.fromRGB(80, 80, 120),
    ToggleBackground = Color3.fromRGB(30, 30, 50),
    ToggleEnabled = Color3.fromRGB(120, 80, 255),
    ToggleDisabled = Color3.fromRGB(80, 80, 80),
    ToggleEnabledStroke = Color3.fromRGB(150, 100, 255),
    ToggleDisabledStroke = Color3.fromRGB(60, 60, 60),
    InputBackground = Color3.fromRGB(30, 30, 50),
    InputStroke = Color3.fromRGB(60, 60, 90)
}

local Window = Rayfield:CreateWindow({
    Name = "Prison Life Extended",
    LoadingTitle = "NaphtaHub",
    LoadingSubtitle = "v" .. Env.Version,
    Theme = customTheme,
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

-- // TABS //
local AimbotTab = Window:CreateTab("Aimbot", 4483362458)
local VisualsTab = Window:CreateTab("Visuals", 4483362458)
local CombatTab = Window:CreateTab("Combat", 4483362458)
local PlayerTab = Window:CreateTab("Player", 4483362458)
local TeleportsTab = Window:CreateTab("Teleports", 4483362458)
local SettingsTab = Window:CreateTab("Settings", 4483362458)

-- [[ AIMBOT TAB ]] --
local MainAim = AimbotTab:CreateSection("Silent Aim")
AimbotTab:CreateToggle({Name = "Enabled", CurrentValue = Env.cfg.enabled, Flag = "SilentAim", Callback = function(v) Env.cfg.enabled = v end})
AimbotTab:CreateToggle({Name = "Team Check", CurrentValue = Env.cfg.teamcheck, Callback = function(v) Env.cfg.teamcheck = v end})
AimbotTab:CreateToggle({Name = "Wall Check", CurrentValue = Env.cfg.wallcheck, Callback = function(v) Env.cfg.wallcheck = v end})
AimbotTab:CreateSlider({Name = "FOV Radius", Range = {10, 500}, CurrentValue = Env.cfg.fov, Flag = "FOV", Callback = function(v) Env.cfg.fov = v end})
AimbotTab:CreateToggle({Name = "Show FOV", CurrentValue = Env.cfg.showfov, Callback = function(v) Env.cfg.showfov = v end})
AimbotTab:CreateSlider({Name = "Hit Chance", Range = {0, 100}, CurrentValue = Env.cfg.hitchance, Callback = function(v) Env.cfg.hitchance = v end})
AimbotTab:CreateDropdown({Name = "Aim Part", Options = Env.cfg.partslist, CurrentOption = {Env.cfg.aimpart}, MultipleOptions = false, Callback = function(o) Env.cfg.aimpart = o[1] end})

local AutoshootSection = AimbotTab:CreateSection("Autoshoot")
AimbotTab:CreateToggle({Name = "Autoshoot", CurrentValue = Env.cfg.autoshoot, Callback = function(v) Env.cfg.autoshoot = v end})
AimbotTab:CreateSlider({Name = "Shot Delay", Range = {0.05, 0.5}, Increment = 0.01, CurrentValue = Env.cfg.autoshootdelay, Callback = function(v) Env.cfg.autoshootdelay = v end})

-- [[ VISUALS TAB ]] --
VisualsTab:CreateSection("ESP")
VisualsTab:CreateToggle({Name = "Enable ESP", CurrentValue = Env.cfg.esp, Callback = function(v) Env.cfg.esp = v; Env.updateEsp() end})
VisualsTab:CreateToggle({Name = "Team Check", CurrentValue = Env.cfg.espteamcheck, Callback = function(v) Env.cfg.espteamcheck = v; Env.updateEsp() end})
VisualsTab:CreateSlider({Name = "Max Distance", Range = {50, 1000}, CurrentValue = Env.cfg.espmaxdist, Callback = function(v) Env.cfg.espmaxdist = v; Env.updateEsp() end})
VisualsTab:CreateColorPicker({Name = "Enemy Color", Color = Env.cfg.espcolor, Callback = function(v) Env.cfg.espcolor = v; Env.updateEsp() end})
VisualsTab:CreateSection("Items")
VisualsTab:CreateToggle({Name = "C4 ESP", CurrentValue = Env.cfg.c4esp, Callback = function(v) Env.cfg.c4esp = v; Env.updateC4Esp() end})

-- [[ COMBAT TAB ]] --
CombatTab:CreateSection("Offensive")
CombatTab:CreateToggle({Name = "Kill Aura (Punch - 25 Studs)", CurrentValue = Env.cfg.punchaura, Callback = function(v) Env.cfg.punchaura = v end})
CombatTab:CreateToggle({Name = "Shoot While Arrested", CurrentValue = Env.cfg.shootarrested, Callback = function(v) Env.cfg.shootarrested = v end})

CombatTab:CreateSection("Guard Features")
CombatTab:CreateToggle({Name = "Auto Arrest (25 Studs)", CurrentValue = Env.cfg.autoarrest, Callback = function(v) Env.cfg.autoarrest = v end})

CombatTab:CreateSection("Get Guns (Risky/Patched)")
local function tpAndBack(pos)
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    if h then
        local old = h.CFrame
        h.CFrame = CFrame.new(pos)
        task.wait(0.2)
        h.CFrame = old
    end
end
CombatTab:CreateButton({Name = "Get Shotgun", Callback = function() tpAndBack(Vector3.new(821.44, 98.91, 2217.17)) end})
CombatTab:CreateButton({Name = "Get AK-47", Callback = function() tpAndBack(Vector3.new(-931.86, 92.20, 2039.39)) end})
CombatTab:CreateButton({Name = "Get M9", Callback = function() tpAndBack(Vector3.new(813.77, 98.80, 2217.45)) end})

-- [[ PLAYER TAB ]] --
PlayerTab:CreateSection("Movement")
PlayerTab:CreateToggle({Name = "Toggle Speed", CurrentValue = Env.cfg.ws_enabled, Callback = function(v) Env.cfg.ws_enabled = v end})
PlayerTab:CreateSlider({Name = "WalkSpeed", Range = {16, 200}, CurrentValue = Env.cfg.walkspeed, Callback = function(v) Env.cfg.walkspeed = v end})
PlayerTab:CreateToggle({Name = "Toggle Jump", CurrentValue = Env.cfg.jp_enabled, Callback = function(v) Env.cfg.jp_enabled = v end})
PlayerTab:CreateSlider({Name = "JumpPower", Range = {50, 300}, CurrentValue = Env.cfg.jumppower, Callback = function(v) Env.cfg.jumppower = v end})
PlayerTab:CreateToggle({Name = "Noclip", CurrentValue = Env.cfg.noclip, Callback = function(v) Env.cfg.noclip = v end})

PlayerTab:CreateSection("Utility")
PlayerTab:CreateToggle({Name = "Auto Grab Keycard/M9 (12 Studs)", CurrentValue = Env.cfg.autograb, Callback = function(v) Env.cfg.autograb = v end})
PlayerTab:CreateToggle({Name = "Anti-Taser", CurrentValue = Env.cfg.antitaser, Callback = function(v) Env.cfg.antitaser = v end})

-- [[ TELEPORTS TAB ]] --
TeleportsTab:CreateSection("Escapes")
TeleportsTab:CreateButton({Name = "Instant Escape", Callback = function()
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    if h then
        h.CFrame = Workspace.Shippingcontainers:GetChildren()[6]:GetChildren()[2].CFrame
        task.wait(2)
        local hum = c:FindFirstChild("Humanoid")
        if hum then hum.Health = 0 end
    end
end})

TeleportsTab:CreateSection("Locations")
local function tp(pos) 
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos) 
    end 
end
TeleportsTab:CreateButton({Name = "Yard", Callback = function() tp(Vector3.new(780, 98, 2470)) end})
TeleportsTab:CreateButton({Name = "Prison", Callback = function() tp(Vector3.new(913, 100, 2388)) end})
TeleportsTab:CreateButton({Name = "Armory", Callback = function() tp(Vector3.new(831, 100, 2233)) end})
TeleportsTab:CreateButton({Name = "Cafeteria", Callback = function() tp(Vector3.new(905, 100, 2316)) end})
TeleportsTab:CreateButton({Name = "Crim Base", Callback = function() tp(Vector3.new(-931, 94, 2063)) end})

-- [[ SETTINGS TAB ]] --
local configNameInput = ""
SettingsTab:CreateInput({Name = "Config Name", PlaceholderText = "Name...", RemoveTextAfterFocusLost = false, Callback = function(t) configNameInput = t end})
SettingsTab:CreateButton({Name = "Save Config", Callback = function() if configNameInput ~= "" then saveConfig(configNameInput) Rayfield:Notify({Title="Saved", Content=configNameInput, Duration=2}) end end})
SettingsTab:CreateButton({Name = "Load Config", Callback = function() if configNameInput ~= "" then loadConfig(configNameInput) Rayfield:Notify({Title="Loaded", Content=configNameInput, Duration=2}) end end})
SettingsTab:CreateButton({Name = "Rejoin Server", Callback = function() game:GetService('TeleportService'):TeleportToPlaceInstance(game.PlaceId,game.JobId,LocalPlayer) end})

Rayfield:Notify({Title = "Loaded", Content = "Casual Coma v" .. Env.Version .. " Ready", Duration = 5})
