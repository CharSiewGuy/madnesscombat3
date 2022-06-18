local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local FastCast = require(Packages.FastCastRedux)

local Knit = require(Packages.Knit)
local WeaponController
Knit.OnStart():andThen(function()
    WeaponController = Knit.GetController("WeaponController")
end)

local module = {}

module.mainCaster = FastCast.new()

local function lengthChanged(_, lastPoint, direction, length, _, bullet)
    if bullet then
        local bulletLength = bullet.Size.Z/2
        local offset = CFrame.new(0, 0, -(length - bulletLength))
        bullet.CFrame = CFrame.lookAt(lastPoint, lastPoint + direction):ToWorldSpace(offset)
    end
end

module.mainCaster.LengthChanged:Connect(lengthChanged)

local function castTerminating(activeCast)
    local bullet = activeCast.RayInfo.CosmeticBulletObject
    bullet:Destroy()
end

module.mainCaster.CastTerminating:Connect(castTerminating)

function module:Fire(character, direction)
    local can = character.Outlaw and character.Outlaw.Handle and character.Outlaw.Handle.MuzzleBack
    if not can then return end
    
    local CastParams = RaycastParams.new()
    CastParams.IgnoreWater = true
    CastParams.FilterType = Enum.RaycastFilterType.Blacklist
    CastParams.FilterDescendantsInstances = {character, workspace.CurrentCamera}

    local CastBehavior = FastCast.newBehavior()
    CastBehavior.RaycastParams = CastParams
    CastBehavior.MaxDistance = 800
    CastBehavior.HighFidelityBehavior = FastCast.HighFidelityBehavior.Default
    CastBehavior.CosmeticBulletContainer = workspace.Projectiles
    CastBehavior.CosmeticBulletTemplate = script.Parent.BulletPart
    CastBehavior.Acceleration = Vector3.new(0, -20, 0)
    CastBehavior.AutoIgnoreContainer = true

    if not character.Outlaw.Handle.Muzzle then return end

    self.mainCaster:Fire(character.Outlaw.Handle.MuzzleBack.WorldPosition, direction, 600, CastBehavior)
    for _, v in pairs(character.Outlaw.Handle.Muzzle:GetChildren()) do
        if v:IsA("ParticleEmitter") then
            v:Emit(10)
        end
    end
end

return module