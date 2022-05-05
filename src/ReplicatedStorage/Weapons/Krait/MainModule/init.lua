local module = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)
local Promise = require(Packages.Promise)
local HumanoidAnimatorUtils = require(Packages.HumanoidAnimatorUtils)

local Modules = ReplicatedStorage.Modules
local Spring = require(Modules.Spring)
local SmoothValue = require(Modules.SmoothValue)

local HudController
local MovementController

local clientCaster = require(script.Parent.ClientCaster)

module.janitor = Janitor.new()
module.camera = workspace.CurrentCamera
module.loadedAnimations = {}
module.springs = {}
module.lerpValues = {}
module.lerpValues.sprint = SmoothValue:create(0, 0, 15)
module.swayspeed = 3
module.swaymodifier = 0.03

module.firingJanitor = Janitor.new()
module.fireRate = 0.12
module.bullets = 30
module.maxBullets = 30
module.isReloading = false
module.isFiring = false

local UtilModule = require(script.Util)

function module:SetupAnimations(character, vm)
    self.springs.sway = Spring.create()
    self.springs.walkCycle = Spring.create()

    self.springs.jump = Spring.create(1, 10, 0, 1.8)
    self.springs.fire = Spring.create()

    self.janitor:Add(character.Humanoid.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Jumping then
            self.springs.jump:shove(Vector3.new(0, 0.3))
            task.delay(0.2, function()
                self.springs.jump:shove(Vector3.new(0, -0.3))
            end)
        elseif newState == Enum.HumanoidStateType.Landed then
            self.springs.jump:shove(Vector3.new(0, -0.5))
            task.delay(0.15, function()
                self.springs.jump:shove(Vector3.new(0, 0.5))
            end)
        end
    end))

    self.janitor:Add(RunService.RenderStepped:Connect(function(dt)
        local mouseDelta = UserInputService:GetMouseDelta()
        self.springs.sway:shove(Vector3.new(mouseDelta.X / 400,mouseDelta.Y / 400))
        local sway = self.springs.sway:update(dt)

        local movementSway = Vector3.new(
            UtilModule:GetBobbing(10,self.swayspeed,self.swaymodifier),
            UtilModule:GetBobbing(5,self.swayspeed,self.swaymodifier),
            UtilModule:GetBobbing(5,self.swayspeed,self.swaymodifier)
        )

        self.springs.walkCycle:shove((movementSway / 25) * dt * 60 * math.clamp(character.HumanoidRootPart.Velocity.Magnitude, 0, 50))
        local walkCycle = self.springs.walkCycle:update(dt)

        local jump = self.springs.jump:update(dt)

        local idleOffset = CFrame.new(0.5,-0.5,-0.5)
        local sprintOffset = idleOffset:Lerp(CFrame.new(0.5,-1,-1) * CFrame.Angles(0.1, 1, 0.2), self.lerpValues.sprint:update(dt))
        local finalOffset = sprintOffset
        vm.HumanoidRootPart.CFrame = self.camera.CFrame:ToWorldSpace(finalOffset)

        vm.HumanoidRootPart.CFrame = vm.HumanoidRootPart.CFrame:ToWorldSpace(CFrame.new(walkCycle.x, walkCycle.y * 3, 0))
        
        if MovementController.isSprinting then
            vm.HumanoidRootPart.CFrame =  vm.HumanoidRootPart.CFrame * CFrame.Angles(jump.y,walkCycle.y, walkCycle.x/2)
        else
            vm.HumanoidRootPart.CFrame =  vm.HumanoidRootPart.CFrame * CFrame.Angles(0,walkCycle.y/2,walkCycle.y)
        end

        vm.HumanoidRootPart.CFrame = vm.HumanoidRootPart.CFrame * CFrame.Angles(jump.y,-sway.x,sway.y)

        local recoil = self.springs.fire:update(dt)
        self.camera.CFrame = self.camera.CFrame * CFrame.Angles(math.rad(recoil.x), math.rad(recoil.y), math.rad(recoil.z))
    end))
end

function module:Reload()
    if not self.isReloading and self.bullets < self.maxBullets then
        self.isFiring = false
        self.isReloading = true
        self.lerpValues.sprint:set(0)
        self.swayspeed = 3
        self.swaymodifier = 0.03
        --self.aimJanitor:Cleanup()

        self.loadedAnimations.Reload:Play()
        self.loadedAnimations.Reload:AdjustSpeed(1.2) 
        self.janitor:AddPromise(Promise.delay(self.loadedAnimations.Reload.Length - 0.6)):andThen(function()
            self.isReloading = false
            self.bullets = self.maxBullets
            HudController:SetBullets(self.bullets)
        end)

        local sound = script.Parent.Sounds.Reload:Clone()
        sound.Parent = self.camera
        sound:Play()
        self.janitor:Add(sound.Ended:Connect(function()
            sound:Destroy()
        end))

        self.janitor:AddPromise(Promise.delay(0.3)):andThen(function()
            UtilModule:SetGlow(self.camera.viewmodel.Krait, false)
        end)

        self.janitor:AddPromise(Promise.delay(0.9)):andThen(function()
            UtilModule:SetGlow(self.camera.viewmodel.Krait, true)
        end)

        self.janitor:Add(function()
            self.isReloading = false
            sound:Destroy()
        end)
    end
