local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Promise = require(Packages.Promise)
local Janitor = require(Packages.Janitor)
local Tween = require(Packages.TweenPromise)
local Shake = require(Packages.Shake)

local Modules = ReplicatedStorage.Modules
local SmoothValue = require(Modules.SmoothValue)

local WeaponController = Knit.CreateController { Name = "WeaponController" }
WeaponController._janitor = Janitor.new()
WeaponController.charJanitor = Janitor.new()

local WeaponService
local PvpService 
local HudController

WeaponController.currentViewmodel = nil
WeaponController.currentModule = nil
WeaponController.loadedAnimations = {}

WeaponController.initialMouseSens = 0
WeaponController.baseFov = SmoothValue.create(90, 90, 8)

WeaponController.lastKill = 0
WeaponController.kills = 0
WeaponController.deaths = 0

function WeaponController:KnitInit()
    WeaponService = Knit.GetService("WeaponService")
    PvpService = Knit.GetService("PvpService")
    HudController = Knit.GetController("HudController")
end

function WeaponController:CreateImpactEffect(raycastResult, human)
    local can = (not raycastResult.Instance.Transparency or raycastResult.Instance.Transparency < 1)
    if not can then return end

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

    can = fxFolder and sound
    if not can then return end

    for _, v in pairs(fxFolder:GetChildren()) do
        local fxClone = v:Clone()
        fxClone.Parent = attachment
        fxClone:Emit(8)
    end

    local soundClone = sound:Clone()
    soundClone.Parent = attachment
    soundClone.PlaybackSpeed = math.random(95, 105)/100
    soundClone:Destroy()
end

function WeaponController:CreateBulletHole(raycastResult)
    local can = (not raycastResult.Instance.Transparency or raycastResult.Instance.Transparency < 1)
    if not can then return end    
    
    local part = Instance.new("Part")
    task.delay(8, function()
        part:Destroy()
    end)
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
    local climbAnim
    if val < -1 then
        climbAnim = self.loadedAnimations.highclimb
    elseif val > 0 then
        climbAnim = self.loadedAnimations.lowclimb
    else
        climbAnim = self.loadedAnimations.midclimb
    end
    climbAnim:Play()
    self._janitor:AddPromise(Promise.delay(self.loadedAnimations.midclimb.Length - 0.05)):andThen(function()
        climbAnim:Stop(0.25)
        self.isClimbing = false
    end)
end

