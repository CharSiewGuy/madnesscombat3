local ReplicatedStorage = game:GetService("ReplicatedStorage")
--local UserInputService = game:GetService("UserInputService") 

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
--local Promise = require(Packages.Promise)
local Janitor = require(Packages.Janitor)
local Tween = require(Packages.TweenPromise)
local Timer = require(Packages.Timer)

local Modules = ReplicatedStorage.Modules
local Spring = require(Modules.Spring)
local CoreCall = require(Modules.CoreCall)

local PvpService

local ClassSelectController = Knit.CreateController { Name = "ClassSelectController" }
ClassSelectController.janitor = Janitor.new()
ClassSelectController.uiJanitor = Janitor.new()

function ClassSelectController:KnitInit()
    PvpService = Knit.GetService("PvpService")   
    self.ClassSelectUI = Knit.Player.PlayerGui:WaitForChild("ClassSelect")
    self.springs = {}
end

function ClassSelectController:KnitStart()
    self.ClassSelectUI.Enabled = true

    local VoidstalkerFrame = self.ClassSelectUI:WaitForChild("Frame"):WaitForChild("Voidstalker")

    VoidstalkerFrame.TextButton.MouseEnter:Connect(function()
        Tween(VoidstalkerFrame, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(103, 1, 255)})
        Tween(VoidstalkerFrame.Image, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(0, 0, 0)})
        Tween(VoidstalkerFrame.Text, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(0, 0, 0)})
        self.ClassSelectUI:WaitForChild("Hover"):Play()
    end)

    VoidstalkerFrame.TextButton.MouseLeave:Connect(function()
        Tween(VoidstalkerFrame, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(0, 0, 0)})
        Tween(VoidstalkerFrame.Image, TweenInfo.new(0.3), {ImageColor3 = Color3.fromRGB(255,255,255)})
        Tween(VoidstalkerFrame.Text, TweenInfo.new(0.3), {TextColor3 = Color3.fromRGB(255,255,255)})
    end)

    self.uiJanitor:Add(VoidstalkerFrame.TextButton.MouseButton1Click:Connect(function()
        self.uiJanitor:Cleanup()

        PvpService:SetClass(1):andThen(function(success)
            if success then
                Knit.Player:SetAttribute("Class", "Voidstalker")
            end
        end)

        Tween(self.ClassSelectUI.Black, TweenInfo.new(1), {BackgroundTransparency = 0})
        Tween(game.Lighting.ClassSelectBlur, TweenInfo.new(0.4), {Size = 30})
        
        task.delay(1, function()
            game.Lighting.ClassSelectBlur.Size = 0
            self.ClassSelectUI.Frame.Visible = false
            self.ClassSelectUI.TextLabel.Visible = false
            self.ClassSelectUI.TextLabelDS.Visible = false
            self.janitor:Cleanup()
            Tween(self.ClassSelectUI:WaitForChild("Sound"), TweenInfo.new(4), {Volume = 0})
        end)

        self.ClassSelectUI:WaitForChild("Click"):Play()
    end))

    local camera = workspace.CurrentCamera
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = workspace.ClassSelect.Cam1.CFrame
    local curCamSpot = 1
    local cameraCycle = Timer.new(10)
    self.janitor:Add(cameraCycle)
    cameraCycle:Start()
    cameraCycle.Tick:Connect(function()
        Tween(game.Lighting.ClassSelectCC, TweenInfo.new(0.4), {Brightness = -1}):andThen(function()
            curCamSpot += 1
            if curCamSpot > 3 then curCamSpot = 1 end
            Tween(game.Lighting.ClassSelectCC, TweenInfo.new(0.4), {Brightness = 0})
        end)
    end)

    self.springs.sway = Spring.create()

    local mouse = Knit.Player:GetMouse()

    self.janitor:Add(game:GetService("RunService").RenderStepped:Connect(function()
        camera.CFrame = workspace.ClassSelect["Cam" .. curCamSpot].CFrame
        local currentTime = tick()
        local bobbleX = math.sin(currentTime) * .1
        local bobbleY = math.abs(math.cos(currentTime)) * .05
        local rotateX = math.sin(currentTime) * 2 * .01
        local rotateY = math.sin(currentTime + math.pi/4) * .01
        
        local bobble = Vector3.new(bobbleX, bobbleY, 0) 
     
        camera.CFrame *= CFrame.new(bobble) * CFrame.Angles(rotateX, rotateY, 0)

        local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
        local moveVector = Vector3.new((mouse.X-center.X)/2500, -(mouse.Y-center.Y)/2000, 0)
        camera.CFrame *= CFrame.new(moveVector/6) * CFrame.Angles(math.rad(moveVector.Y) * 15, math.rad(moveVector.X * -1) * 15, 0)
    end))

    CoreCall('SetCore', 'ResetButtonCallback', false)
    self.ClassSelectUI:WaitForChild("Sound"):Play()
end

return ClassSelectController