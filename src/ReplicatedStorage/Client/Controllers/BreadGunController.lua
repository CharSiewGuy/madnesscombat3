local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)
local Timer = require(Packages.Timer)
local HumanoidAnimatorUtils = require(Packages.HumanoidAnimatorUtils)

local BreadGunController = Knit.CreateController { Name = "BreadGunController" }
BreadGunController._janitor = Janitor.new()

function BreadGunController:KnitStart()
    Knit.Player.CharacterAdded:Connect(function(character)
        local hum = character:WaitForChild("Humanoid")
        local animator = HumanoidAnimatorUtils.getOrCreateAnimator(hum)
        local holdingGun = animator:LoadAnimation(ReplicatedStorage.Client.Assets.Animations.HoldingGun)
        holdingGun:Play()

        local shootingAnim = animator:LoadAnimation(ReplicatedStorage.Client.Assets.Animations.Shooting)

        local function handleAction(actionName, inputState)
            if actionName == "Shoot" then
                if inputState == Enum.UserInputState.Begin then
                    shootingAnim:Play() 
                elseif inputState == Enum.UserInputState.End then
                end
            end
        end

        ContextActionService:BindAction("Shoot", handleAction, true, Enum.UserInputType.MouseButton1)

        RunService.Heartbeat:Connect(function()
          
        end)
    end)
end

return BreadGunController