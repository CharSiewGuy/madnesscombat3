local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OgSoundService = game:GetService("SoundService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
--local Promise = require(Packages.Promise)
local Janitor = require(Packages.Janitor)
local Tween = require(Packages.TweenPromise)

local Modules = ReplicatedStorage.Modules
local CoreCall = require(Modules.CoreCall)

local CharacterController = Knit.CreateController { Name = "CharacterController" }
CharacterController.janitor = Janitor.new()

local PvpService 
local SoundService 
local HudController

function CharacterController:KnitInit()
    PvpService = Knit.GetService("PvpService")
    SoundService = Knit.GetService("SoundService")
    HudController = Knit.GetController("HudController")
end

function CharacterController:KnitStart()
    repeat task.wait() until Knit.Player:GetAttribute("Class")

    Knit.Player.CharacterAdded:Connect(function(character)
        game.Lighting.ClassSelectBlur.Size = 0
        game.Lighting.ClassSelectCC.Brightness = 0
        Tween(Knit.GetController("ClassSelectController").ClassSelectUI.Black, TweenInfo.new(1), {BackgroundTransparency = 1})
        CoreCall('SetCore', 'ResetButtonCallback', true)

        workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        local sound = ReplicatedStorage.Assets.Sounds.Spawn:Clone()
        sound.Parent = workspace.CurrentCamera
        sound:Destroy()
        SoundService:PlaySound(nil, "Spawn", true)

        local hum = character:WaitForChild("Humanoid")
        
        self.janitor:Add(hum.StateChanged:Connect(function(_, _)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        end))
        
        self.janitor:Add(PvpService.OnDamagedSignal:Connect(function(p)
            if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                HudController:ShowDamageDir(p.Character.Name, p.Character.HumanoidRootPart.Position)
            end
        end))

        hum.Died:Connect(function()
            self.janitor:Cleanup()
        end)

        OgSoundService:WaitForChild("Ambience"):WaitForChild("Sound").Volume = 0.2
    end)

end
return CharacterController