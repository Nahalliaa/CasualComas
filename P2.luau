local Env = getgenv().PL_Hub
if not Env then return warn("Load Part 1 First!") end

local HttpService = Env.Services.HttpService
local ReplicatedStorage = Env.Services.ReplicatedStorage
local Players = Env.Services.Players
local LocalPlayer = Players.LocalPlayer
local RunService = Env.Services.RunService
local Workspace = game:GetService("Workspace")
local UserInputService = Env.Services.UserInputService

if Env.cfg.autoarrest == nil then Env.cfg.autoarrest = false end
if Env.cfg.punchaura == nil then Env.cfg.punchaura = false end
if Env.cfg.ws_enabled == nil then Env.cfg.ws_enabled = false end
if Env.cfg.walkspeed == nil then Env.cfg.walkspeed = 16 end
if Env.cfg.jp_enabled == nil then Env.cfg.jp_enabled = false end
if Env.cfg.jumppower == nil then Env.cfg.jumppower = 50 end
if Env.cfg.noclip == nil then Env.cfg.noclip = false end
if Env.cfg.shootarrested == nil then Env.cfg.shootarrested = false end
if Env.cfg.autograb == nil then Env.cfg.autograb = false end
if Env.cfg.fly == nil then Env.cfg.fly = false end
if Env.cfg.flyspeed == nil then Env.cfg.flyspeed = 50 end
if Env.cfg.speedburst == nil then Env.cfg.speedburst = false end
if Env.cfg.burstspeed == nil then Env.cfg.burstspeed = 100 end
if Env.cfg.itemesp == nil then Env.cfg.itemesp = false end
if Env.cfg.itemespdist == nil then Env.cfg.itemespdist = 200 end
if Env.cfg.showdistance == nil then Env.cfg.showdistance = false end
if Env.cfg.showhealthbar == nil then Env.cfg.showhealthbar = false end
if Env.cfg.chams == nil then Env.cfg.chams = false end
if Env.cfg.chamscolor == nil then Env.cfg.chamscolor = Color3.fromRGB(180, 130, 200) end
if Env.cfg.tracers == nil then Env.cfg.tracers = false end
if Env.cfg.tracercolor == nil then Env.cfg.tracercolor = Color3.fromRGB(165, 120, 185) end
if Env.cfg.crosshair == nil then Env.cfg.crosshair = false end
if Env.cfg.crosshairsize == nil then Env.cfg.crosshairsize = 10 end
if Env.cfg.crosshaircolor == nil then Env.cfg.crosshaircolor = Color3.fromRGB(255, 255, 255) end
if Env.cfg.crosshairfollow == nil then Env.cfg.crosshairfollow = true end
if Env.cfg.bulletcolor == nil then Env.cfg.bulletcolor = Color3.fromRGB(180, 130, 200) end
if Env.cfg.custombullets == nil then Env.cfg.custombullets = false end
if Env.cfg.killcounter == nil then Env.cfg.killcounter = 0 end

local kills = Env.cfg.killcounter or 0

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

local flyConnection = nil
local flyBodyGyro = nil
local flyBodyVelocity = nil

