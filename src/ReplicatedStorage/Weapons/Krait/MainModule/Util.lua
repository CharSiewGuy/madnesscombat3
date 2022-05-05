local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Tween = require(Packages.TweenPromise)


local module = {}

function module:GetBobbing(addition,speed,modifier)
    return math.sin(tick()*addition*speed)*modifier
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
                Tween(v, TweenInfo.new(0.2), {Transparency = 0.2})
            else
                Tween(v, TweenInfo.new(0.15), {Transparency = 0.8})
            end
        end
    end
end

return module