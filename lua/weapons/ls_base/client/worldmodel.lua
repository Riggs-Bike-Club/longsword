-- Resolves the world model's position and angle off the right-hand bone from the WMOffset table. Two formats are accepted: the TFA/INS2 form (Pos and Ang given as Up/Right/Forward components, copied verbatim from SWEP.Offset in the TFA source weapons) applied exactly as the TFA base does, and the legacy form (a Vector Position plus an Angle) applied through LocalToWorld.
function SWEP:GetWorldModelTransform(bonePos, boneAng)
	local offset = self.WMOffset

	-- TFA/INS2 offset: rotate the bone angle by Ang (Up, then Right, then Forward), then push along those rotated axes by Pos.
	if offset.Pos then
		local ang = Angle( boneAng.p, boneAng.y, boneAng.r )
		local a = offset.Ang or {}
		ang:RotateAroundAxis( ang:Up(), a.Up or 0 )
		ang:RotateAroundAxis( ang:Right(), a.Right or 0 )
		ang:RotateAroundAxis( ang:Forward(), a.Forward or 0 )

		local p = offset.Pos
		local pos = bonePos
			+ ang:Forward() * ( p.Forward or 0 )
			+ ang:Right() * ( p.Right or 0 )
			+ ang:Up() * ( p.Up or 0 )

		return pos, ang
	end

	return LocalToWorld( offset.Position, offset.Angle or angle_zero, bonePos, boneAng )
end

function SWEP:DrawWorldModel( f )
	if not self.WMOffset then
		return self:DrawModel( f )
	end

	if not IsValid(self.WorldModel) then
		self.WorldModel = ClientsideModel(self.WorldModel)
		self.WorldModel:SetNoDraw(true)
	end


	local _Owner = self:GetOwner()

	if (IsValid(_Owner)) then
		local WorldModel = self.WorldModel

		local boneid = _Owner:LookupBone( "ValveBiped.Bip01_R_Hand" ) -- Right Hand
		if !boneid then return end

		local matrix = _Owner:GetBoneMatrix(boneid)
		if !matrix then return end

		local newPos, newAng = self:GetWorldModelTransform(matrix:GetTranslation(), matrix:GetAngles())

		WorldModel:SetPos(newPos)
		WorldModel:SetAngles(newAng)

		WorldModel:SetModelScale(self.WMOffset.Scale or 1, 0)

		WorldModel:SetupBones()
	else
		self.WorldModel:SetPos(self:GetPos())
		self.WorldModel:SetAngles(self:GetAngles())
	end

	self.WorldModel:DrawModel()
end
