local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)
local Promise = require(Packages.Promise)
local Tween = require(Packages.TweenPromise)
local HumanoidAnimatorUtils = require(Packages.HumanoidAnimatorUtils)

local Modules = ReplicatedStorage.Modules
local Spring = require(Modules.Spring)
local SmoothValue = require(Modules.SmoothValue)

local FastCastController
local HudController
local MovementController

local BreadGunController = Knit.CreateController { Name = "BreadGunController" }
BreadGunController._janitor = Janitor.new()

BreadGunController.Stats = {
    ["FireRate"] = 0.1
}

BreadGunController._springs = {}
BreadGunController._loadedAnim = {}
BreadGunController.lerpValues = {}
BreadGunController.lerpValues.sprint = SmoothValue:create(0, 0, 10)

BreadGunController._camera = workspace.CurrentCamera

function BreadGunController:KnitInit()
    FastCastController = Knit.GetController("FastCastController")
    HudController = Knit.GetController("HudController")
    MovementController = Knit.GetController("MovementController")
end

BreadGunController.firingJanitor = Janitor.new()
BreadGunController.aimJanitor = Janitor.new()
BreadGunController.isAiming = false
BreadGunController._adsOutPromise = nil

function BreadGunController:ToggleAim(inputState)
    if inputState == Enum.UserInputState.Begin then
        if self.isFiring or self.isReloading or self.isAiming then return end

        self.firingJanitor:Cleanup()
        self.canFire = false
        self.isFiring = false
        self.isAiming = true
        self._loadedAnim.adsIn:Play()
        self.aimJanitor:AddPromise(Promise.delay(self._loadedAnim.adsIn.Length - 0.05)):andThen(function()
            self._loadedAnim.ads:Play()
            self.canFire = true
        end)

        self.aimJanitor:Add(function()
            self.isAiming = false
            self._loadedAnim.adsIn:Stop()
            self._loadedAnim.ads:Stop()
        end)

        if self._adsOutPromise then
            self._adsOutPromise:cancel()
        end

        MovementController._sprintJanitor:Cleanup()        
    elseif inputState == Enum.UserInputState.End then
        if self.isAiming then
            self.aimJanitor:Cleanup()
            self.firingJanitor:Cleanup()
            self.canFire = false
            self.isFiring = false
            self.isAiming = true
            
            self._loadedAnim.adsOut:Play()

            self._adsOutPromise = Promise.delay(self._loadedAnim.adsOut.Length)
            self._adsOutPromise:andThen(function()
                self.isAiming = false
                self.canFire = true
            end)
        end
    end
end

function BreadGunController:Reload()
    if not self.isReloading and self.bullets < self.maxBullets then
        self.isFiring = false
        self.isReloading = true
        self.aimJanitor:Cleanup()

        self._loadedAnim.reloadingAnim:Play()
        self._loadedAnim.reloadingFpsAnim:Play()
        MovementController.canSprint = false
        self._janitor:AddPromise(Promise.delay(self._loadedAnim.reloadingAnim.Length - 0.4)):andThen(function()
            self.isReloading = false
            self.bullets = self.maxBullets
            HudController:SetBullets(self.bullets)
            MovementController.canSprint = true
        end)

        local sound = ReplicatedStorage.Assets.Sounds.Reload:Clone()
        sound.Parent = self._camera
        sound:Destroy()

        MovementController._sprintJanitor:Cleanup()
    end
end

function BreadGunController:GetBobbing(addition,speed,modifier)
    return math.sin(tick()*addition*speed)*modifier
end

