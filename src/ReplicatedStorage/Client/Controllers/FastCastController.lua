local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local FastCast = require(Packages.FastCastRedux)

local FastCastController = Knit.CreateController { Name = "FastCastController" }

local random = Random.new()

local mainCaster

function rayUpdated(_, lastPoint, direction, length, _, bullet)
	if bullet then
        local bulletLength = bullet.Size.Z/2
        local offset = CFrame.new(0, 0, -(length - bulletLength))
        bullet.CFrame = CFrame.lookAt(lastPoint, lastPoint + direction):ToWorldSpace(offset)
    end
end

function rayHit(cast, result, velocity, bullet)
	bullet:Destroy()
end

function FastCastController:KnitStart()
    mainCaster = FastCast.new()
    mainCaster.RayHit:Connect(rayHit)
    mainCaster.LengthChanged:Connect(rayUpdated)
end

function FastCastController:fire(origin, direction, isReplicated, repCharacter)	
	local rawOrigin	= origin
	local rawDirection = direction
		
	local directionalCFrame = CFrame.new(Vector3.new(), direction.LookVector)			
	direction = (directionalCFrame * CFrame.fromOrientation(0, 0, random:NextNumber(0, math.pi * 2)) * CFrame.fromOrientation(0, 0, 0)).LookVector			
	
	if not isReplicated then 

	end
	
    local CastParams = RaycastParams.new()
    CastParams.IgnoreWater = true
    CastParams.FilterType = Enum.RaycastFilterType.Blacklist
    CastParams.FilterDescendantsInstances = {repCharacter, workspace.Camera}

    local CastBehavior = FastCast.newBehavior()
    CastBehavior.RaycastParams = CastParams
    CastBehavior.MaxDistance = 5000
    CastBehavior.HighFidelityBehavior = FastCast.HighFidelityBehavior.Default
    CastBehavior.CosmeticBulletContainer = workspace.Projectiles
    CastBehavior.CosmeticBulletTemplate = ReplicatedStorage.Assets.Particles.Bullet
    CastBehavior.Acceleration = Vector3.new(0, -workspace.Gravity, 0)
    CastBehavior.AutoIgnoreContainer = true
	
	mainCaster:Fire(origin, direction, 100, CastBehavior)					
end 



return FastCastController