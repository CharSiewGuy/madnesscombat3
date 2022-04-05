local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local FastCastService = Knit.CreateService {Name = "FastCastService", Client = {} }

function FastCastService.Client:Fire(player, origin, direction)
    
end

return FastCastService