local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)
local Promise = require(Packages.Promise)
local Tween = require(Packages.TweenPromise)
local HumanoidAnimatorUtils = require(Packages.HumanoidAnimatorUtils)

local Modules = ReplicatedStorage.Modules
local Spring = require(Modules.Spring)
local Spring2 = require(Modules.Spring2)
local UtilModule = require(Modules.FPSAnimUtilModule)

local WeaponService
local PvpService
local SoundService
local WeaponController
local HudController
local MovementController

local module = {}
module.janitor = Janitor.new()
module.voidshiftJanitor = Janitor.new()
module.voidshiftFXJanitor = Janitor.new()

module.character = nil
module.vm = nil
module.loadedAnims = {}
module.springs = {}
module.camera = workspace.CurrentCamera

function module:SetupAnimations(character ,vm)
    self.animJanitor = Janitor.new()

    self.springs.sway = Spring.create()

    self.springs.jump = Spring.create(1, 10, 0, 1.8)
    self.springs.speed = Spring2.spring.new()
    self.springs.speed.s = 16
    self.springs.velocity = Spring2.spring.new(Vector3.new())
    self.springs.velocity.s = 16
    self.springs.velocity.t = Vector3.new()
    self.springs.velocity.p = Vector3.new()

    self.animJanitor:Add(character.Humanoid.StateChanged:Connect(function(_, newState)
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

    
    self.animJanitor:Add(character.Humanoid.Running:Connect(function(speed)
        self.charspeed = speed
        if speed > 0.1 then
            self.running = true
        else
            self.running = false
        end
    end))

    self.animJanitor:Add(character.Humanoid.Swimming:Connect(function(speed)
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
    local vmHrp = vm:WaitForChild("HumanoidRootPart")

    local watch =  script.Parent.PocketWatch:Clone()
    watch.Parent = vm
    self.animJanitor:Add(watch)
    local watchMotor6D = script.Parent.Handle:Clone()
    watchMotor6D.Parent = vm
    watchMotor6D.Part0 = vmHrp
    watchMotor6D.Part1 = watch.Handle
    self.animJanitor:Add(watchMotor6D)

    self.animJanitor:Add(RunService.RenderStepped:Connect(function(dt)
        vmHrp.CFrame = self.camera.CFrame

        local mouseDelta = UserInputService:GetMouseDelta()
        self.springs.sway:shove(Vector3.new(mouseDelta.X/200,mouseDelta.Y/200))
        local sway = self.springs.sway:update(dt)

        local gunbobcf = CFrame.new()
        local jump = self.springs.jump:update(dt)
        HudController.ScreenGui.Frame.Position = UDim2.fromScale(0.5, 0.5 + math.abs(jump.y/5))

        local idleOffset = CFrame.new(0,0,0)
        vmHrp.CFrame *= idleOffset

        vmHrp.CFrame *= CFrame.Angles(jump.y + sway.y,-sway.x,sway.y)

        if self.running then
            gunbobcf = gunbobcf:Lerp(CFrame.new(
                0.1 * math.clamp((self.charspeed/2.5), 0, 10) * math.sin(tick() * 10),
                0.05 * math.clamp((self.charspeed/2.5), 0, 10) * math.cos(tick() * 20),
                0
                )* CFrame.Angles(
                    math.rad(3 * math.clamp((self.charspeed/2.5), 0, 10) * math.sin(tick() * 20)), 
                    math.rad(4 * math.clamp((self.charspeed/2.5), 0, 10) * math.cos(tick() * 10)), 
                    math.rad(0)
                ), 0.1)
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

        vmHrp.CFrame *= UtilModule:ViewmodelBreath(0)
        vmHrp.CFrame *= gunbobcf

        local waist = character.HumanoidRootPart.RootJoint
		waist.C0 = waistC0 * CFrame.fromEulerAnglesYXZ(math.asin(self.camera.CFrame.LookVector.y) * -0.8, 0, 0)

        WeaponService:Tilt(waist.C0)
        
        local NewCamCF = vm.FakeCamera.CFrame:ToObjectSpace(vmHrp.CFrame)
        if self.OldCamCF then
            local _, _, Z = NewCamCF:ToOrientation()
            local X, Y, _ = NewCamCF:ToObjectSpace(self.OldCamCF):ToEulerAnglesXYZ()
            self.camera.CFrame = self.camera.CFrame * CFrame.Angles(X, Y, -Z)
        end
        self.OldCamCF = NewCamCF
    end))

    self.animJanitor:Add(function()
        self.loadedAnimations = {}
        HumanoidAnimatorUtils.stopAnimations(vm.AnimationController, 0)
    end)

    self.janitor:Add(self.animJanitor)
end

function module:Init(character, vm)
    for _, v in pairs(game.Players:GetPlayers()) do
        if v ~= Knit.Player and v.Character and v.Character.Humanoid and v.Character:FindFirstChild("HumanoidRootPart") then
            if v.Character.Humanoid.Health > 0 then
                local highlight = Instance.new("Highlight")
                highlight.Parent = v.Character
                Tween(highlight, TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {FillTransparency = 1, OutlineTransparency = 1}):andThen(function()
                    highlight:Destroy()
                end)
            end 
        end
    end
    
    self.character = character
    self.vm = vm

    self.loadedAnims.voidshift = vm.AnimationController:LoadAnimation(script.Parent.Animations.Voidshift)
end

function module.canUseAbility(char, vm)
    if char:FindFirstChild("Humanoid") and char:FindFirstChild("HumanoidRootPart") and char.Humanoid.Health > 0 and vm:FindFirstChild("HumanoidRootPart") and WeaponController.currentModule ~= nil then
        return true
    else
        return false
    end
end

function module:HandleAction(actionName, inputState)
    if not self.character or not self.vm then return end
    if inputState == Enum.UserInputState.Begin then
        if actionName == "UseAbility1" then
            if not self.voidshifting and self.loadedAnims.voidshift.Length > 0 and self.canUseAbility(self.character, self.vm) then
                self.voidshifting = true

                WeaponController.currentModule:Unequip()
                WeaponController.currentModule = nil
                WeaponController.weapon1Equipped = false
                WeaponController.weapon2Equipped = false
                WeaponController.weapon3Equipped = false

                self.loadedAnims.voidshift:Play(0)
                self:SetupAnimations(self.character, self.vm)
                
                MovementController.canClimb = false
                MovementController.normalSpeed = 14
                MovementController.sprintSpeed = 20
                if MovementController.isSprinting then MovementController.value:set(MovementController.sprintSpeed) else MovementController.value:set(MovementController.normalSpeed) end

                self.janitor:AddPromise(Promise.delay(1.5)):andThen(function()
                    self.voidshiftFXJanitor:Add(script.Parent.VoidCC:Clone()).Parent = game.Lighting

                    self.vm.PocketWatch.Handle.SurfaceAppearance:Destroy()
                    self.vm.PocketWatch.Lid.SurfaceAppearance:Destroy()

                    for _, v in ipairs(self.vm.PocketWatch:GetChildren()) do
                        if v:IsA("MeshPart") and v.Name ~= "Meshes/Cube.001 (2)" and v.Name ~= "Pointer1" then
                            v:SetAttribute("Material", v.Material.Name)
                            v.Material = Enum.Material.ForceField
                            v.TextureID = self.vm.PocketWatch.Forcefield.Value
                        end
                    end

                    self.voidshiftFXJanitor:Add(function()
                        if not self.vm then return end
                        if not self.vm:FindFirstChild("PocketWatch") then return end
                        local sAppearance = self.vm.PocketWatch.SurfaceAppearance
                        sAppearance:Clone().Parent = self.vm.PocketWatch.Handle
                        sAppearance:Clone().Parent = self.vm.PocketWatch.Lid

                        for _, v in ipairs(self.vm.PocketWatch:GetChildren()) do
                            if v:IsA("MeshPart") and v.Name ~= "Meshes/Cube.001 (2)" and v.Name ~= "Pointer1" then
                                v.Material = Enum.Material[v:GetAttribute("Material")]
                                v.TextureID = ""
                            end
                        end
                    end)

                    local particles1 = self.voidshiftFXJanitor:Add(script.Parent.Specs:Clone())
                    local particles2 = self.voidshiftFXJanitor:Add(script.Parent.Specs2:Clone())
                    particles1.Parent = self.character.HumanoidRootPart.RootAttachment
                    particles2.Parent = self.character.HumanoidRootPart.RootAttachment

                    self.janitor:Add(function()
                        self.voidshiftFXJanitor:Cleanup()
                    end)

                    MovementController.normalSpeed = 19
                    MovementController.sprintSpeed = 30
                    if MovementController.isSprinting then MovementController.value:set(MovementController.sprintSpeed) else MovementController.value:set(MovementController.normalSpeed) end
                end)

                self.janitor:AddPromise(Promise.delay(5.8)):andThen(function()
                    self.voidshiftFXJanitor:Cleanup()
                end)
                   
                self.janitor:AddPromise(Promise.delay(self.loadedAnims.voidshift.Length)):andThen(function()
                    self.animJanitor:Cleanup()
                    self.voidshiftJanitor:Cleanup()

                    WeaponController.weaponModule:Equip(self.character, self.vm)
                    WeaponController.currentModule = WeaponController.weaponModule
                    WeaponController.weapon1Equipped = true
                    WeaponController.weapon2Equipped = false
                    WeaponController.weapon3Equipped = false
                    WeaponService:SetCurWeapon("Prime")
                    HudController:SetCurWeapon("Prime")
                    PvpService:SetMaxHealth(100)
                end)

                self.voidshiftJanitor:Add(function()
                    MovementController.canClimb = true
                    self.voidshifting = false
                end)
            end
        end
    end
end

function module.HandleActionInterface(actionName, inputState)
    module:HandleAction(actionName, inputState)
end

function module:Cleanup()
    self.character = nil
    self.vm = nil
    self.voidshiftJanitor:Cleanup()
    self.janitor:Cleanup()
end

Knit.OnStart():andThen(function()
    WeaponController = Knit.GetController("WeaponController")
    HudController = Knit.GetController("HudController")
    MovementController = Knit.GetController("MovementController")
    WeaponService = Knit.GetService("WeaponService")
    PvpService = Knit.GetService("PvpService")
    SoundService = Knit.GetService("SoundService")
end)

return module