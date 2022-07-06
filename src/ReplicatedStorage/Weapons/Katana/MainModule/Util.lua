local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Tween = require(Packages.TweenPromise)


local module = {}

module.velocity = Vector3.new()
module.speed = 0
module.distance = 0

function module:ClampMagnitude(v, max)
    if (v.magnitude == 0) then return Vector3.new(0,0,0) end
    return v.Unit * math.min(v.Magnitude, max) 
end

function module:fromAxisAngle(x, y, z)
	if not y then
		x, y, z = x.X, x.Y, x.Z
	end
	local m = (x * x + y * y + z * z) ^ 0.5
	if m > 1e-5 then
		local si = math.sin(m / 2) / m
		return CFrame.new(0, 0, 0, si * x, si * y, si * z, math.cos(m / 2))
	else
		return CFrame.new()
	end
end

function module:viewmodelBob(aa, rr, baseWalkSpeed)
	local a, r = aa or 1, rr or 1
	local d, s, v = self.distance * 6.28318 * 3 / 4, self.speed, -self.velocity
	--if s < baseWalkSpeed then
	local w = Vector3.new(r * math.sin(d / 4 - 1) / 256 + r * (math.sin(d / 64) - r * v.Z / 4) / 512, r * math.cos(d / 128) / 128 - r * math.cos(d / 8) / 256, r * math.sin(d / 8) / 128 + r * v.X / 1024) * s / 20 * 6.28318
	return CFrame.new(r * math.cos(d / 8 - 1) * s / 196, 1.25 * a * math.sin(d / 4) * s / 512, 0) * self:fromAxisAngle(w)
	--else
	--local w = Vector3.new((r * math.sin(d / 4 - 1) / 256 + r * (math.sin(d / 64) - r * v.Z / 4) / 512) * s / 20 * 6.28318, (r * math.cos(d / 128) / 128 - r * math.cos(d / 8) / 256) * s / 20 * 6.28318, r * math.sin(d / 8) / 128 * (5 * s - 56) / 20 * 6.28318 + r * v.X / 1024)
	--return CFrame.new(r * math.cos(d / 8 - 1) * (5 * s - 56) / 196, 1.25 * a * math.sin(d / 4) * s / 512, 0) * Math.FromAxisAngle(w)
	--end
end

function module:ViewmodelBreath(a)
	local d, s = os.clock() * 6, 2 * (1.2 - a)
	return CFrame.new(math.cos(d / 8) * s / 128, -math.sin(d / 4) * s / 128, math.sin(d / 16) * s / 64)
end

function module:GetMousePos(unitRay, CastParams)
    local ori, dir = unitRay.Origin, unitRay.Direction * 500
    local result = workspace:Raycast(ori, dir, CastParams)
    return result and result.Position or ori + dir
end

function module:SetGlow(gun, enabled)
    for _, v in pairs(gun:GetChildren()) do
        if v.Material == Enum.Material.Neon then
            if enabled then
                Tween(v, TweenInfo.new(0.15), {Transparency = 0.2})
            else
                Tween(v, TweenInfo.new(0.1), {Transparency = 0.8})
            end
        end
    end
end

return module