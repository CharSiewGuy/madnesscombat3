local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local WeaponService = Knit.CreateService {Name = "WeaponService", Client = {}}

function WeaponService.Client:Damage(_, hum, damage)
    hum:TakeDamage(damage)
end

return WeaponService