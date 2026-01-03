--[[ 
    Casual Comas // Lucid Dream Edition
    Theme: Deep Sleep (Violet & Soft Pink)
    "Entering the void..."
]]

local Env = getgenv().PL_Hub
if not Env then return warn("Load Part 1 First!") end

--// Services
local HttpService = Env.Services.HttpService
local ReplicatedStorage = Env.Services.ReplicatedStorage
local Players = Env.Services.Players
local LocalPlayer = Players.LocalPlayer
local RunService = Env.Services.RunService
local Workspace = game:GetService("Workspace")

--// Initial Config Checks
if Env.cfg.autoarrest == nil then Env.cfg.autoarrest = false end
if Env.cfg.punchaura == nil then Env.cfg.punchaura = false end
if Env.cfg.ws_enabled == nil then Env.cfg.ws_enabled = false end
if Env.cfg.walkspeed == nil then Env.cfg.walkspeed = 16 end
if Env.cfg.jp_enabled == nil then Env.cfg.jp_enabled = false end
if Env.cfg.jumppower == nil then Env.cfg.jumppower = 50 end
if Env.cfg.noclip == nil then Env.cfg.noclip = false end
if Env.cfg.shootarrested == nil then Env.cfg.shootarrested = false end
if Env.cfg.autograb == nil then Env.cfg.autograb = false end

--// Logic Handlers
local noclipConnection = nil
local function updateNoclip()
    if noclipConnection then noclipConnection:Disconnect() noclipConnection = nil end
    if Env.cfg.noclip then
        noclipConnection = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end)
    end
end

--// Character Collision Bypass
task.spawn(function()
    pcall(function()
        local hook = newcclosure(function() return end)
        for _, obj in getgc(false) do 
            if typeof(obj) == "function" then 
                local source = debug.info(obj, "s")
                if source and source:find("CharacterCollision") then hookfunction(obj, hook) end
            end
        end
    end)
end)

--// Logic Loops
task.spawn(function()
    while true do
        if Env.cfg.shootarrested then
            local rs = ReplicatedStorage
            local re = rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("ClientArrested")
            if re then for _, cn in pairs(getconnections(re.OnClientEvent)) do cn:Disable() end end
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
                    if anc:FindFirstChild("Humanoid") or anc.Name == "Backpack" then isOwned = true break end
                    anc = anc.Parent
                end
                if not isOwned then table.insert(grab_cache, {model = obj, part = part}) end
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
        if now - last_cache_update > cache_update_interval then updateGrabCache() last_cache_update = now end
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
                                task.spawn(function() pcall(function() ReplicatedStorage.Remotes.ArrestPlayer:InvokeServer(target.Character.HumanoidRootPart) end) end)
                            end
                        end
                    end
                    if Env.cfg.punchaura and target.Team ~= LocalPlayer.Team then
                        if not target.Character:FindFirstChild("ForceField") then ReplicatedStorage.meleeEvent:FireServer(target) end
                    end
                end
            end
        end
    end
end)

--// Config System
local configFolder = "CasualComasConfigs"
local function serializeColor3(color) return {R = color.R, G = color.G, B = color.B} end
local function deserializeColor3(tbl) if tbl and tbl.R and tbl.G and tbl.B then return Color3.new(tbl.R, tbl.G, tbl.B) end return Color3.new(1, 1, 1) end

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
            if enumPath then local parts = enumPath:split(".") if #parts == 2 then local enumType = Enum[parts[1]] if enumType then result[key] = enumType[parts[2]] end end end
        elseif entry.type == "table" then result[key] = entry.value
        else result[key] = entry.value end
    end
    return result
end

local function saveConfig(name)
    if not isfolder then return false end
    if not isfolder(configFolder) then makefolder(configFolder) end
    writefile(configFolder .. "/" .. name .. ".json", serializeConfig())
    return true
end

