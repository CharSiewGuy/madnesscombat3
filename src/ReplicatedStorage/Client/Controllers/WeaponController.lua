local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)

local WeaponController = Knit.CreateController { Name = "WeaponController" }
WeaponController._janitor = Janitor.new()

function WeaponController:KnitStart()
    local weaponModule = require(ReplicatedStorage.Weapons.Krait.MainModule)

    Knit.Player.CharacterAdded:Connect(function(character)
        local hum = character:WaitForChild("Humanoid")

        if workspace.CurrentCamera:FindFirstChild("viewmodel") then
            workspace.CurrentCamera.viewmodel:Destroy()
        end

        local viewmodel = ReplicatedStorage.viewmodel:Clone()
        viewmodel.Parent = workspace.CurrentCamera

        repeat
            task.wait()
        until character:FindFirstChild("HumanoidRootPart") and viewmodel:FindFirstChild("HumanoidRootPart")
        
        weaponModule:Equip(character, viewmodel)
        
        local function handleAction(actionName, inputState)
            if actionName == "Equip" then
                if inputState == Enum.UserInputState.Begin then
                    weaponModule:Equip(character, viewmodel)
                end
            elseif actionName == "Unequip" then
                if inputState == Enum.UserInputState.Begin then
                    weaponModule:Unequip(character)
                end
            end
        end
        
        ContextActionService:BindAction("Equip", handleAction, true, Enum.KeyCode.One)
        ContextActionService:BindAction("Unequip", handleAction, true, Enum.KeyCode.Two)

        self._janitor:Add(hum.Died:Connect(function()
            weaponModule:Unequip(character)
            self._janitor:Cleanup()
        end))
    end)
end

return WeaponController