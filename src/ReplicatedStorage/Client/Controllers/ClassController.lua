local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Option = require(Packages.Option)
local Janitor = require(Packages.Janitor)
--local Tween = require(Packages.TweenPromise)

--local Modules = ReplicatedStorage.Modules

local ClassController = Knit.CreateController { Name = "ClassController" }
ClassController.janitor = Janitor.new()

--local PvpService 
--local SoundService 
--local HudController
local ClassService
local WeaponController

function ClassController:KnitInit()
    --PvpService = Knit.GetService("PvpService")
    --SoundService = Knit.GetService("SoundService")
    --HudController = Knit.GetController("HudController")
    ClassService = Knit.GetService("ClassService")
    WeaponController = Knit.GetController("WeaponController")
end

function ClassController:KnitStart()
    ClassService.AddModelSignal:Connect(function(player, modelName, bodyPartName)
        if not player.Character then return end
        if not player:GetAttribute("Class") then return end

        local modelOpt = Option.Some(ReplicatedStorage.Classes[player:GetAttribute("Class")]:FindFirstChild(modelName))
        modelOpt:Match{
            Some = function(model)
                local modelClone = model:Clone()

                local bodyPartOpt = Option.Some(player.Character:FindFirstChild(bodyPartName))
                bodyPartOpt:Match{
                    Some = function(bodyPart)
                        modelClone.Parent = bodyPart
                        
                        local modelMotor6D = Instance.new("Motor6D")
                        modelMotor6D.Parent = bodyPart
                        modelMotor6D.Part0 = bodyPart
                        modelMotor6D.Part1 = modelClone.PrimaryPart
                    end,

                    None = function() modelClone:Destroy() end
                }
            end,

            None = function() return end
        }
    end)

    ClassService.RemoveModelSignal:Connect(function(player, modelName, bodyPartName)
        if not player.Character then return end

        local modelOpt = Option.Some(player.Character:FindFirstChild(bodyPartName):FindFirstChild(modelName))
        modelOpt:Match{
            Some = function(model)
               model:Destroy()
            end,

            None = function() return end
        }    
    end)

    ClassService.UseAbilitySignal:Connect(function(player, abilityName)
        if not player.Character or not player:GetAttribute("Class") then return end
        do 
            local classReplicatedModule = require(ReplicatedStorage.Classes[player:GetAttribute("Class")].ReplicatedModule)
            classReplicatedModule:UseAbility(player, abilityName)
        end
    end)

    repeat task.wait() until Knit.Player:GetAttribute("Class")

    Knit.Player.CharacterAdded:Connect(function(character)
        repeat task.wait() until WeaponController.currentViewmodel
        local hum = character:WaitForChild("Humanoid")

        self.class = Knit.Player:GetAttribute("Class")
        self.classFolder = ReplicatedStorage.Classes:FindFirstChild(self.class)
        self.classModule = require(self.classFolder.MainModule)
        self.classModule:Init(character, WeaponController.currentViewmodel)

        ContextActionService:BindAction("UseAbility1", self.classModule.HandleActionInterface, true, Enum.KeyCode.Q)
        ContextActionService:BindAction("UseUltimateAbility", self.classModule.HandleActionInterface, true, Enum.KeyCode.F)

        hum.Died:Connect(function()
            ContextActionService:UnbindAction("UseAbility1")
            ContextActionService:UnbindAction("UseUltimateAbility")
            self.classModule:Cleanup()
            self.janitor:Cleanup()
        end)
    end)
end

return ClassController