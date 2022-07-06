local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local FastCast = require(Packages.FastCastRedux)

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
    local can = character.Weapons.Prime and character.Weapons.Prime.Handle and character.Weapons.Prime.Handle.MuzzleBack
    if not can then return end
    
    local CastParams = RaycastParams.new()
    CastParams.IgnoreWater = true
    CastParams.FilterType = Enum.RaycastFilterType.Blacklist
    CastParams.FilterDescendantsInstances = {character, workspace.CurrentCamera}

    local CastBehavior = FastCast.newBehavior()
    CastBehavior.RaycastParams = CastParams
    CastBehavior.MaxDistance = 1200
    CastBehavior.HighFidelityBehavior = FastCast.HighFidelityBehavior.Default
    CastBehavior.CosmeticBulletContainer = workspace.Projectiles
    CastBehavior.CosmeticBulletTemplate = script.Parent.BulletPart
    CastBehavior.Acceleration = Vector3.new(0, -200, 0)
    CastBehavior.AutoIgnoreContainer = true

    self.mainCaster:Fire(character.Weapons.Prime.Handle.MuzzleBack.WorldPosition, direction, 800, CastBehavior)

    if not character.Weapons.Prime.Handle.Muzzle then return end

    character.Weapons.Prime.Handle.MuzzleFlash1.Flash:Emit(1)
    character.Weapons.Prime.Handle.MuzzleFlash2.Flash:Emit(1)
    character.Weapons.Prime.Handle.Muzzle.PointLight.Enabled = true
    task.delay(0.06, function()
        character.Weapons.Prime.Handle.Muzzle.PointLight.Enabled = false
    end)
end

return module