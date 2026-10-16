MH = MH or {}
MH.Version = "0.1.0"
MH.Prefix = "metahacker"

local function load_sh(path)
    AddCSLuaFile(path)
    include(path)
end

local function load_sv(path)
    if SERVER then include(path) end
end

local function load_cl(path)
    if SERVER then
        AddCSLuaFile(path)
    else
        include(path)
    end
end

MH.LoadShared = load_sh
MH.LoadServer = load_sv
MH.LoadClient = load_cl

load_sh("metahacker/sh_log.lua")
load_sh("metahacker/sh_net.lua")
load_sh("metahacker/sh_data.lua")
load_sh("metahacker/sh_entbase.lua")

load_sv("metahacker/sv_db.lua")
load_sv("metahacker/sv_state.lua")
load_sv("metahacker/sv_processes.lua")
load_sv("metahacker/sv_viruses.lua")
load_sv("metahacker/sv_api.lua")

load_cl("metahacker/cl_os.lua")

MH.Log.info("boot", "init", "Metahacker loaded (" .. (SERVER and "server" or "client") .. ")")
