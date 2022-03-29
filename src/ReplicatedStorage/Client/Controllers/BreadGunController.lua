local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)
local HumanoidAnimatorUtils = require(Packages.HumanoidAnimatorUtils)

local BreadGunController = Knit.CreateController { Name = "BreadGunController" }
BreadGunController._janitor = Janitor.new()

function BreadGunController:KnitStart()
    Knit.Player.CharacterAdded:Connect(function(character)
        local hum = character:WaitForChild("Humanoid")
        local animator = HumanoidAnimatorUtils.getOrCreateAnimator(hum)
        local holdingGun = animator:LoadAnimation(ReplicatedStorage.Client.Assets.Animations.HoldingGun)
        holdingGun.Looped = true
        holdingGun:Play()
    end)
end

return BreadGunController