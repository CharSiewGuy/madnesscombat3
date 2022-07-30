local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)
local Promise = require(Packages.Promise)
local Tween = require(Packages.TweenPromise)
local Timer = require(Packages.Timer)
local Option = require(Packages.Option)

local Modules = ReplicatedStorage.Modules
local SmoothValue = require(Modules.SmoothValue)
local Spring = require(Modules.Spring)
local Spring4 = require(Modules.Spring4)

local HudController = Knit.CreateController { Name = "HudController" }
HudController.janitor = Janitor.new()

local PvpService

function HudController:KnitInit()
    PvpService = Knit.GetService("PvpService")

    self.crosshairOffset = SmoothValue:create(20, 20, 4)
    self.crosshairOffset2 = SmoothValue:create(0,0,20)
    self.isAiming = false
    self.crosshairOffsetMultiplier = 2
    self.crosshairTransparency = SmoothValue:create(0,0,4)
    self.dotTransparency = SmoothValue:create(0,0,15)
    
    self.score = 0

    self.hudShakeMagnitude = SmoothValue:create(0,0,5)
    self.hudShakeFrequency = 0.1
    self.hudShakeOffset = Vector2.new()
    self.springs = {}
    self.springs.jumpSway = Spring4.new(Vector3.new())
    self.springs.jumpSway.Speed = 5
    self.springs.jumpSway.Damper = 1
end

