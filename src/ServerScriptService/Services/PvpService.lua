local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local pvpOnly = false

local PvpService = Knit.CreateService {
    Name = "PvpService", 
    Client = {
        KillSignal = Knit.CreateSignal(),
        OnDamagedSignal = Knit.CreateSignal(),
        ExplodeSignal = Knit.CreateSignal()
    }
}

function PvpService:KnitStart()
    game.Players.PlayerAdded:Connect(function(p)
        p:SetAttribute("Deaths", 0)
        p:SetAttribute("Kills", 0)
        p:SetAttribute("Score", 0)
    end)
end

function PvpService:FireExplodeSignal(pos)
    self.Client.ExplodeSignal:FireAll(pos)
end

function PvpService:RespawnTnt(c, v)
    task.delay(v, function()
		local t = game.ServerStorage.TNT:Clone()
		t.PrimaryPart.CFrame = c
		t.Parent = workspace
    end)
end

function PvpService.Client:Damage(player, hum, damage, headshot)
    if not player.Character or not player.Character.Humanoid or player.Character.Humanoid.Health <= 0 then return end
    if hum.Health > 0 then
        if hum.Health - damage <= 0 then
            local can = player.Character and player.Character.Humanoid
            if not can then return end
            if game.Players:GetPlayerFromCharacter(hum.Parent) or not pvpOnly then
                player.Character.Humanoid.Health += 50
                self.KillSignal:Fire(player, hum.Parent.Name, headshot, (player.Character.HumanoidRootPart.Position - hum.Parent.HumanoidRootPart.Position).Magnitude)
            end
        end
        hum:TakeDamage(damage)
        if game.Players:GetPlayerFromCharacter(hum.Parent) then
            self.OnDamagedSignal:Fire(game.Players:GetPlayerFromCharacter(hum.Parent), player)
        end
    end
end

function PvpService.Client:SetScore(player, num)
    player:SetAttribute("Score", num)
end

function PvpService.Client:SetKills(player, num)
    player:SetAttribute("Kills", num)
end

function PvpService.Client:SetDeaths(player, num)
    player:SetAttribute("Deaths", num)
end

return PvpService