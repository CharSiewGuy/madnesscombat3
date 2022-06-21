local Packages = game.ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Component = require(Packages.Component)

local ExplosiveComponent = Component.new({
	Tag = "Explosive",
	Ancestors = {workspace},
})

function ExplosiveComponent:Construct()
	self.hum = self.Instance.Humanoid
	self.hrp = self.Instance.HumanoidRootPart
end

function ExplosiveComponent:Start()
	self.hum.HealthChanged:Connect(function(h)
		if h <= 0 then
			self.Instance:Destroy()
		end
	end)
end

function ExplosiveComponent:Stop()
	local c = self.Instance.PrimaryPart.CFrame
	Knit.GetService("PvpService"):RespawnTnt(c, 10)
	Knit.GetService("PvpService"):FireExplodeSignal(c.Position)

	local p = workspace:GetPartBoundsInRadius(self.hrp.Position, 13)
	for _, v in pairs(p) do
		if game.Players:GetPlayerFromCharacter(v.Parent) and not v.Parent.HumanoidRootPart:FindFirstChild("SatchelOut") then 
			local hrp = v.Parent.HumanoidRootPart
			local dist = (hrp.Position - self.hrp.Position).Magnitude
			if dist < 25 then
				local bv = Instance.new("BodyVelocity")
				bv.Name = "SatchelOut"
				bv.MaxForce = Vector3.new(1,0.55,1) * 20000
				local lv = CFrame.new(Vector3.new(self.hrp.Position.X, 0, self.hrp.Position.Z), Vector3.new(v.Parent.HumanoidRootPart.Position.X, 0, v.Parent.HumanoidRootPart.Position.Z)).LookVector
				local m = 1
				if dist < 7 then
					bv.Velocity = lv * 100 * m  + Vector3.new(0,50,0)
					v.Parent.Humanoid.Health -= 40
				elseif dist < 12 then
					bv.Velocity = lv * 80 * m + Vector3.new(0,40,0)
					v.Parent.Humanoid.Health -= 37
				elseif dist < 20 then
					bv.Velocity = lv * 60 * m + Vector3.new(0,30,0)
					v.Parent.Humanoid.Health -= 30
				elseif dist < 25 then
					bv.Velocity = lv * 40 * m + Vector3.new(0,20,0)
					v.Parent.Humanoid.Health -= 25
				end
				bv.Parent = v.Parent.HumanoidRootPart
				task.delay(1 * m, function()
					if bv then bv:Destroy() end
				end)
			end
		end
	end
end

return ExplosiveComponent