function HudController:KnitStart()
    local StarterGui = game:GetService("StarterGui")
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

    repeat task.wait() until Knit.Player:GetAttribute("Class")
    Knit.Player.CharacterAdded:Wait()

    --3D hud poggers
    self.camera = workspace.CurrentCamera
    self.guiPart = ReplicatedStorage:WaitForChild("GuiPart"):Clone()
    self.guiPart.Parent = self.camera
    self.guiPartOriginalSize = self.guiPart.Size

    self.springs.guiSway = Spring.create()

    RunService.RenderStepped:Connect(function(dt)
        self.guiPart.CFrame = self.camera.CFrame
        self.guiPart.CFrame *= CFrame.new(0,0,-24) * CFrame.Angles(-0.075, 0, 0)
        self.guiPart.Size = self.guiPartOriginalSize * self.camera.FieldOfView/90

        local currentTime = tick()
        local mag = self.hudShakeMagnitude:update(dt)
        local freq = self.hudShakeFrequency
        local shakeX = math.cos(currentTime/freq) * mag
        local shakeY = math.abs(math.sin(currentTime/freq)) * 1.5 * mag 
        self.hudShakeOffset = self.hudShakeOffset:Lerp(Vector2.new(shakeX, shakeY), 0.2)

        self.guiPart.CFrame *= CFrame.new(self.hudShakeOffset.X, self.hudShakeOffset.Y, 0)

        local mouseDelta = UserInputService:GetMouseDelta()
        self.springs.guiSway:shove(Vector3.new(mouseDelta.X/420,mouseDelta.Y/420))
        local sway = self.springs.guiSway:update(dt)
        self.guiPart.CFrame *= CFrame.new(-sway.x * 20,-sway.y * 20, 0) * CFrame.Angles(-sway.y/6,-sway.x/6, 0)

        self.springs.jumpSway:TimeSkip(dt)
        local newoffset = CFrame.new(self.springs.jumpSway.p.x,self.springs.jumpSway.p.y,self.springs.jumpSway.p.z)
        self.guiPart.CFrame *= newoffset
    end)

    self.ScreenGui = self.guiPart:WaitForChild("SurfaceGui")
    self.ScreenGui.Enabled = true
    self.Overlay = Knit.Player.PlayerGui:WaitForChild("Overlay")
    self.Overlay.Enabled = true

    self.Tutorial = Knit.Player.PlayerGui:WaitForChild("Tutorial")
    self.Tutorial.Frame.Visible = true
    game.Lighting.TutorialBlur.Enabled = true

    self.Tutorial.Frame.InnerFrame.TextButton.MouseButton1Click:Connect(function()
        Tween(game.Lighting.TutorialBlur, TweenInfo.new(0.2), {Size = 0}):andThen(function()
            game.Lighting.TutorialBlur:Destroy()
        end)
        self.Tutorial:Destroy()
        Knit.GetController("InputController").mouseLocked = true
        self.Overlay.Crosshair.Visible = true
    end)

    if RunService:IsStudio() then
        game.Lighting.TutorialBlur:Destroy()
        self.Tutorial:Destroy()
        Knit.GetController("InputController").mouseLocked = true
        self.Overlay.Crosshair.Visible = true
    end

    RunService.Heartbeat:Connect(function(dt)
        if self.isAiming then
            self.crosshairOffset:set(5)
        end
        self.Overlay.Crosshair.Bottom.Position = UDim2.new(0.5, 0, 0.5, self.crosshairOffset:update(dt) * self.crosshairOffsetMultiplier + self.crosshairOffset2:update(dt))
        self.Overlay.Crosshair.Top.Position = UDim2.new(0.5, 0, 0.5, -self.crosshairOffset:update(dt) * self.crosshairOffsetMultiplier - self.crosshairOffset2:update(dt))
        self.Overlay.Crosshair.Right.Position = UDim2.new(0.5, self.crosshairOffset:update(dt) * self.crosshairOffsetMultiplier + self.crosshairOffset2:update(dt), 0.5, 0)
        self.Overlay.Crosshair.Left.Position = UDim2.new(0.5, -self.crosshairOffset:update(dt)* self.crosshairOffsetMultiplier - self.crosshairOffset2:update(dt), 0.5, 0)

        self.Overlay.Crosshair.Bottom.BackgroundTransparency = self.crosshairTransparency:update(dt)
        self.Overlay.Crosshair.Top.BackgroundTransparency = self.crosshairTransparency:update(dt)
        self.Overlay.Crosshair.Right.BackgroundTransparency = self.crosshairTransparency:update(dt)
        self.Overlay.Crosshair.Left.BackgroundTransparency = self.crosshairTransparency:update(dt)
        self.Overlay.Crosshair.Dot.BackgroundTransparency = self.dotTransparency:update(dt)

        for _, v in pairs(self.Overlay.DamageIndicators:GetChildren()) do
            local myPosition = workspace.CurrentCamera.CFrame.Position
            local enemyPosition = v:GetAttribute("Pos")
            local camCFrame = workspace.CurrentCamera.CFrame
            local flatCFrame = CFrame.lookAt(myPosition, myPosition + camCFrame.LookVector * Vector3.new(1, 0, 1))
            local travel = flatCFrame:Inverse() * enemyPosition 
            local rot = math.atan2(travel.Z, travel.X)
            v.Rotation = math.deg(rot) + 90
        end
    end)

    Timer.Simple(0.1, function()
        for _, v in pairs(self.ScreenGui.Frame.Scoreboard.InnerFrame.Frame:GetChildren()) do
            if v:IsA("Frame") then v:Destroy() end
        end

        local array = {}
        for _, v in pairs(game.Players:GetPlayers()) do
            array[#array+1] = {key = v.Name, value = tonumber(v:GetAttribute("Score"))}
        end
        table.sort(array, function(a, b)
            return a.value > b.value
        end)

        for i, v in ipairs(array) do
            local playerFrame = ReplicatedStorage.Assets.ScoreboardPlayerFrame:Clone()
            playerFrame.Name = string.char(i + 64)
            local player = game.Players:FindFirstChild(v.key)
            playerFrame.PlayerName.Text = string.upper(v.key)
            playerFrame.Kills.Text = player:GetAttribute("Kills")
            playerFrame.Deaths.Text = player:GetAttribute("Deaths")
            playerFrame.Score.Text = v.value
            if v.key ~= Knit.Player.Name then
                if i % 2 == 0 then
                    playerFrame.BackgroundTransparency = 1
                else
                    playerFrame.BackgroundTransparency = 0.5
                    playerFrame.BackgroundColor3 = Color3.fromRGB(0,0,0)
                end
                for _, text in pairs(playerFrame:GetChildren()) do text.TextColor3 = Color3.fromRGB(255,255,255) end
            end
            playerFrame.Parent = self.ScreenGui.Frame.Scoreboard.InnerFrame.Frame
        end
    end)

    PvpService.NewKillSignal:Connect(function(playerName, weaponName, deadPlayerName)
        local killfeed = self.ScreenGui.Frame:WaitForChild("Killfeed")
        local killfeedFrame = ReplicatedStorage.Assets:WaitForChild("KillfeedFrame"):Clone()
        killfeedFrame.Parent = killfeed
        killfeedFrame.WeaponIcon.Image = ReplicatedStorage.Weapons[weaponName].WeaponIconFlipped.Image
        killfeedFrame.Top.WeaponIcon.Image = ReplicatedStorage.Weapons[weaponName].WeaponIconFlipped.Image
        killfeedFrame.P1.Text = playerName
        killfeedFrame.Top.P1.Text = playerName
        killfeedFrame.P2.Text = deadPlayerName
        killfeedFrame.Top.P2.Text = deadPlayerName

        if playerName == Knit.Player.Name then
            killfeedFrame.Top.P1.TextColor3 = Color3.fromRGB(227, 193, 0)
        end

        killfeedFrame.Name = tick()

        if #killfeed:GetChildren() > 6 then
            local lowest = math.huge
            local function setLowest(v)
                if not v:IsA("Frame") then return end
                if tonumber(v.Name) < lowest then lowest = tonumber(v.Name) end
            end
            for _, v in ipairs(killfeed:GetChildren()) do
               setLowest(v)
            end
            killfeed[tostring(lowest)]:Destroy()
        end

        task.delay(8, function()
            killfeedFrame:Destroy()
        end)
    end)

    ContextActionService:BindAction("Scoreboard", function(action, inputState)
        if action == "Scoreboard" then
            if inputState == Enum.UserInputState.Begin then
                Tween(game.Lighting.ScoreboardBlur, TweenInfo.new(0.2), {Size = 12})
                self.Overlay.Crosshair.Visible = false
                self.ScreenGui.Frame.Scoreboard.Visible = true
            elseif inputState == Enum.UserInputState.End then
                Tween(game.Lighting.ScoreboardBlur, TweenInfo.new(0.2), {Size = 0})
                self.Overlay.Crosshair.Visible = true
                self.ScreenGui.Frame.Scoreboard.Visible = false
            end
        end
    end, true, Enum.KeyCode.Tab)

    Knit.Player:GetAttributeChangedSignal("UltCharge"):Connect(function()
        local percentage = Knit.Player:GetAttribute("UltCharge")
        local gradientRotation = (percentage/100) * 180
        Tween(self.ScreenGui.Frame.UltProgress.HalfFrame.ImageLabel.UIGradient, TweenInfo.new(0.2), {Rotation = gradientRotation})
        self.ScreenGui.Frame.Ult.Frame.Percentage.Text = percentage .. "%"
    end)

    Knit.Player:GetAttributeChangedSignal("IsUltReady"):Connect(function()
        if Knit.Player:GetAttribute("IsUltReady") then
            local notif = self.ScreenGui.Frame.UltChargedNotif
            notif.BackgroundTransparency = 0.6
            notif.TextLabel.TextTransparency = 0
            notif.TextLabel.TextStrokeTransparency = 0.8
            notif.Size = UDim2.fromScale(0.25, 0.1)
            Tween(notif, TweenInfo.new(0.2), {Size = UDim2.fromScale(0.2, 0.05)})
            
            task.delay(3, function()
                Tween(notif, TweenInfo.new(1), {BackgroundTransparency = 1})
                Tween(notif.TextLabel, TweenInfo.new(1), {TextTransparency = 1, TextStrokeTransparency = 1})
            end)

            Tween(game.Lighting.ColorCorrection, TweenInfo.new(0.5), {TintColor = Color3.fromRGB(255, 245, 225)}):andThen(function()
                Tween(game.Lighting.ColorCorrection, TweenInfo.new(1), {TintColor = Color3.fromRGB(255, 255, 255)})
            end)
        end
    end)
end

function HudController:ExpandCrosshair()
    self.crosshairOffset2.speed = 20
    self.crosshairOffset2:set(20)
    task.delay(0.05, function()
        self.crosshairOffset2.speed = 4
        self.crosshairOffset2:set(0)
    end)
end

function HudController:SetCurWeapon(weaponName)
    local weaponStats = self.ScreenGui.Frame.WeaponStats
    if weaponStats:FindFirstChild("WeaponIcon") then weaponStats.WeaponIcon:Destroy() end
    local icon = ReplicatedStorage.Weapons[weaponName].WeaponIcon
    if icon then
        local c = icon:Clone()
        c.Parent = weaponStats
    end
    Tween(weaponStats.ColorFrame, TweenInfo.new(0.2), {BackgroundColor3 = ReplicatedStorage.Weapons[weaponName]:GetAttribute("Color")})
end

function HudController:SetBullets(num, max)
    if not self.ScreenGui then return end
    self.ScreenGui.Frame.WeaponStats.Bullets.Cur.Text = num
    if max/num >= 3 then
        self.ScreenGui.Frame.WeaponStats.Bullets.Cur.TextColor3 = Color3.fromRGB(247, 70, 0)
    else
        self.ScreenGui.Frame.WeaponStats.Bullets.Cur.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
    if max then self.ScreenGui.Frame.WeaponStats.Bullets.Max.Text = max end
end

HudController.lastShownHitmarker = tick()
HudController.hitmarkerJanitor = Janitor.new()
HudController.hitmarkerTweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
HudController.headHitmarkerTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad)