function BreadGunController:KnitStart()
    local camera = workspace.CurrentCamera
    camera.FieldOfView = 90

    Knit.Player.CharacterAdded:Connect(function(character)
        local hum = character:WaitForChild("Humanoid")
        local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        local animator = HumanoidAnimatorUtils.getOrCreateAnimator(hum)

        self._loadedAnim.reloadingAnim = animator:LoadAnimation(ReplicatedStorage.Assets.Animations.Reloading)

        self._springs.fire = Spring.create()
        self._springs.walkCycle = Spring.create()
        self._springs.sway = Spring.create()

        self.isFiring = false
        self.canFire = true
        self.bullets = 30
        self.maxBullets = 30
        self.isReloading = false

        local viewmodel = ReplicatedStorage.viewmodel:Clone()
        viewmodel.Parent = camera
        self._janitor:Add(viewmodel)

        viewmodel.AnimationController:LoadAnimation(ReplicatedStorage.Assets.Animations.Idle):Play()
        self._loadedAnim.reloadingFpsAnim = viewmodel.AnimationController:LoadAnimation(ReplicatedStorage.Assets.Animations.ReloadingFps)
        self._loadedAnim.shootingFps = viewmodel.AnimationController:LoadAnimation(ReplicatedStorage.Assets.Animations.ShootingFps)
        self._loadedAnim.shootingAds = viewmodel.AnimationController:LoadAnimation(ReplicatedStorage.Assets.Animations.ShootingAds)
        self._loadedAnim.adsIn = viewmodel.AnimationController:LoadAnimation(ReplicatedStorage.Assets.Animations.AdsIn)
        self._loadedAnim.adsOut = viewmodel.AnimationController:LoadAnimation(ReplicatedStorage.Assets.Animations.AdsOut)
        self._loadedAnim.ads = viewmodel.AnimationController:LoadAnimation(ReplicatedStorage.Assets.Animations.Ads)

        local function handleAction(actionName, inputState)
            if self.bullets <= 0 or self.isReloading then return end
            if actionName == "Shoot" then
                if inputState == Enum.UserInputState.Begin then
                    self.isFiring = true
                    MovementController._sprintJanitor:Cleanup()        
                elseif inputState == Enum.UserInputState.End then
                    self.isFiring = false
                end
            elseif actionName == "Aim" then
                self:ToggleAim(inputState)
            elseif actionName == "Reload" then
                if inputState == Enum.UserInputState.Begin then
                    self:Reload()
                end
            end
        end
        
        ContextActionService:BindAction("Shoot", handleAction, true, Enum.UserInputType.MouseButton1)
        ContextActionService:BindAction("Aim", handleAction, true, Enum.UserInputType.MouseButton2)
        ContextActionService:BindAction("Reload", handleAction, true, Enum.KeyCode.R)

        local CastParams = RaycastParams.new()
        CastParams.IgnoreWater = true
        CastParams.FilterType = Enum.RaycastFilterType.Blacklist
        CastParams.FilterDescendantsInstances = {character, workspace.CurrentCamera}

        local function getMousePos(unitRay)
            local ori, dir = unitRay.Origin, unitRay.Direction * 300
            local result = workspace:Raycast(ori, dir, CastParams)
            return result and result.Position or ori + dir
        end

        self._janitor:Add(RunService.Heartbeat:Connect(function()
            if MovementController.isSprinting then 
                self.isFiring = false
                BreadGunController.lerpValues.sprint:set(1)
                return
            else
                BreadGunController.lerpValues.sprint:set(0)
            end
            if not self.canFire or self.isReloading then return end
            if self.bullets > 0 then
                if self.isFiring then
                    self.canFire = false
                    self.bullets = self.bullets - 1

                    self.firingJanitor:AddPromise(Promise.delay(self.Stats["FireRate"]):andThen(function()
                        self.canFire = true
                    end))

                    local viewportPoint = camera.ViewportSize / 2
                    local pos = getMousePos(camera:ViewportPointToRay(viewportPoint.X, viewportPoint.Y))
                    local direction = (pos - viewmodel.xdgun.Handle.Muzzle.WorldPosition).Unit
                    if not self.isAiming then
                        FastCastController:Fire(viewmodel.xdgun.Handle.Muzzle.WorldPosition, direction, false, character, 2)
                        self._loadedAnim.shootingFps:Play()
                        self._springs.fire:shove(Vector3.new(2, math.random(-0.8, 0.8), 4))
                        task.delay(0.2, function()
                            self._springs.fire:shove(Vector3.new(-1.5, math.random(-0.5, 0.5), -4))
                        end)
                    else
                        FastCastController:Fire(viewmodel.xdgun.Handle.Muzzle.WorldPosition, direction, false, character, 1.2)
                        self._loadedAnim.shootingAds:Play()
                        self._springs.fire:shove(Vector3.new(1, math.random(-0.4, 0.4), 2))
                        task.delay(0.2, function()
                            self._springs.fire:shove(Vector3.new(-1, math.random(-0.3, 0.3), -2))
                        end)
                    end
                        
                    local flash = ReplicatedStorage.Assets.Particles.ElectricMuzzleFlash:Clone()
                    flash.Parent = viewmodel.xdgun.Handle.Muzzle
                    flash:Emit(1)
                    task.delay(0.5, function()
                        flash:Destroy()
                    end)

                    local sound = ReplicatedStorage.Assets.Sounds:FindFirstChild("Shoot" .. math.random(1, 3)):Clone()
                    sound.Parent = camera
                    sound:Destroy()

                    HudController:ExpandCrosshair()
                    HudController:SetBullets(self.bullets)
                end
            else
                self:Reload()
            end
        end))

        self._janitor:Add(RunService.RenderStepped:Connect(function(dt)
            local mouseDelta = UserInputService:GetMouseDelta()
            self._springs.sway:shove(Vector3.new(mouseDelta.X / 400,mouseDelta.Y / 400))

            local speed = 1.5
            local modifier = 0.1
            
            local movementSway = Vector3.new(self:GetBobbing(10,speed,modifier),self:GetBobbing(5,speed,modifier),self:GetBobbing(5,speed,modifier))
        
            self._springs.walkCycle:shove((movementSway / 25) * dt * 60 * humanoidRootPart.Velocity.Magnitude)
            
            local sway = self._springs.sway:update(dt)
            local walkCycle = self._springs.walkCycle:update(dt)

            local idleOffset = ReplicatedStorage.Offsets.Idle.Value
            local sprintOffset = idleOffset:lerp(ReplicatedStorage.Offsets.Sprint.Value, self.lerpValues.sprint:update(dt))
            local finalOffset = sprintOffset
            viewmodel.HumanoidRootPart.CFrame = camera.CFrame:ToWorldSpace(finalOffset)

            if not self.isAiming then
                viewmodel.HumanoidRootPart.CFrame = viewmodel.HumanoidRootPart.CFrame:ToWorldSpace(CFrame.new(walkCycle.x / 2,walkCycle.y / 2,0))
                viewmodel.HumanoidRootPart.CFrame =  viewmodel.HumanoidRootPart.CFrame * CFrame.Angles(0,walkCycle.y,walkCycle.x/2)
            end

            viewmodel.HumanoidRootPart.CFrame =  viewmodel.HumanoidRootPart.CFrame * CFrame.Angles(0,-sway.x,sway.y)

            local recoil = self._springs.fire:update(dt)
            camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(recoil.x), math.rad(recoil.y), math.rad(recoil.z))
        end))

        self._janitor:Add(function()
            ContextActionService:UnbindAction("Shoot")
            ContextActionService:UnbindAction("Reload")
            ContextActionService:UnbindAction("Aim")
            self.canFire = false
            self.isFiring = false
        end)

        self._janitor:Add(hum.Died:Connect(function()
            self._janitor:Cleanup()
        end))
    end)
end

return BreadGunController