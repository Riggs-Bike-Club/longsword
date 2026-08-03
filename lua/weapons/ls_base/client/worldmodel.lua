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

-- Draws the always-on world model sub-models (SWEP.WMElements -- default magazines, folded sights and the like) at the world model's rendered transform. Bone-merged elements attach to a hidden clientside copy of the world model posed at (pos, ang): the real weapon entity is only moved via SetRenderOrigin, so its actual bones sit at the engine's held position, not the offset transform, and a bonemerge onto it would follow the wrong place.
function SWEP:DrawWorldModelElements(pos, ang)
	local elements = self.WMElements
	if not elements then return end

	if not IsValid(self.WMElementRoot) then
		-- self.WorldModel holds the model path string here: only the legacy branch (which these weapons never take) ever reassigns it to a clientside entity.
		local path = isstring(self.WorldModel) and self.WorldModel or self:GetModel()
		self.WMElementRoot = ClientsideModel( path )
		if not IsValid(self.WMElementRoot) then return end

		self.WMElementRoot:SetNoDraw(true)
	end

	local root = self.WMElementRoot
	root:SetPos(pos)
	root:SetAngles(ang)
	root:SetupBones()

	for _, data in pairs(elements) do
		self:DrawWMElement(data, root)
	end
end

-- Draws one world element. Bone-merged elements are parented to the posed root and follow its skeleton; positioned elements resolve their bone on the root and apply the same Pos/Ang convention the viewmodel elements use.
function SWEP:DrawWMElement(data, root)
	if data.Active == false then return end
	if data.ShouldDraw and not data.ShouldDraw(self) then return end

	if not IsValid(data._WMModel) then
		local cs = ClientsideModel(data.Model)
		if not IsValid(cs) then return end

		data._WMModel = cs
		cs:SetNoDraw(true)

		if data.BoneMerge then
			cs:SetParent(root)
			cs:AddEffects(EF_BONEMERGE)
		elseif data.Scale then
			cs:SetModelScale(data.Scale)
		end
	end

	local cs = data._WMModel

	if data.BoneMerge then
		cs:DrawModel()
		return
	end

	local bone = data.Bone and root:LookupBone(data.Bone)
	local pos, ang
	if bone then
		local m = root:GetBoneMatrix(bone)
		if m then
			pos, ang = m:GetTranslation(), m:GetAngles()
		end
	end

	pos = pos or root:GetPos()
	ang = ang or root:GetAngles()

	cs:SetPos(pos + ang:Forward() * data.Pos.x + ang:Right() * data.Pos.y + ang:Up() * data.Pos.z)
	ang:RotateAroundAxis(ang:Up(), data.Ang.y)
	ang:RotateAroundAxis(ang:Right(), data.Ang.p)
	ang:RotateAroundAxis(ang:Forward(), data.Ang.r)
	cs:SetAngles(ang)
	cs:DrawModel()
end

function SWEP:DrawWorldModel( f )
	local offset = self.WMOffset
	if not offset then
		return self:DrawModel( f )
	end

	-- TFA/INS2 format (Pos/Ang given as Up/Right/Forward): drive the weapon entity's OWN render transform off the right-hand bone and draw it, exactly as tfa_gun_base does. Reusing the real entity keeps its skin, bodygroups, submaterials and pose instead of a bare clientside copy.
	if offset.Pos then
		local owner = self:GetOwner()
		local pos, ang

		if IsValid(owner) then
			local boneid = owner:LookupBone( "ValveBiped.Bip01_R_Hand" )
			local matrix = boneid and owner:GetBoneMatrix( boneid )

			if matrix then
				pos, ang = self:GetTFAWorldModelTransform( matrix:GetTranslation(), matrix:GetAngles() )

				self:SetRenderOrigin( pos )
				self:SetRenderAngles( ang )
				self:SetModelScale( offset.Scale or 1, 0 )
			end
		else
			-- Dropped / no owner: clear the overrides so the weapon draws at its real position.
			self:SetRenderOrigin()
			self:SetRenderAngles()
		end

		self:DrawModel( f )

		if pos then
			self:DrawWorldModelElements( pos, ang )
		end

		return
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
