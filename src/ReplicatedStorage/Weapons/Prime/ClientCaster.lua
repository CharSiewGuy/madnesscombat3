local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Janitor = require(Packages.Janitor)
local Knit = require(Packages.Knit)
local FastCast = require(Packages.FastCastRedux)

local module = {}
module.janitor = Janitor.new()

local HudController
local WeaponController
local WeaponService

Knit.OnStart():andThen(function()
    HudController = Knit.GetController("HudController")
    WeaponController = Knit.GetController("WeaponController")
    WeaponService = Knit.GetService("WeaponService")
end)

function module:Fire(origin, direction, repCharacter, spreadMagnitude)	
    local CastParams = RaycastParams.new()
    CastParams.IgnoreWater = true
    CastParams.FilterType = Enum.RaycastFilterType.Blacklist
    CastParams.FilterDescendantsInstances = {repCharacter, workspace.CurrentCamera}

    local CastBehavior = FastCast.newBehavior()
    CastBehavior.RaycastParams = CastParams
    CastBehavior.MaxDistance = 1200
    CastBehavior.HighFidelityBehavior = FastCast.HighFidelityBehavior.Default
    CastBehavior.Acceleration = Vector3.new(0, -200, 0)
    CastBehavior.AutoIgnoreContainer = true

    local directionCF = CFrame.new(Vector3.new(), direction)
    local spreadDirection = CFrame.fromOrientation(0, 0, math.random(0, math.pi * 2))
    local spreadAngle = CFrame.fromOrientation(math.rad(math.random(0, spreadMagnitude)), 0, 0)
    local finalDirection = (directionCF * spreadDirection * spreadAngle).LookVector
    self.mainCaster:Fire(workspace.CurrentCamera.CFrame.Position, finalDirection, 1200, CastBehavior)
    CastBehavior.CosmeticBulletContainer = workspace.Projectiles
    CastBehavior.CosmeticBulletTemplate = script.Parent.BulletPart
    self.cosmeticCaster:Fire(origin, finalDirection, 800, CastBehavior)
    WeaponService:CastProjectile("Prime", finalDirection)
end

function module:Initialize()
    self.mainCaster = FastCast.new()
    self.cosmeticCaster = FastCast.new()

    local function lengthChanged(_, lastPoint, direction, length, _, bullet)
        if bullet then
            self.janitor:Add(bullet)
            local bulletLength = bullet.Size.Z/2
            local offset = CFrame.new(0, 0, -(length - bulletLength))
            bullet.CFrame = CFrame.lookAt(lastPoint, lastPoint + direction):ToWorldSpace(offset)
        end
    end
    
    self.janitor:Add(self.cosmeticCaster.LengthChanged:Connect(lengthChanged), "Disconnect")
    
    local function rayHit(cast, result, velocity, bullet)
        local hitPart = result.Instance
    
        local humanoid = hitPart:FindFirstChild("Humanoid")
        local curParent = hitPart
        local headshot = false	
    
        repeat
            if curParent.Name == "Head" then
                headshot = true
            end
            
            curParent = curParent.Parent
            humanoid = curParent:FindFirstChild("Humanoid")
        until curParent == workspace or humanoid
        
        local resultData = {
            ["Position"] = result.Position, 
            ["Normal"] = result.Normal,
            ["Instance"] = {
                ["Material"] = result.Instance.Material,
                ["Transparency"] = result.Instance.Transparency or 0 
            }
        }
    
        if humanoid and humanoid.Parent ~= Knit.Player.Character then
            local distance = (Knit.Player.Character.HumanoidRootPart.Position - result.Position).Magnitude
            local damage = 15
            if headshot then
                if distance < 30 then
                    damage = 40
                elseif distance < 50 then
                    damage = 35
                else
                    damage = 30
                end
            else
                if distance < 30 then
                    damage = 24
                elseif distance < 50 then
                    damage = 20
                else
                    damage = 17
                end            
            end

            if humanoid.Health > 0 then
                WeaponController:Damage(humanoid, damage, headshot)
                
                local sound
                if headshot then
                    sound = ReplicatedStorage.Assets.Sounds.Headshot:Clone()
                else
                    sound = ReplicatedStorage.Assets.Sounds["Hit" .. math.random(1,3)]:Clone()
                end
                sound.Parent = workspace.CurrentCamera
                sound:Destroy()
            
                HudController:ShowHitmarker()
                WeaponController:CreateImpactEffect(result, true)
                WeaponController:ShowDamageNumber(humanoid, damage, headshot)
                WeaponService:CreateImpactEffect(resultData, true)
            end
        else
            WeaponController:CreateImpactEffect(result, false)
            WeaponService:CreateImpactEffect(resultData, false)
            WeaponController:CreateBulletHole(result)
            WeaponService:CreateBulletHole(resultData)
        end
    end
    
    self.janitor:Add(self.mainCaster.RayHit:Connect(rayHit), "Disconnect")
    
    local function castTerminating(activeCast)
        local bullet = activeCast.RayInfo.CosmeticBulletObject
        bullet:Destroy()
    end
    
    self.janitor:Add(self.cosmeticCaster.CastTerminating:Connect(castTerminating), "Disconnect")
end

function module:Deinitialize()
    self.janitor:Cleanup()
end

return module