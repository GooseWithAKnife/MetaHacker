AddCSLuaFile()
MH.EntBase.Setup(ENT, {
    PrintName = "MetaHacker",
    Model = "models/props_lab/monitor02.mdl",
    Kind = "server",
})

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "ServerId")
end