local function loadConfig(name)
    if not isfolder or not isfile then return false end
    local path = configFolder .. "/" .. name .. ".json"
    if not isfile(path) then return false end
    local loaded = deserializeConfig(readfile(path))
    if not loaded then return false end
    for key, value in pairs(loaded) do if Env.cfg[key] ~= nil then Env.cfg[key] = value end end
    if Env.updateEsp then Env.updateEsp() end
    if Env.updateC4Esp then Env.updateC4Esp() end
    updateNoclip()
    return true
end

--// UI Library Initialization
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

--// THEME: LUCID HAZE (Dark Violet & Soft Pink)
local LucidHaze = {
    TextColor                     = Color3.fromRGB(240, 230, 245), -- White with slight purple tint
    PlaceholderColor              = Color3.fromRGB(120, 110, 130),

    Background                    = Color3.fromRGB(20, 18, 28),    -- Deep Void Purple
    Topbar                        = Color3.fromRGB(26, 22, 35),    -- Slightly Lighter Violet
    Shadow                        = Color3.fromRGB(10, 8, 15),     -- Dark Shadow

    NotificationBackground        = Color3.fromRGB(26, 22, 35),
    NotificationActionsBackground = Color3.fromRGB(35, 30, 45),

    TabBackground                 = Color3.fromRGB(35, 30, 45),
    TabStroke                     = Color3.fromRGB(55, 45, 65),
    TabBackgroundSelected         = Color3.fromRGB(255, 145, 175), -- Soft Pink (The Coma)
    TabTextColor                  = Color3.fromRGB(240, 230, 245),
    SelectedTabTextColor          = Color3.fromRGB(20, 18, 28),    -- Contrast for Pink

    ElementBackground             = Color3.fromRGB(30, 26, 40),
    ElementBackgroundHover        = Color3.fromRGB(40, 34, 55),
    SecondaryElementBackground    = Color3.fromRGB(26, 22, 35),
    ElementStroke                 = Color3.fromRGB(60, 50, 75),
    SecondaryElementStroke        = Color3.fromRGB(50, 40, 60),

    SliderBackground              = Color3.fromRGB(45, 40, 60),
    SliderProgress                = Color3.fromRGB(255, 145, 175), -- Soft Pink
    SliderStroke                  = Color3.fromRGB(70, 60, 90),

    ToggleBackground              = Color3.fromRGB(30, 26, 40),
    ToggleEnabled                 = Color3.fromRGB(255, 145, 175), -- Soft Pink
    ToggleDisabled                = Color3.fromRGB(80, 70, 90),
    ToggleEnabledStroke           = Color3.fromRGB(255, 160, 190),
    ToggleDisabledStroke          = Color3.fromRGB(60, 50, 70),
    ToggleEnabledOuterStroke      = Color3.fromRGB(70, 60, 80),
    ToggleDisabledOuterStroke     = Color3.fromRGB(45, 35, 55),

    DropdownSelected              = Color3.fromRGB(40, 34, 55),
    DropdownUnselected            = Color3.fromRGB(30, 26, 40),

    InputBackground               = Color3.fromRGB(30, 26, 40),
    InputStroke                   = Color3.fromRGB(60, 50, 75)
}

local ComaTitles = {
    "Drifting into unconsciousness...",
    "Fading reality...",
    "Entering REM cycle...",
    "Disconnecting form...",
    "Injecting Casual Comas...",
    "Waking the nightmare...",
    "Lucid Dream initiated...",
    "Dissociating..."
}