function HudController:ShowHitmarker(crit)
    self.lastShownHitmarker = tick()
    local hitmarker = self.Overlay.Crosshair.Hitmarker
    for _, v in pairs(hitmarker:GetChildren()) do
        v.BackgroundTransparency = 0
    end
    self.hitmarkerJanitor:Cleanup()
    self.Overlay.Crosshair.Hitmarker.Bottom.Position = UDim2.new(0.5, 0, 0.5, 20)
    self.Overlay.Crosshair.Hitmarker.Top.Position = UDim2.new(0.5, 0, 0.5, -20)
    self.Overlay.Crosshair.Hitmarker.Right.Position = UDim2.new(0.5, 20, 0.5, 0)
    self.Overlay.Crosshair.Hitmarker.Left.Position = UDim2.new(0.5, -20, 0.5, 0)

    if crit then
        self.hitmarkerJanitor:AddPromise(Tween(self.Overlay.Crosshair.Hitmarker.Bottom, self.headHitmarkerTweenInfo, {Position = UDim2.new(0.5, 0, 0.5, 30)}))
        self.hitmarkerJanitor:AddPromise(Tween(self.Overlay.Crosshair.Hitmarker.Top, self.headHitmarkerTweenInfo, {Position = UDim2.new(0.5, 0, 0.5, -30)}))
        self.hitmarkerJanitor:AddPromise(Tween(self.Overlay.Crosshair.Hitmarker.Right, self.headHitmarkerTweenInfo, {Position = UDim2.new(0.5, 30, 0.5, 0)}))
        self.hitmarkerJanitor:AddPromise(Tween(self.Overlay.Crosshair.Hitmarker.Left, self.headHitmarkerTweenInfo, {Position = UDim2.new(0.5, -30, 0.5, 0)}))
    end

    local lifetime = 0.1
    if crit then lifetime = 0.5 end

    Promise.delay(lifetime):andThen(function()
        if tick() - self.lastShownHitmarker > lifetime then
            for _, v in pairs(hitmarker:GetChildren()) do
                self.hitmarkerJanitor:AddPromise(Tween(v, self.hitmarkerTweenInfo, {BackgroundTransparency = 1}))
            end
            self.hitmarkerJanitor:AddPromise(Tween(self.Overlay.Crosshair.Hitmarker.Bottom, self.hitmarkerTweenInfo, {Position = UDim2.new(0.5, 0, 0.5, 5)}))
            self.hitmarkerJanitor:AddPromise(Tween(self.Overlay.Crosshair.Hitmarker.Top, self.hitmarkerTweenInfo, {Position = UDim2.new(0.5, 0, 0.5, -5)}))
            self.hitmarkerJanitor:AddPromise(Tween(self.Overlay.Crosshair.Hitmarker.Right, self.hitmarkerTweenInfo, {Position = UDim2.new(0.5, 5, 0.5, 0)}))
            self.hitmarkerJanitor:AddPromise(Tween(self.Overlay.Crosshair.Hitmarker.Left, self.hitmarkerTweenInfo, {Position = UDim2.new(0.5, -5, 0.5, 0)}))
        end
    end)

    if crit then
        for _, v in pairs(hitmarker:GetChildren()) do
            v.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        end    
    else
        for _, v in pairs(hitmarker:GetChildren()) do
            v.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        end     
    end
