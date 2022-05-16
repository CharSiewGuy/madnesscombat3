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
local Tween = require(Packages.TweenPromise)

local Modules = ReplicatedStorage.Modules
local Spring = require(Modules.Spring)
local SmoothValue = require(Modules.SmoothValue)

local WeaponService

local HudController
local MovementController

local ClientCaster = require(script.Parent.ClientCaster)
local UtilModule = require(script.Util)

module.janitor = Janitor.new()
module.camera = workspace.CurrentCamera
module.loadedAnimations = {}
module.springs = {}
module.lerpValues = {}
module.lerpValues.sprint = SmoothValue:create(0, 0, 15)
module.lerpValues.slide = SmoothValue:create(0, 0, 7)
module.lerpValues.aim = SmoothValue:create(0, 0, 10)
module.charspeed = 0
module.running = false

function module:SetupAnimations(character, vm)
    self.springs.sway = Spring.create()

    self.springs.jump = Spring.create(1, 10, 0, 1.8)
    self.springs.fire = Spring.create()

    self.janitor:Add(character.Humanoid.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Jumping then
            self.springs.jump:shove(Vector3.new(0, 0.5))
            task.delay(0.2, function()
                self.springs.jump:shove(Vector3.new(0, -0.5))
            end)
        elseif newState == Enum.HumanoidStateType.Landed then
            self.springs.jump:shove(Vector3.new(0, -0.5))
            task.delay(0.15, function()
                self.springs.jump:shove(Vector3.new(0, 0.5))
            end)
        end
        
        if newState == Enum.HumanoidStateType.Swimming then
            self.Swimming = true
        else
            self.Swimming = false
        end
    end))

    
    self.janitor:Add(character.Humanoid.Running:Connect(function(speed)
        self.charspeed = speed
        if speed > 0.1 then
            self.running = true
        else
            self.running = false
        end
    end))

    self.janitor:Add(character.Humanoid.Swimming:Connect(function(speed)
        if self.Swimming then
            self.charspeed = speed
            if speed > 0.1 then
                self.running = true
            else
                self.running = false
            end
        end
    end))

    self.janitor:Add(RunService.RenderStepped:Connect(function(dt)
        if not vm.HumanoidRootPart then return end

        local mouseDelta = UserInputService:GetMouseDelta()
        self.springs.sway:shove(Vector3.new(mouseDelta.X / 400,mouseDelta.Y / 400))
        local sway = self.springs.sway:update(dt)

        local gunbobcf = CFrame.new(0,0,0)
        local jump = self.springs.jump:update(dt)

        local idleOffset = CFrame.new(0.5,-0.5,-0.5)
        local sprintOffset = idleOffset:Lerp(CFrame.new(0.5,-1,-1) * CFrame.Angles(0.1,1,0.2), self.lerpValues.sprint:update(dt))
        local slideOffset = sprintOffset:Lerp(CFrame.new(-0.3,-0.7,-0.8) * CFrame.Angles(0, 0, 0.2), self.lerpValues.slide:update(dt))
        local aimOffset = slideOffset:Lerp(CFrame.new(0,0.03,0) * CFrame.Angles(0.01,0,0), self.lerpValues.aim:update(dt))
        local finalOffset = aimOffset
        vm.HumanoidRootPart.CFrame = self.camera.CFrame:ToWorldSpace(finalOffset)

        if not self.isAiming then   
            vm.HumanoidRootPart.CFrame = vm.HumanoidRootPart.CFrame * CFrame.Angles(jump.y,-sway.x,sway.y)
        else
            vm.HumanoidRootPart.CFrame = vm.HumanoidRootPart.CFrame * CFrame.Angles(jump.y/8,-sway.x,sway.y)
        end

        if self.running then
            if not MovementController.isSprinting then
                local multiplier = .15
                if self.isAiming then
                    multiplier = .01
                end
                gunbobcf = gunbobcf:Lerp(CFrame.new(
                    multiplier * (self.charspeed/4) * math.sin(tick() * 8),
                    multiplier * (self.charspeed/4) * math.cos(tick() * 16),
                    0
                    ) * CFrame.Angles(
                        math.rad( 1 * (self.charspeed/4) * math.sin(tick() * 8) ), 
                        math.rad( 1 * (self.charspeed/4) * math.cos(tick() * 16) ), 
                        math.rad(0)
                    ), 0.1)
            else
                gunbobcf = gunbobcf:Lerp(CFrame.new(
                    .2 * (self.charspeed/4) * math.sin(tick() * 10),
                    .2 * (self.charspeed/4) * math.cos(tick() * 20),
                    0
                    ) * CFrame.Angles(
                        math.rad( 1 * (self.charspeed/4) * math.sin(tick() * 20) ), 
                        math.rad( 1 * (self.charspeed/4) * math.cos(tick() * 10) ), 
                        math.rad(0)
                    ), 0.1)
            end
        else
            gunbobcf = gunbobcf:Lerp(CFrame.new(
                0.005 * math.sin(tick() * 1.5),
                0.005 * math.cos(tick() * 2.5),
                0 
                ), 0.1)
        end

        vm.HumanoidRootPart.CFrame = vm.HumanoidRootPart.CFrame * gunbobcf

        local recoil = self.springs.fire:update(dt)
        self.camera.CFrame = self.camera.CFrame * CFrame.Angles(math.rad(recoil.x), math.rad(recoil.y), math.rad(recoil.z))
    end))
