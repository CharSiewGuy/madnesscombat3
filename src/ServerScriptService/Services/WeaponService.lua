local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)


local WeaponService = Knit.CreateService {
    Name = "WeaponService", 
    Client = {
        FireSignal = Knit.CreateSignal(),
        CreateBulletHoleSignal = Knit.CreateSignal(),
        CreateImpactEffectSignal = Knit.CreateSignal(),
    }
}

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

function WeaponService.Client:SetCurWeapon(player, weaponName)
    if not player.Character then return end
    if not player.Character.Weapons:FindFirstChild(weaponName) then return end
    for _, weapon in pairs(player.Character.Weapons:GetChildren()) do
        if weapon.Name == weaponName then
            for _, v in pairs(weapon:GetDescendants()) do 
                if v:IsA("BasePart") then 
                    v.Transparency = 0 
                elseif v:IsA("Texture") then
                    v.Transparency = tonumber(v.Name)
                end
            end
        else
            for _, v in pairs(weapon:GetDescendants()) do 
                if v:IsA("BasePart") or v:IsA("Texture") then 
                    v.Transparency = 1 
                end 
            end
         end
    end
end

function WeaponService.Client:CreateBulletHole(player, raycastResult)
    self.CreateBulletHoleSignal:FireExcept(player, raycastResult)
end

function WeaponService.Client:CreateImpactEffect(player, raycastResult, human, fxCFrame)
    self.CreateImpactEffectSignal:FireExcept(player, raycastResult, human, fxCFrame)
end

return WeaponService