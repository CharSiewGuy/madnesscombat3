local camera = workspace.CurrentCamera

local stateType = Enum.HumanoidStateType

local character = script.Parent
local enabled = Instance.new("BoolValue")
enabled.Name = "BendingEnabled"
enabled.Value = true
enabled.Parent = character

local humanoid = character:WaitForChild("Humanoid")

humanoid:SetStateEnabled(stateType.FallingDown, false)
humanoid:SetStateEnabled(stateType.Ragdoll, false)

local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local tiltAt = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("tiltAt")
local waistC0 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)

local defaultC0 = humanoidRootPart.RootJoint.C0

enabled.Changed:Connect(function(val)
	if val == false then
		humanoidRootPart.RootJoint.C0 = defaultC0
		tiltAt:FireServer(defaultC0)
	end
end)

game:GetService("RunService").Heartbeat:Connect(function()
	if character:FindFirstChild("HumanoidRootPart") then
		if enabled.Value then
			if humanoidRootPart:FindFirstChild("RootJoint") then
				local waist = humanoidRootPart.RootJoint
				waist.C0 = waistC0 * CFrame.fromEulerAnglesYXZ(math.asin(camera.CFrame.LookVector.y) * -1, 0, 0)
				tiltAt:FireServer(waist.C0)
			end
		end
	end
end)

tiltAt.OnClientEvent:Connect(function(c, c0)
	if c:FindFirstChild("HumanoidRootPart") then
		local waist = c.HumanoidRootPart.RootJoint
		waist.C0 = c0
	end
end)