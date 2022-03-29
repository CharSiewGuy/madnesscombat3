local Packages = game.ReplicatedStorage.Common.Packages
local Component = require(Packages.Component)

local TestComponent = Component.new({
	Tag = "Test",
	Ancestors = {workspace},
})

return TestComponent
