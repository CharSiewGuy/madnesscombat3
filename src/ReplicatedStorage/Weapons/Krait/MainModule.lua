local module = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)

local Modules = ReplicatedStorage.Modules
local Spring = require(Modules.Spring)
local SmoothValue = require(Modules.SmoothValue)

module.janitor = Janitor.new()
module.camera = workspace.CurrentCamera
module.loadedAnimations = {}
module.springs = {}
module.lerpValues = {}
module.lerpValues.sprint = SmoothValue:create(0, 0, 10)

function module:GetBobbing(addition,speed,modifier)
    return math.sin(tick()*addition*speed)*modifier
end

function module:Equip(character, vm)
    local MovementController = Knit.GetController("MovementController")

    print(character.Name)

    self.camera.FieldOfView = 90

    local Krait = script.Parent.Krait:Clone()
    Krait.Parent = vm

    local weaponMotor6D = script.Parent.Handle:Clone()
    weaponMotor6D.Part0 = vm.HumanoidRootPart
    weaponMotor6D.Part1 = Krait.Handle
    weaponMotor6D.Parent = vm.HumanoidRootPart

    self.loadedAnimations.Idle = vm.AnimationController:LoadAnimation(script.Parent.Animations.Idle)
    self.loadedAnimations.Idle:Play()

    self.springs.sway = Spring.create()
    self.springs.walkCycle = Spring.create()
    local speed = 3
    local modifier = 0.03
    self.springs.jump = Spring.create(1, 10, 0, 1.8)

    self.janitor:Add(character.Humanoid.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Jumping then
            self.springs.jump:shove(Vector3.new(0, 0.3))
            task.delay(0.2, function()
                self.springs.jump:shove(Vector3.new(0, -0.3))
            end)
        elseif newState == Enum.HumanoidStateType.Landed then
            self.springs.jump:shove(Vector3.new(0, -0.5))
            task.delay(0.15, function()
                self.springs.jump:shove(Vector3.new(0, 0.5))
            end)
        end
    end))

    self.janitor:Add(RunService.RenderStepped:Connect(function(dt)
        local mouseDelta = UserInputService:GetMouseDelta()
        self.springs.sway:shove(Vector3.new(mouseDelta.X / 400,mouseDelta.Y / 400))
        local sway = self.springs.sway:update(dt)

        if MovementController.isSprinting then 
            self.lerpValues.sprint:set(1)
            speed = 2
            modifier = 0.06
        else
            self.lerpValues.sprint:set(0)
            speed = 3
            modifier = 0.03
        end

        local movementSway = Vector3.new(self:GetBobbing(10,speed,modifier),self:GetBobbing(5,speed,modifier),self:GetBobbing(5,speed,modifier))
        self.springs.walkCycle:shove((movementSway / 25) * dt * 60 * character.HumanoidRootPart.Velocity.Magnitude)
        local walkCycle = self.springs.walkCycle:update(dt)

        local jump = self.springs.jump:update(dt)

        local idleOffset = script.Parent.Offsets.Idle.Value
        local sprintOffset = idleOffset:lerp(script.Parent.Offsets.Sprint.Value, self.lerpValues.sprint:update(dt))
        local finalOffset = sprintOffset
        vm.HumanoidRootPart.CFrame = self.camera.CFrame:ToWorldSpace(finalOffset)

        vm.HumanoidRootPart.CFrame = vm.HumanoidRootPart.CFrame:ToWorldSpace(CFrame.new(walkCycle.x, walkCycle.y * 2, 0))
        
        if MovementController.isSprinting then
            vm.HumanoidRootPart.CFrame =  vm.HumanoidRootPart.CFrame * CFrame.Angles(jump.y,walkCycle.y, walkCycle.x/2)
        else
            vm.HumanoidRootPart.CFrame =  vm.HumanoidRootPart.CFrame * CFrame.Angles(0,walkCycle.y/2, 0)
        end

        vm.HumanoidRootPart.CFrame = vm.HumanoidRootPart.CFrame * CFrame.Angles(jump.y,-sway.x,sway.y)
    end))

    self.janitor:Add(function()
        self.loadedAnimations = {}
    end)
end

function module:Unequip(character)
    self.janitor:Cleanup()
    print(character.Name)
end

return module