local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)
local Shake = require(Packages.Shake)
local Tween = require(Packages.TweenPromise)
local Promise = require(Packages.Promise)
local SmoothValue = require(game.ReplicatedStorage.Modules.SmoothValue)

local MovementController = Knit.CreateController { Name = "MovementController" }
MovementController.janitor = Janitor.new()

local HudController 

MovementController.normalSpeed = 16
MovementController.sprintSpeed = 22

function MovementController:KnitInit()
    HudController = Knit.GetController("HudController")
end

function MovementController:KnitStart()
    self.isSprinting = false
    self.isSliding = false
    self.canSprint = true
    self.canSlide = true
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

        self.sprintJanitor = Janitor.new()
        self.slideJanitor = Janitor.new()
        self.janitor:Add(self.sprintJanitor)
        self.janitor:Add(self.slideJanitor)

        self.canSprint = true
        self.canSlide = true

        local walkShake = Shake.new()
        walkShake.FadeInTime = 0.5
        walkShake.FadeOutTime = 0.2
        walkShake.Frequency = 0.25
        walkShake.Amplitude = 0
        walkShake.Sustain = true
        walkShake.PositionInfluence = Vector3.new(0, 0, 0)
        walkShake.RotationInfluence = Vector3.new(0.1, 0.1, 0.1)

        self.janitor:Add(walkShake)

        walkShake:Start()
        walkShake:BindToRenderStep(Shake.NextRenderName(), Enum.RenderPriority.Last.Value, function(pos, rot)
            self.camera.CFrame *= CFrame.new(pos) * CFrame.Angles(rot.X, rot.Y, rot.Z)
        end)

        local value = SmoothValue:create(self.normalSpeed, self.normalSpeed, 10)

        local function handleAction(actionName, inputState)
            if not self.canSprint then return end
            if actionName == "Sprint" then
                if inputState == Enum.UserInputState.Begin then
                    if hum.MoveDirection.Magnitude > 0 and getMovingDir() == "forward" then
                        self.isSprinting = true
                        value:set(self.sprintSpeed)
                        walkShake.Amplitude = 0.2
                        HudController.crosshairOffset:set(100)
                        self.sprintJanitor:Add(function()
                            self.isSprinting = false
                            value:set(self.normalSpeed)
                            walkShake.Amplitude = 0
                            HudController.crosshairOffset:set(50)
                        end)
                        self.slideJanitor:Cleanup()
                    end
                elseif inputState == Enum.UserInputState.End then
                   self.sprintJanitor:Cleanup()
                end
            elseif actionName == "Slide" then
                local cantSlide = self.isSliding or not self.isSprinting or not self.canSlide or hum.FloorMaterial == Enum.Material.Air 
                if cantSlide then return end

                self.isSliding = true
                self.canSlide = false

                local slideV = Instance.new("BodyVelocity")
                slideV.MaxForce = Vector3.new(1,0,1) * 20000
                slideV.Velocity = humanoidRootPart.CFrame.LookVector * 50
                slideV.Parent = humanoidRootPart

                self.slideJanitor:Add(slideV)
                self.slideJanitor:Add(function()
                    self.isSliding = false
                    slideV:Destroy()
                    Tween(hum, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CameraOffset = Vector3.new(0, 0, 0)})
                end)
                self.sprintJanitor:Cleanup()

                local sound = ReplicatedStorage.Assets.Sounds.Slide:Clone()
                sound.Parent = self.camera
                sound:Play()
                self.slideJanitor:Add(function()
                    self.slideJanitor:AddPromise(Tween(sound, TweenInfo.new(0.2), {Volume = 0}))
                    task.delay(0.2, function()
                        sound:Destroy()
                    end)
                    self.janitor:AddPromise(Promise.delay(1)):andThen(function()
                        self.canSlide = true
                    end)
                end)

                self.slideJanitor:AddPromise(Tween(hum, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CameraOffset = Vector3.new(0, -1.5, 0)}))
                self.slideJanitor:AddPromise(Tween(slideV, TweenInfo.new(.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Velocity = humanoidRootPart.CFrame.LookVector * 20}))
                self.slideJanitor:AddPromise(Promise.delay(.5)):andThen(function()
                    self.slideJanitor:Cleanup()
                end)
            end
        end

        ContextActionService:BindAction("Sprint", handleAction, true, Enum.KeyCode.LeftShift)
        ContextActionService:BindAction("Slide", handleAction, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl)
        self.janitor:Add(function()
            ContextActionService:UnbindAction("Sprint")
            ContextActionService:UnbindAction("Slide")
            self.isSprinting = false
        end)

        self.janitor:Add(RunService.Heartbeat:Connect(function(dt)
            if self.isSliding then
                hum.WalkSpeed = 0
                humanoidRootPart.Running.Volume = 0
            else
                hum.WalkSpeed = value:update(dt)
            end
        end))

        self.janitor:Add(hum:GetPropertyChangedSignal("MoveDirection"):Connect(function()
            if humanoidRootPart.Anchored == true then return end
            if hum.MoveDirection.Magnitude > 0 then
                if getMovingDir() ~= "forward" then
                    self.sprintJanitor:Cleanup()
                end
            else
                self.sprintJanitor:Cleanup()
            end
        end))

        local MAX_JUMPS = 3
        local TIME_BETWEEN_JUMPS = 0.3
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

                numJumps += 1

                self.slideJanitor:Cleanup()
            end
        end

        local function onJumpRequest()
            if canJumpAgain and numJumps < MAX_JUMPS then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end

        self.janitor:Add(hum.StateChanged:Connect(onStateChanged))
        self.janitor:Add(UserInputService.JumpRequest:Connect(onJumpRequest))
        
        self.janitor:Add(hum.Died:Connect(function()
            self.janitor:Cleanup()
        end))
    end)
end

return MovementController