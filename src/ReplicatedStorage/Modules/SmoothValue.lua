local valueCreator = {}
local runService = game:GetService("RunService")

local function lerpNumber(a, b, t)
	return a + (b - a) * t
end

function valueCreator:create(initialValue, target, speed)
	local value = {}
	value.value = initialValue or 0
	value.speed = speed or 10 
	value.target = target or 0 
	
	function value:increment(x)
		value.target = value.target + x
	end
	
	function value:multiply(x)
		value.target = value.target * x
	end
	
	function value:set(x)
		value.target = x
	end
	
	function value:get()
		return value.value
	end
	
	function value:update(dt)
		local lerp = math.min(dt * value.speed, 1)
		value.value = lerpNumber(value.value,value.target,lerp)	
		
		return value.value
	end
	
	return value
end


return valueCreator