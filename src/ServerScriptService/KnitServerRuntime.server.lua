local packages = game:GetService("ReplicatedStorage").Packages
local Knit = require(packages.Knit)
local Loader = require(packages.Loader)
local Promise = require(packages.Promise)

function Knit.OnComponentsLoaded()
    if Knit.ComponentsLoaded then
        return Promise.Resolve()
    end
    return Promise.new(function(resolve)
        repeat task.wait() until Knit.ComponentsLoaded
        resolve(true)
    end)
end

Knit.ComponentsLoaded = false

Knit.AddServices(script.Parent.Services)

Knit.Start():andThen(function()
    Loader.LoadChildren(script.Parent.Components)
    Knit.ComponentsLoaded = true
end):catch(warn)