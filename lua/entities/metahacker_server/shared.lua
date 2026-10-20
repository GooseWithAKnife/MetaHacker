AddCSLuaFile()
MH.EntBase.Setup(ENT, {
    PrintName = "MetaHacker",
    Model = "models/props_silo/silo_launchroom_monitor.mdl",
    Kind = "server",
})

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "ServerId")
end
