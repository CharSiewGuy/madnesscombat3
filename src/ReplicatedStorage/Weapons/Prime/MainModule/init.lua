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
local Spring2 = require(Modules.Spring2)
local Spring3 = require(Modules.Spring3)
local SmoothValue = require(Modules.SmoothValue)

local WeaponService
local SoundService

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
module.lerpValues.sprint = SmoothValue:create(0, 0, 9)
module.lerpValues.slide = SmoothValue:create(0, 0, 10)
module.lerpValues.aim = SmoothValue:create(0, 0, 18)
module.lerpValues.climb = SmoothValue:create(0, 0, 20)
module.charspeed = 0
module.running = false
module.OldCamCF = nil

module.unscopedPattern = {
    {1, 2, 1, -1.8, -1, 1.6};
    {5, 2.2, 1, -1.7, -0.8, 1.8};
    {10, 2.4, 1.2, -1.6, -1, 2};
    {20, 2.5, -1, -1.4, 0.5, 2.4};
    {25, 2.6, 1, -1.2, -0.5, 2.5};
    {30, 2.6, -1, -1, 0.5, 2.5};
}

module.scopedPattern = {
    {1, 2, 1, -2, -1, 0.6};
    {5, 2, 1, -2, -1, 0.8};
    {10, 2, 1, -1.9, -1, 0.9};
    {20, 2, -1, -1.8, 0.9, 1};
    {25, 2, 1, -1.7, -0.9, 1.2};
    {30, 2, -1, -1.6, 0.9, 1.4};
}