end


module.aimJanitor = Janitor.new()
module.isAiming = false
module.scopedIn = false
module.isFiring = false
module.fireRate = 0.115
module.scopeOutPromise = nil

function module:ToggleAim(inputState, vm)
    if inputState == Enum.UserInputState.Begin then
        if self.isReloading or self.isAiming then return end

        self.isAiming = true
        MovementController.canSprint = false
        if HumanoidAnimatorUtils.isPlayingAnimationTrack(vm.AnimationController, self.loadedAnimations.Reload) then self.loadedAnimations.Reload:Stop(0) end
        self.loadedAnimations.scopeIn:Play(0)
        self.loadedAnimations.scopeIn:AdjustSpeed(1.25)
        self.aimJanitor:AddPromise(Promise.delay(self.loadedAnimations.scopeIn.Length/1.25 - 0.05)):andThen(function()
            self.scopedIn = true 
            self.loadedAnimations.scopeIdle:Play(0)
        end)

        self.aimJanitor:AddPromise(Tween(self.camera, TweenInfo.new(0.2), {FieldOfView = 65}))
        HudController:ShowVignette(true, 0.2)
        HudController:ShowCrosshair(false, 0.2)
        HudController.crosshairOffset:set(5)

        self.aimJanitor:Add(function()
            self.isAiming = false
            self.scopedIn = false
            MovementController.canSprint = true
            if HumanoidAnimatorUtils.isPlayingAnimationTrack(vm.AnimationController,self.loadedAnimations.scopeIn) then self.loadedAnimations.scopeIn:Stop() end
            if HumanoidAnimatorUtils.isPlayingAnimationTrack(vm.AnimationController,self.loadedAnimations.scopeIdle) then self.loadedAnimations.scopeIdle:Stop() end
            self.lerpValues.aim:set(0)
            self.janitor:AddPromise(Tween(self.camera, TweenInfo.new(0.2), {FieldOfView = 90}))
            HudController:ShowVignette(false, 0.2)
            HudController:ShowCrosshair(true, 0.2)
            HudController.crosshairOffset:set(50)
            pcall(function() self.loadedAnimations.scopedShoot:Stop(0) end)
        end)

        if self.scopeOutPromise then
            self.scopeOutPromise:cancel()
        end

        pcall(function()MovementController.sprintJanitor:Cleanup()end)
        
        self.lerpValues.aim:set(1)

        local inSound = script.Parent.Sounds.ScopeIn:Clone()
        inSound.Parent = self.camera
        inSound:Destroy()
        local outSound = script.Parent.Sounds.ScopeOut:Clone()
        outSound.Parent = self.camera
        self.aimJanitor:Add(outSound)
    elseif inputState == Enum.UserInputState.End then
        if self.isAiming then
            self.aimJanitor:Cleanup()
            self.loadedAnimations.scopeOut:Play(0)
            self.loadedAnimations.scopeOut:AdjustSpeed(1.25)
        end
    end
