local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
--local Promise = require(Packages.Promise)
local Janitor = require(Packages.Janitor)
--local Tween = require(Packages.TweenPromise)

--local Modules = ReplicatedStorage.Modules

local CharacterController = Knit.CreateController { Name = "CharacterController" }
CharacterController.janitor = Janitor.new()

local PvpService 
local HudController

function CharacterController:KnitInit()
    PvpService = Knit.GetService("PvpService")
    HudController = Knit.GetController("HudController")
end

function CharacterController:KnitStart()
    Knit.Player.CharacterAdded:Connect(function(character)
        local hum = character:WaitForChild("Humanoid")
        
        self.janitor:Add(PvpService.OnDamagedSignal:Connect(function(p)
            if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                HudController:ShowDamageDir(p.Character.Name, p.Character.HumanoidRootPart.Position)
            end
        end))

        hum.Died:Connect(function()
            self.janitor:Cleanup()
        end)
    end)

end
return CharacterController