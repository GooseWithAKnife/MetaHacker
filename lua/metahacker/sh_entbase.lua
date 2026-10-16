MH = MH or {}
MH.EntBase = {}

function MH.EntBase.Setup(ENT, cfg)
    ENT.Type = "anim"
    ENT.Base = "base_gmodentity"
    ENT.PrintName = cfg.PrintName or "Metahacker Device"
    ENT.Category = "RakTheGoose"
    ENT.Spawnable = true
    ENT.AdminOnly = false
    ENT.Author = "Metahacker"
    ENT.Model = cfg.Model
    ENT.Kind = cfg.Kind
end

function MH.EntBase.Init(self)
    self:SetModel(self.Model or "models/props_lab/servers.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end
end

function MH.EntBase.OwnerSID(self)
    return self:GetNWString("mh_owner", "")
end

function MH.EntBase.IsOwner(self, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    return self:GetNWString("mh_owner", "") == ply:SteamID64()
end