end

function module:Equip(character, vm)
    MovementController = Knit.GetController("MovementController")

    self.camera.FieldOfView = 90

    local Krait = script.Parent.Krait:Clone()
    Krait.Parent = vm

    local weaponMotor6D = script.Parent.Handle:Clone()
    weaponMotor6D.Part0 = vm.HumanoidRootPart
    weaponMotor6D.Part1 = Krait.Handle
    weaponMotor6D.Parent = vm.HumanoidRootPart

    self:SetupAnimations(character, vm)

    self.canFire = true

    self.loadedAnimations.Idle = vm.AnimationController:LoadAnimation(script.Parent.Animations.Idle)
    self.loadedAnimations.Idle:Play()

    self.loadedAnimations.Shoot = vm.AnimationController:LoadAnimation(script.Parent.Animations.Shoot)
    self.loadedAnimations.Reload = vm.AnimationController:LoadAnimation(script.Parent.Animations.Reload)

    local function handleAction(actionName, inputState)
        if self.bullets <= 0 or self.isReloading then return end
        if actionName == "KraitShoot" then
            if inputState == Enum.UserInputState.Begin then
                self.isFiring = true
            elseif inputState == Enum.UserInputState.End then
                self.isFiring = false
            end 
        elseif actionName == "KraitReload" then
            if inputState == Enum.UserInputState.Begin then
                self:Reload()
            end
        end
    end

    ContextActionService:BindAction("KraitShoot", handleAction, true, Enum.UserInputType.MouseButton1)
    ContextActionService:BindAction("KraitReload", handleAction, true, Enum.KeyCode.R)

    clientCaster:Initialize()

    local CastParams = RaycastParams.new()
    CastParams.IgnoreWater = true
    CastParams.FilterType = Enum.RaycastFilterType.Blacklist

    self.janitor:Add(RunService.Heartbeat:Connect(function()
        if MovementController.isSprinting and not self.isReloading then 
            self.isFiring = false
            self.lerpValues.sprint:set(1)
            self.swayspeed = 2
            self.swaymodifier = 0.06
        else
            self.lerpValues.sprint:set(0)
            self.swayspeed = 3
            self.swaymodifier = 0.03
        end

        if not self.canFire or self.isReloading then return end
        if self.bullets > 0 then
            if self.isFiring == true then
                self.canFire = false
                self.firingJanitor:AddPromise(Promise.delay(self.fireRate)):andThen(function()
                    self.canFire = true
                end)

                self.loadedAnimations.Shoot:Play(0)

                CastParams.FilterDescendantsInstances = {character, self.camera}
                local viewportPoint = self.camera.ViewportSize / 2
                local pos = UtilModule:GetMousePos(self.camera:ViewportPointToRay(viewportPoint.X, viewportPoint.Y), CastParams)
                local direction = (pos - vm.Krait.Handle.MuzzleBack.WorldPosition).Unit
                clientCaster:Fire(vm.Krait.Handle.MuzzleBack.WorldPosition, direction, character, 1.8)

                local flash = ReplicatedStorage.Assets.Particles.ElectricMuzzleFlash:Clone()
                flash.Parent = vm.Krait.Handle.Muzzle
                flash:Emit(1)
                task.delay(0.5, function()
                    flash:Destroy()
				 end)
				
				local sound = script.Parent.Sounds:FindFirstChild("Shoot" .. math.random(1, 3)):Clone()
				sound.Parent = self.camera
				sound:Destroy()

                self.springs.fire:shove(Vector3.new(2, math.random(-0.8, 0.8), 4))
                task.delay(0.2, function()
                    self.springs.fire:shove(Vector3.new(-1.5, math.random(-0.5, 0.5), -4))
                end)

                HudController:ExpandCrosshair()
                self.bullets = self.bullets - 1
                HudController:SetBullets(self.bullets)

                MovementController._sprintJanitor:Cleanup()
            end
        else
            self:Reload()
        end
    end))

    self.janitor:Add(function()
        self.loadedAnimations = {}
        HumanoidAnimatorUtils.stopAnimations(vm.AnimationController, 0)

        ContextActionService:UnbindAction("KraitShoot")
        ContextActionService:UnbindAction("KraitReload")
        clientCaster:Deinitialize()
        self.canFire = false        
    end)
end

function module:Unequip()
    self.janitor:Cleanup()
end

Knit.OnStart():andThen(function()
    HudController = Knit.GetController("HudController")
end)


return module