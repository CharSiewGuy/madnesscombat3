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
local SoundService

MovementController.normalSpeed = 16
MovementController.sprintSpeed = 24
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
    slideV.Velocity = humanoidRootPart.CFrame.LookVector * math.clamp(humanoidRootPart.Velocity.Magnitude/24 * 90, 20, 110)
    slideV.Name = "SlideVel"
    slideV:SetAttribute("Created", tick())
    slideV.Parent = humanoidRootPart
    self.fovOffset:set(15)
    self.slideJanitor:Add(function()
        self.isSliding = false
        slideV:Destroy()
        self.loadedAnimations.slide:Stop(0.2)
        if not self.isCrouching then
            Tween(hum, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CameraOffset = Vector3.new(0, 0, 0)})
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
        SoundService:StopSound(randSound)
        self.lastSlide = tick()
    end)

    self.slideJanitor:AddPromise(Tween(hum, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CameraOffset = Vector3.new(0, -1.7, 0)}))
    Tween(slideV, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Velocity = humanoidRootPart.CFrame.LookVector * 24})
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

    SoundService:PlaySound(nil, randSound, false)
end

function MovementController:Crouch(hum)
    self.isCrouching = true
    self.canSlide = false
    self.crouchJanitor:AddPromise(Tween(hum, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CameraOffset = Vector3.new(0, -1.7, 0)}))
    self.loadedAnimations.crouch:Play(0.2)
    self.crouchJanitor:Add(function()
        Tween(hum, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CameraOffset = Vector3.new(0, 0, 0)})
        self.isCrouching = false
        self.canSlide = true
        self.loadedAnimations.crouch:Stop(0.2)
    end)
end

function MovementController:KnitInit()
    HudController = Knit.GetController("HudController")
    WeaponController = Knit.GetController("WeaponController")
    SoundService = Knit.GetService("SoundService")

    self.airborneTime = 0
    self.value = SmoothValue:create(self.normalSpeed, self.normalSpeed, 4)
end

