local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)
local Timer = require(Packages.Timer)

local ClassService = Knit.CreateService {
    Name = "ClassService", 
    Client = {
        AddModelSignal = Knit.CreateSignal(), 
        RemoveModelSignal = Knit.CreateSignal(),
        UseAbilitySignal = Knit.CreateSignal()
    }
}

function ClassService:ResetValues(player)
    if not player:GetAttribute("Class") then return end
    if player:FindFirstChild("ClassValues") then player.ClassValues:Destroy() end
    local classValues = ServerScriptService.Classes[player:GetAttribute("Class")].ClassValues:Clone()
    classValues.Parent = player
end

function ClassService:IncreaseUltCharge(player, amount)
    local newUltPercent = player:GetAttribute("UltCharge") + amount
    if newUltPercent >= 100 then
        player:SetAttribute("UltCharge", 100)
        if player:GetAttribute("IsUltReady") == false then
            player:SetAttribute("IsUltReady", true)
        end
    else
        player:SetAttribute("IsUltReady", false)
        player:SetAttribute("UltCharge", newUltPercent)
    end
end

function ClassService:KnitStart()
    local playerJanitors = {}

    Players.PlayerAdded:Connect(function(player)
        playerJanitors[player.Name] = Janitor.new()

        player.CharacterAdded:Connect(function(char)
            local hum = char:WaitForChild("Humanoid")
            local charJanitor = Janitor.new()
            playerJanitors[player.Name]:Add(charJanitor)
            charJanitor:LinkToInstance(char)

            if player:GetAttribute("Class") then
                self:ResetValues(player)
                local ultChargeTimer = charJanitor:Add(Timer.new(player.ClassValues.UltChargeRate.Value))
                ultChargeTimer.Tick:Connect(function()
                    self:IncreaseUltCharge(player, player.ClassValues.UltChargeAmount.Value)
                end)
                ultChargeTimer:Start()
            end

            charJanitor:Add(hum.Died:Connect(function()
                charJanitor:Cleanup()
                charJanitor = nil
            end))
        end)
        
        player:SetAttribute("UltCharge", 0)
        player:SetAttribute("IsUltReady", false)
    end)

    Players.PlayerRemoving:Connect(function(player)
        playerJanitors[player.Name]:Cleanup()
        playerJanitors[player.Name] = nil
    end)
end

function ClassService.Client:SetClass(player, classID)
    if not player.Character or not player.Character.Humanoid then return end

    player.Character.Humanoid.Health = 0
    if classID == 1 then
        player:SetAttribute("Class", "Voidstalker")
        return true
    end
end

function ClassService:ResetUltProgress(player)
    player:SetAttribute("UltCharge", 0)
    player:SetAttribute("IsUltReady", false)
end

function ClassService.Client:ResetUltProgress(player)
    player:SetAttribute("UltCharge", 0)
    player:SetAttribute("IsUltReady", false)
end

function ClassService.Client:AddModel(player, modelName, bodyPartName)
    if not player.Character then return end
    self.AddModelSignal:FireExcept(player, player, modelName, bodyPartName)
end

function ClassService.Client:RemoveModel(player, modelName, bodyPartName)
    if not player.Character then return end
    self.RemoveModelSignal:FireExcept(player, player, modelName, bodyPartName)
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