local OTS_CAMERA_SYSTEM = require(game.ReplicatedStorage.Modules.OtsCameraSystem)

local Player = game:GetService("Players").LocalPlayer
local Character = Player.Character or Player.CharacterAdded:wait()
Character:WaitForChild("Humanoid").AutoRotate = false

OTS_CAMERA_SYSTEM:Enable()
OTS_CAMERA_SYSTEM:SetCharacterAlignment(true)

Player.CharacterAdded:Connect(function()
	Player.Character:WaitForChild("Humanoid").AutoRotate = false
end)

Character:WaitForChild("Humanoid").Died:Connect(function()
	OTS_CAMERA_SYSTEM:Disable()
end)

local uis = game:GetService("UserInputService")
uis.MouseIconEnabled = false