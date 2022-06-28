local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local SoundService = Knit.CreateService {
    Name = "SoundService", 
    Client = {
        PlaySignal = Knit.CreateSignal(), 
        StopSignal = Knit.CreateSignal()
    }
}

function SoundService.Client:PlaySound(player, weapon, soundName, playOnRemove)
    if not player.Character then return end
    self.PlaySignal:FireExcept(player, player.Character, weapon, soundName, playOnRemove)
end

function SoundService.Client:StopSound(player, soundName)
    if not player.Character then return end
    self.StopSignal:FireExcept(player, player.Character, soundName)
end

return SoundService