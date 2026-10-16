AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    MH.EntBase.Init(self)
end

function ENT:SpawnFunction(ply, tr)
    if not tr.Hit then return end
    local pos = tr.HitPos + tr.HitNormal * 16
    local ent = ents.Create("metahacker_server")
    ent:SetPos(pos)
    ent:Spawn()
    ent:Activate()
    local sid = ply:SteamID64()
    ent:SetNWString("mh_owner", sid)
    if MH.State.CountServers(sid) == 0 then
        MH.State.CreateServer(sid, "Server#1")
    end
    local primary = MH.State.GetServersFor(sid)[1]
    if primary then
        ent:SetServerId(tonumber(primary.id))
    end
    return ent
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if not MH.EntBase.IsOwner(self, activator) then
        MH.Api.SendNotify(activator, "warn", "This server is not yours")
        return
    end
    MH.OS = MH.OS or {}
    local sid = activator:SteamID64()
    if MH.State.CountServers(sid) == 0 then
        MH.State.CreateServer(sid, "Server#1")
    end
    MH.Api.SendSnapshot(activator, self:GetServerId() or 0)
    net.Start(MH.Net.Names.OpenOS)
    net.Send(activator)
end
