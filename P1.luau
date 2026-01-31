       if c4espCache[part] then c4espCache[part]:Destroy(); c4espCache[part] = nil end
        end
    end
end

makeVisuals()

-- // AUTOSHOOT & AIMBOT LOGIC //
local ShootEvent = ReplicatedStorage:WaitForChild("GunRemotes"):WaitForChild("ShootEvent")
local lastAutoShoot = 0
local targetAcquiredTime = 0
local lastAutoTarget = nil
local cachedBulletsLabel = nil

local function createBulletTrail(startPos, endPos, isTaser)
    local distance = (endPos - startPos).Magnitude
    local trail = Instance.new("Part")
    trail.Name = "BulletTrail"
    trail.Anchored = true
    trail.CanCollide = false
    trail.Material = Enum.Material.Neon
    trail.Size = Vector3.new(0.1, 0.1, distance)
    trail.CFrame = CFrame.new(startPos, endPos) * CFrame.new(0, 0, -distance / 2)
    trail.Transparency = 0.5
    if isTaser then
        trail.BrickColor = BrickColor.new("Cyan")
        trail.Size = Vector3.new(0.2, 0.2, distance)
    else
        trail.BrickColor = BrickColor.Yellow()
    end
    trail.Parent = workspace
    Debris:AddItem(trail, isTaser and 0.8 or 0.1)
end

local function autoShoot()
    if not Env.cfg.autoshoot or not Env.cfg.enabled or not Env.vars.currentGun then return end
    if Env.vars.currentGun:GetAttribute("Local_IsShooting") then return end
    if (Env.vars.currentGun:GetAttribute("Local_ReloadSession") or 0) > 0 then return end

    local now = os.clock()
    local fireRate = Env.vars.currentGun:GetAttribute("FireRate") or Env.cfg.autoshootdelay
    if now - lastAutoShoot < fireRate then return end

    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myHead = myChar:FindFirstChild("Head")
    if not myHead then return end

    local muzzle = Env.vars.currentGun:FindFirstChild("Muzzle")
    local startPos = muzzle and muzzle.Position or myHead.Position

    local target, targetPos = Env.getClosest(Env.cfg.fov)
    if not target or not Env.fullCheck(target) then 
        lastAutoTarget = nil
        return 
    end

    if target ~= lastAutoTarget then
        targetAcquiredTime = now
        lastAutoTarget = target
    end

    if now - targetAcquiredTime < Env.cfg.autoshootstartdelay then return end

    local targetPart = Env.getTargetPart(target.Character)
    if not targetPart then return end

    local ammo = Env.vars.currentGun:GetAttribute("Local_CurrentAmmo") or Env.vars.currentGun:GetAttribute("CurrentAmmo") or 0
    if ammo <= 0 then return end

    lastAutoShoot = now

    local isTaser = Env.vars.currentGun:GetAttribute("Projectile") == "Taser"
    local isShotgun = Env.vars.currentGun:GetAttribute("IsShotgun")
    local shouldHit = false

    if Env.cfg.taseralwayshit and isTaser then shouldHit = true
    elseif Env.cfg.ifplayerstill and Env.isStanding(target) then shouldHit = true
    elseif Env.cfg.hitchanceAutoOnly and isShotgun then shouldHit = true
    else shouldHit = Env.rollHit() end

    local projectileCount = Env.vars.currentGun:GetAttribute("ProjectileCount") or 1
    local shots = {}

    for i = 1, projectileCount do
        local finalPos
        if shouldHit then finalPos = targetPart.Position
        else
            if Env.cfg.missspread > 0 then finalPos = Env.getMissPos(targetPart.Position)
            else return end
        end
        shots[i] = {myHead.Position, finalPos, shouldHit and targetPart or nil}
        createBulletTrail(startPos, finalPos, isTaser)
    end

    ShootEvent:FireServer(shots)
    local newAmmo = ammo - 1
    Env.vars.currentGun:SetAttribute("Local_CurrentAmmo", newAmmo)

    if not cachedBulletsLabel then
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            local home = playerGui:FindFirstChild("Home")
            if home and home:FindFirstChild("hud") then
                local br = home.hud:FindFirstChild("BottomRightFrame")
                if br and br:FindFirstChild("GunFrame") then
                    cachedBulletsLabel = br.GunFrame:FindFirstChild("BulletsLabel")
                end
            end
        end
    end
    if cachedBulletsLabel then
        cachedBulletsLabel.Text = newAmmo .. "/" .. (Env.vars.currentGun:GetAttribute("MaxAmmo") or 30)
    end
    
    local handle = Env.vars.currentGun:FindFirstChild("Handle")
    if handle and handle:FindFirstChild("ShootSound") then
        local sound = handle.ShootSound:Clone()
        sound.Parent = handle
        sound:Play()
        Debris:AddItem(sound, 2)
    end
