local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)
local Promise = require(Packages.Promise)
local Tween = require(Packages.TweenPromise)
local Timer = require(Packages.Timer)

local SmoothValue = require(game.ReplicatedStorage.Modules.SmoothValue)

local HudController = Knit.CreateController { Name = "HudController" }
HudController.janitor = Janitor.new()

local PvpService

function HudController:KnitInit()
    PvpService = Knit.GetService("PvpService")

    HudController.crosshairOffset = SmoothValue:create(20, 20, 4)
    HudController.crosshairOffset2 = SmoothValue:create(0,0,20)
    HudController.isAiming = false
    HudController.crosshairOffsetMultiplier = 2
    HudController.crosshairTransparency = SmoothValue:create(0,0,4)
    HudController.dotTransparency = SmoothValue:create(0,0,15)
    
    HudController.score = 0
end

function HudController:KnitStart()
    game.Lighting.Atmosphere.Density = 0.33

    local StarterGui = game:GetService("StarterGui")
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

    repeat task.wait() until Knit.Player:GetAttribute("Class")
    Knit.Player.CharacterAdded:Wait()

    self.ScreenGui = Knit.Player.PlayerGui:WaitForChild("ScreenGui")
    self.ScreenGui.Enabled = true
    self.ScreenGui.Frame.Visible = true
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

    task.delay(1, function()
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
    task.delay(1, function()
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
                killPrompt.Fx.Image = v
                task.wait()
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

return HudController