local function updateFly()
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    
    if flyBodyGyro then
        flyBodyGyro:Destroy()
        flyBodyGyro = nil
    end
    
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    
    if Env.cfg.fly then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if hrp then
            flyBodyGyro = Instance.new("BodyGyro")
            flyBodyGyro.P = 9e4
            flyBodyGyro.maxTorque = Vector3.new(9e9, 9e9, 9e9)
            flyBodyGyro.cframe = hrp.CFrame
            flyBodyGyro.Parent = hrp
            
            flyBodyVelocity = Instance.new("BodyVelocity")
            flyBodyVelocity.velocity = Vector3.new(0, 0, 0)
            flyBodyVelocity.maxForce = Vector3.new(9e9, 9e9, 9e9)
            flyBodyVelocity.Parent = hrp
            
            flyConnection = RunService.Heartbeat:Connect(function()
                if not Env.cfg.fly then return end
                
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                
                local cam = Workspace.CurrentCamera
                local moveDir = Vector3.new(0, 0, 0)
                
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    moveDir = moveDir + (cam.CFrame.LookVector)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    moveDir = moveDir - (cam.CFrame.LookVector)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    moveDir = moveDir - (cam.CFrame.RightVector)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    moveDir = moveDir + (cam.CFrame.RightVector)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    moveDir = moveDir + Vector3.new(0, 1, 0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    moveDir = moveDir - Vector3.new(0, 1, 0)
                end
                
                local touchEnabled = UserInputService.TouchEnabled
                if touchEnabled then
                    local moveThumb = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
                    for _, input in pairs(moveThumb) do
                        if input.KeyCode == Enum.KeyCode.Thumbstick1 then
                            local pos = input.Position
                            moveDir = moveDir + (cam.CFrame.LookVector * -pos.Y)
                            moveDir = moveDir + (cam.CFrame.RightVector * pos.X)
                        end
                    end
                end
                
                if moveDir.Magnitude > 0 then
                    moveDir = moveDir.Unit
                end
                
                flyBodyVelocity.velocity = moveDir * Env.cfg.flyspeed
                flyBodyGyro.cframe = cam.CFrame
            end)
        end
    end
end

local burstActive = false
local originalWS = 16

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if Env.cfg.speedburst and input.KeyCode == Enum.KeyCode.LeftControl then
        burstActive = true
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum then
            originalWS = hum.WalkSpeed
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.LeftControl then
        burstActive = false
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

local itemEspCache = {}
local itemEspFolder = nil

local function createItemESP()
    if itemEspFolder then itemEspFolder:Destroy() end
    itemEspFolder = Instance.new("Folder")
    itemEspFolder.Name = "ItemESP"
    itemEspFolder.Parent = Workspace.CurrentCamera
end

local function makeItemEsp(item, itemType)
    if itemEspCache[item] then return itemEspCache[item] end
    
    local esp = Instance.new("BillboardGui")
    esp.Name = "ItemESP_" .. itemType
    esp.AlwaysOnTop = true
    esp.Size = UDim2.new(0, 50, 0, 30)
    esp.StudsOffset = Vector3.new(0, 1, 0)
    esp.Adornee = item
    
    local icon = Instance.new("Frame")
    icon.BackgroundColor3 = itemType == "M9" and Color3.fromRGB(255, 200, 0) or Color3.fromRGB(0, 200, 255)
    icon.Size = UDim2.new(0, 8, 0, 8)
    icon.Position = UDim2.new(0.5, -4, 0, 0)
    icon.Rotation = 45
    icon.Parent = esp
    
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0, 50, 0, 14)
    label.Position = UDim2.new(0.5, -25, 0, 12)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 10
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.5
    label.Text = itemType
    label.Parent = esp
    
    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "DistLabel"
    distLabel.BackgroundTransparency = 1
    distLabel.Size = UDim2.new(0, 50, 0, 12)
    distLabel.Position = UDim2.new(0.5, -25, 0, 24)
    distLabel.Font = Enum.Font.Gotham
    distLabel.TextSize = 9
    distLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
    distLabel.TextStrokeTransparency = 0.5
    distLabel.Text = ""
    distLabel.Parent = esp
    
    itemEspCache[item] = esp
    return esp
end

local function updateItemEsp()
    if not Env.cfg.itemesp or not itemEspFolder then
        for _, esp in pairs(itemEspCache) do
            if esp then esp:Destroy() end
        end
        itemEspCache = {}
        return
    end
    
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end
    
    for item, esp in pairs(itemEspCache) do
        if not item or not item.Parent then
            esp:Destroy()
            itemEspCache[item] = nil
        end
    end
    
    for _, cached in ipairs(grab_cache) do
        if cached.model and cached.part and cached.part.Parent then
            local dist = (cached.part.Position - myHrp.Position).Magnitude
            if dist <= Env.cfg.itemespdist then
                local itemType = cached.model.Name == "M9" and "M9" or "Keycard"
                local esp = makeItemEsp(cached.part, itemType)
                esp.Parent = itemEspFolder
                
                local distLabel = esp:FindFirstChild("DistLabel")
                if distLabel then
                    distLabel.Text = math.floor(dist) .. "m"
                end
            else
                if itemEspCache[cached.part] then
                    itemEspCache[cached.part]:Destroy()
                    itemEspCache[cached.part] = nil
                end
            end
        end
    end
end

local chamsCache = {}

