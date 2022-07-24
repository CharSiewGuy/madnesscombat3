local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Promise = require(Packages.Promise)

local module = {}

function module:Voidshift(player)
    if player:GetAttribute("Class") == "Voidstalker" then
        local val = player.ClassValues.IsInVoidshift
        val.Value = true
        local resetPromise = Promise.delay(4.3)
        resetPromise:andThen(function()
            if val then
                val.Value = false
            end
        end)
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