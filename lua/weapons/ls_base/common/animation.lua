function SWEP:PlayAnim(act, bKeepCycle)
	local vmodel = self:GetOwner():GetViewModel()
	local seq = isstring(act) and self:LookupSequence(act) or vmodel:SelectWeightedSequence(act)

	if not seq or seq == -1 then
		return longsword.debugPrint("Attempting to play invalid sequence " .. act .. "!")
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