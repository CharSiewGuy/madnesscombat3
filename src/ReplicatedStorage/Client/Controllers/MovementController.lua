local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)
local Shake = require(Packages.Shake)
local Tween = require(Packages.TweenPromise)

local MovementController = Knit.CreateController { Name = "MovementController" }
MovementController._janitor = Janitor.new()

function MovementController:KnitInit()
    self.isSprinting = false
    self.canSprint = true
end

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

        self._sprintJanitor = Janitor.new()
        self._janitor:Add(self._sprintJanitor)

        local shake = Shake.new()
        shake.FadeInTime = 0.5
        shake.FadeOutTime = 0.2
        shake.Frequency = 0.2
        shake.Amplitude = 0
        shake.Sustain = true
        shake.PositionInfluence = Vector3.new(0, 0, 0)
        shake.RotationInfluence = Vector3.new(0.1, 0.1, 0.1)

        self._janitor:Add(shake)

        local camera = workspace.CurrentCamera
        shake:Start()
        shake:BindToRenderStep(Shake.NextRenderName(), Enum.RenderPriority.Last.Value, function(pos, rot)
            camera.CFrame *= CFrame.new(pos) * CFrame.Angles(rot.X, rot.Y, rot.Z)
        end)

        local function handleAction(actionName, inputState)
            if not self.canSprint then return end
            if actionName == "Sprint" then
                if inputState == Enum.UserInputState.Begin then
                    self.isSprinting = true
                elseif inputState == Enum.UserInputState.End then
                    self.isSprinting = false
                end
            end
        end

        ContextActionService:BindAction("Sprint", handleAction, true, Enum.KeyCode.LeftShift)
        self._janitor:Add(function()
            ContextActionService:UnbindAction("Sprint")
            self.isSprinting = false
        end)

        self._janitor:Add(hum:GetPropertyChangedSignal("MoveDirection"):Connect(function()
            if humanoidRootPart.Anchored == true then return end
            
            if hum.MoveDirection.Magnitude > 0 then
                if getMovingDir() == "forward" then
                    if self.isSprinting then

                        hum.WalkSpeed = 24
                        shake.Amplitude = 0.3
                    else
                        hum.WalkSpeed = 18
                        shake.Amplitude = 0.1
                    end
                else
                    if hum.WalkSpeed ~= 16 then
                        hum.WalkSpeed = 16
                        shake.Amplitude = 0.1
                    end
                end
            else
                shake.Amplitude = 0
            end
        end))
        
        self._janitor:Add(hum.Died:Connect(function()
            self._janitor:Cleanup()
        end))
    end)
end

return MovementController