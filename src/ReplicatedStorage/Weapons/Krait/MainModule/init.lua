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
local Spring2 = require(Modules.Spring2)
local Spring3 = require(Modules.Spring3)
local SmoothValue = require(Modules.SmoothValue)

local WeaponService

local WeaponController
local HudController
local MovementController

local ClientCaster = require(script.Parent.ClientCaster)
local UtilModule = require(script.Util)

module.janitor = Janitor.new()
module.camera = workspace.CurrentCamera
module.loadedAnimations = {}
module.loaded3PAnimations = {}
module.springs = {}
module.lerpValues = {}
module.lerpValues.sprint = SmoothValue:create(0, 0, 12)
module.lerpValues.slide = SmoothValue:create(0, 0, 10)
module.lerpValues.aim = SmoothValue:create(0, 0, 18)
module.lerpValues.climb = SmoothValue:create(0, 0, 20)
module.lerpValues.unequip = SmoothValue:create(0, 0, 4)
module.charspeed = 0
module.running = false
module.OldCamCF = nil

module.unscopedPattern = {
    {1, 2, 1, -2, -1, 0.6};
    {5, 2, 1, -1.7, -0.8, 0.8};
    {10, 2, 1.2, -1.7, -1, 0.9};
    {20, 2, -1, -1.7, 0.5, 1};
    {25, 2, 1, -1.5, -0.5, 1.2};
    {30, 2, -1, -1.5, 0.5, 1.4};
}

module.scopedPattern = {
    {1, 2, 1, -2, -1, 0.6};
    {5, 2, 1, -2, -0.8, 0.8};
    {10, 2, 1.2, -1.8, -1, 0.9};
    {20, 2, -1, -1.7, 0.7, 1};
    {25, 2, 1, -1.6, -0.7, 1.2};
    {30, 2, -1, -1.6, 0.7, 1.4};
}

