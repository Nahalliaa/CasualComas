--[[ 
    Casual Comas // Cloud Edition (Fixed)
    "Soft as a cloud, hits like a coma."
    
    Changelog:
    - Fixed 2 FPS bug (Optimized Grab Loop)
    - Added RayBeats Mobile Haptics
    - Fixed RichText (<b> tags showing)
    - Optimized Sound Engine
]]

local Env = getgenv().PL_Hub
if not Env then return warn("Load Part 1 First!") end

--// Services
local HttpService = Env.Services.HttpService
local ReplicatedStorage = Env.Services.ReplicatedStorage
local Players = Env.Services.Players
local LocalPlayer = Players.LocalPlayer
local RunService = Env.Services.RunService
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

--// RayBeats Style Asset Loader (Prevent lag by pre-loading)
local Sounds = {
    Click = Instance.new("Sound"),
    Hover = Instance.new("Sound"),
    Notification = Instance.new("Sound"),
    Error = Instance.new("Sound"),
    Success = Instance.new("Sound")
}

Sounds.Click.SoundId = "rbxassetid://6895079853"
Sounds.Hover.SoundId = "rbxassetid://6895079775"
Sounds.Notification.SoundId = "rbxassetid://4590662766"
Sounds.Error.SoundId = "rbxassetid://4590657391"
Sounds.Success.SoundId = "rbxassetid://6895079853"

for _, s in pairs(Sounds) do s.Volume = 1; s.Parent = SoundService end

local function PlaySound(snd)
    if snd then snd:Play() end
end

local function TriggerVibration()
    --// RayBeats Haptic Method (Works on Mobile/Console)
    task.spawn(function()
        pcall(function()
            local vib = Instance.new("HapticEffect")
            vib.Name = "CloudHaptic"
            vib.Type = Enum.HapticEffectType.GameplayExplosion
            vib.Looped = false
            vib.Parent = Workspace
            vib:Play()
            task.wait(0.2)
            vib:Destroy()
        end)
    end)
end

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
if Env.cfg.autoshoot == nil then Env.cfg.autoshoot = false end
if Env.cfg.shieldbreaker == nil then Env.cfg.shieldbreaker = false end
if Env.cfg.c4esp == nil then Env.cfg.c4esp = false end

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
local cache_update_interval = 3 -- Increased delay to save FPS
local last_cache_update = 0

local function updateGrabCache()
    grab_cache = {}
    --// OPTIMIZATION: Only search Children, not Descendants (Fixes 2 FPS issue)
    local items = Workspace:GetChildren()
    for _, obj in pairs(items) do
        if obj:IsA("Model") and (obj.Name:lower():find("keycard") or obj.Name == "M9" or obj.Name == "Remington 870" or obj.Name == "AK-47") then
            local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
            if part then
                local isOwned = false
                local anc = obj.Parent
                -- Quick check if it's being held
                if anc and (anc:FindFirstChild("Humanoid") or anc.Name == "Backpack") then isOwned = true end
                
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
        --// OPTIMIZATION: Throttled loop for combat
        if tick() % 0.1 < 0.02 then 
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

--// THE FIX: Force RichText on all Rayfield Elements
task.spawn(function()
    while true do
        task.wait(1)
        local gui = CoreGui:FindFirstChild("Rayfield")
        if gui then
            for _, v in pairs(gui:GetDescendants()) do
                if v:IsA("TextLabel") and not v.RichText then
                    v.RichText = true
                end
            end
        end
    end
end)

--// Override Notify for Sound/Haptics & RichText
local originalNotify = Rayfield.Notify
Rayfield.Notify = function(self, options)
    PlaySound(Sounds.Notification)
    TriggerVibration()
    
    local notif = originalNotify(self, options)
    
    -- Force RichText on Notification immediately
    task.spawn(function()
        task.wait()
        if notif then
            for _, v in pairs(notif:GetDescendants()) do
                if v:IsA("TextLabel") then v.RichText = true end
            end
        end
    end)
    
    return notif
end

