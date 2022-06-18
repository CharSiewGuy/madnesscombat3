local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)
local Promise = require(Packages.Promise)
local Tween = require(Packages.TweenPromise)

local SmoothValue = require(game.ReplicatedStorage.Modules.SmoothValue)

local HudController = Knit.CreateController { Name = "HudController" }
HudController._janitor = Janitor.new()

function HudController:KnitInit()
    HudController.crosshairOffset = SmoothValue:create(20, 20, 4)
    HudController.crosshairOffset2 = SmoothValue:create(0,0,20)
    HudController.isAiming = false
    HudController.crosshairOffsetMultiplier = 2
    HudController.crosshairTransparency = SmoothValue:create(0,0,4)
    HudController.dotTransparency = SmoothValue:create(0,0,15)
end

function HudController:KnitStart()
    self.ScreenGui = Knit.Player.PlayerGui:WaitForChild("ScreenGui")
    self.ScreenGui:WaitForChild("Frame").Visible = true
    self.Overlay = Knit.Player.PlayerGui:WaitForChild("Overlay")
    self.Overlay.Crosshair.Visible = true
    game:GetService("RunService").Heartbeat:Connect(function(dt)
        if self.isAiming then
            self.crosshairOffset:set(5)
        end
        self.Overlay.Crosshair.Bottom.Position = UDim2.new(0.5, 0, 0.5, self.crosshairOffset:update(dt) * self.crosshairOffsetMultiplier + self.crosshairOffset2:update(dt))
        self.Overlay.Crosshair.Top.Position = UDim2.new(0.5, 0, 0.5, -self.crosshairOffset:update(dt) * self.crosshairOffsetMultiplier - self.crosshairOffset2:update(dt))
        self.Overlay.Crosshair.Right.Position = UDim2.new(0.5, self.crosshairOffset:update(dt) * self.crosshairOffsetMultiplier + self.crosshairOffset2:update(dt), 0.5, 0)
        self.Overlay.Crosshair.Left.Position = UDim2.new(0.5, -self.crosshairOffset:update(dt)* self.crosshairOffsetMultiplier - self.crosshairOffset2:update(dt), 0.5, 0)

        self.Overlay.Crosshair.Bottom.BackgroundTransparency = self.crosshairTransparency:update(dt)
        self.Overlay.Crosshair.Top.BackgroundTransparency = self.crosshairTransparency:update(dt)
        self.Overlay.Crosshair.Right.BackgroundTransparency = self.crosshairTransparency:update(dt)
        self.Overlay.Crosshair.Left.BackgroundTransparency = self.crosshairTransparency:update(dt)
        self.Overlay.Crosshair.Dot.BackgroundTransparency = self.dotTransparency:update(dt)

        for _, v in pairs(self.Overlay.DamageIndicators:GetChildren()) do
            local myPosition = workspace.CurrentCamera.CFrame.Position
            local enemyPosition = v:GetAttribute("Pos")
            local camCFrame = workspace.CurrentCamera.CFrame
            local flatCFrame = CFrame.lookAt(myPosition, myPosition + camCFrame.LookVector * Vector3.new(1, 0, 1))
            local travel = flatCFrame:Inverse() * enemyPosition 
            local rot = math.atan2(travel.Z, travel.X)
            v.Rotation = math.deg(rot) + 90
        end
    end)

    game.Lighting.Atmosphere.Density = 0.45

    local StarterGui = game:GetService("StarterGui")
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end

function HudController:ExpandCrosshair()
    self.crosshairOffset2.speed = 20
    self.crosshairOffset2:set(20)
    task.delay(0.05, function()
        self.crosshairOffset2.speed = 4
        self.crosshairOffset2:set(0)
    end)
end

function HudController:SetBullets(num, max)
    if not self.ScreenGui then return end
    self.ScreenGui.Frame.WeaponStats.Bullets.Cur.Text = num
    if max then self.ScreenGui.Frame.WeaponStats.Bullets.Max.Text = max end
end

HudController.lastShownHitmarker = tick()
HudController.hitmarkerJanitor = Janitor.new()
HudController.hitmarkerTweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
HudController.headHitmarkerTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad)

