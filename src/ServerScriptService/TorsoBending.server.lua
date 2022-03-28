local tiltAt = game.ReplicatedStorage.RemoteEvents.tiltAt
tiltAt.OnServerEvent:Connect(function(player, c0)
    for _, v in pairs(game:GetService("Players"):GetPlayers()) do
        if v ~= player then
             tiltAt:FireClient(v, player.Character, c0)
        end
    end
end)