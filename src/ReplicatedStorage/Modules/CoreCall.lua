local MAX_RETRIES = 8
local StarterGui = game:GetService('StarterGui')
local RunService = game:GetService('RunService')

return function(method, ...) 
	local result = {}
	for _ = 1, MAX_RETRIES do
		result = {pcall(StarterGui[method], StarterGui, ...)}
		if result[1] then
			break
		end
		RunService.Stepped:Wait()
	end
	return unpack(result)
end

