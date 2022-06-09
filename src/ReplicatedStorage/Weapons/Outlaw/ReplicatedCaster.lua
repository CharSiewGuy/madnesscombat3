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
    local can = character.Prime and character.Prime.Handle and character.Prime.Handle.MuzzleBack
    if not can then return end
    
    local CastParams = RaycastParams.new()
    CastParams.IgnoreWater = true
    CastParams.FilterType = Enum.RaycastFilterType.Blacklist
    CastParams.FilterDescendantsInstances = {character, workspace.CurrentCamera}

    local CastBehavior = FastCast.newBehavior()
    CastBehavior.RaycastParams = CastParams
    CastBehavior.MaxDistance = 500
    CastBehavior.HighFidelityBehavior = FastCast.HighFidelityBehavior.Default
    CastBehavior.CosmeticBulletContainer = workspace.Projectiles
    CastBehavior.CosmeticBulletTemplate = script.Parent.BulletPart
    CastBehavior.Acceleration = Vector3.new(0, -5, 0)
    CastBehavior.AutoIgnoreContainer = true

    self.mainCaster:Fire(character.Prime.Handle.MuzzleBack.WorldPosition, direction, 350, CastBehavior)

    if not character.Prime.Handle.Muzzle then return end

    local flash = ReplicatedStorage.Assets.Particles.ElectricMuzzleFlash:Clone()
    flash.Parent = character.Prime.Handle.Muzzle
    flash:Emit(1)
    task.delay(0.15, function()
        flash:Destroy()
    end)
end

return module