end

module.bullets = 30
module.maxBullets = 30
module.isReloading = false

function module:Reload()
    if not self.isReloading and self.bullets < self.maxBullets then
        self.isFiring = false
        self.isReloading = true
        self.lerpValues.sprint:set(0)
        self.lerpValues.slide:set(0)
        self.aimJanitor:Cleanup()

        self.loadedAnimations.Reload:Play(0)
        self.loadedAnimations.Reload:AdjustSpeed(1.25) 
        self.janitor:AddPromise(Promise.delay(self.loadedAnimations.Reload.Length - 0.7)):andThen(function()
            self.isReloading = false
            self.bullets = self.maxBullets
            HudController:SetBullets(self.bullets)
        end)

        local sound = script.Parent.Sounds.Reload:Clone()
        sound.Parent = self.camera
        sound:Play(0)
        if WeaponService then
            WeaponService:PlaySound("Reload", false)
        end
        
        self.janitor:Add(sound.Ended:Connect(function()
            sound:Destroy()
        end))

        self.janitor:AddPromise(Promise.delay(0.25)):andThen(function()
            UtilModule:SetGlow(self.camera.viewmodel.Krait, false)
        end)

        self.janitor:AddPromise(Promise.delay(0.85)):andThen(function()
            UtilModule:SetGlow(self.camera.viewmodel.Krait, true)
        end)

        self.janitor:Add(function()
            self.isReloading = false
            sound:Destroy()
            WeaponService:StopSound("Reload")
        end)
    end
end



