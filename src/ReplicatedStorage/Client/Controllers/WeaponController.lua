local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)
local Tween = require(Packages.TweenPromise)

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

function WeaponController:ShowDamageNumber(hum, num, braindamage)
    if not hum.Parent:FindFirstChild("HumanoidRootPart") then return end
    
    local dmgNum
    local highest = 0
    for _, v in pairs(hum.Parent.HumanoidRootPart:GetChildren()) do
        if v.Name == "DamageNumber" then
            if v:GetAttribute("t") > highest then highest = v:GetAttribute("t") end
        end
    end

    local can = hum.Parent.HumanoidRootPart:FindFirstChild("DamageNumber") and tick() - highest < 0.31    

    if can then
        dmgNum = hum.Parent.HumanoidRootPart.DamageNumber
        dmgNum.TextLabel.Text = tonumber(dmgNum.TextLabel.Text) + num
    else
        dmgNum = ReplicatedStorage.Assets.DamageNumber:Clone()
        dmgNum.Parent = hum.Parent.HumanoidRootPart
        dmgNum.TextLabel.Text = num
        dmgNum.StudsOffset = Vector3.new(math.random(-1.5,1.5),5,0)
    end
    if braindamage then
        dmgNum.TextLabel.TextColor3 = Color3.fromRGB(255,255,0)
    else
        dmgNum.TextLabel.TextColor3 = Color3.fromRGB(255,255,255)
    end
    
    dmgNum:SetAttribute("t", tick())

    task.delay(0.3, function()
        if tick() - dmgNum:GetAttribute("t") > 0.29 then
            task.delay(0.2, function()
                if dmgNum then dmgNum:Destroy() end
            end)
            if not dmgNum:FindFirstChild("TextLabel") then return end
            Tween(dmgNum.TextLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {TextTransparency = 1})
            Tween(dmgNum.TextLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = UDim2.fromScale(0.5, 0.3)})
            Tween(dmgNum.TextLabel.UIStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Transparency = 1})
        end
    end)
end

function WeaponController:Climb(val)
    if not self.currentViewmodel or not self.currentViewmodel.AnimationController or not self.currentModule then return end
    self.isClimbing = true
    self.currentModule.lerpValues.climb:set(1)
    self.currentModule.equipped = false
    local climbAnim
    if val < -1 then
        climbAnim = self.loadedAnimations.highclimb
    elseif val > 0 then
        climbAnim = self.loadedAnimations.lowclimb
    else
        climbAnim = self.loadedAnimations.midclimb
    end
    climbAnim:Play(0)
    pcall(function()self.currentModule.loadedAnimations.hide:Play(0)end)
    task.delay(self.loadedAnimations.midclimb.Length - 0.05, function()
        climbAnim:Stop(0)
        self.currentModule.lerpValues.climb:set(0)
        pcall(function()self.currentModule.loadedAnimations.hide:Stop(0)end)
        self.currentModule.loadedAnimations.equip:Play(0)
        task.delay(self.currentModule.loadedAnimations.equip.Length - 0.35, function()
            self.isClimbing = false
            self.currentModule.equipped = true
        end)
    end)
end

function WeaponController:Damage(humanoid, damage)
    WeaponService:Damage(humanoid, damage)
    if humanoid.Parent.Name == "low" then
        game.Lighting.GlobalShadows = false
    elseif humanoid.Parent.Name == "high" then
        game.Lighting.GlobalShadows = true
    end
end

function WeaponController:KnitStart()
    local weaponModule = require(ReplicatedStorage.Weapons.Prime.MainModule)
    local weaponModule2 = require(ReplicatedStorage.Weapons.Outlaw.MainModule)
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
        self.loadedAnimations.highclimb.Priority = Enum.AnimationPriority.Action3
        self.loadedAnimations.lowclimb.Priority = Enum.AnimationPriority.Action3 
        self.loadedAnimations.midclimb.Priority = Enum.AnimationPriority.Action3
        self.loadedAnimations.slideCamera = ac:LoadAnimation(ReplicatedStorage.Assets.Animations.SlideCamera)
        self.loadedAnimations.sprintCamera = ac:LoadAnimation(ReplicatedStorage.Assets.Animations.SprintCamera)

        repeat
            task.wait()
        until character:FindFirstChild("HumanoidRootPart") and viewmodel:FindFirstChild("HumanoidRootPart")
        
        weaponModule:Equip(character, viewmodel, weaponModule.maxBullets)

        weaponModule.bullets = weaponModule.maxBullets
        weaponModule2.bullets = weaponModule2.maxBullets
        local weapon1Equipped = true
        local weapon2Equipped = false
        local equipDebounce = false
        
        local function handleAction(actionName, inputState)
            local can = not equipDebounce and (hum.Health > 0 and character.HumanoidRootPart and viewmodel.HumanoidRootPart)
            if not can then return end
            if actionName == "Equip" and not weapon1Equipped and weapon2Equipped then
                if inputState == Enum.UserInputState.Begin then
                    equipDebounce = true
                    weaponModule2:Unequip()
                    weaponModule:Equip(character, viewmodel)
                    self.currentModule = weaponModule
                    weapon1Equipped = true
                    weapon2Equipped = false
                    task.delay(0.2, function()
                        equipDebounce = false
                    end)
                end
            elseif actionName == "Equip2" and not weapon2Equipped and weapon1Equipped then
                if inputState == Enum.UserInputState.Begin then
                    equipDebounce = true
                    weaponModule:Unequip()
                    weaponModule2:Equip(character, viewmodel)
                    self.currentModule = weaponModule2
                    weapon2Equipped = true
                    weapon1Equipped = false
                    task.delay(0.2, function()
                        equipDebounce = false
                    end)
                end
            end
        end
        
        ContextActionService:BindAction("Equip", handleAction, true, Enum.KeyCode.One)
        ContextActionService:BindAction("Equip2", handleAction, true, Enum.KeyCode.Two)

        HudController:SetHealth(100)
        hum.HealthChanged:Connect(function(h)
            HudController:SetHealth(math.floor(h))
        end)

        self._janitor:Add(hum.Died:Connect(function()
            local s = ReplicatedStorage.Assets.Sounds.Death:Clone()
            s.Parent = workspace.CurrentCamera
            s:Destroy()
            self.currentModule:Unequip(character)
            self._janitor:Cleanup()
        end))
    end)

    WeaponService.PlaySignal:Connect(function(character, weapon, name, playOnRemove)
        local can = character and character.HumanoidRootPart
        if not can then return end
        local sound
        if weapon ~= nil then 
            sound = ReplicatedStorage.Weapons[weapon].Sounds:FindFirstChild(name)
        else
            sound = ReplicatedStorage.Assets.Sounds:FindFirstChild(name)
        end
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

    WeaponService.OnDamagedSignal:Connect(function(p)
        if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            HudController:ShowDamageDir(p.Character.Name, p.Character.HumanoidRootPart.Position)
        end
    end)

    local casters = {
        ["Prime"] = require(ReplicatedStorage.Weapons.Prime.ReplicatedCaster),
        ["Outlaw"] = require(ReplicatedStorage.Weapons.Outlaw.ReplicatedCaster)
    }

    WeaponService.FireSignal:Connect(function(character, weapon, direction)
        casters[weapon]:Fire(character, direction)
    end)

    WeaponService.CreateBulletHoleSignal:Connect(function(r)
        self:CreateBulletHole(r)
    end)

    WeaponService.CreateImpactEffectSignal:Connect(function(r, h)
        self:CreateImpactEffect(r, h)
    end)
end
return WeaponController