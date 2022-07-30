local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Promise = require(Packages.Promise)

local module = {}

function module:Voidshift(player)
    if player:GetAttribute("Class") == "Voidstalker" and player:GetAttribute("UltCharge") >= 100 then
        local val = player.ClassValues.IsInVoidshift
        val.Value = true
        local resetPromise = Promise.delay(4.5)
        resetPromise:andThen(function()
            if val then
                val.Value = false
            end
        end)
        Knit.GetService("ClassService"):ResetUltProgress(player)
        return resetPromise
    else 
        return false
    end
end

function module:UseAbility(player, abilityName)
    if abilityName == "Voidshift" then
        self:Voidshift(player)
    end   
end

return module