--// THEME: NIGHT SKY (Dark Violet & Soft Pink)
local NightSky = {
    TextColor                     = Color3.fromRGB(240, 230, 245), 
    PlaceholderColor              = Color3.fromRGB(120, 110, 130),

    Background                    = Color3.fromRGB(20, 18, 28),    
    Topbar                        = Color3.fromRGB(26, 22, 35),    
    Shadow                        = Color3.fromRGB(10, 8, 15),     

    NotificationBackground        = Color3.fromRGB(26, 22, 35),
    NotificationActionsBackground = Color3.fromRGB(35, 30, 45),

    TabBackground                 = Color3.fromRGB(35, 30, 45),
    TabStroke                     = Color3.fromRGB(55, 45, 65),
    TabBackgroundSelected         = Color3.fromRGB(255, 145, 175),
    TabTextColor                  = Color3.fromRGB(240, 230, 245),
    SelectedTabTextColor          = Color3.fromRGB(20, 18, 28),    

    ElementBackground             = Color3.fromRGB(30, 26, 40),
    ElementBackgroundHover        = Color3.fromRGB(40, 34, 55),
    SecondaryElementBackground    = Color3.fromRGB(26, 22, 35),
    ElementStroke                 = Color3.fromRGB(60, 50, 75),
    SecondaryElementStroke        = Color3.fromRGB(50, 40, 60),

    SliderBackground              = Color3.fromRGB(45, 40, 60),
    SliderProgress                = Color3.fromRGB(255, 145, 175), 
    SliderStroke                  = Color3.fromRGB(70, 60, 90),

    ToggleBackground              = Color3.fromRGB(30, 26, 40),
    ToggleEnabled                 = Color3.fromRGB(255, 145, 175), 
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

local Window = Rayfield:CreateWindow({
    Name = "Casual Comas",
    LoadingTitle = "Casual Comas",
    LoadingSubtitle = "v" .. Env.Version,
    Icon = "cloud-fog",
    Theme = NightSky,
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
    DisableRayfieldPrompts = true,
})

--// Tabs
local CombatTab = Window:CreateTab("Combat", "sword")
local VisualsTab = Window:CreateTab("Visuals", "eye")
local MovementTab = Window:CreateTab("Movement", "footprints")
local UtilityTab = Window:CreateTab("Utility", "zap")
local ConfigTab = Window:CreateTab("Settings", "settings")
local CreditsTab = Window:CreateTab("Credits", "info")

--// COMBAT TAB //--
CombatTab:CreateSection("Targeting")

CombatTab:CreateToggle({
    Name = "<b>Silent Aim</b> <font color='#ff99bb'>Legit</font>", 
    CurrentValue = Env.cfg.enabled, 
    Callback = function(v) Env.cfg.enabled = v; PlaySound(Sounds.Click) end
})

CombatTab:CreateSlider({
    Name = "FOV Radius <font transparency='0.6'>Size</font>", 
    Range = {10, 500}, 
    Increment = 1, 
    Suffix = "px", 
    CurrentValue = Env.cfg.fov, 
    Callback = function(v) Env.cfg.fov = v end
})

CombatTab:CreateToggle({
    Name = "Show FOV <font transparency='0.6'>Visual</font>", 
    CurrentValue = Env.cfg.showfov, 
    Callback = function(v) Env.cfg.showfov = v; PlaySound(Sounds.Click) end
})

CombatTab:CreateDropdown({
    Name = "Target Limb", 
    Options = Env.cfg.partslist, 
    CurrentOption = {Env.cfg.aimpart}, 
    MultipleOptions = false, 
    Callback = function(o) Env.cfg.aimpart = o[1]; PlaySound(Sounds.Click) end
})

CombatTab:CreateDivider()
CombatTab:CreateSection("Aggression")

CombatTab:CreateToggle({
    Name = "Auto Shoot <font transparency='0.6'>Triggerbot</font>", 
    CurrentValue = Env.cfg.autoshoot, 
    Callback = function(v) Env.cfg.autoshoot = v; PlaySound(Sounds.Click) end
})

CombatTab:CreateToggle({
    Name = "Shield Breaker <font color='#ff99bb'>Bypass</font>", 
    CurrentValue = Env.cfg.shieldbreaker, 
    Callback = function(v) Env.cfg.shieldbreaker = v; PlaySound(Sounds.Click) end
})

CombatTab:CreateToggle({
    Name = "Auto Arrest <font transparency='0.6'>Guards Only</font>", 
    CurrentValue = Env.cfg.autoarrest, 
    Callback = function(v) Env.cfg.autoarrest = v; PlaySound(Sounds.Click) end
})

CombatTab:CreateToggle({
    Name = "Punch Aura <font transparency='0.6'>Melee</font>", 
    CurrentValue = Env.cfg.punchaura, 
    Callback = function(v) Env.cfg.punchaura = v; PlaySound(Sounds.Click) end
})

CombatTab:CreateDivider()
CombatTab:CreateSection("Checks")

CombatTab:CreateToggle({
    Name = "Team Check", 
    CurrentValue = Env.cfg.teamcheck, 
    Callback = function(v) Env.cfg.teamcheck = v; PlaySound(Sounds.Click) end
})

CombatTab:CreateToggle({
    Name = "Wall Check", 
    CurrentValue = Env.cfg.wallcheck, 
    Callback = function(v) Env.cfg.wallcheck = v; PlaySound(Sounds.Click) end
})

--// VISUALS TAB //--
VisualsTab:CreateSection("Player ESP")

VisualsTab:CreateToggle({
    Name = "<b>Player ESP</b> <font color='#ff99bb'>Enable</font>", 
    CurrentValue = Env.cfg.esp, 
    Callback = function(v) Env.cfg.esp = v; Env.updateEsp(); PlaySound(Sounds.Click) end
})

VisualsTab:CreateToggle({
    Name = "C4 ESP <font transparency='0.6'>Explosives</font>", 
    CurrentValue = Env.cfg.c4esp, 
    Callback = function(v) Env.cfg.c4esp = v; Env.updateC4Esp(); PlaySound(Sounds.Click) end
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
VisualsTab:CreateSection("Colors")

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

--// MOVEMENT TAB //--
MovementTab:CreateSection("Character")

MovementTab:CreateToggle({
    Name = "Enable WalkSpeed", 
    CurrentValue = Env.cfg.ws_enabled, 
    Callback = function(v) Env.cfg.ws_enabled = v; PlaySound(Sounds.Click) end
})

MovementTab:CreateSlider({
    Name = "WalkSpeed <font transparency='0.6'>Factor</font>", 
    Range = {16, 200}, 
    Increment = 1, 
    CurrentValue = Env.cfg.walkspeed, 
    Callback = function(v) Env.cfg.walkspeed = v end
})

MovementTab:CreateDivider()

MovementTab:CreateToggle({
    Name = "Enable JumpPower", 
    CurrentValue = Env.cfg.jp_enabled, 
    Callback = function(v) Env.cfg.jp_enabled = v; PlaySound(Sounds.Click) end
})

MovementTab:CreateSlider({
    Name = "JumpPower <font transparency='0.6'>Height</font>", 
    Range = {50, 500}, 
    Increment = 1, 
    CurrentValue = Env.cfg.jumppower, 
    Callback = function(v) Env.cfg.jumppower = v end
})

MovementTab:CreateSection("Physics")
MovementTab:CreateToggle({
    Name = "Noclip <font color='#ff99bb'>Ghost</font>", 
    CurrentValue = Env.cfg.noclip, 
    Callback = function(v) Env.cfg.noclip = v; updateNoclip(); PlaySound(Sounds.Click) end
})

MovementTab:CreateSection("Teleports")

local function tp(pos) 
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then 
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos) 
        PlaySound(Sounds.Success)
    end 
end

MovementTab:CreateButton({ Name = "Yard", Callback = function() tp(Vector3.new(780, 98, 2470)) end })
MovementTab:CreateButton({ Name = "Prison Interior", Callback = function() tp(Vector3.new(913, 100, 2388)) end })
MovementTab:CreateButton({ Name = "Armory", Callback = function() tp(Vector3.new(831, 100, 2233)) end })
MovementTab:CreateButton({ Name = "Criminal Base", Callback = function() tp(Vector3.new(-931, 94, 2063)) end })
MovementTab:CreateButton({ Name = "Instant Escape", Callback = function() 
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    if h then
        local containers = Workspace:FindFirstChild("Shippingcontainers")
        if containers then
            pcall(function() h.CFrame = containers:GetChildren()[6]:GetChildren()[2].CFrame end)
        else
            h.CFrame = CFrame.new(-931, 94, 2063)
        end
        PlaySound(Sounds.Success)
    end
end })

--// UTILITY TAB //--
UtilityTab:CreateSection("Interaction")

UtilityTab:CreateToggle({
    Name = "Auto Grab <font color='#ff99bb'>Keycards/Guns</font>", 
    CurrentValue = Env.cfg.autograb, 
    Callback = function(v) Env.cfg.autograb = v; PlaySound(Sounds.Click) end
})

UtilityTab:CreateSection("Bypasses")

UtilityTab:CreateToggle({
    Name = "Walk While Arrested", 
    CurrentValue = Env.cfg.shootarrested, 
    Callback = function(v) Env.cfg.shootarrested = v; PlaySound(Sounds.Click) end
})

UtilityTab:CreateSection("Server")

UtilityTab:CreateButton({
    Name = "Server Hop <font transparency='0.6'>New Game</font>",
    Callback = function()
        PlaySound(Sounds.Success)
        Rayfield:Notify({Title = "Server", Content = "Searching for a new server...", Duration = 3})
        local x = {}
        for _, v in ipairs(HttpService:JSONDecode(game:HttpGetAsync("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")).data) do
            if type(v) == "table" and v.maxPlayers > v.playing and v.id ~= game.JobId then
                x[#x + 1] = v.id
            end
        end
        if #x > 0 then
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, x[math.random(1, #x)], LocalPlayer)
        else
            Rayfield:Notify({Title = "Server", Content = "No other servers found.", Image = "alert-circle"})
        end
    end
})

UtilityTab:CreateButton({
    Name = "Rejoin Server",
    Callback = function()
        PlaySound(Sounds.Success)
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end
})

--// CONFIG TAB //--
ConfigTab:CreateSection("Configuration")

local configNameInput = ""
ConfigTab:CreateInput({
    Name = "Config Name", 
    PlaceholderText = "Enter name...", 
    RemoveTextAfterFocusLost = false, 
    Callback = function(t) configNameInput = t end
})

ConfigTab:CreateButton({
    Name = "Save Config", 
    Callback = function() 
        if configNameInput == "" then 
            Rayfield:Notify({Title = "Error", Content = "Please enter a config name.", Image = "alert-circle"}) 
            return 
        end 
        if saveConfig(configNameInput) then 
            PlaySound(Sounds.Success)
            Rayfield:Notify({Title = "Saved", Content = "Config <b>" .. configNameInput.."</b> saved.", Image = "check"}) 
        end 
    end
})

ConfigTab:CreateButton({
    Name = "Load Config", 
    Callback = function() 
        if configNameInput == "" then 
            Rayfield:Notify({Title = "Error", Content = "Enter a config name.", Image = "alert-circle"}) 
            return 
        end 
        if loadConfig(configNameInput) then 
            PlaySound(Sounds.Success)
            Rayfield:Notify({Title = "Loaded", Content = "Config <b>" .. configNameInput.."</b> active.", Image = "check"}) 
        end 
    end
})

--// CREDITS TAB //--
CreditsTab:CreateSection("About")

CreditsTab:CreateParagraph({
    Title = "Casual Comas <font color='#ff99bb'>Cloud Edition</font>",
    Content = [[
Developed with <font color='#ff99bb'>♥</font> by the Casual Comas Team.

<font transparency='0.6'>Version:</font> <b>]] .. Env.Version .. [[</b>
<font transparency='0.6'>Status:</font> <font color='#88ff88'>Undetected</font>
<font transparency='0.6'>License:</font> Private

This script provides an enhanced experience for Prison Life. 
Use responsibly.
]]
})

CreditsTab:CreateDivider()
CreditsTab:CreateSection("Management")

CreditsTab:CreateButton({
    Name = "Join Discord",
    Callback = function()
        setclipboard("https://discord.gg/yourinvite") 
        PlaySound(Sounds.Success)
        Rayfield:Notify({Title = "Discord", Content = "Invite copied to clipboard!", Image = "link", Duration = 3})
    end
})

CreditsTab:CreateButton({
    Name = "Reload Hub",
    Callback = function()
        PlaySound(Sounds.Click)
        Rayfield:Destroy()
        Rayfield:Notify({Title = "Reload", Content = "Please re-execute the script.", Duration = 3})
    end
})

CreditsTab:CreateButton({
    Name = "Destroy UI <font color='#ff5555'>Panic</font>",
    Callback = function()
        PlaySound(Sounds.Error)
        Rayfield:Destroy()
    end
})

Rayfield:Notify({
    Title = "Casual Comas", 
    Content = "Welcome to the <b>Cloud</b>.", 
    Image = "cloud",
    Duration = 5
})