local Window = Rayfield:CreateWindow({
    Name = "Casual Comas",
    LoadingTitle = ComaTitles[math.random(1, #ComaTitles)],
    LoadingSubtitle = "v" .. Env.Version .. " // Dream State",
    Theme = LucidHaze,
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
    DisableRayfieldPrompts = true,
})

--// Tabs
local CombatTab = Window:CreateTab("Violence", "sword") -- "Combat" is boring. Violence fits the "bad dream" vibe.
local VisualsTab = Window:CreateTab("Hallucinations", "eye") -- "Visuals" -> Hallucinations
local MovementTab = Window:CreateTab("Sleepwalk", "footprints") -- "Movement" -> Sleepwalk
local UtilityTab = Window:CreateTab("Lucidity", "zap") -- "Utility" -> Lucidity
local ConfigTab = Window:CreateTab("Memory", "save") -- "Config" -> Memory

--// COMBAT TAB //--
CombatTab:CreateSection("Targeting")

CombatTab:CreateToggle({
    Name = "<b>Silent Aim</b> <font color='#ff99bb'>Hazy Hit</font>", 
    CurrentValue = Env.cfg.enabled, 
    Callback = function(v) Env.cfg.enabled = v end
})

CombatTab:CreateSlider({
    Name = "FOV Radius <font transparency='0.6'>Vision Blur</font>", 
    Range = {10, 500}, 
    Increment = 1, 
    Suffix = "px", 
    CurrentValue = Env.cfg.fov, 
    Callback = function(v) Env.cfg.fov = v end
})

CombatTab:CreateToggle({
    Name = "Show FOV <font transparency='0.6'>Draw Circle</font>", 
    CurrentValue = Env.cfg.showfov, 
    Callback = function(v) Env.cfg.showfov = v end
})

CombatTab:CreateDropdown({
    Name = "Target Limb", 
    Options = Env.cfg.partslist, 
    CurrentOption = {Env.cfg.aimpart}, 
    MultipleOptions = false, 
    Callback = function(o) Env.cfg.aimpart = o[1] end
})

CombatTab:CreateDivider()

CombatTab:CreateSection("Safety Checks")

CombatTab:CreateToggle({
    Name = "Team Check <font transparency='0.6'>Friendly Fire</font>", 
    CurrentValue = Env.cfg.teamcheck, 
    Callback = function(v) Env.cfg.teamcheck = v end
})

CombatTab:CreateToggle({
    Name = "Wall Check <font transparency='0.6'>Visible Only</font>", 
    CurrentValue = Env.cfg.wallcheck, 
    Callback = function(v) Env.cfg.wallcheck = v end
})

CombatTab:CreateSection("Aggression")

CombatTab:CreateToggle({
    Name = "Auto Arrest <font color='#ff99bb'>Nightmare Mode</font>", 
    CurrentValue = Env.cfg.autoarrest, 
    Callback = function(v) Env.cfg.autoarrest = v end
})

CombatTab:CreateToggle({
    Name = "Punch Aura <font transparency='0.6'>Personal Space</font>", 
    CurrentValue = Env.cfg.punchaura, 
    Callback = function(v) Env.cfg.punchaura = v end
})

--// VISUALS TAB //--
VisualsTab:CreateSection("ESP Settings")

VisualsTab:CreateToggle({
    Name = "<b>Player ESP</b> <font color='#ff99bb'>See Souls</font>", 
    CurrentValue = Env.cfg.esp, 
    Callback = function(v) Env.cfg.esp = v; Env.updateEsp() end
})

VisualsTab:CreateSlider({
    Name = "Render Distance", 
    Range = {50, 2000}, 
    Increment = 10, 
    Suffix = "m", 
    CurrentValue = Env.cfg.espmaxdist, 
    Callback = function(v) Env.cfg.espmaxdist = v; Env.updateEsp() end
})

VisualsTab:CreateDivider()

VisualsTab:CreateColorPicker({
    Name = "Guards <font transparency='0.6'>Aura</font>", 
    Color = Env.cfg.espguards, 
    Callback = function(v) Env.cfg.espguards = v; Env.updateEsp() end
})
VisualsTab:CreateColorPicker({
    Name = "Inmates <font transparency='0.6'>Aura</font>", 
    Color = Env.cfg.espinmates, 
    Callback = function(v) Env.cfg.espinmates = v; Env.updateEsp() end
})
VisualsTab:CreateColorPicker({
    Name = "Criminals <font transparency='0.6'>Aura</font>", 
    Color = Env.cfg.espcriminals, 
    Callback = function(v) Env.cfg.espcriminals = v; Env.updateEsp() end
})

--// MOVEMENT TAB //--
MovementTab:CreateSection("Body Control")

MovementTab:CreateToggle({
    Name = "Enable WalkSpeed", 
    CurrentValue = Env.cfg.ws_enabled, 
    Callback = function(v) Env.cfg.ws_enabled = v end
})

MovementTab:CreateSlider({
    Name = "WalkSpeed <font transparency='0.6'>Pace</font>", 
    Range = {16, 200}, 
    Increment = 1, 
    CurrentValue = Env.cfg.walkspeed, 
    Callback = function(v) Env.cfg.walkspeed = v end
})

MovementTab:CreateDivider()

MovementTab:CreateToggle({
    Name = "Enable JumpPower", 
    CurrentValue = Env.cfg.jp_enabled, 
    Callback = function(v) Env.cfg.jp_enabled = v end
})

MovementTab:CreateSlider({
    Name = "JumpPower <font transparency='0.6'>Height</font>", 
    Range = {50, 500}, 
    Increment = 1, 
    CurrentValue = Env.cfg.jumppower, 
    Callback = function(v) Env.cfg.jumppower = v end
})

MovementTab:CreateSection("Ghost Mode")
MovementTab:CreateToggle({
    Name = "Noclip <font color='#ff99bb'>Phase</font>", 
    CurrentValue = Env.cfg.noclip, 
    Callback = function(v) Env.cfg.noclip = v; updateNoclip() end
})

MovementTab:CreateSection("Dream Warping")

local function tp(pos) 
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then 
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos) 
    end 
end

MovementTab:CreateButton({ Name = "Yard", Callback = function() tp(Vector3.new(780, 98, 2470)) end })
MovementTab:CreateButton({ Name = "Prison Interior", Callback = function() tp(Vector3.new(913, 100, 2388)) end })
MovementTab:CreateButton({ Name = "Armory", Callback = function() tp(Vector3.new(831, 100, 2233)) end })
MovementTab:CreateButton({ Name = "Criminal Base", Callback = function() tp(Vector3.new(-931, 94, 2063)) end })

--// UTILITY TAB //--
UtilityTab:CreateSection("Interaction")

UtilityTab:CreateToggle({
    Name = "Auto Grab <font color='#ff99bb'>Snatch</font>", 
    CurrentValue = Env.cfg.autograb, 
    Callback = function(v) Env.cfg.autograb = v end
})

UtilityTab:CreateSection("Exploits")

UtilityTab:CreateToggle({
    Name = "Walk While Arrested <font transparency='0.6'>Anti-Stun</font>", 
    CurrentValue = Env.cfg.shootarrested, 
    Callback = function(v) Env.cfg.shootarrested = v end
})

--// CONFIG TAB //--
ConfigTab:CreateSection("Brain State")

local configNameInput = ""
ConfigTab:CreateInput({
    Name = "State Name", 
    PlaceholderText = "Name this dream...", 
    RemoveTextAfterFocusLost = false, 
    Callback = function(t) configNameInput = t end
})

ConfigTab:CreateButton({
    Name = "Save State", 
    Callback = function() 
        if configNameInput == "" then 
            Rayfield:Notify({Title = "Error", Content = "Name your dream first.", Image = "alert-circle"}) 
            return 
        end 
        if saveConfig(configNameInput) then 
            Rayfield:Notify({Title = "Saved", Content = "State <b>" .. configNameInput.."</b> preserved.", Image = "check"}) 
        end 
    end
})

ConfigTab:CreateButton({
    Name = "Load State", 
    Callback = function() 
        if configNameInput == "" then 
            Rayfield:Notify({Title = "Error", Content = "Which dream to load?", Image = "alert-circle"}) 
            return 
        end 
        if loadConfig(configNameInput) then 
            Rayfield:Notify({Title = "Loaded", Content = "Entering state: <b>" .. configNameInput.."</b>", Image = "check"}) 
        end 
    end
})

ConfigTab:CreateDivider()
ConfigTab:CreateLabel("Casual Comas v" .. Env.Version, "info", Color3.fromRGB(180, 160, 200))

Rayfield:Notify({
    Title = "Casual Comas", 
    Content = "You are now <b>asleep</b>. Good luck.", 
    Image = "moon",
    Duration = 5
})
