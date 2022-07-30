local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Zone = require(Packages.Zone)

local pvpOnly = false
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

local ClassService 

function PvpService:KnitInit()
    ClassService = Knit.GetService("ClassService")    
end

function PvpService:KnitStart()
    for _, spawn in pairs(workspace.Spawns:GetChildren()) do
        for _, v in pairs(spawn:GetDescendants()) do
            if not v:IsA("SpecialMesh") then v.Transparency = 1 end
            if v:IsA("Decal") then v:Destroy() end
        end        
    end

    Players.PlayerAdded:Connect(function(p)
        p:SetAttribute("Deaths", 0)
        p:SetAttribute("Kills", 0)
        p:SetAttribute("Score", 0)
        p.CharacterAdded:Connect(function(char)
            if not p:GetAttribute("Class") then return end
            local randSpawn = math.random(1, #workspace.Spawns:GetChildren())
            task.defer(function()
                repeat task.wait() until char.HumanoidRootPart or not char
                local spawnPoint = workspace.Spawns:GetChildren()[randSpawn].HumanoidRootPart
                char.HumanoidRootPart.CFrame = spawnPoint.CFrame
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
    if safeZone:findPlayer(player) then return false end
    if not hum.Parent then return false end
    local hitPlayer = Players:GetPlayerFromCharacter(hum.Parent)
    if not hitPlayer or not safeZone:findPlayer(hitPlayer) then
        if damage > 120 then player:Kick() end
        if not player.Character or not player.Character.Humanoid or player.Character.Humanoid.Health <= 0 then return false end
        if not (hitPlayer and hitPlayer:GetAttribute("Class") == "Voidstalker" and hitPlayer.ClassValues.IsInVoidshift.Value == true) then 
            if hum.Health > 0 then
                if hum.Health - damage <= 0 then
                    if hitPlayer or not pvpOnly then
                        ClassService:IncreaseUltCharge(player, player.ClassValues.UltChargePerKill.Value)
                        self.KillSignal:Fire(player, hum.Parent.Name, headshot, (player.Character.HumanoidRootPart.Position - hum.Parent.HumanoidRootPart.Position).Magnitude)
                        self.NewKillSignal:FireAll(player.Name, player:GetAttribute("Weapon"), hum.Parent.Name)
                    end
                end
                hum:TakeDamage(damage)
                if hitPlayer then
                    self.OnDamagedSignal:Fire(hitPlayer, player)
                end
                return true
            end
        else
            return false
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