local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)
--local Tween = require(Packages.TweenPromise)

--local Modules = ReplicatedStorage.Modules

local ClassController = Knit.CreateController { Name = "ClassController" }
ClassController.janitor = Janitor.new()

--local PvpService 
--local SoundService 
--local HudController
local WeaponController

function ClassController:KnitInit()
    --PvpService = Knit.GetService("PvpService")
    --SoundService = Knit.GetService("SoundService")
    --HudController = Knit.GetController("HudController")
    WeaponController = Knit.GetController("WeaponController")
end

function ClassController:KnitStart()
    repeat task.wait() until Knit.Player:GetAttribute("Class")

    Knit.Player.CharacterAdded:Connect(function(character)
        repeat task.wait() until WeaponController.currentViewmodel
        local hum = character:WaitForChild("Humanoid")

        self.class = Knit.Player:GetAttribute("Class")
        self.classFolder = ReplicatedStorage.Classes:FindFirstChild(self.class)
        self.classModule = require(self.classFolder.MainModule)
        self.classModule:Init(character, WeaponController.currentViewmodel)

        ContextActionService:BindAction("UseAbility1", self.classModule.HandleActionInterface, true, Enum.KeyCode.Q)

        hum.Died:Connect(function()
            ContextActionService:UnbindAction("UseAbility1")
            self.classModule:Cleanup()
            self.janitor:Cleanup()
        end)
    end)
end

return ClassController