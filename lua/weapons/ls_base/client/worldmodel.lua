-- Computes the world model's position and angle off the right-hand bone for the TFA/INS2 offset format, matching tfa_gun_base WorldModelOffsetUpdate exactly: translate along the ORIGINAL (unrotated) bone axes by Pos, THEN rotate the angle by Ang (Up, then Right, then Forward). The order is load-bearing -- the Forward ~180 flip means translating after the rotation would mirror the position.
function SWEP:GetTFAWorldModelTransform(bonePos, boneAng)
	local offset = self.WMOffset
	local p = offset.Pos

	local pos = bonePos
		+ boneAng:Forward() * ( p.Forward or 0 )
		+ boneAng:Right() * ( p.Right or 0 )
		+ boneAng:Up() * ( p.Up or 0 )

	local ang = Angle( boneAng.p, boneAng.y, boneAng.r )
	local a = offset.Ang or {}
	ang:RotateAroundAxis( ang:Up(), a.Up or 0 )
	ang:RotateAroundAxis( ang:Right(), a.Right or 0 )
	ang:RotateAroundAxis( ang:Forward(), a.Forward or 0 )

	return pos, ang
end

function SWEP:DrawWorldModel( f )
	local offset = self.WMOffset
	if not offset then
		return self:DrawModel( f )
	end

	-- TFA/INS2 format (Pos/Ang given as Up/Right/Forward): drive the weapon entity's OWN render transform off the right-hand bone and draw it, exactly as tfa_gun_base does. Reusing the real entity keeps its skin, bodygroups, submaterials and pose instead of a bare clientside copy.
	if offset.Pos then
		local owner = self:GetOwner()

		if IsValid(owner) then
			local boneid = owner:LookupBone( "ValveBiped.Bip01_R_Hand" )
			local matrix = boneid and owner:GetBoneMatrix( boneid )

			if matrix then
				local pos, ang = self:GetTFAWorldModelTransform( matrix:GetTranslation(), matrix:GetAngles() )

				self:SetRenderOrigin( pos )
				self:SetRenderAngles( ang )
				self:SetModelScale( offset.Scale or 1, 0 )
			end
		else
			-- Dropped / no owner: clear the overrides so the weapon draws at its real position.
			self:SetRenderOrigin()
			self:SetRenderAngles()
		end

		return self:DrawModel( f )
	end

	-- Legacy format (Vector Position + Angle): draw a bone-attached clientside copy.
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

		local newPos, newAng = LocalToWorld( offset.Position, offset.Angle or angle_zero, matrix:GetTranslation(), matrix:GetAngles() )

		WorldModel:SetPos(newPos)
		WorldModel:SetAngles(newAng)

		WorldModel:SetModelScale(offset.Scale or 1, 0)

		WorldModel:SetupBones()
	else
		self.WorldModel:SetPos(self:GetPos())
		self.WorldModel:SetAngles(self:GetAngles())
	end

	self.WorldModel:DrawModel()
end
