local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)

local SoundController = Knit.CreateController { Name = "SoundController" }
SoundController.janitor = Janitor.new()

local SoundService

function SoundController:KnitInit()
    SoundService = Knit.GetService("SoundService")
    
    self.charspeed = 0
    self.fsinterval = 0
    self.lastplayedfs = 0
    self.lastplayednum = 0
end

function SoundController:KnitStart()
    repeat task.wait() until Knit.Player:GetAttribute("Class")

    local WalkingFootsteps = game.SoundService:WaitForChild("WalkingFootsteps")
    local RunningFootsteps = game.SoundService:WaitForChild("RunningFootsteps")

    Knit.Player.CharacterAdded:Connect(function(character)
        self.janitor:Add(character:WaitForChild("Humanoid").Running:Connect(function(speed)
            self.charspeed = speed
            self.fsinterval = 6/self.charspeed
        end))

        self.janitor:Add(RunService.Heartbeat:Connect(function()
            if self.charspeed > 0 and character.Humanoid.FloorMaterial ~= Enum.Material.Air and character.Humanoid.WalkSpeed > 0 then
                if tick() - self.lastplayedfs > self.fsinterval then
                    self.lastplayedfs = tick()
                    self.lastplayednum += 1
                    if self.lastplayednum > 5 then
                        self.lastplayednum = 1
                    end
                    local sound
                    local mat = "Concrete"
                    if character.Humanoid.FloorMaterial == Enum.Material.Wood or character.Humanoid.FloorMaterial == Enum.Material.WoodPlanks then
                        mat = "Wood"
                    end 
                    if character.Humanoid.WalkSpeed >= 20 then
                        sound = RunningFootsteps:WaitForChild(mat .. self.lastplayednum):Clone()
                        SoundService:PlaySound(RunningFootsteps, mat .. self.lastplayednum, true)
                    else
                        sound = WalkingFootsteps:WaitForChild(mat .. self.lastplayednum):Clone()
                        SoundService:PlaySound(WalkingFootsteps, mat .. self.lastplayednum, true)
                    end
                    if not sound then return end
                    sound.Parent = workspace.CurrentCamera
                    sound:Destroy()
                end
            end
        end))
        
        character.Humanoid.Died:Connect(function()
            self.charspeed = 0
            self.janitor:Cleanup()
        end)
    end)

    SoundService.PlaySignal:Connect(function(character, weapon, name, playOnRemove)
        local can
        pcall(function() can = character and character:FindFirstChild("HumanoidRootPart") end)
        if not can then return end
        local sound
        if weapon == nil then
            sound = ReplicatedStorage.Assets.Sounds:FindFirstChild(name)
        elseif type(weapon) == "string" then
            if ReplicatedStorage.Weapons:FindFirstChild(weapon) then
                sound = ReplicatedStorage.Weapons[weapon].Sounds:FindFirstChild(name)
            else
                sound = ReplicatedStorage.Classes[weapon].Sounds:FindFirstChild(name)
            end
        elseif weapon:IsA("SoundGroup") then
            sound = weapon:FindFirstChild(name)
        end
        if sound then
            local soundClone = sound:Clone()
            pcall(function() soundClone.Parent = character.HumanoidRootPart end)
            if playOnRemove then
                soundClone:Destroy()
            else
                soundClone:Play()
                task.delay(soundClone.TimeLength, function()
                    if soundClone then
                        soundClone:Destroy()
                    end
                end)
            end
        end
    end)

    SoundService.StopSignal:Connect(function(character, name)
        if not character:FindFirstChild("HumanoidRootPart") then return end
        local sound = character.HumanoidRootPart:FindFirstChild(name)
        if sound then
            sound:Destroy()
        end
    end)
end

return SoundController