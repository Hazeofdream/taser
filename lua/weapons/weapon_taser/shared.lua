SWEP.Gun					= ("weapon_taser")
SWEP.Base					= "weapon_base"
SWEP.PrintName				= "Taser"
SWEP.Slot 					= 1
SWEP.SlotPos 				= 2
SWEP.DrawAmmo				= true		
SWEP.BounceWeaponIcon		= false		
SWEP.DrawCrosshair			= true		
SWEP.ViewModel				= "models/realistic_police/taser/c_taser.mdl"
SWEP.ViewModelFOV			= 80
SWEP.WorldModel				= "models/realistic_police/taser/w_taser.mdl"
SWEP.HoldType				= "pistol"
SWEP.UseHands  		       	= true

-- Other settings
SWEP.Weight					= 0
SWEP.AutoSwitchTo			= true			
SWEP.Spawnable				= true	

-- Weapon info
SWEP.Author					= "Haze_of_dream"		
SWEP.Contact				= "https://steamcommunity.com/id/Haze_of_dream/"		
SWEP.Purpose				= "Easily apprehend criminals, or sadistically watch people writhe in pain i guess."	
SWEP.Instructions			= "Immobilize things you dislike."
SWEP.Category 				= "The Tactician's Kit"	

-- Primary fire settings
SWEP.Primary.Spread 		= 0.1
SWEP.Primary.NumberofShots  = 1
SWEP.Primary.Automatic 		= false
SWEP.Primary.Recoil 		= .2
SWEP.Primary.Delay 			= 0.1
SWEP.Primary.Force 			= 100
SWEP.Primary.Sound 			= Sound("stungun/taser_shoot.mp3")
SWEP.Primary.ClipSize		= 1	
SWEP.Primary.DefaultClip	= 2		
SWEP.Primary.Ammo			= "Pistol"


-- Secondary fire settings		
SWEP.Secondary.ClipSize		= -1	
SWEP.Secondary.DefaultClip	= -1		
SWEP.Secondary.Ammo			= ""

-- Misc
SWEP.SelectIcon				= "hud/weaponicons/taser"

sv_taser_stuntime = CreateConVar("sv_taser_stuntime", 7, {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "How long the Taser will stun a user (In Seconds)") 

-- List of immune jobs, won't apply outside darkrp
local ImmuneJobs = {
	TEAM_MAYOR,
	TEAM_CHIEF
}

local TasedUsers = TasedUsers or {}

function SWEP:Initialize()
    self:SetWeaponHoldType("pistol")
end

if SERVER then
	util.AddNetworkString("taser_stunned")
end

-- Render all the clientside text
if CLIENT then
	-- visual slump when hit
	net.Receive("taser_stunned", function()
		local ply = net.ReadEntity()
		local stunned = net.ReadBool()
		if IsValid(ply) and ply:IsPlayer() and ply:Alive() then
			if stunned then
				ply:AnimRestartGesture(GESTURE_SLOT_CUSTOM, ACT_HL2MP_IDLE, false)   
			else
				ply:AnimResetGestureSlot(GESTURE_SLOT_CUSTOM)
			end
		end	
	end)
end

-- Conveniant function for stuns
function SWEP:Stun(ply)
	if not SERVER then return end
	
	TasedUsers[ply:SteamID()] = true
	
	ply:EmitSound( "ambient/voices/m_scream1.wav" )
	ply:EmitSound("stungun/active_stun.mp3")
	
	ply:Freeze(true)
	net.Start("taser_stunned") 
		net.WriteEntity(ply) 
		net.WriteBool(true) 
	net.Broadcast()

	timer.Create("taser_unstun_" .. tostring(ply:EntIndex()), GetConVar("sv_taser_stuntime"):GetInt(), 1, function()
		if IsValid(ply) then
			TasedUsers[ply:SteamID()] = nil

			ply:Freeze(false)

			ply:StopSound("stungun/active_stun.mp3")

			net.Start("taser_stunned")
				net.WriteEntity(ply)
				net.WriteBool(false)
			net.Broadcast()
		end
	end)
end

function SWEP:PrimaryAttack()
	if self.Weapon:Clip1() == 0 then  
		sound.Play("Weapon_Pistol.Empty", self.Owner:GetPos(), 75, 100, 1)
	return end	
	if (!self:CanPrimaryAttack() ) then return end
	
	self.Owner:EmitSound("stungun/taser_shoot.mp3")

	--  changed to a hulltrace for leniancy
    local taserTrace = {
        start = self.Owner:GetShootPos(),
        endpos = self.Owner:GetShootPos() + self.Owner:GetAimVector() * 500,
        mins = Vector( -2, -2, -2 ),
        maxs = Vector( 2, 2, 2 ),
        filter = self.Owner
    }

	self:GetOwner():LagCompensation(true)
    local trace = util.TraceHull(taserTrace)
	self:GetOwner():LagCompensation(false)

	local ply = trace.Entity

	-- taser line
	if CLIENT then
		local tracepos = util.TraceLine(util.GetPlayerTrace( self.Owner ))
		local effect = EffectData()
		effect:SetOrigin(tracepos.HitPos)
		effect:SetStart(self.Owner:GetShootPos())
		effect:SetAttachment(1)
		effect:SetEntity(self)
		util.Effect("ToolTracer", effect)
	end

	if IsValid(ply) and ply:IsPlayer()  and ply:Alive() and not TasedUsers[ply:SteamID()] then
		if ((type(DarkRP) == "table") or (RPExtraTeams != nil)) then
			if table.HasValue(ImmuneJobs, ply:Team()) then return end
		end
	
		self:Stun(ply)
	end 

	self:TakePrimaryAmmo(1)
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay) 
end 

