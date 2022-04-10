local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)
local Shake = require(Packages.Shake)
local Tween = require(Packages.TweenPromise)
local SmoothValue = require(game.ReplicatedStorage.Modules.SmoothValue)

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

        local value = SmoothValue:create(0, 0, 5)

        self._janitor:Add(RunService.Heartbeat:Connect(function(dt)
            hum.WalkSpeed = value:update(dt)
        end))

        self._janitor:Add(hum:GetPropertyChangedSignal("MoveDirection"):Connect(function()
            if humanoidRootPart.Anchored == true then return end
            
            if hum.MoveDirection.Magnitude > 0 then
                if getMovingDir() == "forward" then
                    if self.isSprinting then
                        value:set(24)
                        shake.Amplitude = 0.3
                        if hum.CameraOffset.Z <= 0 then
                            self._janitor:AddPromise(Tween(hum, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {CameraOffset = Vector3.new(3, 1, 1)}))
                        end
                    else
                        value:set(18)
                        shake.Amplitude = 0.1
                    end
                else
                    if value.target ~= 16 then
                        value:set(16)
                        shake.Amplitude = 0.1
                    end
                end
                if not self.isSprinting then
                    if hum.CameraOffset.Z >= 1 then
                        self._janitor:AddPromise(Tween(hum, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CameraOffset = Vector3.new(3, 1, 0)}))
                    end
                end
            else
                shake.Amplitude = 0
                if hum.CameraOffset.Z >= 1 then
                    self._janitor:AddPromise(Tween(hum, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CameraOffset = Vector3.new(3, 1, 0)}))
                end
            end
        end))
        
        self._janitor:Add(hum.Died:Connect(function()
            self._janitor:Cleanup()
        end))
    end)
end

return MovementController