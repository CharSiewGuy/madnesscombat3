local ReplicatedStorage = game:GetService("ReplicatedStorage")

local packages = game:GetService("ReplicatedStorage").Packages
local client = game:GetService("ReplicatedStorage").Client
local Knit = require(packages.Knit)
local Loader = require(packages.Loader)
local Promise = require(packages.Promise)

Knit.AddControllers(client.Controllers)

client.Controllers:Destroy()

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

local assetsTable = {}
for _, weaponFolder in pairs(ReplicatedStorage.Weapons:GetChildren()) do
    for _, anim in pairs(weaponFolder.Animations:GetChildren()) do
        assetsTable[#assetsTable+1] = anim.AnimationId 
    end
    for _, anim in pairs(weaponFolder["3PAnimations"]:GetChildren()) do
        assetsTable[#assetsTable+1] = anim.AnimationId 
    end
end

print(#assetsTable .. " animations found")

local lStart = tick()
game:GetService("ContentProvider"):PreloadAsync(assetsTable)
print("took " .. tick() - lStart .. " seconds to load")