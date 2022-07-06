local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService('RunService')
local GameSettings = UserSettings().GameSettings
local UserInputService = game:GetService('UserInputService')

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)

local InputController = Knit.CreateController { Name = "InputController" }
InputController.janitor = Janitor.new()

InputController.mouseLocked = false

function InputController:KnitStart()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.M then
            if self.mouseLocked == true then self.mouseLocked = false else self.mouseLocked = true end
        end
    end)

    RunService.Heartbeat:Connect(function()
        GameSettings.RotationType = Enum.RotationType.CameraRelative
        if self.mouseLocked then
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
            UserInputService.MouseIconEnabled = false
        else
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end
    end)
end

return InputController