local function updateChams()
    for player, highlight in pairs(chamsCache) do
        if highlight then
            highlight:Destroy()
        end
        chamsCache[player] = nil
    end
    
    if not Env.cfg.chams then return end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            if not chamsCache[player] then
                local highlight = Instance.new("Highlight")
                highlight.Name = "Cham"
                highlight.FillColor = Env.cfg.chamscolor
                highlight.OutlineColor = Color3.new(0, 0, 0)
                highlight.FillTransparency = 0.5
                highlight.OutlineTransparency = 0
                highlight.Parent = char
                chamsCache[player] = highlight
            end
        end
    end
end

local tracerLines = {}

local function updateTracers()
    for _, line in pairs(tracerLines) do
        if line then line:Remove() end
    end
    tracerLines = {}
    
    if not Env.cfg.tracers then return end
    
    local cam = Workspace.CurrentCamera
    if not cam then return end
    
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end
    
    local viewportSize = cam.ViewportSize
    local screenCenter = Vector2.new(viewportSize.X / 2, viewportSize.Y)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local screenPos, onScreen = cam:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    local line = Drawing.new("Line")
                    line.From = screenCenter
                    line.To = Vector2.new(screenPos.X, screenPos.Y)
                    line.Color = Env.cfg.tracercolor
                    line.Thickness = 1
                    line.Transparency = 0.7
                    line.Visible = true
                    table.insert(tracerLines, line)
                end
            end
        end
    end
end

local crosshairLines = {}

local function createCrosshair()
    for _, line in pairs(crosshairLines) do
        if line then line:Remove() end
    end
    crosshairLines = {}
    
    if not Env.cfg.crosshair then return end
    
    for i = 1, 4 do
        local line = Drawing.new("Line")
        line.Color = Env.cfg.crosshaircolor
        line.Thickness = 2
        line.Transparency = 1
        line.Visible = true
        table.insert(crosshairLines, line)
    end
end

local function updateCrosshair()
    if not Env.cfg.crosshair then
        for _, line in pairs(crosshairLines) do
            if line then line.Visible = false end
        end
        return
    end
    
    local center
    local cam = Workspace.CurrentCamera
    
    if Env.cfg.crosshairfollow and cam then
        if UserInputService.TouchEnabled and UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
            local touches = UserInputService:GetTouchesInProgress()
            if #touches > 0 then
                center = touches[1].Position
            else
                local viewportSize = cam.ViewportSize
                center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
            end
        else
            center = UserInputService:GetMouseLocation()
        end
    else
        if cam then
            local viewportSize = cam.ViewportSize
            center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
        end
    end
    
    if not center then return end
    
    local size = Env.cfg.crosshairsize
    local gap = 5
    
    if crosshairLines[1] then
        crosshairLines[1].From = Vector2.new(center.X - gap - size, center.Y)
        crosshairLines[1].To = Vector2.new(center.X - gap, center.Y)
        crosshairLines[1].Visible = true
    end
    
    if crosshairLines[2] then
        crosshairLines[2].From = Vector2.new(center.X + gap, center.Y)
        crosshairLines[2].To = Vector2.new(center.X + gap + size, center.Y)
        crosshairLines[2].Visible = true
    end
    
    if crosshairLines[3] then
        crosshairLines[3].From = Vector2.new(center.X, center.Y - gap - size)
        crosshairLines[3].To = Vector2.new(center.X, center.Y - gap)
        crosshairLines[3].Visible = true
    end
    
    if crosshairLines[4] then
        crosshairLines[4].From = Vector2.new(center.X, center.Y + gap)
        crosshairLines[4].To = Vector2.new(center.X, center.Y + gap + size)
        crosshairLines[4].Visible = true
    end
end

task.spawn(function()
    local killfeed = ReplicatedStorage:WaitForChild("Killfeed")
    killfeed.ChildAdded:Connect(function(child)
        local name = child.Name
        local myName = LocalPlayer.Name
        local displayName = LocalPlayer.DisplayName
        
        local patterns = {
            myName .. " %(@.-%)" .. "  killed .+ with",
            displayName .. " %(@.-%)" .. "  killed .+ with"
        }
        
        for _, pattern in ipairs(patterns) do
            if name:match(pattern) then
                kills = kills + 1
                Env.cfg.killcounter = kills
                break
            end
        end
    end)
end)

