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
        self.Overlay.Crosshair.Bottom.Position = UDim2.new(0.5, 0, 0.5, self.crosshairOffset:update(dt) * 2 + self.crosshairOffset2:update(dt))
        self.Overlay.Crosshair.Top.Position = UDim2.new(0.5, 0, 0.5, -self.crosshairOffset:update(dt) * 2 - self.crosshairOffset2:update(dt))
        self.Overlay.Crosshair.Right.Position = UDim2.new(0.5, self.crosshairOffset:update(dt) * 2 + self.crosshairOffset2:update(dt), 0.5, 0)
        self.Overlay.Crosshair.Left.Position = UDim2.new(0.5, -self.crosshairOffset:update(dt)* 2 - self.crosshairOffset2:update(dt), 0.5, 0)
    end)

    workspace.ServerRegion.Changed:Connect(function(v)
        self.ScreenGui.Frame.Stats.ServerRegion.Text = v
    end)
    
    local StarterGui = game:GetService("StarterGui")
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

    game.Lighting.Atmosphere.Density = 0.55
end

function HudController:ExpandCrosshair()
    self.crosshairOffset2.speed = 20
    self.crosshairOffset2:set(20)
    task.delay(0.05, function()
        self.crosshairOffset2.speed = 4
        self.crosshairOffset2:set(0)
    end)
end

function HudController:SetBullets(num)
    if not self.ScreenGui then return end
    self.ScreenGui.Frame.Bullets.Cur.Text = num
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
    if crit then lifetime = 0.3 end

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

function HudController:ShowCrosshair(val, time)
    for _, v in pairs(self.Overlay.Crosshair:GetChildren()) do
        if v:IsA("Frame") and v.Name ~= "Hitmarker" then
            if val then
                Tween(v, TweenInfo.new(time), {BackgroundTransparency = 0})
            else
                Tween(v, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1})
            end
        end
    end
end

HudController.BloodTweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function HudController:SetHealth(h)
    Tween(self.ScreenGui.Frame.HealthBar.Bar, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.fromScale(h/100, 1)})
    self.ScreenGui.Frame.HealthBar.Health.Text = h
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

function HudController:SetVel(v)
    self.ScreenGui.Frame.Stats.Velocity.Text = v
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

return HudController