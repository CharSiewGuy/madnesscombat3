local Promise = require(game:GetService("ReplicatedStorage").Packages.Promise)
local TweenService = game:GetService("TweenService")

function tween(obj, tweenInfo, props)
	return Promise.new(function(resolve, _, onCancel)
		local tweenObj = TweenService:Create(obj, tweenInfo, props)
			
		-- Register a callback to be called if the Promise is cancelled.
		onCancel(function()
			tweenObj:Cancel()
		end) 
			
		tweenObj.Completed:Connect(resolve)
		tweenObj:Play()
	end)
end

return tween
