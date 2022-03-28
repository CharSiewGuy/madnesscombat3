local players = game:GetService("Players")
players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		character.Torso["Left Hip"].Part0 = character.HumanoidRootPart
		character.Torso["Left Hip"].Parent = character.HumanoidRootPart
		character.Torso["Right Hip"].Part0 = character.HumanoidRootPart
		character.Torso["Right Hip"].Parent = character.HumanoidRootPart
	end)
end)