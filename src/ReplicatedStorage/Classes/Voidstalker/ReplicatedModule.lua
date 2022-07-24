local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Tween = require(Packages.TweenPromise)

local module = {}

function module:UseAbility(player, abilityName)
    if abilityName == "VoidshiftIn" then
        for _, v in pairs(player.Character:GetChildren()) do
            if v.Name ~= "HumanoidRootPart" and (v:IsA("BasePart") or v:IsA("Decal")) then
                Tween(v, TweenInfo.new(0.5), {Transparency = 1})
            end
        end
        player.Character.Head.face.Transparency = 1
        if player.Character.Humanoid then
            player.Character.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end
        if player.Character.HumanoidRootPart then
            local att = script.Parent.VoidshiftInFx.Attachment:Clone()
            att.Parent = player.Character.HumanoidRootPart
            for _, v in pairs(att:GetChildren()) do
                v:Emit(v:GetAttribute("EmitCount"))
            end
            task.delay(2, function()
                if att then att:Destroy() end
            end)
        end
    elseif abilityName == "VoidshiftOut" then
        for _, v in pairs(player.Character:GetChildren()) do
            if v.Name ~= "HumanoidRootPart" and (v:IsA("BasePart") or v:IsA("Decal")) then
                Tween(v, TweenInfo.new(1), {Transparency = 0})
            end
        end
        player.Character.Head.face.Transparency = 0
        if player.Character.Humanoid then
            player.Character.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
        end
    end   
    print(player.Character.Name .. abilityName)
end

return module