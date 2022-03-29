local Packages = game.ReplicatedStorage.Packages
local Component = require(Packages.Component)

local TestComponent = Component.new({
	Tag = "Test",
	Ancestors = {workspace},
})

return TestComponent