function module:Equip(character, vm)
    self.camera.FieldOfView = 90

    local Krait = script.Parent.Krait:Clone()
    Krait.Parent = vm
    self.janitor:Add(Krait)

    local vmRoot = vm:WaitForChild("HumanoidRootPart")

    local weaponMotor6D = script.Parent.Handle:Clone()
    weaponMotor6D.Part0 = vmRoot
    weaponMotor6D.Part1 = Krait.Handle
    weaponMotor6D.Parent = vmRoot

    self:SetupAnimations(character, vm)

    self.canFire = true
    self.bullets = 30
    self.isReloading = false

    self.loadedAnimations.Idle = vm.AnimationController:LoadAnimation(script.Parent.Animations.Idle)
    self.loadedAnimations.Shoot = vm.AnimationController:LoadAnimation(script.Parent.Animations.Shoot)
    self.loadedAnimations.Reload = vm.AnimationController:LoadAnimation(script.Parent.Animations.Reload)
    self.loadedAnimations.scopeIn = vm.AnimationController:LoadAnimation(script.Parent.Animations.ScopeIn)
    self.loadedAnimations.scopeIdle = vm.AnimationController:LoadAnimation(script.Parent.Animations.ScopeIdle)
    self.loadedAnimations.scopeOut = vm.AnimationController:LoadAnimation(script.Parent.Animations.ScopeOut)
    self.loadedAnimations.scopedShoot = vm.AnimationController:LoadAnimation(script.Parent.Animations.ScopeShoot)

    self.loadedAnimations.Idle:Play(0)
    self.loadedAnimations.scopeIdle.Looped = true

    local function handleAction(actionName, inputState)
        if self.bullets <= 0 or self.isReloading then return end
        if actionName == "KraitShoot" then
            if inputState == Enum.UserInputState.Begin then
                self.isFiring = true
            elseif inputState == Enum.UserInputState.End then
                self.isFiring = false
            end 
        elseif actionName == "KraitAim" then
            self:ToggleAim(inputState, vm)
        elseif actionName == "KraitReload" then
            if inputState == Enum.UserInputState.Begin then
                self:Reload()
            end
        end
    end

    ContextActionService:BindAction("KraitShoot", handleAction, true, Enum.UserInputType.MouseButton1)
    ContextActionService:BindAction("KraitAim", handleAction, true, Enum.UserInputType.MouseButton2)
    ContextActionService:BindAction("KraitReload", handleAction, true, Enum.KeyCode.R)

    ClientCaster:Initialize()

    local CastParams = RaycastParams.new()
    CastParams.IgnoreWater = true
    CastParams.FilterType = Enum.RaycastFilterType.Blacklist

    self.janitor:Add(RunService.Heartbeat:Connect(function()
        if MovementController.isSprinting and not self.isReloading then 
            self.isFiring = false
            self.lerpValues.sprint:set(1)
            self.lerpValues.slide:set(0)
        elseif MovementController.isSliding and not self.isReloading then
            self.lerpValues.sprint:set(0)
            self.lerpValues.slide:set(1)
        else
            self.lerpValues.slide:set(0)
            self.lerpValues.sprint:set(0)
        end

        if not self.canFire or self.isReloading then return end
        if self.bullets > 0 then
            if self.isFiring == true then
                self.canFire = false
                self.janitor:AddPromise(Promise.delay(self.fireRate)):andThen(function()
                    self.canFire = true
                end)

                CastParams.FilterDescendantsInstances = {character, self.camera}
                local direction = self.camera.CFrame.LookVector * 500

                if HumanoidAnimatorUtils.isPlayingAnimationTrack(vm.AnimationController, self.loadedAnimations.Reload) then self.loadedAnimations.Reload:Stop(0) end

                if not self.scopedIn then
                    ClientCaster:Fire(vm.Krait.Handle.MuzzleBack.WorldPosition, direction, character, 3)
                    self.loadedAnimations.Shoot:Play(0)
                    self.springs.fire:shove(Vector3.new(3, math.random(-2, 2), 2))
                    task.delay(0.3, function()
                        self.springs.fire:shove(Vector3.new(-2.5, math.random(-1, 1), -4))
                    end)
                else
                    ClientCaster:Fire(vm.Krait.Handle.Muzzle.WorldPosition, direction, character, 1.1)
                    self.loadedAnimations.scopedShoot:Play(0)
                    self.springs.fire:shove(Vector3.new(1, math.random(-0.4, 0.4), 1))
                    task.delay(0.2, function()
                        self.springs.fire:shove(Vector3.new(-0.5, math.random(-0.3, 0.3), -1))
                    end)
                end

                local flash = ReplicatedStorage.Assets.Particles.ElectricMuzzleFlash:Clone()
                flash.Parent = vm.Krait.Handle.Muzzle
                flash:Emit(1)
                task.delay(0.15, function()
                    flash:Destroy()
			    end)

                vm.Krait.Handle.Muzzle.PointLight.Enabled = true

                self.janitor:AddPromise(Promise.delay(.05)):andThen(function()
                    vm.Krait.Handle.Muzzle.PointLight.Enabled = false
                end)
				
                local randSound = "Shoot" .. math.random(1, 3)
				local sound = script.Parent.Sounds[randSound]:Clone()
				sound.Parent = self.camera
				sound:Destroy()       
                WeaponService:PlaySound(randSound, true)             

                HudController:ExpandCrosshair()
                self.bullets = self.bullets - 1
                HudController:SetBullets(self.bullets)

                pcall(function()MovementController.sprintJanitor:Cleanup()end)
            end
        else
            self:Reload()
        end
    end))

    self.janitor:Add(function()
        self.loadedAnimations = {}
        HumanoidAnimatorUtils.stopAnimations(vm.AnimationController, 0)

        ContextActionService:UnbindAction("KraitShoot")
        ContextActionService:UnbindAction("KraitAim")
        ContextActionService:UnbindAction("KraitReload")
        ClientCaster:Deinitialize()
        self.canFire = false
        self.isFiring = false
    end)
end

function module:Unequip()
    self.janitor:Cleanup()
    self.aimJanitor:Cleanup()
end

Knit.OnStart():andThen(function()
    HudController = Knit.GetController("HudController")
    MovementController = Knit.GetController("MovementController")
    WeaponService = Knit.GetService("WeaponService")
end)


return module