function HudController:ShowHitmarker(crit)
    self.lastShownHitmarker = tick()
    local hitmarker = self.Overlay.Crosshair.Hitmarker
    for _, v in pairs(hitmarker:GetChildren()) do
        v.BackgroundTransparency = 0
    end
    self.hitmarkerJanitor:Cleanup()
    self.Overlay.Crosshair.Hitmarker.Bottom.Position = UDim2.new(0.5, 0, 0.5, 20)
    self.Overlay.Crosshair.Hitmarker.Top.Position = UDim2.new(0.5, 0, 0.5, -20)
    self.Overlay.Crosshair.Hitmarker.Right.Position = UDim2.new(0.5, 20, 0.5, 0)
    self.Overlay.Crosshair.Hitmarker.Left.Position = UDim2.new(0.5, -20, 0.5, 0)

    if crit then
        self.hitmarkerJanitor:AddPromise(Tween(self.Overlay.Crosshair.Hitmarker.Bottom, self.headHitmarkerTweenInfo, {Position = UDim2.new(0.5, 0, 0.5, 30)}))
        self.hitmarkerJanitor:AddPromise(Tween(self.Overlay.Crosshair.Hitmarker.Top, self.headHitmarkerTweenInfo, {Position = UDim2.new(0.5, 0, 0.5, -30)}))
        self.hitmarkerJanitor:AddPromise(Tween(self.Overlay.Crosshair.Hitmarker.Right, self.headHitmarkerTweenInfo, {Position = UDim2.new(0.5, 30, 0.5, 0)}))
        self.hitmarkerJanitor:AddPromise(Tween(self.Overlay.Crosshair.Hitmarker.Left, self.headHitmarkerTweenInfo, {Position = UDim2.new(0.5, -30, 0.5, 0)}))
    end

    local lifetime = 0.1
    if crit then lifetime = 0.5 end

    Promise.delay(lifetime):andThen(function()
        if tick() - self.lastShownHitmarker > lifetime then
            for _, v in pairs(hitmarker:GetChildren()) do
                self.hitmarkerJanitor:AddPromise(Tween(v, self.hitmarkerTweenInfo, {BackgroundTransparency = 1}))
            end
            self.hitmarkerJanitor:AddPromise(Tween(self.Overlay.Crosshair.Hitmarker.Bottom, self.hitmarkerTweenInfo, {Position = UDim2.new(0.5, 0, 0.5, 5)}))
            self.hitmarkerJanitor:AddPromise(Tween(self.Overlay.Crosshair.Hitmarker.Top, self.hitmarkerTweenInfo, {Position = UDim2.new(0.5, 0, 0.5, -5)}))
            self.hitmarkerJanitor:AddPromise(Tween(self.Overlay.Crosshair.Hitmarker.Right, self.hitmarkerTweenInfo, {Position = UDim2.new(0.5, 5, 0.5, 0)}))
            self.hitmarkerJanitor:AddPromise(Tween(self.Overlay.Crosshair.Hitmarker.Left, self.hitmarkerTweenInfo, {Position = UDim2.new(0.5, -5, 0.5, 0)}))
        end
    end)

    if crit then
        for _, v in pairs(hitmarker:GetChildren()) do
            v.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        end    
    else
        for _, v in pairs(hitmarker:GetChildren()) do
            v.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        end     
    end
end

function HudController:ShowVignette(val, time)
    if val then
        Tween(self.Overlay.Vignette, TweenInfo.new(time), {ImageTransparency = 0.1})
    else
        Tween(self.Overlay.Vignette, TweenInfo.new(time), {ImageTransparency = 0.5})
    end
end

HudController.BloodTweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
HudController.LastChangedHealth = 0
HudController.HealthJanitor = Janitor.new()

