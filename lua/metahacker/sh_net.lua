MH = MH or {}
MH.Net = MH.Net or {}

MH.Net.Names = {
    OpenOS = "mh_open_os",
    CloseOS = "mh_close_os",
    StateSync = "mh_state_sync",
    Command = "mh_command",
    Notify = "mh_notify",
}

if SERVER then
    for _, name in pairs(MH.Net.Names) do
        util.AddNetworkString(name)
    end
end