function WeaponController:Damage(humanoid, damage, headshot)
    PvpService:Damage(humanoid, damage, headshot)
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

    local projectilesFolder = Instance.new("Folder")
    projectilesFolder.Name = "Projectiles"
    projectilesFolder.Parent = workspace

    Knit.Player.CharacterAdded:Connect(function(character)
        local hum = character:WaitForChild("Humanoid")
        self.charJanitor:Cleanup()
        self.charJanitor:Add(RunService.Heartbeat:Connect(function()
            if hum.Health <= 0 then
                weaponModule:Unequip()
                weaponModule2:Unequip()
            end
        end))

        if workspace.CurrentCamera:FindFirstChild("viewmodel") then
            workspace.CurrentCamera.viewmodel:Destroy()
        end

        local viewmodel = ReplicatedStorage.viewmodel:Clone()
        viewmodel.Parent = workspace.CurrentCamera
        self.currentViewmodel = viewmodel
        local ac = viewmodel:WaitForChild("AnimationController")
        self.loadedAnimations.highclimb = ac:LoadAnimation(ReplicatedStorage.Assets.Animations.Climb)
        self.loadedAnimations.lowclimb = ac:LoadAnimation(ReplicatedStorage.Assets.Animations.Climb)
        self.loadedAnimations.midclimb = ac:LoadAnimation(ReplicatedStorage.Assets.Animations.Climb)
        self.loadedAnimations.highclimb.Priority = Enum.AnimationPriority.Action3
        self.loadedAnimations.lowclimb.Priority = Enum.AnimationPriority.Action3 
        self.loadedAnimations.midclimb.Priority = Enum.AnimationPriority.Action3
        self.loadedAnimations.slideCamera = ac:LoadAnimation(ReplicatedStorage.Assets.Animations.SlideCamera)

        repeat
            task.wait()
        until character:FindFirstChild("HumanoidRootPart") and viewmodel:FindFirstChild("HumanoidRootPart")
        
        weaponModule:Equip(character, viewmodel, weaponModule.maxBullets)
        WeaponService:SetCurWeapon("Prime")
        HudController:SetCurWeapon("Prime")

        weaponModule.bullets = weaponModule.maxBullets
        weaponModule2.bullets = weaponModule2.maxBullets
        local weapon1Equipped = true
        local weapon2Equipped = false
        local equipDebounce = false
        
        local function handleAction(actionName, inputState)
            local can = not equipDebounce and (hum.Health > 0 and character.HumanoidRootPart and viewmodel.HumanoidRootPart)
            if not can then return end
            for _, v in pairs(workspace.Projectiles:GetChildren()) do
                if v.Name == Knit.Player.UserId then v:Destroy() end
            end
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
                    WeaponService:SetCurWeapon("Prime")
                    HudController:SetCurWeapon("Prime")
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
                    WeaponService:SetCurWeapon("Outlaw")
                    HudController:SetCurWeapon("Outlaw")
                end
            end
        end
        
        ContextActionService:BindAction("Equip", handleAction, true, Enum.KeyCode.One)
        ContextActionService:BindAction("Equip2", handleAction, true, Enum.KeyCode.Two)

        HudController:SetHealth(100)
        hum.HealthChanged:Connect(function(h)
            HudController:SetHealth(math.floor(h))
        end)

        self._janitor:Add(PvpService.ExplodeSignal:Connect(function(p)
            local dist = (character.HumanoidRootPart.Position - p).Magnitude
			if dist < 25 then
				local bv = Instance.new("BodyVelocity")
				bv.Name = "SatchelOut"
				bv.MaxForce = Vector3.new(1,0.55,1) * 20000
				local lv = CFrame.new(Vector3.new(p.X, 0, p.Z), Vector3.new(character.HumanoidRootPart.Position.X, 0, character.HumanoidRootPart.Position.Z)).LookVector
				local m = 1
				if dist < 7 then
					bv.Velocity = lv * 100 * m  + Vector3.new(0,50,0)
					PvpService:Damage(hum, 40, false)
				elseif dist < 12 then
					bv.Velocity = lv * 80 * m + Vector3.new(0,40,0)
					PvpService:Damage(hum, 37, false)
				elseif dist < 20 then
					bv.Velocity = lv * 60 * m + Vector3.new(0,30,0)
					PvpService:Damage(hum, 30, false)
				elseif dist < 25 then
					bv.Velocity = lv * 40 * m + Vector3.new(0,20,0)
					PvpService:Damage(hum, 25, false)
				end
				bv.Parent = character.HumanoidRootPart
				task.delay(1 * m, function()
					if bv then bv:Destroy() end
				end)
			end

            local a = game.ReplicatedStorage.TntAtt.Attachment:Clone()
            a.Parent = workspace.Terrain
            a.WorldPosition = p
            for _, v in pairs(a:GetChildren()) do
                v:Emit(v:GetAttribute("EmitCount"))
            end
            task.delay(5, function()
                a:Destroy()
            end)

            local shake = Shake.new()
            shake.FadeInTime = 0
            shake.FadeOutTime = 0.6
            shake.Frequency = 0.1
            shake.Amplitude = math.clamp(50/(character.HumanoidRootPart.Position - p).Magnitude - 1, 0, 5)
            shake.RotationInfluence = Vector3.new(0.15, 0.15, 0.15)

            shake:Start()
            shake:BindToRenderStep(Shake.NextRenderName(), Enum.RenderPriority.Last.Value, function(pos, rot, _)
                workspace.CurrentCamera.CFrame *= CFrame.new(pos) * CFrame.Angles(rot.X, rot.Y, rot.Z)
            end)
        end))
    

        self._janitor:Add(hum.Died:Connect(function()
            self.deaths += 1
            PvpService:SetDeaths(self.deaths)
            local s = ReplicatedStorage.Assets.Sounds.Death:Clone()
            s.Parent = workspace.CurrentCamera
            s:Destroy()
            self.currentModule:Unequip(character)
            self._janitor:Cleanup()
        end))
    end)

    PvpService.KillSignal:Connect(function(name, hs, dist)
        local sound = ReplicatedStorage.Assets.Sounds.Kill:Clone()
        sound.Parent = workspace.CurrentCamera
        HudController:PromptKill(name)
        sound:Destroy()
        HudController:AddScore(100, "kill")
        if tick() - self.lastKill <= 3 then
            HudController:AddScore(20, "multikill")
        end
        if hs then
            HudController:AddScore(25, "headshot")
        end
        if dist > 80 then
            HudController:AddScore(25, "longshot")
        end
        self.lastKill = tick()
        self.kills += 1
        PvpService:SetKills(self.kills)
    end)

    PvpService.OnDamagedSignal:Connect(function(p)
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