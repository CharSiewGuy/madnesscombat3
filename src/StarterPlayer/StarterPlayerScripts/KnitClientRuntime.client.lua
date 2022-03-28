local packages = game:GetService("ReplicatedStorage").Packages
local client = game:GetService("ReplicatedStorage").Client
local Knit = require(packages.Knit)
local Loader = require(packages.Loader)
local Promise = require(packages.Promise)

Knit.AddControllers(client.Controllers)

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

Knit.Start():andThen(function()
    Loader.LoadChildren(client.Components)
    Knit.ComponentsLoaded = true
end):catch(warn)