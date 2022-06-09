local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local WeaponService = Knit.CreateService {
    Name = "WeaponService", 
    Client = {
        PlaySignal = Knit.CreateSignal(), 
        StopSignal = Knit.CreateSignal(),
        FireSignal = Knit.CreateSignal(),
        KillSignal = Knit.CreateSignal(),
        CreateBulletHoleSignal = Knit.CreateSignal(),
        CreateImpactEffectSignal = Knit.CreateSignal(),
        OnDamagedSignal = Knit.CreateSignal()
    }
}

function WeaponService.Client:Damage(player, hum, damage)
    if hum.Health > 0 then
        if hum.Health - damage <= 0 then
            local can = player.Character and player.Character.Humanoid
            if not can then return end
            player.Character.Humanoid.Health += 50
            self.KillSignal:Fire(player, hum.Parent.Name)
        end
        hum:TakeDamage(damage)
        if game.Players:GetPlayerFromCharacter(hum.Parent) then
            self.OnDamagedSignal:Fire(game.Players:GetPlayerFromCharacter(hum.Parent), player)
        end
    end
end

function WeaponService.Client:PlaySound(player, weapon, soundName, playOnRemove)
    if not player.Character then return end
    self.PlaySignal:FireExcept(player, player.Character, weapon, soundName, playOnRemove)
end

function WeaponService.Client:StopSound(player, soundName)
    if not player.Character then return end
    self.StopSignal:FireExcept(player, player.Character, soundName)
end

function WeaponService.Client:CastProjectile(player, weapon, direction)
    if not player.Character then return end
    self.FireSignal:FireExcept(player, player.Character, weapon, direction)
end

function WeaponService.Client:Tilt(player, c0)
    if not player.Character then return end
    if not player.Character.Humanoid then return end
    if player.Character.Humanoid.Health <= 0 then return end
	local hrp = player.Character:FindFirstChild("HumanoidRootPart");
	if hrp then
        local rj = hrp:FindFirstChild("RootJoint")
        if rj then
    		rj.C0 = c0
		end
	end
end

function WeaponService.Client:CreateBulletHole(player, raycastResult)
    self.CreateBulletHoleSignal:FireExcept(player, raycastResult)
end

function WeaponService.Client:CreateImpactEffect(player, raycastResult, human)
    self.CreateImpactEffectSignal:FireExcept(player, raycastResult, human)
    
end

return WeaponService