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
end

return ExplosiveComponent