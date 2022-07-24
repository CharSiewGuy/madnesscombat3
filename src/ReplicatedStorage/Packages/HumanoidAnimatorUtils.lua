---
-- @module HumanoidAnimatorUtils

local HumanoidAnimatorUtils = {}

function HumanoidAnimatorUtils.getOrCreateAnimator(humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Name = "Animator"
		animator.Parent = humanoid
	end

	return animator
end

function HumanoidAnimatorUtils.stopAnimations(humanoid, fadeTime)
	for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
		track:Stop(fadeTime)
	end
end

function HumanoidAnimatorUtils.stopAnimationsList(list, fadeTime)
	for _, track in pairs(list) do
		if track.IsPlaying == true then
			track:Stop(fadeTime)
		end
	end
end

function HumanoidAnimatorUtils.isPlayingAnimationTrack(humanoid, track)
	for _, playingTrack in pairs(humanoid:GetPlayingAnimationTracks()) do
		if playingTrack == track then
			return true
		end
	end

	return false
end


return HumanoidAnimatorUtils