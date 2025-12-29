-- [[ PART 3: UI ]] --
local Env = getgenv().PL_Hub
if not Env then return warn("Load Part 1 First!") end

local HttpService = Env.Services.HttpService
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- // CONFIG SYSTEM //
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

-- // THEME & WINDOW //
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

local AimbotTab = Window:CreateTab("Aimbot", 4483362458)
local ESPTab = Window:CreateTab("ESP", 4483362458)
local AutoshootTab = Window:CreateTab("Autoshoot", 4483362458)
local SettingsTab = Window:CreateTab("Settings", 4483362458)

-- // AIMBOT TAB //
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

-- // ESP TAB //
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

-- // AUTOSHOOT TAB //
local AutoShootSection = AutoshootTab:CreateSection("Configuration")
AutoshootTab:CreateToggle({Name = "Enabled", CurrentValue = Env.cfg.autoshoot, Callback = function(v) Env.cfg.autoshoot = v end})
AutoshootTab:CreateSlider({Name = "Shot Delay", Range = {0.05, 0.5}, Increment = 0.01, Suffix = "s", CurrentValue = Env.cfg.autoshootdelay, Callback = function(v) Env.cfg.autoshootdelay = v end})
AutoshootTab:CreateSlider({Name = "Start Delay", Range = {0, 1}, Increment = 0.05, Suffix = "s", CurrentValue = Env.cfg.autoshootstartdelay, Callback = function(v) Env.cfg.autoshootstartdelay = v end})

-- // SETTINGS TAB //
local configNameInput = ""
SettingsTab:CreateInput({Name = "Config Name", PlaceholderText = "Enter config name...", RemoveTextAfterFocusLost = false, Callback = function(t) configNameInput = t end})
SettingsTab:CreateButton({Name = "Save Config", Callback = function() if configNameInput == "" then Rayfield:Notify({Title = "Config", Content = "Please enter a config name!", Duration = 3}) return end if saveConfig(configNameInput) then Rayfield:Notify({Title = "Config", Content = "Saved config: " .. configNameInput, Duration = 3}) else Rayfield:Notify({Title = "Config", Content = "Failed to save config!", Duration = 3}) end end})
SettingsTab:CreateButton({Name = "Load Config", Callback = function() if configNameInput == "" then Rayfield:Notify({Title = "Config", Content = "Please enter a config name!", Duration = 3}) return end if loadConfig(configNameInput) then Rayfield:Notify({Title = "Config", Content = "Loaded config: " .. configNameInput, Duration = 3}) else Rayfield:Notify({Title = "Config", Content = "Config not found!", Duration = 3}) end end})
SettingsTab:CreateButton({Name = "Reset Defaults", Callback = function() Env.cfg.enabled = true Env.cfg.teamcheck = false Env.cfg.esp = false Env.updateEsp() Rayfield:Notify({Title = "Config", Content = "Reset to defaults", Duration = 3}) end})

Rayfield:Notify({Title = "Loaded", Content = "NaphtaHub v" .. Env.Version .. " Welcome!", Duration = 5})
