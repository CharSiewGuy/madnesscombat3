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

        local equipped = true
        local equipDebounce = false
        
        local function handleAction(actionName, inputState)
            if equipDebounce then return end
            if actionName == "Equip" and not equipped then
                if inputState == Enum.UserInputState.Begin then
                    equipDebounce = true
                    weaponModule:Equip(character, viewmodel)
                    equipped = true
                    task.delay(0.2, function()
                        equipDebounce = false
                    end)
                end
            elseif actionName == "Unequip" and equipped then
                if inputState == Enum.UserInputState.Begin then
                    equipDebounce = true
                    weaponModule:Unequip(character)
                    equipped = false
                    task.delay(0.2, function()
                        equipDebounce = false
                    end)
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