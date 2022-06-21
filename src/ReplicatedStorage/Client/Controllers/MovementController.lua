local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
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
local Spring4 = require(Modules.Spring4)

local MovementController = Knit.CreateController { Name = "MovementController" }
MovementController.janitor = Janitor.new()

local HudController 
local WeaponController
local WeaponService

MovementController.normalSpeed = 16
MovementController.sprintSpeed = 23
MovementController.loadedAnimations = {}
MovementController.fovOffset = SmoothValue:create(0, 0, 5)
MovementController.jumpCamSpring = Spring4.new(Vector3.new())
MovementController.jumpCamSpring.Speed = 5
MovementController.jumpCamSpring.Damper = 1

function MovementController:Slide(hum, humanoidRootPart)
    if humanoidRootPart.Velocity.Magnitude < 18 then return end

    self.isSliding = true
    self.canSlide = false

    local slideV = Instance.new("BodyVelocity")
    slideV.MaxForce = Vector3.new(1,0,1) * 30000
    slideV.Velocity = humanoidRootPart.CFrame.LookVector * math.clamp(Vector3.new(humanoidRootPart.Velocity.X, humanoidRootPart.Velocity.Y * 1.5, humanoidRootPart.Velocity.Z).Magnitude/18 * 80, 20, 150)
    slideV.Name = "SlideVel"
    slideV:SetAttribute("Created", tick())
    slideV.Parent = humanoidRootPart
    self.fovOffset:set(10)
    self.slideJanitor:Add(function()
        self.isSliding = false
        slideV:Destroy()
        self.loadedAnimations.slide:Stop(0.2)
        if not self.isCrouching then
            Tween(hum, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CameraOffset = Vector3.new(0, 0, 0)})
        end
        self.fovOffset:set(0)
    end)

    self.sprintJanitor:Cleanup()

    local randSound = "Slide" .. math.random(1,2)

    local sound = ReplicatedStorage.Assets.Sounds[randSound]:Clone()
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
        WeaponService:StopSound(randSound)
        self.lastSlide = tick()
    end)

    self.slideJanitor:AddPromise(Tween(hum, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CameraOffset = Vector3.new(0, -1.7, 0)}))
    Tween(slideV, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Velocity = humanoidRootPart.CFrame.LookVector * 30})
    self.lastSlide = tick()
    task.delay(0.65, function()
        if tick() - self.lastSlide >= 0.64 then 
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

    WeaponService:PlaySound(nil, randSound, false)
end

function MovementController:Crouch(hum)
    self.isCrouching = true
    self.canSlide = false
    self.crouchJanitor:AddPromise(Tween(hum, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CameraOffset = Vector3.new(0, -1.7, 0)}))
    self.loadedAnimations.crouch:Play(0.2)
    self.crouchJanitor:Add(function()
        Tween(hum, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CameraOffset = Vector3.new(0, 0, 0)})
        self.isCrouching = false
        self.canSlide = true
        self.loadedAnimations.crouch:Stop(0.2)
    end)
end

