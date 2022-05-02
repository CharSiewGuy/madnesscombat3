local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)
local Promise = require(Packages.Promise)
local Tween = require(Packages.TweenPromise)

local SmoothValue = require(game.ReplicatedStorage.Modules.SmoothValue)

local HudController = Knit.CreateController { Name = "HudController" }
HudController._janitor = Janitor.new()

function HudController:KnitStart()
    self.ScreenGui = Knit.Player.PlayerGui:WaitForChild("ScreenGui")
end

function HudController:ExpandCrosshair()
    if not self.ScreenGui then return end
    Tween(self.ScreenGui.Crosshair.Bottom, TweenInfo.new(0.05, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, 0, 0.5, 20)})
    Tween(self.ScreenGui.Crosshair.Top, TweenInfo.new(0.05, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, 0, 0.5, -20)})
    Tween(self.ScreenGui.Crosshair.Right, TweenInfo.new(0.05, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, 20, 0.5, 0)})
    Tween(self.ScreenGui.Crosshair.Left, TweenInfo.new(0.05, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, -20, 0.5, 0)})
    task.delay(0.05, function()
        Tween(self.ScreenGui.Crosshair.Bottom, TweenInfo.new(0.1, Enum.EasingStyle.Sine), {Position = UDim2.new(0.5, 0, 0.5, 15)})
        Tween(self.ScreenGui.Crosshair.Top, TweenInfo.new(0.1, Enum.EasingStyle.Sine), {Position = UDim2.new(0.5, 0, 0.5, -15)})
        Tween(self.ScreenGui.Crosshair.Right, TweenInfo.new(0.1, Enum.EasingStyle.Sine), {Position = UDim2.new(0.5, 15, 0.5, 0)})
        Tween(self.ScreenGui.Crosshair.Left, TweenInfo.new(0.1, Enum.EasingStyle.Sine), {Position = UDim2.new(0.5, -15, 0.5, 0)})
    end)
end

function HudController:SetBullets(num)
    if not self.ScreenGui then return end
    self.ScreenGui.Bullets.Cur.Text = num
end

local lastShownHitmarker = os.clock()

function HudController:ShowHitmarker(headshot)
    lastShownHitmarker = os.clock()
    local hitmarker = self.ScreenGui.Crosshair.Hitmarker
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
return HudController