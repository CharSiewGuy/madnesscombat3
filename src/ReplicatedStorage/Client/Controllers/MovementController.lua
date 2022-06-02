local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)
local Tween = require(Packages.TweenPromise)
local Promise = require(Packages.Promise)
local HumanoidAnimatorUtils = require(Packages.HumanoidAnimatorUtils)

local Modules = ReplicatedStorage.Modules
local SmoothValue = require(Modules.SmoothValue)

local MovementController = Knit.CreateController { Name = "MovementController" }
MovementController.janitor = Janitor.new()

local HudController 
local WeaponController
local WeaponService

MovementController.normalSpeed = 14
MovementController.sprintSpeed = 24
MovementController.loadedAnimations = {}
MovementController.fovOffset = SmoothValue:create(0, 0, 5)

function MovementController:Slide(hum, humanoidRootPart)
    if humanoidRootPart.Velocity.Magnitude < 18 then return end

    self.isSliding = true
    self.canSlide = false

    local slideV = Instance.new("BodyVelocity")
    slideV.MaxForce = Vector3.new(1,0,1) * 30000
    if humanoidRootPart.Velocity.Magnitude > 20 then
        slideV.Velocity = humanoidRootPart.CFrame.LookVector * math.clamp(humanoidRootPart.Velocity.Magnitude * 3.5, 20, 100)
    else
        slideV.Velocity = humanoidRootPart.CFrame.LookVector * 50
    end
    slideV.Name = "SlideVel"
    slideV:SetAttribute("Created", tick())
    slideV.Parent = humanoidRootPart
    self.fovOffset:set(10)
    self.slideJanitor:Add(function()
        self.isSliding = false
        task.delay(0.05, function()
            slideV:Destroy()
        end)        
        self.loadedAnimations.slide:Stop(0.2)
        if not self.isCrouching then
            Tween(hum, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CameraOffset = Vector3.new(0, 0, 0)})
        end
        self.fovOffset:set(0)
    end)

    self.sprintJanitor:Cleanup()

    local sound = ReplicatedStorage.Assets.Sounds.Slide:Clone()
    sound.Parent = self.camera
    sound:Play()
    WeaponController.loadedAnimations.slideCamera:Play()

    self.slideJanitor:Add(function()
        self.slideJanitor:AddPromise(Tween(sound, TweenInfo.new(0.2), {Volume = 0}))
        task.delay(0.2, function()
            sound:Destroy()
        end)
        self.janitor:AddPromise(Promise.delay(1)):andThen(function()
            self.canSlide = true
        end)
        WeaponService:StopSound("Slide")
        self.lastSlide = tick()
        WeaponController.loadedAnimations.slideCamera:Stop()
    end)

    self.slideJanitor:AddPromise(Tween(hum, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CameraOffset = Vector3.new(0, -1.5, 0)}))
    Tween(slideV, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Velocity = humanoidRootPart.CFrame.LookVector * 30})
    self.lastSlide = tick()
    task.delay(0.65, function()
        print(tick() - self.lastSlide)
        if tick() - self.lastSlide >= 0.64 then 
            print("Slide Ended")
            self.isSliding = false
            slideV:Destroy()
            self.loadedAnimations.slide:Stop(0.2)
            self.slideJanitor:AddPromise(Tween(sound, TweenInfo.new(0.2), {Volume = 0}))
            self.slideJanitor:AddPromise(Promise.delay(0.2)):andThen(function()
                sound:Destroy()
            end)
            self.fovOffset:set(0)
            self:Crouch(hum)
        end
    end)

    self.loadedAnimations.slide:Play(0.2)

    self.janitor:Add(self.slideJanitor)

    WeaponService:PlaySound("Slide", false)
end

function MovementController:Crouch(hum)
    self.isCrouching = true
    self.canSlide = false
    self.crouchJanitor:AddPromise(Tween(hum, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CameraOffset = Vector3.new(0, -1.5, 0)}))
    self.loadedAnimations.crouch:Play(0.2)
    self.crouchJanitor:Add(function()
        Tween(hum, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CameraOffset = Vector3.new(0, 0, 0)})
        self.isCrouching = false
        self.canSlide = true
        self.loadedAnimations.crouch:Stop(0.2)
    end)
end

function MovementController:KnitInit()
    HudController = Knit.GetController("HudController")
    WeaponController = Knit.GetController("WeaponController")
    WeaponService = Knit.GetService("WeaponService")