end

function HudController:ShowVignette(val, time)
    if val then
        Tween(self.Overlay.Vignette, TweenInfo.new(time), {ImageTransparency = 0.1})
    else
        Tween(self.Overlay.Vignette, TweenInfo.new(time), {ImageTransparency = 0.5})
    end
end

HudController.BloodTweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
HudController.LastChangedHealth = 0
HudController.HealthJanitor = Janitor.new()

function HudController:SetHealth(h, mh)
    self.HealthJanitor:Cleanup()
    self.LastChangedHealth = tick()
    self.ScreenGui.Frame.HealthBar.Health.Health.Text = math.floor(h)
    self.ScreenGui.Frame.HealthBar.HealthDS.Health.Text = math.floor(h)
    if h ~= 100 then
        self.ScreenGui.Frame.HealthBar.BackgroundTransparency = 0.6
        self.ScreenGui.Frame.HealthBar.Bar.BackgroundTransparency = 0
    end
    task.delay(1, function()
        if tick() - self.LastChangedHealth >= 1 then
            self.HealthJanitor:AddPromise(Tween(self.ScreenGui.Frame.HealthBar, TweenInfo.new(.5), {BackgroundTransparency = 1}))
            self.HealthJanitor:AddPromise(Tween(self.ScreenGui.Frame.HealthBar.Bar, TweenInfo.new(.5), {BackgroundTransparency = 1}))
        end
    end)
    if h > 70 then
        self.ScreenGui.Frame.HealthBar.Health.ImageLabel.ImageColor3   = Color3.fromRGB(255,255,255)
        self.ScreenGui.Frame.HealthBar.Health.Health.TextColor3 = Color3.fromRGB(255,255,255)
        self.ScreenGui.Frame.HealthBar.Bar.BackgroundColor3 = Color3.fromRGB(255,255,255)
    elseif h > 35 then
        self.ScreenGui.Frame.HealthBar.Health.ImageLabel.ImageColor3   = Color3.fromRGB(243, 203, 0)
        self.ScreenGui.Frame.HealthBar.Health.Health.TextColor3   = Color3.fromRGB(243, 203, 0)
        self.ScreenGui.Frame.HealthBar.Bar.BackgroundColor3   = Color3.fromRGB(243, 203, 0)
    else
        self.ScreenGui.Frame.HealthBar.Health.ImageLabel.ImageColor3   = Color3.fromRGB(247, 70, 0)
        self.ScreenGui.Frame.HealthBar.Health.Health.TextColor3   = Color3.fromRGB(247, 70, 0)
        self.ScreenGui.Frame.HealthBar.Bar.BackgroundColor3   = Color3.fromRGB(247, 70, 0)
    end
    Tween(self.ScreenGui.Frame.HealthBar.Bar, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.fromScale(h/mh, 1)})
    Tween(self.Overlay.Blood, self.BloodTweenInfo, {ImageTransparency = h/mh})
    Tween(self.Overlay.Blood2, self.BloodTweenInfo, {ImageTransparency = h/mh})
    Tween(self.Overlay.Vignette2, self.BloodTweenInfo, {ImageTransparency = h/mh})
    --yanderedev
    if h < 50 then
        if h <= 0 then
            self.Overlay.Heartbeat.Volume = 0
            game.Lighting.ColorCorrection.Saturation = -0.6
        elseif h < 10 then
            game.Lighting.ColorCorrection.Saturation = -0.5
            self.Overlay.Heartbeat.Volume = 1
        elseif h < 20 then
            game.Lighting.ColorCorrection.Saturation = -0.4
            self.Overlay.Heartbeat.Volume = 0.8
        elseif h < 30 then
            game.Lighting.ColorCorrection.Saturation = -0.3
            self.Overlay.Heartbeat.Volume = 0.6
        elseif h < 40 then
            game.Lighting.ColorCorrection.Saturation = -0.2
            self.Overlay.Heartbeat.Volume = 0.4
        else
            self.Overlay.Heartbeat.Volume = 0.2
            game.Lighting.ColorCorrection.Saturation = -0.1
        end
    else
        self.Overlay.Heartbeat.Volume = 0
        game.Lighting.ColorCorrection.Saturation = 0
    end
