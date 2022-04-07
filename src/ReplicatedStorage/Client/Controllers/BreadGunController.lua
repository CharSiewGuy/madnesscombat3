local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)
local Promise = require(Packages.Promise)
local Tween = require(Packages.TweenPromise)
local Timer = require(Packages.Timer)
local HumanoidAnimatorUtils = require(Packages.HumanoidAnimatorUtils)

local Modules = ReplicatedStorage.Modules
local Spring = require(Modules.Spring)

local FastCastController

local BreadGunController = Knit.CreateController { Name = "BreadGunController" }
BreadGunController._janitor = Janitor.new()

BreadGunController.Stats = {
    ["FireRate"] = 0.12
}

BreadGunController._springs = {}

function BreadGunController:KnitInit()
    FastCastController = Knit.GetController("FastCastController")
end

function BreadGunController:KnitStart()
    local camera = workspace.CurrentCamera

    Knit.Player.CharacterAdded:Connect(function(character)
        local hum = character:WaitForChild("Humanoid")
        local animator = HumanoidAnimatorUtils.getOrCreateAnimator(hum)
        local holdingGun = animator:LoadAnimation(ReplicatedStorage.Assets.Animations.HoldingGun)
        holdingGun:Play()

        self._springs.fire = Spring.create();

        --AIMING

        self._aimJanitor = Janitor.new()
        self.isFiring = false
        self.canFire = true

        local function getLookAngle()
            return camera.CFrame.LookVector.Y * 1.3
        end

        local pointingGun = animator:LoadAnimation(ReplicatedStorage.Assets.Animations.PointingGun)

        local function updateAim()
            local lookAngle = getLookAngle()
            local aimTimePos = (lookAngle + math.pi/2) * (pointingGun.Length / math.pi)
            pointingGun.TimePosition = aimTimePos
        end

        local function handleAction(actionName, inputState)
            if actionName == "Shoot" then
                if inputState == Enum.UserInputState.Begin then
                    self._aimJanitor:Cleanup()

                    pointingGun:Play(0)
                    pointingGun:AdjustSpeed(0)

                    self._aimJanitor:Add(RunService.RenderStepped:Connect(updateAim))

                    self._janitor:Add(self._aimJanitor)
                    
                    self.isFiring = true                   
                elseif inputState == Enum.UserInputState.End then
                    if hum.MoveDirection.Magnitude ~= 0 then
                        self._aimJanitor:AddPromise(Promise.delay(0.4)):andThen(function()
                            self._aimJanitor:Cleanup()
                            pointingGun:Stop(0)
                        end)
                    else
                        self._aimJanitor:Add(hum:GetPropertyChangedSignal("MoveDirection"):Connect(function()
                            self._aimJanitor:Cleanup()
                            pointingGun:Stop(0)
                        end))
                    end

                    self.isFiring = false
                end
            end
        end
        
        ContextActionService:BindAction("Shoot", handleAction, true, Enum.UserInputType.MouseButton1)

        local CastParams = RaycastParams.new()
        CastParams.IgnoreWater = true
        CastParams.FilterType = Enum.RaycastFilterType.Blacklist
        CastParams.FilterDescendantsInstances = {character, workspace.CurrentCamera}

        local function getMousePos(unitRay)
            local ori, dir = unitRay.Origin, unitRay.Direction * 300
            local result = workspace:Raycast(ori, dir, CastParams)
            return result and result.Position or ori + dir
        end

        RunService.Heartbeat:Connect(function(dt)
            if self.canFire then
                if self.isFiring then
                    self.canFire = false

                    local newCFrame = character.Torso["Right Shoulder"].C0 *
                    CFrame.Angles(0, 0, 0.2)

                    Tween(character.Torso["Right Shoulder"], TweenInfo.new(0.03, Enum.EasingStyle.Back), {C0 = newCFrame})
                    
                    newCFrame = newCFrame *
                    CFrame.Angles(0, 0, -0.2)

                    self._janitor:AddPromise(Promise.delay(0.03)):andThen(function()
                        Tween(character.Torso["Right Shoulder"], TweenInfo.new(0.09, Enum.EasingStyle.Sine), {C0 = newCFrame})
                    end)
                    
                    local flash = ReplicatedStorage.Assets.Particles.ElectricMuzzleFlash:Clone()
                    flash.Parent = character.breadgun.Handle.Muzzle
                    flash:Emit(1)
                    task.delay(0.5, function()
                        flash:Destroy()
                    end)

                    self._janitor:AddPromise(Promise.delay(self.Stats["FireRate"]):andThen(function()
                        self.canFire = true
                    end))
                    
                    local sound = ReplicatedStorage.Assets.Sounds:FindFirstChild("Shoot" .. math.random(1, 3)):Clone()
                    sound.Parent = camera
                    sound:Destroy()

                    self._springs.fire:shove(Vector3.new(2, math.random(-1, 1), 5) * dt * 60)
                    task.delay(0.2, function()
                        self._springs.fire:shove(Vector3.new(-1, math.random(-0.5, 0.5), -5) * dt * 60)
                    end)

                    local viewportPoint = camera.ViewportSize / 2
                    local pos = getMousePos(camera:ViewportPointToRay(viewportPoint.X, viewportPoint.Y))
                    local direction = (pos - character.breadgun.Handle.Muzzle.WorldPosition).Unit
                    FastCastController:Fire(character.breadgun.Handle.Muzzle.WorldPosition, direction, false, character)
                end
            end

            local recoil = self._springs.fire:update(dt)
            camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(recoil.x), math.rad(recoil.y), math.rad(recoil.z))
        end)

        self._janitor:Add(function()
            ContextActionService:UnbindAction("Shoot")
            self.canFire = false
            self.isFiring = false
            RunService:UnbindFromRenderStep("after camera")
        end)

        self._janitor:Add(hum.Died:Connect(function()
            self._janitor:Cleanup()
        end))
    end)
end

return BreadGunController