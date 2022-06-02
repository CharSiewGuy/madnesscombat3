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
    HudController.crosshairOffset = SmoothValue:create(0, 0, 4)
    HudController.crosshairOffset:set(40)
end

function HudController:KnitStart()
    self.ScreenGui = Knit.Player.PlayerGui:WaitForChild("ScreenGui")
    self.ScreenGui:WaitForChild("Frame").Visible = true
    self.Overlay = Knit.Player.PlayerGui:WaitForChild("Overlay")
    self.Overlay.Crosshair.Visible = true
    game:GetService("RunService").Heartbeat:Connect(function(dt)
        self.Overlay.Crosshair.Bottom.Position = UDim2.new(0.5, 0, 0.5, self.crosshairOffset:update(dt))
        self.Overlay.Crosshair.Top.Position = UDim2.new(0.5, 0, 0.5, -self.crosshairOffset:update(dt))
        self.Overlay.Crosshair.Right.Position = UDim2.new(0.5, self.crosshairOffset:update(dt), 0.5, 0)
        self.Overlay.Crosshair.Left.Position = UDim2.new(0.5, -self.crosshairOffset:update(dt), 0.5, 0)
    end)

    workspace.ServerRegion.Changed:Connect(function(v)
        self.ScreenGui.Frame.Stats.ServerRegion.Text = v
    end)
    
    local StarterGui = game:GetService("StarterGui")
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end

function HudController:ExpandCrosshair()
    self.crosshairOffset.speed = 20
    self.crosshairOffset:set(self.crosshairOffset.target + 20)
    task.delay(0.05, function()
        self.crosshairOffset.speed = 4
        self.crosshairOffset:set(self.crosshairOffset.target - 20)
    end)
end

function HudController:SetBullets(num)
    if not self.ScreenGui then return end
    self.ScreenGui.Frame.Bullets.Cur.Text = num
end

local lastShownHitmarker = os.clock()

function HudController:ShowHitmarker(headshot)
    lastShownHitmarker = os.clock()
    local hitmarker = self.Overlay.Crosshair.Hitmarker
    Tween(hitmarker, TweenInfo.new(0.05, Enum.EasingStyle.Sine), {ImageTransparency = 0})
    Promise.delay(0.2):andThen(function()
        if os.clock() - lastShownHitmarker > 0.2 then
            Tween(hitmarker, TweenInfo.new(0.1, Enum.EasingStyle.Sine), {ImageTransparency = 1})
        end
    end)

    if headshot then
        hitmarker.ImageColor3 = Color3.fromRGB(193, 6, 6)
    else
        hitmarker.ImageColor3 = Color3.fromRGB(255, 255, 255)
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
        if v:IsA("Frame") then
            if val then
                Tween(v, TweenInfo.new(time), {BackgroundTransparency = 0})
            else
                Tween(v, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1})
            end
        end
    end
end

function HudController:SetHealth(h)
    Tween(self.ScreenGui.Frame.HealthBar.Bar, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.fromScale(h/100, 1)})
    self.ScreenGui.Frame.HealthBar.Health.Text = h
end

function HudController:SetVel(v)
    self.ScreenGui.Frame.Stats.Velocity.Text = v
end

function HudController:PromptKill(name)
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