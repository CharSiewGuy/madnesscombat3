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
    self.ScreenGui.Crosshair.Visible = true
    game:GetService("RunService").Heartbeat:Connect(function(dt)
        self.ScreenGui.Crosshair.Bottom.Position = UDim2.new(0.5, 0, 0.5, self.crosshairOffset:update(dt))
        self.ScreenGui.Crosshair.Top.Position = UDim2.new(0.5, 0, 0.5, -self.crosshairOffset:update(dt))
        self.ScreenGui.Crosshair.Right.Position = UDim2.new(0.5, self.crosshairOffset:update(dt), 0.5, 0)
        self.ScreenGui.Crosshair.Left.Position = UDim2.new(0.5, -self.crosshairOffset:update(dt), 0.5, 0)
    end)
end

function HudController:ExpandCrosshair()
    self.crosshairOffset.speed = 20
    self.crosshairOffset:set(self.crosshairOffset.target + 16)
    task.delay(0.05, function()
        self.crosshairOffset.speed = 4
        self.crosshairOffset:set(self.crosshairOffset.target - 16)
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

function HudController:ShowVignette(val, time)
    if val then
        Tween(self.ScreenGui.Overlay, TweenInfo.new(time), {ImageTransparency = 0.1})
    else
        Tween(self.ScreenGui.Overlay, TweenInfo.new(time), {ImageTransparency = 0.5})
    end
end

function HudController:ShowCrosshair(val, time)
    for _, v in pairs(self.ScreenGui.Crosshair:GetChildren()) do
        if v:IsA("Frame") then
            if val then
                Tween(v, TweenInfo.new(time), {BackgroundTransparency = 0})
            else
                Tween(v, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1})
            end
        end
    end
end

return HudController