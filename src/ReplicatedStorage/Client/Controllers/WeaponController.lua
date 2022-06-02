local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)

local Modules = ReplicatedStorage.Modules
local SmoothValue = require(Modules.SmoothValue)

local WeaponController = Knit.CreateController { Name = "WeaponController" }
WeaponController._janitor = Janitor.new()

local WeaponService
local HudController

WeaponController.currentViewmodel = nil
WeaponController.currentModule = nil
WeaponController.loadedAnimations = {}

WeaponController.initialMouseSens = 0
WeaponController.baseFov = SmoothValue.create(90, 90, 8)

function WeaponController:KnitInit()
    WeaponService = Knit.GetService("WeaponService")
    HudController = Knit.GetController("HudController")
end

function WeaponController:CreateImpactEffect(raycastResult, human)
    local attachment = Instance.new("Attachment")
    attachment.CFrame = CFrame.new(raycastResult.Position, raycastResult.Position + raycastResult.Normal)
    attachment.Parent = workspace.Terrain
    task.delay(1, function()
        attachment:Destroy()
    end)

    local fxFolder
    local sound

    if human then
        fxFolder = ReplicatedStorage.Assets.Particles.ImpactEffects.Blood
        sound = ReplicatedStorage.Assets.Sounds.BulletImpact.Blood
    else
        fxFolder = ReplicatedStorage.Assets.Particles.ImpactEffects:FindFirstChild(raycastResult.Instance.Material.Name)
        sound = ReplicatedStorage.Assets.Sounds.BulletImpact:FindFirstChild(raycastResult.Instance.Material.Name)
    end

    local can = fxFolder and sound
    if not can then return end

    for _, v in pairs(fxFolder:GetChildren()) do
        local fxClone = v:Clone()
        fxClone.Parent = attachment
        fxClone:Emit(12)
    end

    local soundClone = sound:Clone()
    soundClone.Parent = attachment
    soundClone.PlaybackSpeed = math.random(9, 11)/10
    soundClone:Destroy()
end

