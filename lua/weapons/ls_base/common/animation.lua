function SWEP:PlayAnim(act, bKeepCycle)
	local vmodel = self:GetOwner():GetViewModel()
	if not IsValid(vmodel) then return end

	-- Named sequences must be resolved on the viewmodel, not on self: sequence indices are per-model, SendViewModelMatchingSequence only accepts the viewmodel's own, and self:LookupSequence() reads the weapon's WORLD model, where viewmodel sequence names ("walk", "sprint", "idle01_is") do not exist. That returned -1 and aborted the call silently, so the swap never happened and whatever was already playing -- a sprint loop, say -- just kept looping.
	local seq = isstring(act) and vmodel:LookupSequence(act) or vmodel:SelectWeightedSequence(act)

	if not seq or seq == -1 then
		return longsword.debugPrint("Attempting to play invalid sequence " .. tostring(act) .. " on " .. self:GetClass() .. "!")
	end

	-- Carry the current normalised cycle across so looping locomotion anims (idle/walk/sprint) blend by phase instead of snapping back to frame 0.
	local cycle = bKeepCycle and vmodel:GetCycle() or nil

	vmodel:ResetSequenceInfo()
	vmodel:SendViewModelMatchingSequence(seq)

	if cycle then
		vmodel:SetCycle(cycle)
	end

	return vmodel:SequenceDuration(seq)
end

function SWEP:PlayAnimWorld(act)
	local wmodel = self
	local seq = wmodel:SelectWeightedSequence(act)

	self:ResetSequence(seq)
end

function SWEP:QueueIdle()
	self:SetNextIdle( CurTime() + self:GetOwner():GetViewModel():SequenceDuration() + 0.1 )
end