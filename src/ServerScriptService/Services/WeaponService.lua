local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local WeaponService = Knit.CreateService {
    Name = "WeaponService", 
    Client = {
        PlaySignal = Knit.CreateSignal(), 
        StopSignal = Knit.CreateSignal(),
        FireSignal = Knit.CreateSignal()
    }
}

function WeaponService.Client:Damage(_, hum, damage)
    hum:TakeDamage(damage)
end

function WeaponService.Client:PlaySound(player, soundName, playOnRemove)
    if not player.Character then return end
    self.PlaySignal:FireExcept(player, player.Character, soundName, playOnRemove)
end

function WeaponService.Client:StopSound(player, soundName)
    if not player.Character then return end
    self.StopSignal:FireExcept(player, player.Character, soundName)
end

function WeaponService.Client:CastProjectile(player, direction)
    if not player.Character then return end
    self.FireSignal:FireExcept(player, player.Character, direction)
end

return WeaponService