task.spawn(function()
    while task.wait(0.1) do
        if Env.cfg.custombullets then
            local cam = Workspace.CurrentCamera
            if cam then
                for _, obj in pairs(cam:GetChildren()) do
                    if obj.Name == "RayPart" and obj:IsA("BasePart") then
                        obj.Color = Env.cfg.bulletcolor
                        
                        for _, light in pairs(obj:GetChildren()) do
                            if light:IsA("Light") then
                                light.Color = Env.cfg.bulletcolor
                            end
                        end
                    end
                end
            end
            
            local taser = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Taser")
            if taser then
                for _, obj in pairs(taser:GetDescendants()) do
                    if obj.Name == "RayPart" and obj:IsA("BasePart") then
                        obj.Color = Env.cfg.bulletcolor
                        
                        for _, light in pairs(obj:GetChildren()) do
                            if light:IsA("Light") then
                                light.Color = Env.cfg.bulletcolor
                            end
                        end
                    end
                end
            end
        end
    end
end)

createItemESP()
createCrosshair()

RunService.Heartbeat:Connect(function()
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myHum = myChar and myChar:FindFirstChild("Humanoid")

    if myHum and myHrp then
        if Env.cfg.ws_enabled and not burstActive then 
            myHum.WalkSpeed = Env.cfg.walkspeed 
        elseif burstActive and Env.cfg.speedburst then
            myHum.WalkSpeed = Env.cfg.burstspeed
        end
        
        if Env.cfg.jp_enabled then 
            myHum.JumpPower = Env.cfg.jumppower 
        end
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
    
    updateItemEsp()
    updateCrosshair()
end)

RunService.RenderStepped:Connect(function()
    updateChams()
    updateTracers()
end)

Players.PlayerAdded:Connect(function()
    task.wait(1)
    updateChams()
end)