function MovementController:KnitStart()
    repeat task.wait() until Knit.Player:GetAttribute("Class")

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
        self.ziplineJanitor = Janitor.new()
        self.janitor:Add(self.sprintJanitor)
        self.janitor:Add(self.slideJanitor)
        self.janitor:Add(self.crouchJanitor)

        self.isSliding = false
        self.isZiplining = false
        self.zipJumpMultiplier = 1
        self.canSprint = true
        self.canSlide = true
        self.canZipline = true

        self.fovOffset.value = 0
        self.fovOffset.target = 0

        local canDoubleJump = false
        local hasDoubleJumped = false
        local oldPower = hum.JumpPower
        local TIME_BETWEEN_JUMPS = 0.2
        local DOUBLE_JUMP_POWER_MULTIPLIER = 1
        
        local function onJumpRequest()
            self.ziplineJanitor:Cleanup()
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
                self.zipJumpMultiplier = 1
                self.jumpCamSpring:Impulse(Vector3.new(-math.clamp(((math.abs(humanoidRootPart.Velocity.Y)/30) ^ 2), .5, 10),0,0))
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
                    SoundService:PlaySound(nil, "Jump", true)
                elseif canDoubleJump then
                    local s = ReplicatedStorage.Assets.Sounds.DoubleJump:Clone()
                    s.Parent = self.camera
                    s:Destroy()
                    SoundService:PlaySound(nil, "DoubleJump", true)
                end
                self.jumpCamSpring:Impulse(Vector3.new(-1,0,0))
            end
        end))
        
        self.janitor:Add(UserInputService.JumpRequest:Connect(onJumpRequest))

        local function handleAction(actionName, inputState)
            if actionName == "Sprint" then
                if not self.canSprint then return end
                if inputState == Enum.UserInputState.Begin then
                    if hum.MoveDirection.Magnitude > 0 and hum.WalkSpeed > 0 and getMovingDir() == "forward" then
                        self.isSprinting = true
                        self.value:set(self.sprintSpeed)
                        self.loadedAnimations.sprint:Play(0.3)
                        HudController.crosshairTransparency:set(1)
                        self.sprintJanitor:Add(function()
                            self.isSprinting = false
                            self.value:set(self.normalSpeed)
                            HudController.crosshairTransparency:set(0)
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
                            self:Crouch(hum, humanoidRootPart)
                        end
                    end
                elseif inputState == Enum.UserInputState.End then
                    self.crouchJanitor:Cleanup()
                    self.slideJanitor:Cleanup()
                end
            elseif actionName == "Zipline" then
                if inputState == Enum.UserInputState.Begin and self.canZipline and self.nearestZipline then
                    self.isZiplining = true
                    self.canZipline = false

                    local zipCF = self.nearestZipline.CFrame - Vector3.new(0, 4, 0)
                    local Transform = zipCF:PointToObjectSpace(character.HumanoidRootPart.Position)
                    local HalfSize = self.nearestZipline.Size * 0.5
                    local targetPos = zipCF * Vector3.new(
                        math.clamp(Transform.x, -HalfSize.x, HalfSize.x),
                        math.clamp(Transform.y, -HalfSize.y, HalfSize.y),
                        math.clamp(Transform.z, -HalfSize.z, HalfSize.z)
                    )

                    local zipMagnitude
                    if math.deg(math.acos(self.camera.CFrame.LookVector:Dot(zipCF.LookVector))) > 90 then
                        zipMagnitude = -50
                    else
                        zipMagnitude = 50
                    end
                    
                    character.HumanoidRootPart.CFrame = CFrame.new(targetPos)
                    hasDoubleJumped = true
                    local onSound = ReplicatedStorage.Assets.Sounds.ZiplineOn:Clone()
                    onSound.Parent = self.camera
                    onSound:Destroy()
                    SoundService:PlaySound(nil, "ZiplineOn", true)
                    local loopSound = ReplicatedStorage.Assets.Sounds.ZiplineLoop:Clone()
                    loopSound.Parent = self.camera
                    Tween(loopSound, TweenInfo.new(0.2), {Volume = 1})
                    loopSound:Play()

                    local ziplineVelocity = Instance.new("BodyVelocity")
                    self.ziplineJanitor:Add(ziplineVelocity)
                    ziplineVelocity.Name = "ZiplineVelocity"
                    ziplineVelocity.MaxForce = Vector3.new(1,1,1) * 30000
                    ziplineVelocity.Velocity = zipCF.LookVector * (zipMagnitude/4)
                    Tween(ziplineVelocity, TweenInfo.new(1, Enum.EasingStyle.Sine), {Velocity = zipCF.LookVector * zipMagnitude})
                    ziplineVelocity.Parent = character.HumanoidRootPart
                    self.airborneTime = 0

                    self.fovOffset:set(10)

                    self.ziplineJanitor:Add(function()
                        self.isZiplining = false
                        local offSound = ReplicatedStorage.Assets.Sounds.ZiplineOff:Clone()
                        offSound.Parent = self.camera
                        offSound:Destroy()
                        SoundService:PlaySound(nil, "ZiplineOff", true)
                        Tween(loopSound, TweenInfo.new(0.2), {Volume = 0}):andThen(function() loopSound:Destroy() end)

                        if self.nearestZipline then
                            local zipJumpVel = Instance.new("AlignPosition")
                            zipJumpVel.Mode = Enum.PositionAlignmentMode.OneAttachment
                            zipJumpVel.Attachment0 = humanoidRootPart.RootAttachment
                            zipJumpVel.Responsiveness = 60
                            zipJumpVel.Position = (humanoidRootPart.CFrame*CFrame.new(0, 6 * self.zipJumpMultiplier, -8 * self.zipJumpMultiplier)).Position
                            zipJumpVel.Parent = humanoidRootPart
                            task.delay(.1, function() if zipJumpVel then zipJumpVel:Destroy() end end)
                            self.zipJumpMultiplier *= 0.6
                            math.clamp(self.zipJumpMultiplier, 0, 1)
                        end

                        self.fovOffset:set(0)
                        task.delay(0.6, function() self.canZipline = true end)
                    end)

                    self.janitor:Add(self.ziplineJanitor)
                    pcall(function() self.sprintJanitor:Cleanup() end)
                    pcall(function() self.crouchJanitor:Cleanup() end)
                end
            end
        end 

        ContextActionService:BindAction("Sprint", handleAction, true, Enum.KeyCode.LeftShift)
        ContextActionService:BindAction("Crouch", handleAction, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl)
        ContextActionService:BindAction("Zipline", handleAction, true, Enum.KeyCode.E)
        self.janitor:Add(function()
            ContextActionService:UnbindAction("Sprint")
            ContextActionService:UnbindAction("Crouch")
            ContextActionService:UnbindAction("Zipline")
            self.isSprinting = false
        end)

        self.janitor:Add(hum:GetPropertyChangedSignal("MoveDirection"):Connect(function()
            if humanoidRootPart.Anchored == true then return end
            if hum.MoveDirection.Magnitude > 0 then
                if getMovingDir() ~= "forward" and not humanoidRootPart:FindFirstChild("SatchelOut") then
                    self.sprintJanitor:Cleanup()
                end
                if not self.isSprinting then
                    HudController.crosshairOffset:set(40)
                else
                    HudController.crosshairOffset:set(80)
                end
            else
                HudController.crosshairOffset:set(20)
                self.sprintJanitor:Cleanup()
            end
        end))
        
        local camoffset = CFrame.new()
        self.nearestZipline = nil

        self.janitor:Add(RunService.Heartbeat:Connect(function(dt)
            --WALKING
            if self.isSliding or self.isZiplining then
                hum.WalkSpeed = 0
                HudController.crosshairOffset:set(20)
            elseif self.isCrouching then
                hum.WalkSpeed = 8
            else
                hum.WalkSpeed = self.value:update(dt)
            end

            --CLIMBING
            local can = character and character.Humanoid and character.Humanoid.Health > 0 and character.Head
            if can then                
                if hum.FloorMaterial == Enum.Material.Air and canClimb and self.canClimb then
                    local raycastParams = RaycastParams.new()
                    raycastParams.FilterDescendantsInstances = {character, self.camera, CollectionService:GetTagged("Unclimbable")}
                    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                    for i = 0, 0.5, 0.1 do
                        local raycastResult = workspace:Raycast(character.Head.Position - Vector3.new(0,i,0), (character.Head.CFrame.LookVector - Vector3.new(0,i,0)).Unit * 3, raycastParams)
                        if raycastResult and raycastResult.Instance and raycastResult.Instance.CanCollide and not raycastResult.Instance:IsA("TrussPart") and not raycastResult.Instance.Parent:FindFirstChild("Humanoid") then
                            if character.Head.Position.Y >= (raycastResult.Instance.Position.Y + (raycastResult.Instance.Size.Y / 2)) - 1 and character.Head.Position.Y <= raycastResult.Instance.Position.Y + (raycastResult.Instance.Size.Y / 2) + 3 then 
                                if humanoidRootPart:FindFirstChild("SlideVel") then humanoidRootPart.SlideVel:Destroy() end 
                                local climbV = Instance.new("AlignPosition")
                                climbV.Mode = Enum.PositionAlignmentMode.OneAttachment
                                climbV.Attachment0 = humanoidRootPart.RootAttachment
                                climbV.Responsiveness = 50
                                climbV.Position = (humanoidRootPart.CFrame*CFrame.new(0, 4, -2)).Position
                                climbV.Parent = humanoidRootPart
                                task.delay(.1, function() if climbV then climbV:Destroy() end end)
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
            end
            
            --FORCE STOP SLIDING
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

            --FALLING
            if hum.FloorMaterial == Enum.Material.Air then
                local yVel = humanoidRootPart.Velocity.Magnitude
                if yVel > 50 then
                    self.airborneTime += 0.005
                end
            else
                self.airborneTime = 0
            end
            self.fallingSound.Volume = math.clamp(self.airborneTime, 0, 2)

            if hum:GetState() == Enum.HumanoidStateType.Climbing then 
                hum.WalkSpeed *= 2
            end

            --ZIPLINE
            local op = OverlapParams.new()
            op.FilterDescendantsInstances = {self.camera, character}
            op.FilterType = Enum.RaycastFilterType.Blacklist
            self.nearestZipline = nil
            for _, part in ipairs(workspace:GetPartBoundsInBox(character.HumanoidRootPart.CFrame, Vector3.new(14, 16, 14), op)) do
                if part.Parent == workspace.Ziplines and part.Name == "Zipline" then self.nearestZipline = part end
            end
            if not self.nearestZipline then
                self.isZiplining = false
                self.ziplineJanitor:Cleanup()
                HudController.ScreenGui.Frame.Interact.Visible = false
            else    
                if not self.isZiplining and self.canZipline then
                    HudController.ScreenGui.Frame.Interact.Visible = true
                else
                    HudController.ScreenGui.Frame.Interact.Visible = false
                end
            end

            --CAMERA
            self.jumpCamSpring:TimeSkip(dt)
            local newoffset = CFrame.Angles(self.jumpCamSpring.p.x,self.jumpCamSpring.p.y,self.jumpCamSpring.p.z)
            self.camera.CFrame = self.camera.CFrame * camoffset:Inverse() * newoffset
            camoffset = newoffset

            self.camera.FieldOfView = WeaponController.baseFov:update(dt) + self.fovOffset:update(dt)
        end))

        --RAGDOLL
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