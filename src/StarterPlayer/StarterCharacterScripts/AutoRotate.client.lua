local character = script.Parent
local Humanoid = character:WaitForChild("Humanoid")
local RootPart = character:WaitForChild("HumanoidRootPart")

Humanoid.CameraOffset = Vector3.new(3, 1, 0)
Humanoid.AutoRotate = false

local CurrentCamera = workspace.CurrentCamera

local RunService = game:GetService("RunService")

RunService:BindToRenderStep("rotate torso", Enum.RenderPriority.Camera.Value - 10, function()
	local newRootPartCFrame = CFrame.new(RootPart.Position, RootPart.Position + Vector3.new(CurrentCamera.CFrame.LookVector.X, 0 , CurrentCamera.CFrame.LookVector.Z))
	RootPart.CFrame = RootPart.CFrame:Lerp(newRootPartCFrame,0.5)
end)