function module:SetupAnimations(character, vm)
    self.springs.sway = Spring.create()

    self.springs.jump = Spring.create(1, 10, 0, 1.8)
    self.springs.jumpCam = Spring.create()
    self.springs.fire = Spring3.new()
    self.springs.speed = Spring2.spring.new()
    self.springs.speed.s = 16
    self.springs.velocity = Spring2.spring.new(Vector3.new())
    self.springs.velocity.s = 16
    self.springs.velocity.t = Vector3.new()
    self.springs.velocity.p = Vector3.new()

    self.janitor:Add(character.Humanoid.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Jumping then
            self.springs.jump:shove(Vector3.new(0, 0.5))
            task.delay(0.2, function()
                self.springs.jump:shove(Vector3.new(0, -0.5))
            end)
            self.springs.jumpCam:shove(Vector3.new(0, 0.1))
        elseif newState == Enum.HumanoidStateType.Landed then
            self.springs.jump:shove(Vector3.new(0, -0.5))
            task.delay(0.15, function()
                self.springs.jump:shove(Vector3.new(0, 0.5))
            end)
            self.springs.jumpCam:shove(Vector3.new(0, -0.1))
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

    local waistC0 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)

    self.janitor:Add(RunService.RenderStepped:Connect(function(dt)
        if not vm.HumanoidRootPart then return end
        vm.HumanoidRootPart.CFrame = self.camera.CFrame

        local mouseDelta = UserInputService:GetMouseDelta()
        self.springs.sway:shove(Vector3.new(mouseDelta.X/300,mouseDelta.Y/300))
        local sway = self.springs.sway:update(dt)

        local gunbobcf = CFrame.new(0,0,0)
        local jump = self.springs.jump:update(dt)
        HudController.ScreenGui.Frame.Position = UDim2.fromScale(0, math.abs(jump.y/10))

        local idleOffset = CFrame.new(0.5,-0.5,-0.5)
        local sprintOffset = idleOffset:Lerp(CFrame.new(0.5,-1,-1) * CFrame.Angles(0.1,1,0.2), self.lerpValues.sprint:update(dt))
        local slideOffset = sprintOffset:Lerp(CFrame.new(-0.3,-0.7,-0.8) * CFrame.Angles(0, 0, 0.2), self.lerpValues.slide:update(dt))
        local aimOffset = slideOffset:Lerp(CFrame.new(0,0.03,0) * CFrame.Angles(0.01,0,0), self.lerpValues.aim:update(dt))
        local climbOffset = aimOffset:Lerp(CFrame.new(0,0,0), self.lerpValues.climb:update(dt))
        local unequipOffset = climbOffset:Lerp(CFrame.new(0,-3,0) * CFrame.Angles(4,0,0), self.lerpValues.unequip:update(dt))
        local finalOffset = unequipOffset

        vm.HumanoidRootPart.CFrame *= finalOffset

        if not self.isAiming then   
            vm.HumanoidRootPart.CFrame *= CFrame.Angles(jump.y,-sway.x,sway.y)
        else
            vm.HumanoidRootPart.CFrame *= CFrame.Angles(jump.y/8,-sway.x,sway.y)
        end

        if self.running then
            if not MovementController.isSprinting then
                gunbobcf = CFrame.new(0,0,0)
            else
                gunbobcf = gunbobcf:Lerp(CFrame.new(
                    .2 * (self.charspeed/4) * math.sin(tick() * 10),
                    .2 * (self.charspeed    /4) * math.cos(tick() * 20),
                    0
                    ) * CFrame.Angles(
                        math.rad( 1 * (self.charspeed/4) * math.sin(tick() * 20) ), 
                        math.rad( 1 * (self.charspeed/4) * math.cos(tick() * 10) ), 
                        math.rad(0)
                    ), 0.1)
            end
        end

        local RelativeVelocity
        if MovementController.isSliding then
            RelativeVelocity = CFrame.new().VectorToObjectSpace(character.HumanoidRootPart.CFrame, character.HumanoidRootPart.Velocity/3)
        else
            RelativeVelocity = CFrame.new().VectorToObjectSpace(character.HumanoidRootPart.CFrame, character.HumanoidRootPart.Velocity)
        end
        RelativeVelocity = UtilModule:ClampMagnitude(RelativeVelocity, 15)
        self.springs.speed.t = (Vector3.new(1, 0, 1) * RelativeVelocity).Magnitude
		self.springs.velocity.t = RelativeVelocity
		UtilModule.speed = self.springs.speed.p
		UtilModule.distance = UtilModule.distance + dt * self.springs.speed.p
		UtilModule.velocity = self.springs.velocity.p

        if not MovementController.isSprinting then
            if self.isAiming then
                vm.HumanoidRootPart.CFrame *= UtilModule:viewmodelBob(0.3, 0.15, character.Humanoid.WalkSpeed)
                vm.HumanoidRootPart.CFrame *= UtilModule:ViewmodelBreath(0.8)
            else
                vm.HumanoidRootPart.CFrame *= UtilModule:viewmodelBob(0.8, 0.4, character.Humanoid.WalkSpeed)
                vm.HumanoidRootPart.CFrame *= UtilModule:ViewmodelBreath(0)
            end
        end

        vm.HumanoidRootPart.CFrame *= gunbobcf

        local recoil = self.springs.fire:update(dt)
        self.camera.CFrame *= CFrame.Angles(math.rad(recoil.x), math.rad(recoil.y), math.rad(recoil.z) * 2)

        local jumpCam = self.springs.jumpCam:update(dt)
        self.camera.CFrame *= CFrame.Angles(jumpCam.y, 0, 0)

        local waist = character.HumanoidRootPart.RootJoint
		waist.C0 = waistC0 * CFrame.fromEulerAnglesYXZ(math.asin(self.camera.CFrame.LookVector.y) * -0.8, 0, 0)

        WeaponService:Tilt(waist.C0)

        
        local NewCamCF = vm.FakeCamera.CFrame:ToObjectSpace(vm.HumanoidRootPart.CFrame)
        if self.OldCamCF then
            local _, _, Z = NewCamCF:ToOrientation()
            local X, Y, _ = NewCamCF:ToObjectSpace(self.OldCamCF):ToEulerAnglesXYZ()
            self.camera.CFrame = self.camera.CFrame * CFrame.Angles(X, Y, -Z)
        end
        self.OldCamCF = NewCamCF
    end))

    
    self.loadedAnimations.Idle = vm.AnimationController:LoadAnimation(script.Parent.Animations.Idle)
    self.loadedAnimations.Shoot = vm.AnimationController:LoadAnimation(script.Parent.Animations.Shoot)
    self.loadedAnimations.Reload = vm.AnimationController:LoadAnimation(script.Parent.Animations.Reload)
    self.loadedAnimations.scopeIn = vm.AnimationController:LoadAnimation(script.Parent.Animations.ScopeIn)
    self.loadedAnimations.scopeIdle = vm.AnimationController:LoadAnimation(script.Parent.Animations.ScopeIdle)
    self.loadedAnimations.scopeOut = vm.AnimationController:LoadAnimation(script.Parent.Animations.ScopeOut)
    self.loadedAnimations.scopedShoot = vm.AnimationController:LoadAnimation(script.Parent.Animations.ScopeShoot)
    self.loadedAnimations.hide = vm.AnimationController:LoadAnimation(script.Parent.Animations.Hide)

    self.loadedAnimations.Idle:Play(0)
    self.loadedAnimations.scopeIdle.Looped = true

    local animator = HumanoidAnimatorUtils.getOrCreateAnimator(character.Humanoid)
    self.loaded3PAnimations.idle = animator:LoadAnimation(script.Parent["3PAnimations"].Idle)
    self.loaded3PAnimations.idle:Play(0)
    self.loaded3PAnimations.scoped = animator:LoadAnimation(script.Parent["3PAnimations"].Scoped)
    self.loaded3PAnimations.shoot = animator:LoadAnimation(script.Parent["3PAnimations"].Shoot)
    self.loaded3PAnimations.scopedShoot = animator:LoadAnimation(script.Parent["3PAnimations"].ScopedShoot)
    self.loaded3PAnimations.reload = animator:LoadAnimation(script.Parent["3PAnimations"].Reload)