end

HudController.lastChangedScore = 0

function HudController:AddScore(scoreNum, reason)
    self.lastChangedScore = tick()

    local score = self.ScreenGui.Frame.Score:FindFirstChild("Score")
    if not score then score = ReplicatedStorage.Assets.Score:Clone() end
    score.TextTransparency = 1
    score.TextStrokeTransparency = 1
    score.Size = UDim2.fromScale(0.3, 0.4)
    Tween(score, TweenInfo.new(0.2), {Size = UDim2.fromScale(0.3, 0.15), TextTransparency = 0, TextStrokeTransparency = 0.8})
    score.Text = "+" .. score:GetAttribute("num") + scoreNum
    score:SetAttribute("num", score:GetAttribute("num") + scoreNum)
    score.Parent = self.ScreenGui.Frame.Score

    local scoreBg = self.ScreenGui.Frame.Score:FindFirstChild("ScoreBg")
    if not scoreBg then scoreBg = ReplicatedStorage.Assets.ScoreBg:Clone() end
    scoreBg.TextTransparency = 1
    scoreBg.Size = UDim2.fromScale(0.3, 0.4)
    Tween(scoreBg, TweenInfo.new(0.2), {Size = UDim2.fromScale(0.3, 0.15), TextTransparency = 0.5})
    scoreBg.Text = "+" .. scoreBg:GetAttribute("num") + scoreNum
    scoreBg:SetAttribute("num", scoreBg:GetAttribute("num") + scoreNum)
    scoreBg.Parent = self.ScreenGui.Frame.Score

    task.delay(2, function()
        if tick() - self.lastChangedScore >= 1 then
            Tween(score, TweenInfo.new(0.3), {TextTransparency = 1, TextStrokeTransparency = 1})
            Tween(scoreBg, TweenInfo.new(0.3), {TextTransparency = 1})
            task.delay(0.3, function()
                if tick() - self.lastChangedScore >= 1.3 then
                    score:Destroy()
                    scoreBg:Destroy()
                end
            end)
        end
    end)

    local scoreText = ReplicatedStorage.Assets.ScoreText:Clone()
    scoreText.Text = string.upper(reason)
    scoreText.Parent = self.ScreenGui.Frame.Score.Frame
    task.delay(2, function()
        Tween(scoreText, TweenInfo.new(0.3), {TextTransparency = 1, TextStrokeTransparency = 1})
        task.delay(0.3, function()
            scoreText:Destroy()
        end)
    end)

    self.score += scoreNum
    PvpService:SetScore(self.score)