end

function MovementController:KnitStart()
    self.isSprinting = false
    self.canSprint = true
    self.isSliding = false
    self.canSlide = true
    self.lastSlide = 0
    self.isCrouching = false
    self.canCrouch = true
    self.canClimb = true
    self.camera = workspace.CurrentCamera

    Knit.Player.CharacterAdded:Connect(function(character)
        local hum = character:WaitForChild("Humanoid")
        local animator = HumanoidAnimatorUtils.getOrCreateAnimator(hum)
        self.loadedAnimations.slide = animator:LoadAnimation(ReplicatedStorage.Assets.Animations.Slide)
        self.loadedAnimations.slide.Priority = Enum.AnimationPriority.Action4
        self.loadedAnimations.sprint = animator:LoadAnimation(ReplicatedStorage.Assets.Animations.Sprint)
        self.loadedAnimations.crouch = animator:LoadAnimation(ReplicatedStorage.Assets.Animations.Crouch)

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
        self.crouchJanitor = Janitor.new()
        self.janitor:Add(self.sprintJanitor)
        self.janitor:Add(self.slideJanitor)
        self.janitor:Add(self.crouchJanitor)

        self.isSliding = false
        self.canSprint = true
        self.canSlide = true

        local value = SmoothValue:create(self.normalSpeed, self.normalSpeed, 2.5)
        self.fovOffset.value = 0
        self.fovOffset.target = 0

        local function handleAction(actionName, inputState)
            if actionName == "Sprint" then
                if not self.canSprint then return end
                if inputState == Enum.UserInputState.Begin then
                    if hum.MoveDirection.Magnitude > 0 and getMovingDir() == "forward" then
                        self.isSprinting = true
                        value:set(self.sprintSpeed)
                        WeaponController.loadedAnimations.sprintCamera:Play()
                        HudController.crosshairOffset:set(80)
                        self.loadedAnimations.sprint:Play(0.3)
                        self.sprintJanitor:Add(function()
                            self.isSprinting = false
                            value:set(self.normalSpeed)
                            WeaponController.loadedAnimations.sprintCamera:Stop()
                            self.loadedAnimations.sprint:Stop(0.3)
                            HudController.crosshairOffset:set(40)
                        end)
                        self.crouchJanitor:Cleanup()
                    end
                elseif inputState == Enum.UserInputState.End then
                   self.sprintJanitor:Cleanup()
                end
            elseif actionName == "Crouch" then
                if inputState == Enum.UserInputState.Begin then
                    if hum.FloorMaterial == Enum.Material.Air then return end
                    if self.isSprinting then
                        if self.canSlide and not self.isSliding then
                            self:Slide(hum, humanoidRootPart)
                        end
                    else
                        if self.canCrouch and not self.isSliding then
                            if self.isCrouching then
                                self.crouchJanitor:Cleanup()
                            else
                                self:Crouch(hum, humanoidRootPart)
                            end
                        end
                    end
                elseif inputState == Enum.UserInputState.End then
                    self.slideJanitor:Cleanup()
                end
            end
        end

        ContextActionService:BindAction("Sprint", handleAction, true, Enum.KeyCode.LeftShift)
        ContextActionService:BindAction("Crouch", handleAction, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl)
        self.janitor:Add(function()
            ContextActionService:UnbindAction("Sprint")
            ContextActionService:UnbindAction("Crouch")
            self.isSprinting = false
        end)

        self.janitor:Add(hum:GetPropertyChangedSignal("MoveDirection"):Connect(function()
            if humanoidRootPart.Anchored == true then return end
            if hum.MoveDirection.Magnitude > 0 then
                if getMovingDir() ~= "forward" then
                    self.sprintJanitor:Cleanup()
                end
            else
                HudController.crosshairOffset:set(40)
                self.sprintJanitor:Cleanup()
            end
        end))

        local canDoubleJump = false
        local hasDoubleJumped = false
        local oldPower = hum.JumpPower
        local TIME_BETWEEN_JUMPS = 0.2
        local DOUBLE_JUMP_POWER_MULTIPLIER = 1
        
        local function onJumpRequest()
            if not character or not hum or not character:IsDescendantOf(workspace) or
            hum:GetState() == Enum.HumanoidStateType.Dead then
                return
            end
            if canDoubleJump and not hasDoubleJumped then
                hasDoubleJumped = true
                hum.JumpPower = oldPower * DOUBLE_JUMP_POWER_MULTIPLIER
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
        
        local canClimb = true    

        self.janitor:Add(hum.StateChanged:Connect(function(_, new)
            if new == Enum.HumanoidStateType.Landed then
                canDoubleJump = false
                hasDoubleJumped = false
                canClimb = true
                hum.JumpPower = oldPower
            elseif new == Enum.HumanoidStateType.Freefall then
                task.wait(TIME_BETWEEN_JUMPS)
                canDoubleJump = true
            elseif new == Enum.HumanoidStateType.Jumping then
                self.crouchJanitor:Cleanup()
                self.slideJanitor:Cleanup()
                if humanoidRootPart:FindFirstChild("SlideVel") then
                    local slideV = Instance.new("BodyVelocity")
                    slideV.Name = "SlideJumpVel"
                    slideV.MaxForce = Vector3.new(1,0,1) * 15000
                    slideV.Velocity = humanoidRootPart.SlideVel.Velocity * 5                 
                    slideV.Parent = humanoidRootPart
                    Tween(slideV, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Velocity = humanoidRootPart.SlideVel.Velocity * 1})
                    task.delay(0.5, function()
                        if slideV then slideV:Destroy() end
                    end)
                end
            end
        end))
        
        self.janitor:Add(UserInputService.JumpRequest:Connect(onJumpRequest))
        
        self.janitor:Add(RunService.Heartbeat:Connect(function(dt)
            if self.isSliding then
                hum.WalkSpeed = 0
            elseif self.isCrouching then
                hum.WalkSpeed = 10
            else
                hum.WalkSpeed = value:update(dt)
            end

            local can = character and character.Humanoid and character.Humanoid.Health > 0 and character.Head
            if not can then return end
            
            if hum.FloorMaterial == Enum.Material.Air and canClimb and self.canClimb then
                local raycastParams = RaycastParams.new()
                raycastParams.FilterDescendantsInstances = {character, self.camera}
                raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                for i = 0, 0.5, 0.1 do
                    local raycastResult = workspace:Raycast(character.Head.Position - Vector3.new(0,i,0), (character.Head.CFrame.LookVector - Vector3.new(0,i,0)).Unit * 3, raycastParams)
                    if raycastResult then
                        if character.Head.Position.Y >= (raycastResult.Instance.Position.Y + (raycastResult.Instance.Size.Y / 2)) - 3 and character.Head.Position.Y <= raycastResult.Instance.Position.Y + (raycastResult.Instance.Size.Y / 2) + 4 then 
                            if humanoidRootPart:FindFirstChild("SlideJumpVel") then humanoidRootPart.SlideJumpVel:Destroy() end 
                            if humanoidRootPart:FindFirstChild("SlideVel") then humanoidRootPart.SlideVel:Destroy() end 
                            local climbV = Instance.new("BodyVelocity")
                            climbV.MaxForce = Vector3.new(1,1,1) * 30000
                            climbV.Velocity = humanoidRootPart.CFrame.LookVector * 40 + Vector3.new(0,32,0)
                            climbV.Parent = humanoidRootPart
                            task.delay(0.05, function()climbV:Destroy()end)
                            canClimb = false
                            WeaponController:Climb(character.Head.Position.Y - (raycastResult.Instance.Position.Y + raycastResult.Instance.Size.Y / 2))

                            local sound = ReplicatedStorage.Assets.Sounds:FindFirstChild("Climb" .. math.random(1, 3)):Clone()
                            sound.Parent = self.camera
                            sound:Destroy()
                            break
                        end
                    end
                end
            end

            local v = character.HumanoidRootPart:FindFirstChild("SlideVel")
            if v then
                if tick() - v:GetAttribute("Created") > 0.71 then
                    print("force stopped slide")
                    v:Destroy()
                    self.isSliding = false
                    self.loadedAnimations.slide:Stop(0.2)
                    self.fovOffset:set(0)
                    self:Crouch(hum)
                end
            end 

            self.camera.FieldOfView = WeaponController.baseFov:update(dt) + self.fovOffset:update(dt)
            HudController:SetVel(math.floor(humanoidRootPart.Velocity.Magnitude))
        end))

        
        self.janitor:Add(hum.Died:Connect(function()
            self.janitor:Cleanup()
        end))
    end)
end

return MovementController