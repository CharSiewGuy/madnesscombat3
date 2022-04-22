local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local WeaponController = Knit.CreateController { Name = "WeaponController" }

function WeaponController:KnitStart()

end

return WeaponController