end

function HudController:PromptKill(name)
    self:ShowHitmarker(true)
    for _, v in pairs(self.ScreenGui.Frame.KillPromptArea:GetChildren()) do
        v.Position = UDim2.fromScale(0, v.Position.Y.Scale + 0.6)
    end
    local killPrompt = ReplicatedStorage.Assets.KillPrompt:Clone()
    killPrompt.PlayerName.Text = '<font color = "#FFFFFF">' .. "KILLED " .. "</font>" .. string.upper(name)
    killPrompt.Position = UDim2.fromScale(0, 0)
    killPrompt.PlayerName.Size = UDim2.fromScale(1, 1)
    killPrompt.Parent = self.ScreenGui.Frame.KillPromptArea
    task.delay(2.5, function()
        Tween(killPrompt.PlayerName, TweenInfo.new(0.3), {TextTransparency = 1, TextStrokeTransparency = 1})
        Tween(killPrompt.Bg, TweenInfo.new(0.3), {ImageTransparency = 1})
        task.spawn(function()
            local fx = require(ReplicatedStorage.Modules.GlitchEffect)
            for _, v in pairs(fx) do
                local fadeOutFxOpt = Option.Some(killPrompt:FindFirstChild("FadeOutFx"))
                fadeOutFxOpt:Match{
                    Some = function(fadeOutFx)
                        fadeOutFx.Image = v
                        task.wait()
                    end,
                    None = function() return end
                }
            end
        end)
        task.delay(.6, function()
            killPrompt:Destroy()
        end)
    end)