function HudController:SetHealth(h)
    self.HealthJanitor:Cleanup()
    self.LastChangedHealth = tick()
    self.ScreenGui.Frame.HealthBar.Health.Health.Text = math.floor(h)
    if h ~= 100 then
        self.ScreenGui.Frame.HealthBar.BackgroundTransparency = 0.5
        self.ScreenGui.Frame.HealthBar.Bar.BackgroundTransparency = 0
    end
    task.delay(1, function()
        if tick() - self.LastChangedHealth >= 1 then
            self.HealthJanitor:AddPromise(Tween(self.ScreenGui.Frame.HealthBar, TweenInfo.new(.5), {BackgroundTransparency = 1}))
            self.HealthJanitor:AddPromise(Tween(self.ScreenGui.Frame.HealthBar.Bar, TweenInfo.new(.5), {BackgroundTransparency = 1}))
        end
    end)
    if h > 70 then
        self.ScreenGui.Frame.HealthBar.Health.ImageLabel.ImageColor3   = Color3.fromRGB(255,255,255)
        self.ScreenGui.Frame.HealthBar.Health.Health.TextColor3   = Color3.fromRGB(255,255,255)
    elseif h > 30 then
        self.ScreenGui.Frame.HealthBar.Health.ImageLabel.ImageColor3   = Color3.fromRGB(243, 203, 0)
        self.ScreenGui.Frame.HealthBar.Health.Health.TextColor3   = Color3.fromRGB(243, 203, 0)
    else
        self.ScreenGui.Frame.HealthBar.Health.ImageLabel.ImageColor3   = Color3.fromRGB(247, 70, 0)
        self.ScreenGui.Frame.HealthBar.Health.Health.TextColor3   = Color3.fromRGB(247, 70, 0)
    end
    Tween(self.ScreenGui.Frame.HealthBar.Bar, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.fromScale(h/100, 1)})
    Tween(self.Overlay.Blood, self.BloodTweenInfo, {ImageTransparency = h/100})
    Tween(self.Overlay.Blood2, self.BloodTweenInfo, {ImageTransparency = h/100})
    Tween(self.Overlay.Vignette2, self.BloodTweenInfo, {ImageTransparency = h/100})
    if h < 50 then
        if h < 10 then
            game.Lighting.ColorCorrection.Saturation = -0.8
            self.Overlay.Heartbeat.Volume = 1
        elseif h < 20 then
            game.Lighting.ColorCorrection.Saturation = -0.6
            self.Overlay.Heartbeat.Volume = 0.8
        elseif h < 30 then
            game.Lighting.ColorCorrection.Saturation = -0.4
            self.Overlay.Heartbeat.Volume = 0.6
        elseif h < 40 then
            game.Lighting.ColorCorrection.Saturation = -0.2
            self.Overlay.Heartbeat.Volume = 0.4
        else
            self.Overlay.Heartbeat.Volume = 0.2
            game.Lighting.ColorCorrection.Saturation = -0.1
        end
    else
        self.Overlay.Heartbeat.Volume = 0
        game.Lighting.ColorCorrection.Saturation = 0
    end
end

function HudController:PromptKill(name)
    self:ShowHitmarker(true)
    for _, v in pairs(self.ScreenGui.KillPromptArea:GetChildren()) do
        Tween(v, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {Position = UDim2.fromScale(0, v.Position.Y.Scale + 0.5)})
    end
    local killPrompt = ReplicatedStorage.Assets.KillPrompt:Clone()
    killPrompt.PlayerName.Text = '<i><font color = "#FFFFFF">' .. "KILLED " .. "</font>" .. string.upper(name) .. "</i>"
    killPrompt.Parent = self.ScreenGui.KillPromptArea
    killPrompt.Position = UDim2.fromScale(0, -0.5)
    Tween(killPrompt, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {Position = UDim2.fromScale(0, 0)})
    task.delay(1.5, function()
        Tween(killPrompt.PlayerName, TweenInfo.new(1, Enum.EasingStyle.Linear), {TextTransparency = 1, TextStrokeTransparency = 1})
        task.delay(1, function()
            killPrompt:Destroy()
        end)
    end)
end

local damageDirDur = 0.5

function HudController:ShowDamageDir(playerName, pos)
    local can = self.Overlay.DamageIndicators:FindFirstChild(playerName) and tick() - self.Overlay.DamageIndicators[playerName]:GetAttribute("t") < damageDirDur
    local d
    if can then
        d = self.Overlay.DamageIndicators[playerName]
    else    
        d = ReplicatedStorage.Assets.DamageIndicator:Clone()
        d.Name = playerName
        d.Parent = self.Overlay.DamageIndicators
    end
    d:SetAttribute("t", tick())
    d:SetAttribute("Pos", pos)
    task.delay(damageDirDur, function()
        if d and tick() - d:GetAttribute("t") > damageDirDur then
            Tween(d, TweenInfo.new(damageDirDur), {ImageTransparency = 1})
            task.delay(damageDirDur, function()
                d:Destroy()
            end)
        end
    end)
end

return HudController