function MovementController:KnitInit()
    HudController = Knit.GetController("HudController")
    WeaponController = Knit.GetController("WeaponController")
    WeaponService = Knit.GetService("WeaponService")

    self.airborneTime = 0
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
    self.fallingSound = ReplicatedStorage.Assets.Sounds.Fall:Clone()
    self.fallingSound.Parent = self.camera
    self.fallingSound:Play()

    Knit.Player.CharacterAdded:Connect(function(character)
        local hum = character:WaitForChild("Humanoid")
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

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
                        self.loadedAnimations.sprint:Play(0.3)
                        HudController.crosshairTransparency:set(1)
                        self.sprintJanitor:Add(function()
                            self.isSprinting = false
                            value:set(self.normalSpeed)
                            HudController.crosshairTransparency:set(0)
                            WeaponController.loadedAnimations.sprintCamera:Stop()
                            self.loadedAnimations.sprint:Stop(0.3)
                        end)
                        self.crouchJanitor:Cleanup()
                        self.slideJanitor:Cleanup()
                        HudController.crosshairOffset:set(80)
                    end
                elseif inputState == Enum.UserInputState.End then
                    HudController.crosshairOffset:set(40)
                    self.sprintJanitor:Cleanup()
                end
            elseif actionName == "Crouch" then
                if inputState == Enum.UserInputState.Begin then
                    if not (hum:GetState() == Enum.HumanoidStateType.Running or hum:GetState() == Enum.HumanoidStateType.Landed) then return end
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
                if getMovingDir() ~= "forward" and not humanoidRootPart:FindFirstChild("SatchelOut") then
                    self.sprintJanitor:Cleanup()
                end
                if not self.isSprinting then
                    if self.isCrouching then
                        HudController.crosshairOffset:set(30)
                    else
                        HudController.crosshairOffset:set(40)
                    end
                else
                    HudController.crosshairOffset:set(80)
                end
            else
                HudController.crosshairOffset:set(20)
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
                if hum.Parent.Name == "1109t" then hasDoubleJumped = false end
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
                self.jumpCamSpring:Impulse(Vector3.new(-math.clamp((math.abs(humanoidRootPart.Velocity.Y)/40), .5, 7),0,0))
            elseif new == Enum.HumanoidStateType.Freefall then
                task.wait(TIME_BETWEEN_JUMPS)
                canDoubleJump = true
            elseif new == Enum.HumanoidStateType.Jumping then
                self.crouchJanitor:Cleanup()
                self.slideJanitor:Cleanup()
                if not canDoubleJump then
                    local s = ReplicatedStorage.Assets.Sounds.Jump:Clone()
                    s.Parent = self.camera
                    s:Destroy()
                    WeaponService:PlaySound(nil, "Jump", true)
                elseif canDoubleJump then
                    local s = ReplicatedStorage.Assets.Sounds.DoubleJump:Clone()
                    s.Parent = self.camera
                    s:Destroy()
                    WeaponService:PlaySound(nil, "DoubleJump", true)
                end
                self.jumpCamSpring:Impulse(Vector3.new(-1,0,0))
            end
        end))
        
        self.janitor:Add(UserInputService.JumpRequest:Connect(onJumpRequest))
        
        local camoffset = CFrame.new()

        self.janitor:Add(RunService.RenderStepped:Connect(function(dt)
            if self.isSliding then
                hum.WalkSpeed = 0
                HudController.crosshairOffset:set(20)
            elseif self.isCrouching then
                hum.WalkSpeed = 8
            else
                hum.WalkSpeed = value:update(dt)
            end

            local can = character and character.Humanoid and character.Humanoid.Health > 0 and character.Head
            if not can then return end
                
            if hum.FloorMaterial == Enum.Material.Air and canClimb and self.canClimb then
                local raycastParams = RaycastParams.new()
                raycastParams.FilterDescendantsInstances = {character, self.camera, CollectionService:GetTagged("Unclimbable")}
                raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                for i = 0, 0.5, 0.1 do
                    local raycastResult = workspace:Raycast(character.Head.Position - Vector3.new(0,i,0), (character.Head.CFrame.LookVector - Vector3.new(0,i,0)).Unit * 3, raycastParams)
                    if raycastResult and raycastResult.Instance and raycastResult.Instance.CanCollide and not raycastResult.Instance:IsA("TrussPart") then
                        if character.Head.Position.Y >= (raycastResult.Instance.Position.Y + (raycastResult.Instance.Size.Y / 2)) - 1 and character.Head.Position.Y <= raycastResult.Instance.Position.Y + (raycastResult.Instance.Size.Y / 2) + 3 then 
                            if humanoidRootPart:FindFirstChild("SlideVel") then humanoidRootPart.SlideVel:Destroy() end 
                            local climbV = Instance.new("AlignPosition")
                            climbV.Mode = Enum.PositionAlignmentMode.OneAttachment
                            climbV.Attachment0 = humanoidRootPart.RootAttachment
                            climbV.Responsiveness = 50
                            climbV.Position = (humanoidRootPart.CFrame*CFrame.new(0, 4, -2)).Position
                            climbV.Parent = humanoidRootPart
                            task.delay(.1, function()climbV:Destroy()end)
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
                if tick() - v:GetAttribute("Created") > 0.7 then
                    v:Destroy()
                    self.isSliding = false
                    self.loadedAnimations.slide:Stop(0.2)
                    self.fovOffset:set(0)
                    self:Crouch(hum)
                end
            end 

            if hum.FloorMaterial == Enum.Material.Air then
                local yVel = humanoidRootPart.Velocity.Magnitude
                if yVel > 45 then
                    self.airborneTime += 0.01
                end
            else
                self.airborneTime = 0
            end

            self.fallingSound.Volume = math.clamp(self.airborneTime, 0, 2)

            if hum:GetState() == Enum.HumanoidStateType.Climbing then 
                hum.WalkSpeed *= 2
            end

            self.jumpCamSpring:TimeSkip(dt)
            local newoffset = CFrame.Angles(self.jumpCamSpring.p.x,self.jumpCamSpring.p.y,self.jumpCamSpring.p.z)
            self.camera.CFrame = self.camera.CFrame * camoffset:Inverse() * newoffset
            camoffset = newoffset

            self.camera.FieldOfView = WeaponController.baseFov:update(dt) + self.fovOffset:update(dt)
        end))

        self.janitor:Add(function()
            for _, v in pairs(character:GetDescendants()) do
                if v:IsA("Motor6D") and not v:FindFirstAncestor("Weapons") and v.Name ~= "Handle" then
                    local Att0, Att1 = Instance.new("Attachment"), Instance.new("Attachment")
                    Att0.CFrame = v.C0
                    Att1.CFrame = v.C1
                    Att0.Parent = v.Part0
                    Att1.Parent = v.Part1
                    local BSC = Instance.new("BallSocketConstraint")
                    BSC.Attachment0 = Att0
                    BSC.Attachment1 = Att1
                    BSC.Parent = v.Part0
                    v:Destroy()
                end
            end
        end)

        self.janitor:Add(hum.Died:Connect(function()
            self.janitor:Cleanup()
        end))
    end)
end

return MovementController