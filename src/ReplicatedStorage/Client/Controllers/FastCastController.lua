local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local FastCast = require(Packages.FastCastRedux)

local FastCastController = Knit.CreateController { Name = "FastCastController" }

local mainCaster

function rayUpdated(_, lastPoint, direction, length, _, bullet)
	if bullet then
        local bulletLength = bullet.Size.Z/2
        local offset = CFrame.new(0, 0, -(length - bulletLength))
        bullet.CFrame = CFrame.lookAt(lastPoint, lastPoint + direction):ToWorldSpace(offset)
    end
end

function rayHit(cast, result, velocity, bullet)
    local hitEffect = ReplicatedStorage.Assets.Particles.ElectricHit:Clone()
    hitEffect.Parent = workspace
    hitEffect.Position = result.Position
    for _, v in pairs(hitEffect:GetChildren()) do
        v:Emit(tonumber(v.Name))
    end
end

function cleanUpBullet(activeCast)
    local bullet = activeCast.RayInfo.CosmeticBulletObject
    bullet:Destroy()
end

local FastCastService

function FastCastController:KnitInit()
    FastCastService = Knit.GetService("FastCastService")
end

function FastCastController:KnitStart()
    mainCaster = FastCast.new()
    mainCaster.RayHit:Connect(rayHit)
    mainCaster.LengthChanged:Connect(rayUpdated)
    mainCaster.CastTerminating:Connect(cleanUpBullet)
end

function FastCastController:Fire(origin, direction, isReplicated, repCharacter)	
	local rawOrigin	= origin
	local rawDirection = direction
			
	if not isReplicated then 
        FastCastService:Fire(rawOrigin, rawDirection)
	end

    local CastParams = RaycastParams.new()
    CastParams.IgnoreWater = true
    CastParams.FilterType = Enum.RaycastFilterType.Blacklist
    CastParams.FilterDescendantsInstances = {repCharacter, workspace.CurrentCamera}

    local CastBehavior = FastCast.newBehavior()
    CastBehavior.RaycastParams = CastParams
    CastBehavior.MaxDistance = 300
    CastBehavior.HighFidelityBehavior = FastCast.HighFidelityBehavior.Default
    CastBehavior.CosmeticBulletContainer = workspace.Projectiles
    CastBehavior.CosmeticBulletTemplate = ReplicatedStorage.Assets.Particles.Bullet
    CastBehavior.Acceleration = Vector3.new(0, -3, 0)
    CastBehavior.AutoIgnoreContainer = true

    local directionCF = CFrame.new(Vector3.new(), direction)
    local spreadDirection = CFrame.fromOrientation(0, 0, math.random(0, math.pi * 2))
    local spreadAngle = CFrame.fromOrientation(math.rad(math.random(1, 2)), 0, 0)
    local finalDirection = (directionCF * spreadDirection * spreadAngle).LookVector
	mainCaster:Fire(origin, finalDirection, 100, CastBehavior)					
end 

return FastCastController