function WeaponController:CreateBulletHole(raycastResult)
    local part = Instance.new("Part")
    part.Size = Vector3.new(1, 1, 0.1)
    part.Transparency = 1
    part.CastShadow = false
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CFrame = CFrame.new(raycastResult.Position, raycastResult.Position + raycastResult.Normal)
    part.Name = "bullethole"
    part.Parent = workspace.Projectiles

    local bulletHoleFolder = ReplicatedStorage.Assets.BulletHoles:FindFirstChild(raycastResult.Instance.Material.Name)
    if not bulletHoleFolder then bulletHoleFolder = ReplicatedStorage.Assets.BulletHoles.Concrete end

    local bulletHole = bulletHoleFolder:FindFirstChild(math.random(1, #bulletHoleFolder:GetChildren()))
    if not bulletHole then return end

    local fxClone = bulletHole:Clone()
    fxClone.Parent = part
    task.delay(8, function()
        part:Destroy()
    end)
end

function WeaponController:Climb(val)
    if not self.currentViewmodel or not self.currentViewmodel.AnimationController or not self.currentModule then return end
    self.currentModule.lerpValues.climb:set(1)
    pcall(function()self.currentModule.loadedAnimations.hide:Play(0)end)
    self.currentModule.equipped = false
    task.delay(0.1, function()
        self.currentModule.lerpValues.unequip:set(1)
    end)
    if val < -1 then
        self.loadedAnimations.highclimb:Play()
    elseif val > 0 then
        self.loadedAnimations.lowclimb:Play()
    else
        self.loadedAnimations.midclimb:Play()
    end
    task.delay(self.loadedAnimations.midclimb.Length, function()
        self.currentModule.lerpValues.climb:set(0)
        pcall(function()self.currentModule.loadedAnimations.hide:Stop(0)end)
        self.currentModule.lerpValues.unequip:set(0)
        self.currentModule.equipped = true
    end)
end

function WeaponController:Damage(humanoid, damage)
    WeaponService:Damage(humanoid, damage)
end

function WeaponController:KnitStart()
    local weaponModule = require(ReplicatedStorage.Weapons.Prime.MainModule)
    self.currentModule = weaponModule

    self.initialMouseSens = game:GetService("UserInputService").MouseDeltaSensitivity

    Knit.Player.CharacterAdded:Connect(function(character)
        local hum = character:WaitForChild("Humanoid")

        if workspace.CurrentCamera:FindFirstChild("viewmodel") then
            workspace.CurrentCamera.viewmodel:Destroy()
        end

        local viewmodel = ReplicatedStorage.viewmodel:Clone()
        viewmodel.Parent = workspace.CurrentCamera
        self.currentViewmodel = viewmodel
        local ac = viewmodel:WaitForChild("AnimationController")
        self.loadedAnimations.highclimb = ac:LoadAnimation(ReplicatedStorage.Assets.Animations.HighClimb)
        self.loadedAnimations.lowclimb = ac:LoadAnimation(ReplicatedStorage.Assets.Animations.LowClimb)
        self.loadedAnimations.midclimb = ac:LoadAnimation(ReplicatedStorage.Assets.Animations.MidClimb)
        self.loadedAnimations.slideCamera = ac:LoadAnimation(ReplicatedStorage.Assets.Animations.SlideCamera)
        self.loadedAnimations.sprintCamera = ac:LoadAnimation(ReplicatedStorage.Assets.Animations.SprintCamera)

        repeat
            task.wait()
        until character:FindFirstChild("HumanoidRootPart") and viewmodel:FindFirstChild("HumanoidRootPart")
        
        weaponModule:Equip(character, viewmodel)

        local equipped = true
        local equipDebounce = false
        
        local function handleAction(actionName, inputState)
            if equipDebounce then return end
            if actionName == "Equip" and not equipped then
                if inputState == Enum.UserInputState.Begin then
                    equipDebounce = true
                    weaponModule:Equip(character, viewmodel)
                    equipped = true
                    task.delay(0.2, function()
                        equipDebounce = false
                    end)
                end
            elseif actionName == "Unequip" and equipped then
                if inputState == Enum.UserInputState.Begin then
                    equipDebounce = true
                    weaponModule:Unequip(character)
                    equipped = false
                    task.delay(0.2, function()
                        equipDebounce = false
                    end)
                end
            end
        end
        
        ContextActionService:BindAction("Equip", handleAction, true, Enum.KeyCode.One)
        ContextActionService:BindAction("Unequip", handleAction, true, Enum.KeyCode.Two)

        HudController:SetHealth(100)
        hum.HealthChanged:Connect(function(h)
            HudController:SetHealth(math.floor(h))
        end)

        self._janitor:Add(hum.Died:Connect(function()
            weaponModule:Unequip(character)
            self._janitor:Cleanup()
        end))
    end)

    WeaponService.PlaySignal:Connect(function(character, name, playOnRemove)
        local can = character and character.HumanoidRootPart
        if not can then return end
        local sound = ReplicatedStorage.Weapons.Prime.Sounds:FindFirstChild(name)
        if not sound then sound = ReplicatedStorage.Assets.Sounds:FindFirstChild(name) end
        if sound then
            local soundClone = sound:Clone()
            soundClone.Parent = character.HumanoidRootPart
            if playOnRemove then
                soundClone:Destroy()
            else
                soundClone:Play()
                task.delay(soundClone.TimeLength, function()
                    if soundClone then
                        soundClone:Destroy()
                    end
                end)
            end
        end
    end)

    WeaponService.StopSignal:Connect(function(character, name)
        if not character.HumanoidRootPart then return end
        local sound = character.HumanoidRootPart:FindFirstChild(name)
        if sound then
            sound:Destroy()
        end
    end)

    WeaponService.KillSignal:Connect(function(name)
        local sound = ReplicatedStorage.Assets.Sounds.Kill:Clone()
        sound.Parent = workspace.CurrentCamera
        HudController:PromptKill(name)
        sound:Destroy()
    end)
    local casters = {
        ["Prime"] = require(ReplicatedStorage.Weapons.Prime.ReplicatedCaster)
    }

    WeaponService.FireSignal:Connect(function(character, direction)
        casters["Prime"]:Fire(character, direction)
    end)

    WeaponService.CreateBulletHoleSignal:Connect(function(r)
        self:CreateBulletHole(r)
    end)

    WeaponService.CreateImpactEffectSignal:Connect(function(r, h)
        self:CreateImpactEffect(r, h)
    end)
end
return WeaponController