end

local function getGun()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and tool:GetAttribute("ToolType") == "Gun" then
            return tool
        end
    end
    return nil
end

local lastGun = nil
RunService.Heartbeat:Connect(function()
    Env.vars.currentGun = getGun()
    if Env.vars.currentGun ~= lastGun then
        lastAutoShoot = 0
        lastGun = Env.vars.currentGun
    end
    autoShoot()
end)

RunService.PreRender:Connect(function()
    local aimPos = Env.Services.UserInputService:GetMouseLocation()
    local camera = workspace.CurrentCamera
    if camera then
        local lastInput = Env.Services.UserInputService:GetLastInputType()
        local locked = (lastInput == Enum.UserInputType.Touch) or (Env.Services.UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter)
        if locked then
            local viewportSize = camera.ViewportSize
            aimPos = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
        end
    end

    fovCircle.Position = aimPos
    fovCircle.Radius = Env.cfg.fov
    fovCircle.Visible = Env.cfg.showfov and Env.cfg.enabled

    if Env.cfg.showtargetline and Env.cfg.enabled then
        local target, targetPos = Env.getClosest()
        if target and targetPos and camera then
            local screenPos, onScreen = camera:WorldToViewportPoint(targetPos)
            if onScreen then
                targetLine.From = aimPos
                targetLine.To = Vector2.new(screenPos.X, screenPos.Y)
                targetLine.Visible = true
            else targetLine.Visible = false end
        else targetLine.Visible = false end
    else targetLine.Visible = false end

    Env.updateEsp()
    Env.updateC4Esp()
end)

Players.PlayerRemoving:Connect(removeEsp)
LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function() 
    for player, e in pairs(espCache) do if e then e:Destroy() end espCache[player] = nil end 
end)

-- Hook Setup
local origCastRay
local hooked = false
local function setupHook()
    local castRayFunc = filtergc("function", {Name = "castRay"}, true)
    if not castRayFunc then return false end

    origCastRay = hookfunction(castRayFunc, function(startPos, targetPos, ...)
        if not Env.cfg.enabled then return origCastRay(startPos, targetPos, ...) end
        local closest, closestPos = Env.getClosest(Env.cfg.fov)
        if closest and closest.Character then
            local isTaser = Env.vars.currentGun and Env.vars.currentGun:GetAttribute("Projectile") == "Taser"
            local isShotgun = Env.vars.currentGun and Env.vars.currentGun:GetAttribute("IsShotgun")
            local shouldHit = false
            if Env.cfg.hitchanceAutoOnly and isShotgun then return origCastRay(startPos, targetPos, ...) end
            if Env.cfg.shotgungamehandled and isShotgun then
                local targetPart = Env.getTargetPart(closest.Character)
                if targetPart then return origCastRay(startPos, targetPart.Position, ...) end
                return origCastRay(startPos, targetPos, ...)
            end
            if Env.cfg.taseralwayshit and isTaser then shouldHit = true
            elseif Env.cfg.ifplayerstill and Env.isStanding(closest) then shouldHit = true
            else shouldHit = Env.rollHit() end

            if shouldHit then
                local targetPart = Env.getTargetPart(closest.Character)
                if targetPart then
                    if Env.cfg.shotgunnaturalspread and isShotgun then return origCastRay(startPos, targetPart.Position, ...) end
                    return targetPart, targetPart.Position
                end
            else
                if Env.cfg.missspread > 0 then
                    local targetPart = Env.getTargetPart(closest.Character)
                    if targetPart then
                        local missPos = Env.getMissPos(targetPart.Position)
                        return origCastRay(startPos, missPos, ...)
                    end
                end
                return origCastRay(startPos, targetPos, ...)
            end
        end
        return origCastRay(startPos, targetPos, ...)
    end)
    return true
end

if not setupHook() then
    task.spawn(function()
        while not hooked do
            task.wait(0.5)
            if setupHook() then hooked = true end
        end
    end)
else hooked = true end
