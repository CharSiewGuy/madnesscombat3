local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)
local Tween = require(Packages.TweenPromise)

local MovementController = Knit.CreateController { Name = "MovementController" }
MovementController._janitor = Janitor.new()

function MovementController:KnitStart()
    Knit.Player.CharacterAdded:Connect(function(character)
        local hum = character:WaitForChild("Humanoid")
        local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

        local function getMovingDir()
            local dir = humanoidRootPart.CFrame:VectorToObjectSpace(hum.MoveDirection)
            if dir.X < -0.9 then return "left" end
            if dir.X > 0.9 then return "right" end
            if dir.Z < 0 then return "forward" end
            if dir.Z > 0 then return "backward" end
        end

        self._janitor:Add(hum:GetPropertyChangedSignal("MoveDirection"):Connect(function()
            if humanoidRootPart.Anchored == true then return end
            
            if hum.MoveDirection.Magnitude > 0 then
                if getMovingDir() == "forward" then
                    if hum.WalkSpeed ~= 20 then
                        hum.WalkSpeed = 20
                    end
                else
                    if hum.WalkSpeed ~= 16 then
                        hum.WalkSpeed = 16
                    end                
                end
            end
        end))
        
        self._janitor:Add(hum.Died:Connect(function()
            self._janitor:Cleanup()
        end))
    end)
end

return MovementController