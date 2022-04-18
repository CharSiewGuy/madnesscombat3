local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)
local Shake = require(Packages.Shake)
local Tween = require(Packages.TweenPromise)
local SmoothValue = require(game.ReplicatedStorage.Modules.SmoothValue)

local MovementController = Knit.CreateController { Name = "MovementController" }
MovementController._janitor = Janitor.new()

local BreadGunController

function MovementController:KnitInit()
    BreadGunController = Knit.GetController("BreadGunController")
end

function MovementController:KnitStart()
    self.isSprinting = false
    self.canSprint = true
    self.camera = workspace.CurrentCamera

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

        local walkShake = Shake.new()
        walkShake.FadeInTime = 0.5
        walkShake.FadeOutTime = 0.2
        walkShake.Frequency = 0.25
        walkShake.Amplitude = 0
        walkShake.Sustain = true
        walkShake.PositionInfluence = Vector3.new(0, 0, 0)
        walkShake.RotationInfluence = Vector3.new(0.1, 0.1, 0.1)

        self._janitor:Add(walkShake)

        walkShake:Start()
        walkShake:BindToRenderStep(Shake.NextRenderName(), Enum.RenderPriority.Last.Value, function(pos, rot)
            self.camera.CFrame *= CFrame.new(pos) * CFrame.Angles(rot.X, rot.Y, rot.Z)
        end)

        local value = SmoothValue:create(0, 0, 5)

        local function handleAction(actionName, inputState)
            if not self.canSprint then return end
            if actionName == "Sprint" then
                if inputState == Enum.UserInputState.Begin then
                    if hum.MoveDirection.Magnitude > 0 and getMovingDir() == "forward" then
                        self.isSprinting = true
                        value:set(24)
                        walkShake.Amplitude = 0.2
                    end
                elseif inputState == Enum.UserInputState.End then
                    self.isSprinting = false
                    value:set(16)
                    walkShake.Amplitude = 0
                end
            end
        end

        ContextActionService:BindAction("Sprint", handleAction, true, Enum.KeyCode.LeftShift)
        self._janitor:Add(function()
            ContextActionService:UnbindAction("Sprint")
            self.isSprinting = false
        end)

        self._janitor:Add(RunService.Heartbeat:Connect(function(dt)
            hum.WalkSpeed = value:update(dt)
        end))

        self._janitor:Add(hum:GetPropertyChangedSignal("MoveDirection"):Connect(function()
            if humanoidRootPart.Anchored == true then return end
            if hum.MoveDirection.Magnitude > 0 then
               if getMovingDir() ~= "forward" then
                    self.isSprinting = false
                    value:set(16)
                    walkShake.Amplitude = 0
                end
            else
                self.isSprinting = false
                value:set(16)
                walkShake.Amplitude = 0
            end
        end))

        local MAX_JUMPS = 3
        local TIME_BETWEEN_JUMPS = 0.2
        local numJumps = 0
        local canJumpAgain = false

        local function onStateChanged(_, newState)
            if Enum.HumanoidStateType.Landed == newState then
                numJumps = 0
                canJumpAgain = false
            elseif Enum.HumanoidStateType.Freefall == newState then
                task.wait(TIME_BETWEEN_JUMPS)
                canJumpAgain = true
            elseif Enum.HumanoidStateType.Jumping == newState then
                canJumpAgain = false

                local sound = ReplicatedStorage.Assets.Sounds:FindFirstChild("Jump" .. math.clamp(numJumps, 0, 2) + 1):Clone()
                sound.Parent = self.camera
                sound:Destroy()

                if numJumps > 0 then   
                    local jumpShake = Shake.new()
                    jumpShake.FadeInTime = 0.05
                    jumpShake.Frequency = 0.5
                    jumpShake.Amplitude = 5
                    jumpShake.PositionInfluence = Vector3.new(0, 0, 0)
                    jumpShake.RotationInfluence = Vector3.new(0, 0, 0)

                    jumpShake:Start()
                    jumpShake:BindToRenderStep(Shake.NextRenderName(), Enum.RenderPriority.Last.Value, function(pos, rot)
                        self.camera.CFrame *= CFrame.new(pos) * CFrame.Angles(rot.X, rot.Y, rot.Z)
                    end)
                 end

                 numJumps += 1
            end

        end

        local function onJumpRequest()
            if canJumpAgain and numJumps < MAX_JUMPS then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end

        self._janitor:Add(hum.StateChanged:Connect(onStateChanged))
        self._janitor:Add(UserInputService.JumpRequest:Connect(onJumpRequest))
        
        self._janitor:Add(hum.Died:Connect(function()
            self._janitor:Cleanup()
        end))
    end)
end

return MovementController