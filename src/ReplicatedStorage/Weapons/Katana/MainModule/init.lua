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
local RaycastHitbox = require(Packages.RaycastHitboxV4)

local Modules = ReplicatedStorage.Modules
local Spring = require(Modules.Spring)
local Spring2 = require(Modules.Spring2)
local SmoothValue = require(Modules.SmoothValue)

local PvpService
local WeaponService
local SoundService

local WeaponController
local HudController
local MovementController

local UtilModule = require(script.Util)

module.janitor = Janitor.new()
module.camera = workspace.CurrentCamera
module.loadedAnimations = {}
module.loaded3PAnimations = {}
module.springs = {}
module.lerpValues = {}
module.lerpValues.sprint = SmoothValue:create(0, 0, 12)
module.lerpValues.slide = SmoothValue:create(0, 0, 12)
module.lerpValues.climb = SmoothValue:create(0, 0, 16)
module.charspeed = 0
module.running = false
module.OldCamCF = nil

function module:SetupAnimations(character, vm)
    module.lerpValues.attack = SmoothValue:create(1, 1, 8)

    self.springs.sway = Spring.create()

    self.springs.jump = Spring.create(1, 10, 0, 1.8)
    self.springs.speed = Spring2.spring.new()
    self.springs.speed.s = 16
    self.springs.velocity = Spring2.spring.new(Vector3.new())
    self.springs.velocity.s = 16
    self.springs.velocity.t = Vector3.new()
    self.springs.velocity.p = Vector3.new()

    self.janitor:Add(character.Humanoid.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Jumping then
            self.springs.jump:shove(Vector3.new(0, 0.4))
            task.delay(0.2, function()
                self.springs.jump:shove(Vector3.new(0, -0.4))
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
        self.springs.sway:shove(Vector3.new(mouseDelta.X/150,mouseDelta.Y/150))
        local sway = self.springs.sway:update(dt)

        local jump = self.springs.jump:update(dt)
        HudController.ScreenGui.Frame.Position = UDim2.fromScale(0.5, 0.5 + math.abs(jump.y/8)) 

        vm.HumanoidRootPart.CFrame *= CFrame.Angles(jump.y,-sway.x,sway.y)

        local idleOffset = CFrame.new(0.7,0,0.5) * CFrame.Angles(0.1,0,-0.5)
        local sprintOffset = idleOffset:Lerp(CFrame.new(0.3,0,-0.8) * CFrame.Angles(-0.4,0,0), self.lerpValues.sprint:update(dt))
        local slideOffset = sprintOffset:Lerp(CFrame.new(0.5,-1,0) * CFrame.Angles(0,0,-1), self.lerpValues.slide:update(dt))
        local climbOffset = slideOffset:Lerp(CFrame.new(0.3,0.4,0) * CFrame.Angles(-0.3,0,0), self.lerpValues.climb:update(dt))
        local attackOffset = climbOffset:Lerp(CFrame.new(0,0,0.2), self.lerpValues.attack:update(dt))
        local finalOffset = attackOffset

        vm.HumanoidRootPart.CFrame *= finalOffset

        local RelativeVelocity
        if MovementController.isSliding then
            RelativeVelocity = CFrame.new().VectorToObjectSpace(character.HumanoidRootPart.CFrame, character.HumanoidRootPart.Velocity/2)
        else
            RelativeVelocity = CFrame.new().VectorToObjectSpace(character.HumanoidRootPart.CFrame, character.HumanoidRootPart.Velocity/1.5)
        end
        if MovementController.isSprinting then
            RelativeVelocity = UtilModule:ClampMagnitude(RelativeVelocity, 24)
            self.springs.speed.t = (Vector3.new(1.2, 0, 1.2) * RelativeVelocity).Magnitude
        else
            RelativeVelocity = UtilModule:ClampMagnitude(RelativeVelocity, 16)
            self.springs.speed.t = (Vector3.new(1, 0, 1) * RelativeVelocity).Magnitude
        end
		self.springs.velocity.t = RelativeVelocity
		UtilModule.speed = self.springs.speed.p
		UtilModule.distance = UtilModule.distance + dt * self.springs.speed.p
		UtilModule.velocity = self.springs.velocity.p

        if character.Humanoid.WalkSpeed > 0 then
            if MovementController.isSprinting then
                vm.HumanoidRootPart.CFrame *= UtilModule:viewmodelBob(0.4, 0.8, character.Humanoid.WalkSpeed)
            else
                vm.HumanoidRootPart.CFrame *= UtilModule:viewmodelBob(0.6, 1.2, character.Humanoid.WalkSpeed)
            end
        end
        vm.HumanoidRootPart.CFrame *= UtilModule:ViewmodelBreath(0)

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
    self.loadedAnimations.hide = vm.AnimationController:LoadAnimation(script.Parent.Animations.Hide)
    self.loadedAnimations.equip = vm.AnimationController:LoadAnimation(script.Parent.Animations.Equip)
    self.loadedAnimations.equipCam = vm.AnimationController:LoadAnimation(script.Parent.Animations.EquipCam)
    self.loadedAnimations.attack1 = vm.AnimationController:LoadAnimation(script.Parent.Animations.Attack1)
    self.loadedAnimations.attack2 = vm.AnimationController:LoadAnimation(script.Parent.Animations.Attack2)
    self.loadedAnimations.attack3 = vm.AnimationController:LoadAnimation(script.Parent.Animations.Attack3)
    self.loadedAnimations.attack4 = vm.AnimationController:LoadAnimation(script.Parent.Animations.Attack4)

    local animator = HumanoidAnimatorUtils.getOrCreateAnimator(character.Humanoid)
    self.loaded3PAnimations.Idle = animator:LoadAnimation(script.Parent["3PAnimations"].Idle)

    MovementController.loadedAnimations.sprint = animator:LoadAnimation(script.Parent["3PAnimations"].Sprint)

    self.janitor:Add(function()
        for _, v in pairs(self.loaded3PAnimations) do
            v:Stop(0)
        end
    end)
end

function module:Equip(character, vm)
    local can = character.Humanoid and character.Humanoid.Health > 0 and character.HumanoidRootPart and vm.HumanoidRootPart
    if not can then return end

    self.equipped = false
    WeaponController.baseFov:set(90)
    MovementController.normalSpeed = 18
    MovementController.sprintSpeed = 26
    if MovementController.isSprinting then 
        MovementController.value:set(MovementController.sprintSpeed)
    else
        MovementController.value:set(MovementController.normalSpeed)
    end

    local Katana = script.Parent.Katana:Clone()
    for _, v in pairs(Katana:GetDescendants()) do if v:IsA("BasePart") or v:IsA("Texture") then v.Transparency = 1 end end
    Katana.Parent = vm
    self.janitor:Add(Katana)

    self.killstreak = 0

    local Params = RaycastParams.new()
    Params.FilterDescendantsInstances = {character}
    Params.FilterType = Enum.RaycastFilterType.Blacklist
    local hitbox = RaycastHitbox.new(Katana)
    hitbox.RaycastParams = Params
    hitbox.OnHit:Connect(function(hit, hitHum)
        hitbox:HitStop()
        if hitHum.Health > 0 then
            if hitHum.Health - 55 <= 0 then
                self.killstreak += 1
                if self.killstreak > 3 then
                    MovementController.normalSpeed = 20
                    MovementController.sprintSpeed = 34
                    PvpService:SetMaxHealth(160)
                elseif self.killstreak > 2 then
                    MovementController.normalSpeed = 20
                    MovementController.sprintSpeed = 32
                    PvpService:SetMaxHealth(145)
                elseif self.killstreak > 1 then
                    MovementController.normalSpeed = 19
                    MovementController.sprintSpeed = 30
                    PvpService:SetMaxHealth(130)
                else
                    MovementController.normalSpeed = 18
                    MovementController.sprintSpeed = 28
                    PvpService:SetMaxHealth(115)
                end
                if MovementController.isSprinting then MovementController.value:set(MovementController.sprintSpeed) else MovementController.value:set(MovementController.normalSpeed) end
            end

            WeaponController:Damage(hitHum, 55, false)
            
            local sound
            sound = ReplicatedStorage.Assets.Sounds["Hit" .. math.random(1,3)]:Clone()
            sound.Parent = workspace.CurrentCamera
            sound:Destroy()
            
            local resultData = {["Position"] = hit.Position, ["Normal"] = Vector3.new(), ["Instance"] = {["Transparency"] = 0}}

            HudController:ShowHitmarker()
            WeaponController:CreateImpactEffect(resultData, true, hit.CFrame)
            WeaponController:ShowDamageNumber(hitHum, 55, false)
            WeaponService:CreateImpactEffect(resultData, true, hit.CFrame)

            local randSound = "Hit" .. math.random(1, 2)
            sound = script.Parent.Sounds[randSound]:Clone()
            sound.Parent = self.camera
            sound:Destroy()
            SoundService:PlaySound("Katana", randSound, true)
        end
    end)

    local vmRoot = vm:WaitForChild("HumanoidRootPart")
    local weaponMotor6D = script.Parent.Handle:Clone()
    weaponMotor6D.Part0 = vmRoot
    weaponMotor6D.Part1 = Katana.Handle
    weaponMotor6D.Parent = vmRoot
    self.janitor:Add(weaponMotor6D)

    self:SetupAnimations(character, vm)
    self.loadedAnimations.Idle:Play(0)
    self.loaded3PAnimations.Idle:Play(0)
    
    self.loadedAnimations.equip:Play(0)
    self.loadedAnimations.equipCam:Play(0)
    self.janitor:AddPromise(Promise.delay(self.loadedAnimations.equip.Length - 0.6)):andThen(function()
        self.loadedAnimations.equip.Priority = Enum.AnimationPriority.Idle
        self.equipped = true
        self.lerpValues.attack:set(0)
    end)

    local s = script.Parent.Sounds.Equip:Clone()
    s.Parent = self.camera
    s:Destroy()

    for _, v in pairs(vm.Katana:GetDescendants()) do 
        if v:IsA("BasePart") then 
            v.Transparency = 0 
        elseif v:IsA("Texture") then
            v.Transparency = tonumber(v.Name)
        end
    end

    HudController:SetBullets(0, 0)
    HudController.crosshairOffsetMultiplier = 1

    self.isAttacking = false
    self.combo = 1
    self.lastAttacked = 0

    local function handleAction(actionName, inputState)
        if actionName == "KatanaAttack" then
            if inputState == Enum.UserInputState.Begin then
                if self.loadedAnimations.equip.IsPlaying then self.loadedAnimations.equip:Stop(0) end
                if not self.isAttacking then
                    self.isAttacking = true
                    self.lerpValues.attack.speed = 100
                    self.lerpValues.attack:set(1)
                    MovementController.canClimb = false

                    local attackAnim = self.loadedAnimations["attack" .. self.combo]
                    if self.combo == 1 then
                        if self.loadedAnimations["attack2"].IsPlaying then self.loadedAnimations["attack2"]:Stop(0) end
                    else
                        if self.loadedAnimations["attack1"].IsPlaying then self.loadedAnimations["attack1"]:Stop(0) end
                    end
                    attackAnim:Play()
                    hitbox:HitStart()
                    self.janitor:AddPromise(Promise.delay(attackAnim.Length - 0.3)):andThen(function()
                        self.isAttacking = false
                        self.lerpValues.attack.speed = 8
                        self.lerpValues.attack:set(0)
                    end)

                    local sound = script.Parent.Sounds["Swing" .. self.combo]:Clone()
                    sound.Parent = self.camera
                    sound:Destroy()
                    SoundService:PlaySound("Katana", "Swing" .. self.combo, true)

                    self.combo += 1
                    if self.combo > 2 then 
                        self.combo = 1
                    end
                    self.lastAttacked = tick()
                    
                    self.janitor:AddPromise(Promise.delay(attackAnim.Length)):andThen(function()
                        if tick() - self.lastAttacked > attackAnim.Length then
                            hitbox:HitStop()
                            self.combo = 1
                            MovementController.canClimb = true
                        end
                    end)
                 end
            end 
        end
    end

    ContextActionService:BindAction("KatanaAttack", handleAction, true, Enum.UserInputType.MouseButton1)

    self.janitor:Add(RunService.Heartbeat:Connect(function()
        if MovementController.isSprinting then 
            self.lerpValues.sprint:set(1)
            self.lerpValues.slide:set(0)
        elseif MovementController.isSliding or MovementController.isCrouching then
            self.lerpValues.sprint:set(0)
            self.lerpValues.slide:set(1)
        else
            self.lerpValues.slide:set(0)
            self.lerpValues.sprint:set(0)
        end
        
        if WeaponController.isClimbing then
            self.lerpValues.climb:set(1)
        else
            self.lerpValues.climb:set(0)
        end
    end))

    self.janitor:Add(function()
        self.loadedAnimations = {}
        self.loaded3PAnimations.Idle:Stop(0)
        HumanoidAnimatorUtils.stopAnimations(vm.AnimationController, 0)
        ContextActionService:UnbindAction("KatanaAttack")
    end)
end

function module:Unequip()
    self.janitor:Cleanup()
end

Knit.OnStart():andThen(function()
    WeaponController = Knit.GetController("WeaponController")
    HudController = Knit.GetController("HudController")
    MovementController = Knit.GetController("MovementController")
    PvpService = Knit.GetService("PvpService")
    WeaponService = Knit.GetService("WeaponService")
    SoundService = Knit.GetService("SoundService")
end)


return module