function SWEP:SecondaryAttack()
	return false
end

function SWEP:Deploy()
	self:SendWeaponAnim(ACT_VM_DRAW)
	self:SetNextPrimaryFire(CurTime() + 9999999)
	timer.Create("taser_animation"..self:GetOwner():EntIndex(), self:SequenceDuration() * 0.5, 1, function()	
		if IsValid(self) and IsValid(self:GetOwner()) then 		
			if self:GetOwner():GetActiveWeapon() == self then
				self:SendWeaponAnim(ACT_VM_IDLE)
				self:SetNextPrimaryFire(CurTime() + 0) 
			end 
		end 
	end)
	
	return true
end 

function SWEP:Holster()
	return true
end

function SWEP:Reload()
	local wep = self:GetOwner():GetActiveWeapon()
	if ( !IsValid( wep ) ) then return -1 end
	local ammo = self:GetOwner():GetAmmoCount( wep:GetPrimaryAmmoType() ) 

	if self:Clip1() == 0 and ammo != 0 then 
		self.Weapon:EmitSound("stungun/taser_reload.mp3")
		self.Weapon:DefaultReload(ACT_VM_RELOAD)
	end 
end

function SWEP:DrawWeaponSelection( x, y, wide, tall, alpha )
	if self.SelectIcon then
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetTexture(surface.GetTextureID(self.SelectIcon))
		surface.DrawTexturedRect(x + 20, y + 30, 200, 100)
	else
		draw.SimpleText(self.IconLetter, self.SelectFont, x + wide / 2, y + tall * 0.2, Color(255, 210, 0, alpha), TEXT_ALIGN_CENTER)
	end

	y = y + 10
	x = x + 10
	wide = wide - 20

	self:PrintWeaponInfo( x + wide + 20, y + tall * 0.95, alpha )
end

function SWEP:Precache()
	util.PrecacheSound(self.Primary.Sound)
	util.PrecacheModel(self.ViewModel)
	util.PrecacheModel(self.WorldModel)
end

local TaserVersion = 1.0

-- recently added console command, really only for the developer/powerusers
concommand.Add("taser_info", function()
	local InfoTable = {
		"https://steamcommunity.com/sharedfiles/filedetails/?id=2595774444 created by Haze_of_dream",
		"",
		"Contact at: ",
		"STEAM_0:1:75838598",
		"https:/steamcommunity.com/id/Haze_of_dream",
		"",
		string.format("Taser Version: %s", TaserVersion)
	}
	
	for _, msg in pairs(InfoTable) do
		print(msg)
	end
end)