Players.PlayerRemoving:Connect(function(player)
    if chamsCache[player] then
        chamsCache[player]:Destroy()
        chamsCache[player] = nil
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
    updateFly()
    createCrosshair()
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
VisualsTab:CreateToggle({
    Name = "Show Distance", 
    CurrentValue = Env.cfg.showdistance, 
    Callback = function(v) Env.cfg.showdistance = v; Env.updateEsp() end
})
VisualsTab:CreateToggle({
    Name = "Show Health Bar", 
    CurrentValue = Env.cfg.showhealthbar, 
    Callback = function(v) Env.cfg.showhealthbar = v; Env.updateEsp() end
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

VisualsTab:CreateSection("Item ESP")
VisualsTab:CreateToggle({
    Name = "Enable Item ESP", 
    CurrentValue = Env.cfg.itemesp, 
    Callback = function(v) Env.cfg.itemesp = v end
})
VisualsTab:CreateSlider({
    Name = "Item ESP Distance", 
    Range = {50, 500}, 
    Increment = 10, 
    Suffix = "m", 
    CurrentValue = Env.cfg.itemespdist, 
    Callback = function(v) Env.cfg.itemespdist = v end
})

VisualsTab:CreateSection("Chams")
VisualsTab:CreateToggle({
    Name = "Enable Chams", 
    CurrentValue = Env.cfg.chams, 
    Callback = function(v) Env.cfg.chams = v; updateChams() end
})
VisualsTab:CreateColorPicker({
    Name = "Chams Color", 
    Color = Env.cfg.chamscolor, 
    Callback = function(v) Env.cfg.chamscolor = v; updateChams() end
})

VisualsTab:CreateSection("Tracers")
VisualsTab:CreateToggle({
    Name = "Enable Tracers", 
    CurrentValue = Env.cfg.tracers, 
    Callback = function(v) Env.cfg.tracers = v end
})
VisualsTab:CreateColorPicker({
    Name = "Tracer Color", 
    Color = Env.cfg.tracercolor, 
    Callback = function(v) Env.cfg.tracercolor = v end
})

VisualsTab:CreateSection("Crosshair")
VisualsTab:CreateToggle({
    Name = "Enable Crosshair", 
    CurrentValue = Env.cfg.crosshair, 
    Callback = function(v) Env.cfg.crosshair = v; createCrosshair() end
})
VisualsTab:CreateToggle({
    Name = "Follow Cursor/Touch", 
    CurrentValue = Env.cfg.crosshairfollow, 
    Callback = function(v) Env.cfg.crosshairfollow = v end
})
VisualsTab:CreateSlider({
    Name = "Crosshair Size", 
    Range = {5, 30}, 
    Increment = 1, 
    CurrentValue = Env.cfg.crosshairsize, 
    Callback = function(v) Env.cfg.crosshairsize = v end
})
VisualsTab:CreateColorPicker({
    Name = "Crosshair Color", 
    Color = Env.cfg.crosshaircolor, 
    Callback = function(v) Env.cfg.crosshaircolor = v; createCrosshair() end
})

VisualsTab:CreateSection("Bullet Trails")
VisualsTab:CreateToggle({
    Name = "Custom Bullet Color", 
    CurrentValue = Env.cfg.custombullets, 
    Callback = function(v) Env.cfg.custombullets = v end
})
VisualsTab:CreateColorPicker({
    Name = "Bullet Color", 
    Color = Env.cfg.bulletcolor, 
    Callback = function(v) Env.cfg.bulletcolor = v end
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

MovementTab:CreateSection("Speed Burst")
MovementTab:CreateToggle({
    Name = "Enable Speed Burst", 
    CurrentValue = Env.cfg.speedburst, 
    Callback = function(v) Env.cfg.speedburst = v end
})
MovementTab:CreateSlider({
    Name = "Burst Speed", 
    Range = {50, 300}, 
    Increment = 5, 
    CurrentValue = Env.cfg.burstspeed, 
    Callback = function(v) Env.cfg.burstspeed = v end
})
MovementTab:CreateParagraph({Title = "Controls", Content = "Hold Left Ctrl to activate speed burst"})

MovementTab:CreateSection("Physics")
MovementTab:CreateToggle({
    Name = "Noclip", 
    CurrentValue = Env.cfg.noclip, 
    Callback = function(v) 
        Env.cfg.noclip = v 
        updateNoclip()
    end
})

MovementTab:CreateSection("Fly")
MovementTab:CreateToggle({
    Name = "Enable Fly", 
    CurrentValue = Env.cfg.fly, 
    Callback = function(v) 
        Env.cfg.fly = v 
        updateFly()
    end
})
MovementTab:CreateSlider({
    Name = "Fly Speed", 
    Range = {10, 150}, 
    Increment = 5, 
    CurrentValue = Env.cfg.flyspeed, 
    Callback = function(v) Env.cfg.flyspeed = v end
})
MovementTab:CreateParagraph({Title = "Controls", Content = "WASD to move, Space to go up, Shift to go down. Mobile uses left thumbstick."})

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

UtilityTab:CreateSection("Stats")
UtilityTab:CreateLabel("Session Kills: " .. kills)
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            local label = UtilityTab.Elements and UtilityTab.Elements[1]
            if label and label.Text then
                label.Text = "Session Kills: " .. kills
            end
        end)
    end
end)

UtilityTab:CreateButton({
    Name = "Reset Kill Counter", 
    Callback = function() 
        kills = 0 
        Env.cfg.killcounter = 0 
        Rayfield:Notify({
            Title = "Kill Counter", 
            Content = "Kill counter reset to 0", 
            Duration = 3
        })
    end
})

UtilityTab:CreateSection("Quick Actions")
UtilityTab:CreateButton({
    Name = "Suicide (Respawn)", 
    Callback = function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if hum then
            hum.Health = 0
            Rayfield:Notify({
                Title = "Respawn", 
                Content = "Respawning...", 
                Duration = 2
            })
        end
    end
})

UtilityTab:CreateButton({
    Name = "Remove All Doors", 
    Callback = function()
        local doors = Workspace:FindFirstChild("Doors")
        if doors then
            doors:Destroy()
            Rayfield:Notify({
                Title = "Doors Removed", 
                Content = "All doors have been removed", 
                Duration = 3
            })
        else
            Rayfield:Notify({
                Title = "Error", 
                Content = "Doors folder not found", 
                Duration = 3
            })
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
        Env.cfg.fly = false
        Env.cfg.speedburst = false
        Env.cfg.itemesp = false
        Env.cfg.chams = false
        Env.cfg.tracers = false
        Env.cfg.crosshair = false
        Env.cfg.custombullets = false
        updateNoclip()
        updateFly()
        updateChams()
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
    Content = "Casual Comas v" .. Env.Version .. " | Kills: " .. kills, 
    Duration = 5
})