end


module.aimJanitor = Janitor.new()
module.isAiming = false
module.scopedIn = false
module.isFiring = false
module.fireRate = 0.1
module.scopeOutPromise = nil

function module:ToggleAim(inputState, vm)
    if inputState == Enum.UserInputState.Begin then
        if not self.equipped or self.isReloading or self.isAiming then return end

        self.isAiming = true
        MovementController.canSprint = false
        MovementController.canClimb = false
        if HumanoidAnimatorUtils.isPlayingAnimationTrack(vm.AnimationController, self.loadedAnimations.Reload) then self.loadedAnimations.Reload:Stop(0) end
        self.loadedAnimations.scopeIn:Play(0)
        self.loadedAnimations.scopeIn:AdjustSpeed(1.25)
        self.loaded3PAnimations.scoped:Play()
        self.aimJanitor:AddPromise(Promise.delay(self.loadedAnimations.scopeIn.Length/1.25 - 0.05)):andThen(function()
            self.scopedIn = true 
            self.loadedAnimations.scopeIdle:Play(0)
        end)

        if HumanoidAnimatorUtils.isPlayingAnimationTrack(vm.AnimationController, self.loadedAnimations.scopeOut) then self.loadedAnimations.scopeOut:Stop(0) end
        if HumanoidAnimatorUtils.isPlayingAnimationTrack(vm.AnimationController, self.loadedAnimations.scoped) then self.loadedAnimations.scoped:Stop(0) end

        WeaponController.baseFov:set(65)
        game:GetService("UserInputService").MouseDeltaSensitivity = 65/90 * WeaponController.initialMouseSens
        HudController:ShowVignette(true, 0.2)
        HudController:ShowCrosshair(false, 0.2)
        local oldOffset = HudController.crosshairOffset.target
        HudController.crosshairOffset:set(5)
        self.lerpValues.unequip.speed = 15

        self.aimJanitor:Add(function()
            self.isAiming = false
            self.scopedIn = false
            MovementController.canSprint = true
            MovementController.canClimb = true
            if HumanoidAnimatorUtils.isPlayingAnimationTrack(vm.AnimationController,self.loadedAnimations.scopeIn) then self.loadedAnimations.scopeIn:Stop() end
            if HumanoidAnimatorUtils.isPlayingAnimationTrack(vm.AnimationController,self.loadedAnimations.scopeIdle) then self.loadedAnimations.scopeIdle:Stop() end
            self.loaded3PAnimations.scoped:Stop()
            self.lerpValues.aim:set(0)
            WeaponController.baseFov:set(90)
            game:GetService("UserInputService").MouseDeltaSensitivity = WeaponController.initialMouseSens
            HudController:ShowVignette(false, 0.2)
            HudController:ShowCrosshair(true, 0.2)
            HudController.crosshairOffset:set(oldOffset)
            pcall(function() self.loadedAnimations.scopedShoot:Stop(0) end)
            self.lerpValues.unequip.speed = 4
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
            self.loaded3PAnimations.scoped:Stop()
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
        MovementController.canClimb = false
        self.lerpValues.sprint:set(0)
        self.lerpValues.slide:set(0)
        self.aimJanitor:Cleanup()

        self.loadedAnimations.Reload:Play(0)
        self.loaded3PAnimations.reload:Play(0)
        self.loadedAnimations.Reload:AdjustSpeed(1.25) 
        self.janitor:AddPromise(Promise.delay(self.loadedAnimations.Reload.Length - 0.7)):andThen(function()
            self.isReloading = false
            MovementController.canClimb = true
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
            MovementController.canClimb = true
            sound:Destroy()
            WeaponService:StopSound("Reload")
        end)
    end
end



function module:Equip(character, vm)
    WeaponController.baseFov:set(90)

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
    self.equipped = true
    HudController:SetBullets(self.bullets)
    self.isReloading = false
    self.curshots = 0
    self.lastshot = tick()

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
        elseif MovementController.isSliding or MovementController.isCrouching and not self.isReloading then
            self.lerpValues.sprint:set(0)
            self.lerpValues.slide:set(1)
        else
            self.lerpValues.slide:set(0)
            self.lerpValues.sprint:set(0)
        end

        if not self.equipped then
            self.isFiring = false
        end

        if not self.canFire or not self.equipped or self.isReloading then return end
        if self.bullets > 0 then
            if self.isFiring == true then
                self.canFire = false
                self.janitor:AddPromise(Promise.delay(self.fireRate)):andThen(function()
                    self.canFire = true
                end)

                CastParams.FilterDescendantsInstances = {character, self.camera}
                local direction

                if HumanoidAnimatorUtils.isPlayingAnimationTrack(vm.AnimationController, self.loadedAnimations.Reload) then 
                    self.loadedAnimations.Reload:Stop(0)
                end
                if HumanoidAnimatorUtils.isPlayingAnimationTrack(HumanoidAnimatorUtils.getOrCreateAnimator(character.Humanoid), self.loaded3PAnimations.Reload) then 
                    self.loaded3PAnimations.Reload:Stop(0)
                end

                local randSound = "Shoot" .. math.random(1, 3)
				local sound = script.Parent.Sounds[randSound]:Clone()
				sound.Parent = self.camera
                sound.PlayOnRemove = false
                if tick() - self.lastshot > 0.3 then
                    sound.Volume = 3
                else
                    sound.Volume = 2
                end
				sound:Play() 
                task.delay(sound.TimeLength, function()
                    sound:Destroy()
                end)   
                WeaponService:PlaySound(randSound, true) 
                
                if self.camera:FindFirstChild("Tail") then self.camera.Tail:Destroy() end
                local tailSound = script.Parent.Sounds.Tail:Clone()
                tailSound.Parent = self.camera
                tailSound:Play()

                local emptyClipSound = script.Parent.Sounds.EmptyClip:Clone()
                emptyClipSound.Parent = self.camera
                emptyClipSound.Volume = (30/self.bullets)/2
                emptyClipSound:Destroy()

                if not self.scopedIn then
                    self.loadedAnimations.Shoot:Play(0)
                    self.loaded3PAnimations.shoot:Play()
                    self.curshots = (tick() - self.lastshot > 0.3 and 1 or self.curshots + 1)
                    self.lastshot = tick()
                    if self.curshots > 28 then
                        self.curshots = 1
                    end
                    local curRecoil
                    for _, v in pairs(self.unscopedPattern) do
                        if self.curshots < v[1] then
                            curRecoil = v
                            break
                        end
                    end
                    self.springs.fire:shove(Vector3.new(curRecoil[2], curRecoil[3], 6))
                    task.delay(0.1, function()
                        self.springs.fire:shove(Vector3.new(curRecoil[4], curRecoil[5], -6))
                    end)
                    direction = (self.camera.CFrame * CFrame.Angles(math.rad(1.5),math.rad(1.5),0)).LookVector
                    ClientCaster:Fire(vm.Krait.Handle.MuzzleBack.WorldPosition, direction, character, curRecoil[6])
                else
                    self.loadedAnimations.scopedShoot:Play(0)
                    self.loaded3PAnimations.scopedShoot:Play(0)
                    self.curshots = (tick() - self.lastshot > 0.3 and 1 or self.curshots + 1)
                    self.lastshot = tick()
                    if self.curshots > 24 then
                        self.curshots = 1
                    end
                    local curRecoil
                    for _, v in pairs(self.scopedPattern) do
                        if self.curshots < v[1] then
                            curRecoil = v
                            break
                        end
                    end
                    self.springs.fire:shove(Vector3.new(curRecoil[2], curRecoil[3], 4))
                    task.delay(0.1, function()
                        self.springs.fire:shove(Vector3.new(curRecoil[4], curRecoil[5], -4))
                    end)
                    direction = self.camera.CFrame.LookVector
                    ClientCaster:Fire(vm.Krait.Handle.MuzzleBack.WorldPosition, direction, character, curRecoil[6])
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
    WeaponController = Knit.GetController("WeaponController")
    HudController = Knit.GetController("HudController")
    MovementController = Knit.GetController("MovementController")
    WeaponService = Knit.GetService("WeaponService")
end)


return module