local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

function ClassService.Client:UseAbility(player, abilityName)
    if not player.Character then return end
    self.UseAbilitySignal:FireExcept(player, player, abilityName)    
end

return ClassService