function module:SetupAnimations(character, vm)
    self.springs.sway = Spring.create()

    self.springs.jump = Spring.create(1, 10, 0, 1.8)
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

    local waistC0 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)

    self.janitor:Add(RunService.RenderStepped:Connect(function(dt)
        vm.HumanoidRootPart.CFrame = self.camera.CFrame

        local mouseDelta = UserInputService:GetMouseDelta()
        self.springs.sway:shove(Vector3.new(mouseDelta.X/250,mouseDelta.Y/250))
        local sway = self.springs.sway:update(dt)

        local gunbobcf = CFrame.new(0,0,0)
        local jump = self.springs.jump:update(dt)

        local idleOffset = CFrame.new(0.8,-0.8,-0.7)
        local sprintOffset = idleOffset:Lerp(CFrame.new(0.5,-1.5,-1.2) * CFrame.Angles(0,1,0.2), self.lerpValues.sprint:update(dt))
        local slideOffset = sprintOffset:Lerp(CFrame.new(-0.3,-0.7,-0.8) * CFrame.Angles(0, 0, 0.2), self.lerpValues.slide:update(dt))
        local aimOffset = slideOffset:Lerp(CFrame.new(0,0.03,0) * CFrame.Angles(0.01,0,0), self.lerpValues.aim:update(dt))
        local finalOffset = aimOffset
        vm.HumanoidRootPart.CFrame *= finalOffset

        if not self.isAiming then   
            vm.HumanoidRootPart.CFrame *= CFrame.Angles(jump.y + sway.y,-sway.x,sway.y)
        else
            vm.HumanoidRootPart.CFrame *= CFrame.Angles(jump.y/8 + sway.y,-sway.x,sway.y)
        end

        if self.running then
            if not MovementController.isSprinting then
                gunbobcf = CFrame.new(0,0,0)
            else
                gunbobcf = gunbobcf:Lerp(CFrame.new(
                    0.1 *  math.clamp((self.charspeed/3.5), 0, 10) * math.sin(tick() * 10),
                    0.2 * math.clamp((self.charspeed/3.5), 0, 10) * math.cos(tick() * 10),
                    0
                    ) * CFrame.Angles(
                        math.rad(7 *  math.clamp((self.charspeed/3.5), 0, 10) * math.sin(tick() * 20)), 
                        math.rad(11 *  math.clamp((self.charspeed/3.5), 0, 10) * math.cos(tick() * 10)), 
                        math.rad(0)
                    ), 0.1)
            end
        end

        local RelativeVelocity
        if MovementController.isSliding then
            RelativeVelocity = CFrame.new().VectorToObjectSpace(character.HumanoidRootPart.CFrame, character.HumanoidRootPart.Velocity/2)
        else
            RelativeVelocity = CFrame.new().VectorToObjectSpace(character.HumanoidRootPart.CFrame, character.HumanoidRootPart.Velocity)
        end
        RelativeVelocity = UtilModule:ClampMagnitude(RelativeVelocity, 15)
        self.springs.speed.t = (Vector3.new(1, 0, 1) * RelativeVelocity).Magnitude
		self.springs.velocity.t = RelativeVelocity
		UtilModule.speed = self.springs.speed.p
		UtilModule.distance = UtilModule.distance + dt * self.springs.speed.p
		UtilModule.velocity = self.springs.velocity.p

        if not MovementController.isSprinting and character.Humanoid.WalkSpeed > 0 then
            if self.isAiming then
                vm.HumanoidRootPart.CFrame *= UtilModule:viewmodelBob(0.15, 0.2, character.Humanoid.WalkSpeed)
                vm.HumanoidRootPart.CFrame *= UtilModule:ViewmodelBreath(0.8)
            else
                vm.HumanoidRootPart.CFrame *= UtilModule:viewmodelBob(0.5, 1, character.Humanoid.WalkSpeed)
                vm.HumanoidRootPart.CFrame *= UtilModule:ViewmodelBreath(0)
            end
        end

        if self.isAiming then
            vm.HumanoidRootPart.CFrame *= UtilModule:ViewmodelBreath(0.8)
        else
            vm.HumanoidRootPart.CFrame *= UtilModule:ViewmodelBreath(0)
        end

        vm.HumanoidRootPart.CFrame *= gunbobcf

        local recoil = self.springs.fire:update(dt)
        self.camera.CFrame *= CFrame.Angles(math.rad(recoil.x), math.rad(recoil.y), math.rad(recoil.z) * 2)

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

    HumanoidAnimatorUtils.stopAnimations(vm.AnimationController, 0)
    
    self.loadedAnimations.Idle = vm.AnimationController:LoadAnimation(script.Parent.Animations.Idle)
    self.loadedAnimations.Shoot = vm.AnimationController:LoadAnimation(script.Parent.Animations.Shoot)
    self.loadedAnimations.Reload = vm.AnimationController:LoadAnimation(script.Parent.Animations.Reload)
    self.loadedAnimations.scopeIn = vm.AnimationController:LoadAnimation(script.Parent.Animations.ScopeIn)
    self.loadedAnimations.scopeIdle = vm.AnimationController:LoadAnimation(script.Parent.Animations.ScopeIdle)
    self.loadedAnimations.scopeOut = vm.AnimationController:LoadAnimation(script.Parent.Animations.ScopeOut)
    self.loadedAnimations.scopedShoot = vm.AnimationController:LoadAnimation(script.Parent.Animations.ScopeShoot)
    self.loadedAnimations.hide = vm.AnimationController:LoadAnimation(script.Parent.Animations.Hide)
    self.loadedAnimations.equip = vm.AnimationController:LoadAnimation(script.Parent.Animations.Equip)
    self.loadedAnimations.equipCam = vm.AnimationController:LoadAnimation(script.Parent.Animations.EquipCam)
    self.loadedAnimations.equip.Looped = false

    self.loadedAnimations.scopeIdle.Looped = true

    local animator = HumanoidAnimatorUtils.getOrCreateAnimator(character.Humanoid)
    self.loaded3PAnimations.Idle = animator:LoadAnimation(script.Parent["3PAnimations"].Idle)
    self.loaded3PAnimations.scoped = animator:LoadAnimation(script.Parent["3PAnimations"].Scoped)
    self.loaded3PAnimations.shoot = animator:LoadAnimation(script.Parent["3PAnimations"].Shoot)
    self.loaded3PAnimations.scopedShoot = animator:LoadAnimation(script.Parent["3PAnimations"].ScopedShoot)
    self.loaded3PAnimations.reload = animator:LoadAnimation(script.Parent["3PAnimations"].Reload)

    if MovementController.loadedAnimations.sprint then
        if MovementController.loadedAnimations.sprint.IsPlaying then
            MovementController.loadedAnimations.sprint:Stop(0) 
            MovementController.loadedAnimations.sprint = animator:LoadAnimation(script.Parent["3PAnimations"].Sprint)
            MovementController.loadedAnimations.sprint:Play(0)
        else
            MovementController.loadedAnimations.sprint = animator:LoadAnimation(script.Parent["3PAnimations"].Sprint)
        end
    end

    self.janitor:Add(function()
        for _, v in pairs(self.loaded3PAnimations) do
            v:Stop(0)
        end
    end)
end


module.aimJanitor = Janitor.new()
module.isAiming = false
module.scopedIn = false
module.isFiring = false
module.fireRate = 0.088
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
            self.loadedAnimations.scopeIdle:Play()
        end)

        if HumanoidAnimatorUtils.isPlayingAnimationTrack(vm.AnimationController, self.loadedAnimations.scopeOut) then self.loadedAnimations.scopeOut:Stop(0) end
        if HumanoidAnimatorUtils.isPlayingAnimationTrack(vm.AnimationController, self.loadedAnimations.scoped) then self.loadedAnimations.scoped:Stop(0) end
        pcall(function()MovementController.sprintJanitor:Cleanup()end)

        WeaponController.baseFov:set(65)
        game:GetService("UserInputService").MouseDeltaSensitivity = 65/90 * WeaponController.initialMouseSens
        HudController:ShowVignette(true, 0.2)
        HudController.crosshairTransparency:set(1)
        HudController.dotTransparency:set(1)

        self.aimJanitor:Add(function()
            self.isAiming = false
            self.scopedIn = false
            MovementController.canSprint = true
            if not self.isReloading then
                MovementController.canClimb = true
            end
            if HumanoidAnimatorUtils.isPlayingAnimationTrack(vm.AnimationController,self.loadedAnimations.scopeIn) then self.loadedAnimations.scopeIn:Stop() end
            if HumanoidAnimatorUtils.isPlayingAnimationTrack(vm.AnimationController,self.loadedAnimations.scopeIdle) then self.loadedAnimations.scopeIdle:Stop() end
            self.loaded3PAnimations.scoped:Stop()
            self.lerpValues.aim:set(0)
            WeaponController.baseFov:set(90)
            game:GetService("UserInputService").MouseDeltaSensitivity = WeaponController.initialMouseSens
            HudController:ShowVignette(false, 0.2)
            HudController.crosshairTransparency:set(0)
            HudController.dotTransparency:set(0)
            HudController.isAiming = false
            HudController.crosshairOffset:set(20)
            pcall(function() self.loadedAnimations.scopedShoot:Stop(0) end)
        end)

        if self.scopeOutPromise then
            self.scopeOutPromise:cancel()
        end
        
        HudController.isAiming = true
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

        local reloadLength = 3
        if self.loadedAnimations.Reload.Length > 0 then
            reloadLength = self.loadedAnimations.Reload.Length
        end 

        self.janitor:AddPromise(Promise.delay(reloadLength - 0.7)):andThen(function()
            self.isReloading = false
            MovementController.canClimb = true
            self.bullets = self.maxBullets
            HudController:SetBullets(self.bullets, self.maxBullets)
        end)

        local sound = script.Parent.Sounds.Reload:Clone()
        sound.Parent = self.camera
        sound:Play(0)
        SoundService:PlaySound("Prime", "Reload", false)
        
        self.janitor:Add(sound.Ended:Connect(function()
            sound:Destroy()
        end))

        self.janitor:AddPromise(Promise.delay(0.25)):andThen(function()
            UtilModule:SetGlow(self.camera.viewmodel.Prime, false)
        end)

        self.janitor:AddPromise(Promise.delay(0.85)):andThen(function()
            UtilModule:SetGlow(self.camera.viewmodel.Prime, true)
        end)

        self.janitor:Add(function()
            self.isReloading = false
            MovementController.canClimb = true
            sound:Destroy()
            SoundService:StopSound("Reload")
        end)
    end
end



function module:Equip(character, vm, bullets)
    local can = character.Humanoid and character.Humanoid.Health > 0 and character.HumanoidRootPart and vm.HumanoidRootPart
    if not can then return end

    self.janitor:LinkToInstance(character)

    self.equipped = false
    WeaponController.baseFov:set(90)
    MovementController.normalSpeed = 15
    MovementController.sprintSpeed = 23
    if MovementController.isSprinting then 
        MovementController.value:set(MovementController.sprintSpeed)
    else
        MovementController.value:set(MovementController.normalSpeed)
    end

    local Prime = script.Parent.Prime:Clone()
    for _, v in pairs(Prime:GetDescendants()) do if v:IsA("BasePart") or v:IsA("Texture") then v.Transparency = 1 end end
    Prime.Parent = vm
    self.janitor:Add(Prime)

    local vmRoot = vm:WaitForChild("HumanoidRootPart")

    local weaponMotor6D = script.Parent.Handle:Clone()
    weaponMotor6D.Part0 = vmRoot
    weaponMotor6D.Part1 = Prime.Handle
    weaponMotor6D.Parent = vmRoot
    self.janitor:Add(weaponMotor6D)

    self:SetupAnimations(character, vm)
    self.loadedAnimations.Idle:Play(0)
    self.loadedAnimations.Idle.Looped = true
    self.loaded3PAnimations.Idle:Play(0)

    self.loadedAnimations.equip.Priority = Enum.AnimationPriority.Action4
    self.loadedAnimations.equip:Play(0)
    self.loadedAnimations.equipCam:Play(0)
    self.janitor:AddPromise(Promise.delay(self.loadedAnimations.equip.Length - 0.5)):andThen(function()
        self.loadedAnimations.equip.Priority = Enum.AnimationPriority.Idle
        self.equipped = true
    end)

    local s = script.Parent.Sounds.Equip:Clone()
    s.Parent = self.camera
    s:Destroy()

    self.janitor:AddPromise(Promise.delay(0.03)):andThen(function()
        for _, v in pairs(vm.Prime:GetDescendants()) do 
            if v:IsA("BasePart") then 
                v.Transparency = 0 
            elseif v:IsA("Texture") then
                v.Transparency = tonumber(v.Name)
            end
        end
    end)

    self.canFire = true
    HudController:SetBullets(self.bullets, self.maxBullets)
    HudController.crosshairOffsetMultiplier = 2
    self.isReloading = false
    self.curshots = 0
    self.lastshot = tick()

    if bullets then
        self.bullets = bullets
        HudController:SetBullets(bullets, self.maxBullets)
    end

    local function handleAction(actionName, inputState)
        if self.bullets <= 0 or self.isReloading then return end
        if actionName == "PrimeShoot" then
            if inputState == Enum.UserInputState.Begin then
                self.isFiring = true
            elseif inputState == Enum.UserInputState.End then
                self.isFiring = false
            end 
        elseif actionName == "PrimeAim" then
            self:ToggleAim(inputState, vm)
        elseif actionName == "PrimeReload" then
            if inputState == Enum.UserInputState.Begin then
                self:Reload()
            end
        end
    end

    ContextActionService:BindAction("PrimeShoot", handleAction, true, Enum.UserInputType.MouseButton1)
    ContextActionService:BindAction("PrimeAim", handleAction, true, Enum.UserInputType.MouseButton2)
    ContextActionService:BindAction("PrimeReload", handleAction, true, Enum.KeyCode.R)

    ClientCaster:Initialize()

    local CastParams = RaycastParams.new()
    CastParams.IgnoreWater = true
    CastParams.FilterType = Enum.RaycastFilterType.Blacklist

    self.janitor:Add(RunService.Heartbeat:Connect(function()
        if MovementController.isSprinting and not self.isReloading then 
            self.lerpValues.sprint:set(1)
            self.lerpValues.slide:set(0)
        elseif MovementController.isSliding or MovementController.isCrouching and not self.isReloading then
            self.lerpValues.sprint:set(0)
            self.lerpValues.slide:set(1)
        else
            self.lerpValues.slide:set(0)
            self.lerpValues.sprint:set(0)
        end

        if WeaponController.isClimbing then
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
                    sound.Volume = 7
                else
                    sound.Volume = 4
                end
				sound:Play() 
                task.delay(sound.TimeLength, function()
                    sound:Destroy()
                end)   
                SoundService:PlaySound("Prime", randSound, true) 
                
                if self.camera:FindFirstChild("Tail") then self.camera.Tail:Destroy() end
                local tailSound = script.Parent.Sounds.Tail:Clone()
                tailSound.Parent = self.camera
                tailSound:Play()

                local emptyClipSound = script.Parent.Sounds.EmptyClip:Clone()
                emptyClipSound.Parent = self.camera
                emptyClipSound.Volume = (30/self.bullets)/2
                emptyClipSound:Destroy()

                if self.loadedAnimations.equip.IsPlaying then self.loadedAnimations.equip:Stop(0) end

                if not self.isAiming then
                    self.loadedAnimations.Shoot:Play()
                    self.loaded3PAnimations.shoot:Play()
                else
                    self.loadedAnimations.scopedShoot:Play()
                    self.loaded3PAnimations.scopedShoot:Play()
                end

                if not self.scopedIn then
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
                    direction = self.camera.CFrame.LookVector
                    ClientCaster:Fire(vm.Prime.Handle.MuzzleBack.WorldPosition, direction, character, curRecoil[6])
                else
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
                    ClientCaster:Fire(vm.Prime.Handle.MuzzleBack.WorldPosition, direction, character, curRecoil[6])
                end
                
                vm.Prime.Handle.MuzzleFlash1.Flash:Emit(1)
                vm.Prime.Handle.MuzzleFlash2.Flash:Emit(1)

                self.janitor:AddPromise(Promise.delay(.06)):andThen(function()
                    vm.Prime.Handle.Muzzle.PointLight.Enabled = false
                end)         

                HudController:ExpandCrosshair()
                self.bullets = self.bullets - 1
                HudController:SetBullets(self.bullets, self.maxBullets)

                pcall(function()MovementController.sprintJanitor:Cleanup()end)
            end
        else
            self:Reload()
        end
    end))

    self.janitor:Add(function()
        self.loadedAnimations = {}
        HumanoidAnimatorUtils.stopAnimationsList(self.loaded3PAnimations,0)
        HumanoidAnimatorUtils.stopAnimations(vm.AnimationController, 0)
        ContextActionService:UnbindAction("PrimeShoot")
        ContextActionService:UnbindAction("PrimeAim")
        ContextActionService:UnbindAction("PrimeReload")
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
    SoundService = Knit.GetService("SoundService")
end)


return module