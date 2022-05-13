local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Janitor = require(Packages.Janitor)
local Knit = require(Packages.Knit)
local FastCast = require(Packages.FastCastRedux)

local module = {}
module.janitor = Janitor.new()

local HudController
local WeaponService

Knit.OnStart():andThen(function()
    HudController = Knit.GetController("HudController")
    WeaponService = Knit.GetService("WeaponService")
end)

function module:Fire(origin, direction, repCharacter, spreadMagnitude)	
    local CastParams = RaycastParams.new()
    CastParams.IgnoreWater = true
    CastParams.FilterType = Enum.RaycastFilterType.Blacklist
    CastParams.FilterDescendantsInstances = {repCharacter, workspace.CurrentCamera}

    local CastBehavior = FastCast.newBehavior()
    CastBehavior.RaycastParams = CastParams
    CastBehavior.MaxDistance = 500
    CastBehavior.HighFidelityBehavior = FastCast.HighFidelityBehavior.Default
    CastBehavior.CosmeticBulletContainer = workspace.Projectiles
    CastBehavior.CosmeticBulletTemplate = script.Parent.BulletPart
    CastBehavior.Acceleration = Vector3.new(0, -5, 0)
    CastBehavior.AutoIgnoreContainer = true

    local directionCF = CFrame.new(Vector3.new(), direction)
    local spreadDirection = CFrame.fromOrientation(0, 0, math.random(0, math.pi * 2))
    local spreadAngle = CFrame.fromOrientation(math.rad(math.random(1, spreadMagnitude)), 0, 0)
    local finalDirection = (directionCF * spreadDirection * spreadAngle).LookVector
    self.mainCaster:Fire(origin, finalDirection, 500, CastBehavior)
end

function module:Initialize()
    self.mainCaster = FastCast.new()

    local function lengthChanged(_, lastPoint, direction, length, _, bullet)
        if bullet then
            local bulletLength = bullet.Size.Z/2
            local offset = CFrame.new(0, 0, -(length - bulletLength))
            bullet.CFrame = CFrame.lookAt(lastPoint, lastPoint + direction):ToWorldSpace(offset)
        end
    end
    
    self.janitor:Add(self.mainCaster.LengthChanged:Connect(lengthChanged), "Disconnect")
    
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
    
        if humanoid and humanoid.Parent ~= Knit.Player.Character then
            local distance = (Knit.Player.Character.HumanoidRootPart.Position - result.Position).Magnitude
            if headshot then
                if distance < 30 then
                    WeaponService:Damage(humanoid, 45)
                elseif distance < 50 then
                    WeaponService:Damage(humanoid, 38)
                else
                    WeaponService:Damage(humanoid, 30)
                end
            else
                if distance < 30 then
                    WeaponService:Damage(humanoid, 20)
                elseif distance < 50 then
                    WeaponService:Damage(humanoid, 18)
                else
                    WeaponService:Damage(humanoid, 15)
                end            
            end

            local sound
            sound = ReplicatedStorage.Assets.Sounds.Hit:Clone()
            sound.Parent = workspace.CurrentCamera
            sound:Destroy()
    
            HudController:ShowHitmarker(headshot)
        end
    end
    
    self.janitor:Add(self.mainCaster.RayHit:Connect(rayHit), "Disconnect")
    
    local function castTerminating(activeCast)
        local bullet = activeCast.RayInfo.CosmeticBulletObject
        bullet:Destroy()
    end
    
    self.janitor:Add(self.mainCaster.CastTerminating:Connect(castTerminating), "Disconnect")
end

function module:Deinitialize()
    self.janitor:Cleanup()
end

return module