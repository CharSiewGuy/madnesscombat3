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

        local pointingGun = animator:LoadAnimation(ReplicatedStorage.Client.Assets.Animations.PointingGun)
        local lastPointedGun = 0

        local function handleAction(actionName, inputState)
            if actionName == "Shoot" then
                if inputState == Enum.UserInputState.Begin then
                    if not pointingGun.IsPlaying then
                        pointingGun:Play(0.1)
                        lastPointedGun = math.huge
                    end
                elseif inputState == Enum.UserInputState.End then
                    lastPointedGun = os.time()
                end
            end
        end

        ContextActionService:BindAction("Shoot", handleAction, true, Enum.UserInputType.MouseButton1)

        RunService.Heartbeat:Connect(function()
            if os.time() > lastPointedGun + 1 then
                pointingGun:Stop(0.3)
            end
        end)
    end)
end

return BreadGunController