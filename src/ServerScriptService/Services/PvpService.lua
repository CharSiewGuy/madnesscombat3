local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Zone = require(Packages.Zone)

local pvpOnly = true
local safeZone = Zone.new(workspace.SafeZones)

local PvpService = Knit.CreateService {
    Name = "PvpService", 
    Client = {
        KillSignal = Knit.CreateSignal(),
        OnDamagedSignal = Knit.CreateSignal(),
        ExplodeSignal = Knit.CreateSignal(),
        NewKillSignal = Knit.CreateSignal()
    }
}

function PvpService:KnitStart()
    Players.PlayerAdded:Connect(function(p)
        p:SetAttribute("Deaths", 0)
        p:SetAttribute("Kills", 0)
        p:SetAttribute("Score", 0)
        p.CharacterAdded:Connect(function(char)
            if not p:GetAttribute("Class") then return end
            local randSpawn = math.random(1, #workspace.Spawns:GetChildren())
            task.defer(function()
                repeat task.wait() until char.HumanoidRootPart
                char:MoveTo(workspace.Spawns:GetChildren()[randSpawn].Position)
            end)
        end)
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
    if safeZone:findPlayer(player) then return end
    if not hum.Parent then return end
    if not Players:GetPlayerFromCharacter(hum.Parent) or not safeZone:findPlayer(Players:GetPlayerFromCharacter(hum.Parent)) then
        if damage > 120 then player:Kick() end
        if not player.Character or not player.Character.Humanoid or player.Character.Humanoid.Health <= 0 then return end
        if hum.Health > 0 then
            if hum.Health - damage <= 0 then
                local can = player.Character and player.Character.Humanoid
                if not can then return end
                if Players:GetPlayerFromCharacter(hum.Parent) or not pvpOnly then
                    self.KillSignal:Fire(player, hum.Parent.Name, headshot, (player.Character.HumanoidRootPart.Position - hum.Parent.HumanoidRootPart.Position).Magnitude)
                    self.NewKillSignal:FireAll(player.Name, player:GetAttribute("Weapon"), hum.Parent.Name)
                end
            end
            hum:TakeDamage(damage)
            if Players:GetPlayerFromCharacter(hum.Parent) then
                self.OnDamagedSignal:Fire(Players:GetPlayerFromCharacter(hum.Parent), player)
            end
        end
    end
end

function PvpService.Client:SetMaxHealth(player, num)
    if num > 160 then player:Kick() end
    if player.Character and player.Character.Humanoid then
        player.Character.Humanoid.MaxHealth = num
        if player.Character.Humanoid.Health > num then player.Character.Humanoid.Health = num end
    end
end

function PvpService.Client:SetClass(player, classID)
    if not player.Character or not player.Character.Humanoid then return end

    player.Character.Humanoid.Health = 0
    if classID == 1 then
        player:SetAttribute("Class", "Voidstalker")
        return true
    end
end

function PvpService.Client:SetScore(player, num)
    if typeof(num) ~= "number" then return end
    player:SetAttribute("Score", num)
end

function PvpService.Client:SetKills(player, num)
    if typeof(num) ~= "number" then return end
    player:SetAttribute("Kills", num)
end

function PvpService.Client:SetDeaths(player, num)
    if typeof(num) ~= "number" then return end
    player:SetAttribute("Deaths", num)
end

return PvpService