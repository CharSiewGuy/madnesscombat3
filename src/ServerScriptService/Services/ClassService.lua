local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local ClassService = Knit.CreateService {
    Name = "ClassService", 
    Client = {
        AddModelSignal = Knit.CreateSignal(), 
        RemoveModelSignal = Knit.CreateSignal(),
        UseAbilitySignal = Knit.CreateSignal()
    }
}

function ClassService.Client:AddModel(player, modelName, bodyPartName)
    if not player.Character then return end
    self.AddModelSignal:FireExcept(player, player, modelName, bodyPartName)
end

function ClassService.Client:RemoveModel(player, modelName, bodyPartName)
    if not player.Character then return end
    self.RemoveModelSignal:FireExcept(player, player, modelName, bodyPartName)
end

function ClassService.Client:ResetValues(player)
    if not player:GetAttribute("Class") then return end
    if player:FindFirstChild("ClassValues") then player.ClassValues:Destroy() end
    local classValues = ServerScriptService.Classes[player:GetAttribute("Class")].ClassValues:Clone()
    classValues.Parent = player
end

function ClassService.Client:UseAbility(player, abilityName, isServer)
    if not player.Character or not player:GetAttribute("Class") then return end
    if isServer then
        do
            local serverModule = require(ServerScriptService.Classes[player:GetAttribute("Class")].ServerModule)
            serverModule:UseAbility(player, abilityName)
        end
    else
        self.UseAbilitySignal:FireExcept(player, player, abilityName) 
    end
end

return ClassService