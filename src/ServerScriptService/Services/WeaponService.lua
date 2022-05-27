local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local WeaponService = Knit.CreateService {
    Name = "WeaponService", 
    Client = {
        PlaySignal = Knit.CreateSignal(), 
        StopSignal = Knit.CreateSignal(),
        FireSignal = Knit.CreateSignal(),
        CreateBulletHoleSignal = Knit.CreateSignal(),
        CreateImpactEffectSignal = Knit.CreateSignal()
    }
}

function WeaponService.Client:Damage(player, hum, damage)
    if hum.Health > 0 then
        if hum.Health - damage <= 0 then
            local can = player.Character and player.Character.Humanoid
            if not can then return end
            player.Character.Humanoid.Health += 50
        end
    end
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

function WeaponService.Client:Tilt(player, c0)
	local hrp = player.Character:FindFirstChild("HumanoidRootPart");
	if (hrp) then
		hrp.RootJoint.C0 = c0
	end
end

function WeaponService.Client:CreateBulletHole(player, raycastResult)
    self.CreateBulletHoleSignal:FireExcept(player, raycastResult)
end

function WeaponService.Client:CreateImpactEffect(player, raycastResult, human)
    self.CreateImpactEffectSignal:FireExcept(player, raycastResult, human)
    
end

return WeaponService