end

local damageDirDur = 0.5

function HudController:ShowDamageDir(playerName, pos)
    local can = self.Overlay.DamageIndicators:FindFirstChild(playerName) and tick() - self.Overlay.DamageIndicators[playerName]:GetAttribute("t") < damageDirDur
    local d
    if can then
        d = self.Overlay.DamageIndicators[playerName]
    else    
        d = ReplicatedStorage.Assets.DamageIndicator:Clone()
        d.Name = playerName
        d.Parent = self.Overlay.DamageIndicators
    end
    d:SetAttribute("t", tick())
    d:SetAttribute("Pos", pos)
    task.delay(damageDirDur, function()
        if d and tick() - d:GetAttribute("t") > damageDirDur then
            Tween(d, TweenInfo.new(damageDirDur), {ImageTransparency = 1})
            task.delay(damageDirDur, function()
                d:Destroy()
            end)
        end
    end)
end

function HudController:ResetAbility()
    local abilityFrame = HudController.ScreenGui.Frame.Ability1
    abilityFrame.Top.Size = UDim2.fromScale(1, 1)
    abilityFrame.TextLabel.TextColor3 = Color3.fromRGB(0,0,0)
    abilityFrame.InnerFrame.UIStroke.Color = Color3.fromRGB(0,0,0)
    abilityFrame.Cooldown.TextTransparency = 1
end

function HudController:CooldownAbility(duration, janitor)
    local abilityFrame = HudController.ScreenGui.Frame.Ability1
    abilityFrame.Top.Size = UDim2.fromScale(1, 0)
    janitor:AddPromise(Tween(abilityFrame.Top, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Size = UDim2.fromScale(1, 1)}))
    abilityFrame.TextLabel.TextColor3 = Color3.fromRGB(255,255,255)
    abilityFrame.InnerFrame.UIStroke.Color = Color3.fromRGB(150,150,150)
    janitor:AddPromise(Tween(abilityFrame.TextLabel, TweenInfo.new(duration, Enum.EasingStyle.Linear), {TextColor3 = Color3.fromRGB(0,0,0)}))
    janitor:AddPromise(Tween(abilityFrame.InnerFrame.UIStroke, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Color = Color3.fromRGB(0,0,0)}))
    abilityFrame.Cooldown.TextTransparency = 0

    local countdown = duration
    abilityFrame.Cooldown.Text = countdown

    local countdownTimer = Timer.new(1)
    janitor:Add(countdownTimer)
    countdownTimer.Tick:Connect(function()
        countdown -= 1
        abilityFrame.Cooldown.Text = countdown
        if countdown <= 0 then 
            janitor:AddPromise(Tween(abilityFrame.Cooldown, TweenInfo.new(0.5), {TextTransparency = 1}))
            countdownTimer:Destroy()
        end
    end)
    countdownTimer:Start()
end

return HudController