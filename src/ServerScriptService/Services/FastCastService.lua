local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local FastCastService = Knit.CreateService {Name = "FastCastService", Client = {FireSignal = Knit.CreateSignal()} }

function FastCastService.Client:Fire(player, origin, direction)
    if not player.Character then return end
    self.FireSignal:FireExcept(player, origin, direction, true, player.Character)
end

return FastCastService