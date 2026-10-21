MH = MH or {}
MH.Proc = {}

local function now() return os.time() end

local function cpu_mhz(serverRow)
    local t = tonumber(serverRow.cpu_tier or 1) or 1
    local tier = MH.Data.Hardware.cpu[t] or MH.Data.Hardware.cpu[1]
    return tier.mhz
end

function MH.Proc.ResearchCost(softType, currentVersion)
    return MH.Data.ResearchCost(softType, currentVersion)
end

local function hdd_cap_mb(srvId)
    local srv = MH.State.GetServerById(tonumber(srvId or 0))
    if not srv then return 0 end
    local tier = MH.Data.Hardware.hdd[tonumber(srv.hdd_tier or 1) or 1] or MH.Data.Hardware.hdd[1]
    return tonumber(tier.mb) or 0
end
local function hdd_used_mb(srvId)
    return tonumber(MH.DB.QueryValue(
        "SELECT COALESCE(SUM(soft_size),0) FROM mh_software WHERE server_id = " ..
        tonumber(srvId or 0))) or 0
end
local function ram_cap_mb(srvId)
    local srv = MH.State.GetServerById(tonumber(srvId or 0))
    if not srv then return 0 end
    local tier = MH.Data.Hardware.ram[tonumber(srv.ram_tier or 1) or 1] or MH.Data.Hardware.ram[1]
    return tonumber(tier.mb) or 0
end
local function ram_used_mb(srvId)
    return tonumber(MH.DB.QueryValue(
        "SELECT COALESCE(SUM(soft_ram),0) FROM mh_software WHERE server_id = " ..
        tonumber(srvId or 0) .. " AND installed = 1")) or 0
end
local function notify_creator(sid, kind, msg)
    local p = player.GetBySteamID64(sid or "")
    if IsValid(p) and MH.Api and MH.Api.SendNotify then
        MH.Api.SendNotify(p, kind, msg)
    end
end

function MH.Proc.ResearchDuration(cost, mhz)
    return math.max(10, math.floor(cost / math.max(1, mhz)))
end

local RAM_COSTS = {
    research = 100,
    scan = 30,
    crack = 150,
    DDOS = 200,
    DOOM_SPREAD = 250,
    AV_SCAN = 100,
    BANK_ACC_CRACK = 150,
    SOFT_INSTALL = 50,
    SOFT_UNINSTALL = 50,
    SOFT_DELETE = 30,
    SOFT_DOWNLOAD = 60,
    SOFT_UPLOAD = 60,
    SOFT_HIDE = 50,
    SOFT_SEEK = 50,
    E_LOG = 20,
    D_LOG = 20,
    RESET_PWD = 20,
    RESET_IP = 20,
}

local function ram_cost_for(action)
    return tonumber(RAM_COSTS[action]) or 50
end

local function is_net_bound(cpu, netU)
    return (tonumber(netU) or 0) > (tonumber(cpu) or 0)
end

local function active_pool_counts_for_creator(sid)
    local rows = MH.DB.Query(
        "SELECT cpu_usage, net_usage FROM mh_processes WHERE creator_sid = " .. MH.DB.Esc(sid) ..
        " AND paused_remaining = 0 AND (cpu_usage > 0 OR net_usage > 0)") or {}
    local cpuN = 0
    local netN = 0
    for _, r in ipairs(rows) do
        if is_net_bound(r.cpu_usage, r.net_usage) then
            netN = netN + 1
        else
            cpuN = cpuN + 1
        end
    end
    return cpuN, netN
end

local function proc_ram_used_mb(srvId)
    return tonumber(MH.DB.QueryValue(
        "SELECT COALESCE(SUM(ram_usage),0) FROM mh_processes WHERE local_server = " ..
        tonumber(srvId or 0) .. " AND paused_remaining = 0")) or 0
end

local function reschedule_creator(sid)
    local rows = MH.DB.Query("SELECT id, time_start, ideal_duration, cpu_usage, net_usage FROM mh_processes WHERE creator_sid = " ..
        MH.DB.Esc(sid) .. " AND paused_remaining = 0 AND (cpu_usage > 0 OR net_usage > 0)") or {}
    if #rows == 0 then return end
    local cpuN, netN = 0, 0
    for _, r in ipairs(rows) do
        if is_net_bound(r.cpu_usage, r.net_usage) then netN = netN + 1 else cpuN = cpuN + 1 end
    end
    local nowT = now()
    for _, r in ipairs(rows) do
        local ts = tonumber(r.time_start) or nowT
        local ideal = tonumber(r.ideal_duration) or 0
        local n = is_net_bound(r.cpu_usage, r.net_usage) and netN or cpuN
        local newEnd = ts + ideal * n
        if newEnd < nowT + 1 then newEnd = nowT + 1 end
        MH.DB.Query("UPDATE mh_processes SET time_end = " .. newEnd ..
            " WHERE id = " .. tonumber(r.id))
    end
end

function MH.Proc.Spawn(opts)
    local sid = tostring(opts.creator_sid or "")
    local localSrv = tonumber(opts.local_server or 0) or 0
    local action = tostring(opts.action or "")
    local ideal = tonumber(opts.duration or 10) or 10
    local cpu = tonumber(opts.cpu_usage or 100) or 100
    local netU = tonumber(opts.net_usage or 0) or 0
    local ramNeed = tonumber(opts.ram_usage) or ram_cost_for(action)
    if ramNeed > 0 and localSrv > 0 then
        local cap = ram_cap_mb(localSrv)
        local installedRam = ram_used_mb(localSrv)
        local procRam = proc_ram_used_mb(localSrv)
        local free = cap - installedRam - procRam
        if ramNeed > free then
            notify_creator(sid, "error",
                "Not enough RAM to start " .. action ..
                " (need " .. ramNeed .. " MB, free " .. math.max(0, free) .. " MB)")
            return nil
        end
    end
    local start = now()
    local newN = 1
    if sid ~= "" and (cpu > 0 or netU > 0) then
        local cpuN, netN = active_pool_counts_for_creator(sid)
        if is_net_bound(cpu, netU) then
            newN = netN + 1
        else
            newN = cpuN + 1
        end
    end
    local tentativeEnd = start + ideal * newN
    MH.DB.Query("INSERT INTO mh_processes (creator_sid, victim_server, local_server, action, soft_id, info, time_start, time_end, cpu_usage, net_usage, ideal_duration, ram_usage) VALUES (" ..
        MH.DB.Esc(opts.creator_sid) .. ", " ..
        tonumber(opts.victim_server or 0) .. ", " ..
        localSrv .. ", " ..
        MH.DB.Esc(action) .. ", " ..
        tonumber(opts.soft_id or 0) .. ", " ..
        MH.DB.Esc(opts.info or "") .. ", " ..
        start .. ", " ..
        tentativeEnd .. ", " ..
        cpu .. ", " ..
        netU .. ", " ..
        ideal .. ", " ..
        ramNeed .. ")")
    local pid = tonumber(MH.DB.QueryValue("SELECT last_insert_rowid()"))
    if sid ~= "" and (cpu > 0 or netU > 0) then reschedule_creator(sid) end
    return pid
end

MH.Proc._RescheduleCreator = reschedule_creator

function MH.Proc.CheckRam(localSrv, action, override)
    localSrv = tonumber(localSrv or 0) or 0
    if localSrv <= 0 then return true end
    local need = tonumber(override) or ram_cost_for(action)
    if need <= 0 then return true end
    local cap = ram_cap_mb(localSrv)
    local free = cap - ram_used_mb(localSrv) - proc_ram_used_mb(localSrv)
    if need > free then
        return false, "Not enough RAM (need " .. need ..
            " MB, free " .. math.max(0, free) .. " MB)"
    end
    return true
end

local Completers = {}

Completers.research = function(row)
    local serverId = tonumber(row.local_server)
    local softId = tonumber(row.soft_id)
    local srv = MH.State.GetServerById(serverId)
    if not srv then return end
    local existing = MH.DB.QueryRow("SELECT * FROM mh_software WHERE id = " .. softId)
    local existingLicense = existing and tostring(existing.licensed_to or "") or ""
    if existingLicense == "NULL" then existingLicense = "" end
    if not existing or existingLicense ~= tostring(row.creator_sid or "") then
        notify_creator(row.creator_sid, "error",
            "Research aborted: the licensed file is gone or no longer licensed to you")
        return
    end
    local softType = tonumber(existing.soft_type)
    local newVer = (tonumber(existing.soft_version) or 0) + 1
    MH.DB.Query("UPDATE mh_software SET soft_version = soft_version + 1 WHERE id = " .. tonumber(existing.id))
    MH.State.AppendLog(serverId, "Research complete: " .. (MH.Data.Soft[softType] or {}).name)
    local baseRep = 35 + math.floor(newVer)
    if softType <= 4 then baseRep = baseRep * 2 end
    MH.DB.Query("UPDATE mh_players SET exp = exp + " .. baseRep ..
        " WHERE sid64 = " .. MH.DB.Esc(row.creator_sid))
end

Completers.scan = function(row)
    local serverId = tonumber(row.local_server)
    local targetIP = row.info or ""
    local target = MH.DB.QueryRow("SELECT id, name, ip FROM mh_servers WHERE ip = " .. MH.DB.Esc(targetIP))
    if not target then return end
    local firewallV = tonumber(MH.DB.QueryValue(
        "SELECT MAX(soft_version) FROM mh_software WHERE server_id = " .. tonumber(target.id) ..
        " AND soft_type = 4")) or 0
    local attFTP = tonumber(MH.DB.QueryValue(
        "SELECT MAX(soft_version) FROM mh_software WHERE server_id = " .. tonumber(row.local_server) ..
        " AND soft_type = 13")) or 0
    local attSSH = tonumber(MH.DB.QueryValue(
        "SELECT MAX(soft_version) FROM mh_software WHERE server_id = " .. tonumber(row.local_server) ..
        " AND soft_type = 14")) or 0
    local ftpOk = attFTP > 0 and attFTP >= firewallV
    local sshOk = attSSH > 0 and attSSH >= firewallV
    local ftpTag = ftpOk and "VULNERABLE" or "FAILED"
    local sshTag = sshOk and "VULNERABLE" or "FAILED"
    MH.State.AppendLog(serverId, "Scan complete: " .. targetIP .. " (" .. target.name ..
        ")  FTP [" .. ftpTag .. "] SSH [" .. sshTag .. "] firewall v" .. MH.Data.DotVersion(firewallV))
end

Completers.crack = function(row)
    local attackerSrv = tonumber(row.local_server)
    local victimSrv = tonumber(row.victim_server)
    local victim = MH.State.GetServerById(victimSrv)
    if not victim then return end
    local already = MH.DB.QueryValue("SELECT id FROM mh_hacked WHERE owner_sid = " ..
        MH.DB.Esc(row.creator_sid) .. " AND target_server = " .. victimSrv)
    if already then
        MH.DB.Query("UPDATE mh_hacked SET discovered_pass = " .. MH.DB.Esc(victim.root_pass) ..
            ", stamp = " .. now() .. " WHERE id = " .. tonumber(already))
    else
        MH.DB.Query("INSERT INTO mh_hacked (owner_sid, target_server, discovered_pass, stamp) VALUES (" ..
            MH.DB.Esc(row.creator_sid) .. ", " .. victimSrv .. ", " ..
            MH.DB.Esc(victim.root_pass) .. ", " .. now() .. ")")
    end
    MH.State.MarkDiscovered(row.creator_sid, victimSrv)
    MH.State.AppendLog(attackerSrv, "Cracked " .. victim.ip .. " root pass acquired")
    MH.DB.Query("INSERT OR REPLACE INTO mh_internet (owner_sid, target_server, authed, stamp) VALUES (" ..
        MH.DB.Esc(row.creator_sid) .. ", " .. victimSrv .. ", 1, " .. now() .. ")")
    MH.State.AppendLog(victimSrv, "User logged in from " .. MH.State.AttackerIP(row.creator_sid or ""))
    if not already then
        local hashV = tonumber(MH.DB.QueryValue(
            "SELECT MAX(soft_version) FROM mh_software WHERE server_id = " .. victimSrv ..
            " AND soft_type = 2")) or 0
        local crackV = tonumber(MH.DB.QueryValue(
            "SELECT MAX(soft_version) FROM mh_software WHERE server_id = " .. victimSrv ..
            " AND soft_type = 1")) or 0
        local hackRep = (MH.Data.Rep.HACK_BASE or 50) + math.floor(hashV + crackV)
        MH.DB.Query("UPDATE mh_players SET exp = exp + " .. hackRep ..
            " WHERE sid64 = " .. MH.DB.Esc(row.creator_sid))
        MH.State.CheckFBIThresholds(row.creator_sid)
        MH.State.AwardBadge(row.creator_sid, "first_hack")
        MH.DB.Query("UPDATE mh_players SET hack_count = hack_count + 1 WHERE sid64 = " .. MH.DB.Esc(row.creator_sid))
        local nick = MH.DB.QueryValue("SELECT nick FROM mh_players WHERE sid64 = " .. MH.DB.Esc(row.creator_sid)) or "someone"
        if tonumber(victim.is_npc) == 1 and
            (victim.name == "MSA" or victim.name == "Employers" or
             string.find(string.lower(victim.name or ""), "bank"))
        then
            MH.State.AddNews(nick .. " cracked " .. victim.name)
        end
        if tonumber(victim.is_npc) == 1 and string.find(string.lower(victim.name or ""), "bank") then
            local accts = MH.DB.Query("SELECT acc_num, acc_pass FROM mh_banks WHERE bank_npc = " .. victimSrv) or {}
            if #accts > 0 then
                local pick = accts[math.random(1, #accts)]
                MH.DB.Query("INSERT INTO mh_hacked_banks (owner_sid, bank_server_id, acc_num, acc_pass, stamp) VALUES (" ..
                    MH.DB.Esc(row.creator_sid) .. ", " .. victimSrv .. ", " ..
                    MH.DB.Esc(pick.acc_num) .. ", " .. MH.DB.Esc(pick.acc_pass) .. ", " .. now() .. ")")
                MH.State.AppendLog(attackerSrv, "Captured bank credential: " .. pick.acc_num)
                MH.State.CheckMissionProgress(row.creator_sid, "bank_credential", { target_server = victimSrv })
            end
        end
    end
    if tonumber(victim.is_npc) == 1 and victim.name == "MSA" then
        MH.State.CheckEmployersMSAHit(row.creator_sid)
    end
end

Completers.E_LOG = function(row)
    local tmpId = tonumber(row.soft_id)
    local tmp = MH.DB.QueryRow("SELECT * FROM mh_tmp_log WHERE id = " .. tmpId)
    if not tmp then return end
    MH.State.ReplaceLog(tonumber(tmp.server_id), tostring(tmp.content or ""))
    MH.DB.Query("DELETE FROM mh_tmp_log WHERE id = " .. tmpId)
end

Completers.D_LOG = function(row)
    MH.State.ReplaceLog(tonumber(row.local_server), "")
end

local function row_is_local(row) return tonumber(row.victim_server or 0) == 0 end

local function log_soft_action(row, verbPast, soft)
    local sid = row.creator_sid or ""
    local attIp = MH.State.AttackerIP(sid)
    local fname = (soft and soft.soft_name or "file")
    if row_is_local(row) then
        MH.State.AppendLog(tonumber(row.local_server), verbPast .. " " .. fname)
    else
        local target = MH.State.GetServerById(tonumber(row.victim_server))
        local tgtIp = target and target.ip or "?"
        MH.State.AppendLog(tonumber(row.local_server), verbPast .. " " .. fname .. " on " .. tgtIp)
        MH.State.AppendLog(tonumber(row.victim_server), fname .. " was " .. string.lower(verbPast) .. " by " .. attIp)
    end
end

Completers.SOFT_DELETE = function(row)
    local soft = MH.DB.QueryRow("SELECT * FROM mh_software WHERE id = " .. tonumber(row.soft_id or 0))
    local targetServer = soft and tonumber(soft.server_id) or 0
    local softName = soft and tostring(soft.soft_name or "") or ""
    log_soft_action(row, "Deleted", soft)
    MH.DB.Query("DELETE FROM mh_software WHERE id = " .. tonumber(row.soft_id or 0))
    if row.creator_sid and row.creator_sid ~= "" then
        MH.State.CheckSourcenetSoftwareDeleted(row.creator_sid)
        if targetServer > 0 then
            MH.State.CheckMissionProgress(row.creator_sid, "soft_delete",
                { target_server = targetServer, soft_name = softName })
        end
    end
end

Completers.RESET_PWD = function(row)
    local sid = row.creator_sid or ""
    local serverId = tonumber(row.info or 0) or 0
    if serverId <= 0 then return end
    local srv = MH.State.GetServerById(serverId)
    if not srv or srv.owner_sid ~= sid then return end
    local newPass = ""
    local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    for _ = 1, 10 do
        local idx = math.random(1, #chars)
        newPass = newPass .. chars:sub(idx, idx)
    end
    MH.DB.Query("UPDATE mh_servers SET root_pass = " .. MH.DB.Esc(newPass) .. " WHERE id = " .. serverId)
    MH.DB.Query("UPDATE mh_players SET pwd_resets = pwd_resets + 1, last_pwd_reset = " .. now() ..
        " WHERE sid64 = " .. MH.DB.Esc(sid))
    MH.State.AppendLog(serverId, "Root password rotated")
    MH.DB.Query("DELETE FROM mh_hacked WHERE target_server = " .. serverId)
end

Completers.RESET_IP = function(row)
    local sid = row.creator_sid or ""
    local serverId = tonumber(row.info or 0) or 0
    if serverId <= 0 then return end
    local srv = MH.State.GetServerById(serverId)
    if not srv or srv.owner_sid ~= sid then return end
    local newIp
    for _ = 1, 20 do
        local candidate = math.random(1, 254) .. "." .. math.random(0, 254) .. "." .. math.random(0, 254) .. "." .. math.random(1, 254)
        local hit = MH.DB.QueryValue("SELECT id FROM mh_servers WHERE ip = " .. MH.DB.Esc(candidate))
        if not hit then newIp = candidate break end
    end
    newIp = newIp or ("10." .. math.random(0, 254) .. "." .. math.random(0, 254) .. "." .. math.random(1, 254))
    local oldIp = srv.ip or "?"
    MH.DB.Query("UPDATE mh_servers SET ip = " .. MH.DB.Esc(newIp) .. " WHERE id = " .. serverId)
    MH.DB.Query("UPDATE mh_players SET ip_resets = ip_resets + 1, last_ip_reset = " .. now() ..
        " WHERE sid64 = " .. MH.DB.Esc(sid))
    MH.State.AppendLog(serverId, "IP reset: " .. oldIp .. " -> " .. newIp)
end

Completers.BANK_ACC_CRACK = function(row)
    local info = tostring(row.info or "")
    local accNum = info:match("#(%d+)")
    if not accNum then return end
    local acc = MH.DB.QueryRow("SELECT * FROM mh_banks WHERE acc_num = " .. MH.DB.Esc(accNum) ..
        " AND bank_npc = " .. tonumber(row.victim_server or 0))
    if not acc then return end
    MH.DB.Query("INSERT INTO mh_hacked_banks (owner_sid, bank_server_id, acc_num, acc_pass, stamp) VALUES (" ..
        MH.DB.Esc(row.creator_sid) .. ", " .. tonumber(row.victim_server) .. ", " ..
        MH.DB.Esc(accNum) .. ", " .. MH.DB.Esc(acc.acc_pass) .. ", " .. now() .. ")")
    MH.State.AppendLog(tonumber(row.local_server), "Captured bank credential: " .. accNum .. " on " .. (info:match("^(%S+)") or "?"))
    MH.State.AppendLog(tonumber(row.victim_server), "Account " .. accNum .. " compromised")
    MH.State.CheckMissionProgress(row.creator_sid, "bank_credential", { target_server = tonumber(row.victim_server) })
end

Completers.AV_SCAN = function(row)
    local targetId = tonumber(row.victim_server or 0)
    if targetId == 0 then return end
    local avVer = tonumber(row.soft_id or 0) or 0
    local virusTypes = "8, 9, 10, 11, 12, 20, 96"
    local removed = MH.DB.Query("SELECT id FROM mh_software WHERE server_id = " .. targetId ..
        " AND soft_type IN (" .. virusTypes .. ")") or {}
    MH.DB.Query("DELETE FROM mh_software WHERE server_id = " .. targetId ..
        " AND soft_type IN (" .. virusTypes .. ")")
    MH.State.AppendLog(targetId, "Antivirus v" .. MH.Data.DotVersion(avVer) ..
        " removed " .. #removed .. " viruses")
    local isLocal = tostring(row.info or "") == "local"
    if not isLocal then
        local attIp = MH.State.AttackerIP(row.creator_sid or "")
        MH.State.AppendLog(tonumber(row.local_server or 0),
            "Antivirus scan on " .. tostring(MH.State.GetServerById(targetId) and MH.State.GetServerById(targetId).ip or "?") ..
            " removed " .. #removed .. " viruses")
        local target = MH.State.GetServerById(targetId)
        if target then
            MH.DB.Query("UPDATE mh_server_log SET content = content WHERE server_id = " .. targetId)
        end
    end
end

Completers.DOOM_SPREAD = function(row)
    local sid = row.creator_sid or ""
    MH.DB.Query("UPDATE mh_players SET exp = exp + " .. (MH.Data.Rep.DOOM or 10000) ..
        ", doom_count = doom_count + 1 WHERE sid64 = " .. MH.DB.Esc(sid))
    local victims = MH.DB.Query("SELECT id FROM mh_servers WHERE is_npc = 1") or {}
    local scorched = 0
    for _, v in ipairs(victims) do
        local newHp = math.max(0, math.random(0, 60))
        MH.DB.Query("UPDATE mh_servers SET hp = " .. newHp .. " WHERE id = " .. tonumber(v.id))
        if newHp <= 10 then scorched = scorched + 1 end
    end
    local nick = MH.DB.QueryValue("SELECT nick FROM mh_players WHERE sid64 = " .. MH.DB.Esc(sid)) or "someone"
    MH.State.AddNews(nick .. " completed DOOM: " .. scorched .. " servers scorched")
    MH.State.AppendLog(tonumber(row.victim_server), "DOOM spread complete, " .. scorched .. " servers damaged")
end

Completers.DDOS = function(row)
    local victim = MH.State.GetServerById(tonumber(row.victim_server))
    if not victim then return end
    local power = tonumber(row.soft_id or 0) or 0
    local av = MH.DB.QueryValue("SELECT MAX(soft_version) FROM mh_software WHERE server_id = " ..
        tonumber(victim.id) .. " AND soft_type = 7 AND installed = 1")
    local avVer = tonumber(av) or 0
    local breakerV = tonumber(MH.DB.QueryValue(
        "SELECT MAX(soft_version) FROM mh_software WHERE server_id = " .. tonumber(victim.id) ..
        " AND soft_type = 12 AND installed = 1")) or 0
    local baseDmg
    if power < 10000 then baseDmg = math.random() < 0.15 and 1 or 0
    elseif power < 15000 then baseDmg = math.random() < 0.30 and math.random(1, 2) or 0
    elseif power < 20000 then baseDmg = math.random() < 0.50 and math.random(1, 3) or 0
    else baseDmg = math.ceil((power - 20000) / 2000) + math.random(0, 2) end
    local dmg = math.max(0, baseDmg - math.floor(avVer / 10) - math.floor(breakerV / 5))
    local newHp = math.max(0, (tonumber(victim.hp) or 100) - dmg)
    MH.DB.Query("UPDATE mh_servers SET hp = " .. newHp .. " WHERE id = " .. tonumber(victim.id))
    local attIp = MH.State.AttackerIP(row.creator_sid or "")
    MH.State.AppendLog(tonumber(victim.id), "DDoS damage " .. dmg .. " from " .. attIp .. ", hp now " .. newHp)
    MH.State.AppendLog(tonumber(row.local_server or 0),
        "DDoS complete against " .. tostring(victim.ip) .. " for " .. dmg .. " damage")
    local ddosRep = 250 + math.floor(power * 0.01)
    MH.DB.Query("UPDATE mh_players SET exp = exp + " .. ddosRep ..
        ", ddos_count = ddos_count + 1 WHERE sid64 = " .. MH.DB.Esc(row.creator_sid))
    if newHp == 0 then
        MH.State.AppendLog(tonumber(victim.id), "Server offline")
        MH.State.CheckMissionProgress(row.creator_sid, "server_wiped", { target_server = tonumber(victim.id) })
    end
end

Completers.SOFT_HIDE = function(row)
    local soft = MH.DB.QueryRow("SELECT * FROM mh_software WHERE id = " .. tonumber(row.soft_id or 0))
    log_soft_action(row, "Hid", soft)
    local hiderV = tonumber(MH.DB.QueryValue(
        "SELECT MAX(soft_version) FROM mh_software WHERE server_id = " ..
        tonumber(row.local_server or 0) .. " AND soft_type = 5 AND installed = 1")) or 0
    MH.DB.Query("UPDATE mh_software SET hidden = 1, hidden_version = " .. hiderV ..
        " WHERE id = " .. tonumber(row.soft_id or 0))
end

Completers.SOFT_SEEK = function(row)
    local soft = MH.DB.QueryRow("SELECT * FROM mh_software WHERE id = " .. tonumber(row.soft_id or 0))
    log_soft_action(row, "Revealed", soft)
    MH.DB.Query("UPDATE mh_software SET hidden = 0, hidden_version = 0 WHERE id = " .. tonumber(row.soft_id or 0))
end

local function soft_file_desc(soft)
    if not soft then return "file" end
    local meta = MH.Data.Soft[tonumber(soft.soft_type or 0)] or {}
    local name = tostring(soft.soft_name or "file") .. tostring(meta.ext or "")
    local verStr = MH.Data.DotVersion(soft.soft_version)
    return name .. " (" .. verStr .. ")"
end

local function log_install_action(row, verbPast, soft)
    local sid = row.creator_sid or ""
    local desc = soft_file_desc(soft)
    if row_is_local(row) then
        MH.State.AppendLog(tonumber(row.local_server),
            "localhost " .. string.lower(verbPast) .. " file " .. desc)
    else
        local target = MH.State.GetServerById(tonumber(row.victim_server))
        local tgtIp = target and target.ip or "?"
        local attIp = MH.State.AttackerIP(sid)
        MH.State.AppendLog(tonumber(row.local_server),
            "localhost " .. string.lower(verbPast) .. " file " .. desc .. " at [" .. tgtIp .. "]")
        MH.State.AppendLog(tonumber(row.victim_server),
            "[" .. attIp .. "] " .. string.lower(verbPast) .. " file " .. desc .. " at localhost")
    end
end

Completers.SOFT_UNINSTALL = function(row)
    local soft = MH.DB.QueryRow("SELECT * FROM mh_software WHERE id = " .. tonumber(row.soft_id or 0))
    log_install_action(row, "Uninstalled", soft)
    MH.DB.Query("UPDATE mh_software SET installed = 0 WHERE id = " .. tonumber(row.soft_id or 0))
end

Completers.SOFT_INSTALL = function(row)
    local soft = MH.DB.QueryRow("SELECT * FROM mh_software WHERE id = " .. tonumber(row.soft_id or 0))
    if not soft then return end
    local softSrv = tonumber(soft.server_id or 0)
    local need = tonumber(soft.soft_ram or 0) or 0
    local free = ram_cap_mb(softSrv) - ram_used_mb(softSrv)
    if need > free then
        notify_creator(row.creator_sid, "error",
            "Not enough RAM to run " .. (soft.soft_name or "file") ..
            " (need " .. need .. " MB, free " .. math.max(0, free) .. " MB)")
        return
    end
    log_install_action(row, "Installed", soft)
    MH.DB.Query("UPDATE mh_software SET installed = 1 WHERE id = " .. tonumber(row.soft_id or 0))
end

Completers.SOFT_DOWNLOAD = function(row)
    local soft = MH.DB.QueryRow("SELECT * FROM mh_software WHERE id = " .. tonumber(row.soft_id or 0))
    if not soft then return end
    local destServer = tonumber(row.local_server or 0)
    local srcServer = tonumber(row.victim_server or 0)
    local sid = row.creator_sid or ""
    local need = tonumber(soft.soft_size or 0) or 0
    local free = hdd_cap_mb(destServer) - hdd_used_mb(destServer)
    if need > free then
        notify_creator(sid, "error",
            "Not enough HDD space to download " .. (soft.soft_name or "file") ..
            " (need " .. need .. " MB, free " .. math.max(0, free) .. " MB)")
        return
    end
    local attIp = MH.State.AttackerIP(sid)
    local srcInfo = MH.State.GetServerById(srcServer)
    MH.DB.Query("INSERT INTO mh_software (server_id, owner_sid, soft_type, soft_version, soft_name, soft_size, soft_ram, installed, hidden, content, last_collect) VALUES (" ..
        destServer .. ", " .. MH.DB.Esc(sid) .. ", " .. tonumber(soft.soft_type) ..
        ", " .. tonumber(soft.soft_version or 1) .. ", " .. MH.DB.Esc(soft.soft_name) ..
        ", " .. tonumber(soft.soft_size or 10) .. ", " .. tonumber(soft.soft_ram or 32) ..
        ", 0, 0, " .. MH.DB.Esc(soft.content or "") .. ", 0)")
    MH.State.AppendLog(destServer, "Downloaded " .. (soft.soft_name or "file") .. " from " .. (srcInfo and srcInfo.ip or "?"))
    MH.State.AppendLog(srcServer, (soft.soft_name or "file") .. " was downloaded by " .. attIp)
    MH.State.CheckMissionProgress(sid, "soft_download",
        { target_server = srcServer, soft_name = tostring(soft.soft_name or "") })
end

Completers.SOFT_UPLOAD = function(row)
    local soft = MH.DB.QueryRow("SELECT * FROM mh_software WHERE id = " .. tonumber(row.soft_id or 0))
    if not soft then return end
    local destServer = tonumber(row.victim_server or 0)
    local srcServer = tonumber(row.local_server or 0)
    local sid = row.creator_sid or ""
    local need = tonumber(soft.soft_size or 0) or 0
    local free = hdd_cap_mb(destServer) - hdd_used_mb(destServer)
    if need > free then
        notify_creator(sid, "error",
            "Not enough HDD space on target to upload " .. (soft.soft_name or "file") ..
            " (need " .. need .. " MB, free " .. math.max(0, free) .. " MB)")
        return
    end
    local attIp = MH.State.AttackerIP(sid)
    local destInfo = MH.State.GetServerById(destServer)
    MH.DB.Query("INSERT INTO mh_software (server_id, owner_sid, soft_type, soft_version, soft_name, soft_size, soft_ram, installed, hidden, content, last_collect) VALUES (" ..
        destServer .. ", " .. MH.DB.Esc(sid) .. ", " .. tonumber(soft.soft_type) ..
        ", " .. tonumber(soft.soft_version or 1) .. ", " .. MH.DB.Esc(soft.soft_name) ..
        ", " .. tonumber(soft.soft_size or 10) .. ", " .. tonumber(soft.soft_ram or 32) ..
        ", 0, 0, " .. MH.DB.Esc(soft.content or "") .. ", 0)")
    MH.State.AppendLog(srcServer, "Uploaded " .. (soft.soft_name or "file") .. " to " .. (destInfo and destInfo.ip or "?"))
    MH.State.AppendLog(destServer, (soft.soft_name or "file") .. " was uploaded by " .. attIp)
end

MH.Proc.Completers = Completers

function MH.Proc.Tick()
    local nowT = now()
    local rows = MH.DB.Query("SELECT * FROM mh_processes WHERE time_end <= " .. nowT ..
        " AND paused_remaining = 0") or {}
    local touchedCreators = {}
    for _, row in ipairs(rows) do
        local fn = Completers[row.action]
        if fn then
            local ok, err = pcall(fn, row)
            if not ok then MH.Log.error("proc", row.action or "?", tostring(err)) end
        end
        MH.DB.Query("DELETE FROM mh_processes WHERE id = " .. tonumber(row.id))
        if ((tonumber(row.cpu_usage) or 0) > 0 or (tonumber(row.net_usage) or 0) > 0) and row.creator_sid and row.creator_sid ~= "" then
            touchedCreators[row.creator_sid] = true
        end
        local ply = player.GetBySteamID64(row.creator_sid or "")
        if IsValid(ply) then MH.Api.SendSnapshot(ply, 0) end
    end
    for sid in pairs(touchedCreators) do reschedule_creator(sid) end
end

function MH.Proc.Pause(pid)
    local row = MH.DB.QueryRow("SELECT * FROM mh_processes WHERE id = " .. tonumber(pid))
    if not row or tonumber(row.paused_remaining or 0) > 0 then return false end
    local remaining = math.max(1, tonumber(row.time_end or 0) - now())
    MH.DB.Query("UPDATE mh_processes SET paused_remaining = " .. remaining ..
        " WHERE id = " .. tonumber(pid))
    if ((tonumber(row.cpu_usage) or 0) > 0 or (tonumber(row.net_usage) or 0) > 0) and
        row.creator_sid and row.creator_sid ~= "" then
        reschedule_creator(row.creator_sid)
    end
    return true
end

function MH.Proc.Resume(pid)
    local row = MH.DB.QueryRow("SELECT * FROM mh_processes WHERE id = " .. tonumber(pid))
    if not row or tonumber(row.paused_remaining or 0) <= 0 then return false end
    local newEnd = now() + tonumber(row.paused_remaining)
    MH.DB.Query("UPDATE mh_processes SET paused_remaining = 0, time_end = " .. newEnd ..
        " WHERE id = " .. tonumber(pid))
    if ((tonumber(row.cpu_usage) or 0) > 0 or (tonumber(row.net_usage) or 0) > 0) and
        row.creator_sid and row.creator_sid ~= "" then
        reschedule_creator(row.creator_sid)
    end
    return true
end

function MH.Proc.Cancel(pid)
    local row = MH.DB.QueryRow("SELECT creator_sid, cpu_usage, net_usage FROM mh_processes WHERE id = " .. tonumber(pid))
    MH.DB.Query("DELETE FROM mh_processes WHERE id = " .. tonumber(pid))
    if row and ((tonumber(row.cpu_usage) or 0) > 0 or (tonumber(row.net_usage) or 0) > 0) and
        row.creator_sid and row.creator_sid ~= "" then
        reschedule_creator(row.creator_sid)
    end
end

function MH.Proc.Complete(pid)
    local row = MH.DB.QueryRow("SELECT * FROM mh_processes WHERE id = " .. tonumber(pid))
    if not row then return end
    local fn = Completers[row.action]
    if fn then
        local ok, err = pcall(fn, row)
        if not ok then MH.Log.error("proc", row.action or "?", tostring(err)) end
    end
    MH.DB.Query("DELETE FROM mh_processes WHERE id = " .. tonumber(pid))
    if ((tonumber(row.cpu_usage) or 0) > 0 or (tonumber(row.net_usage) or 0) > 0) and
        row.creator_sid and row.creator_sid ~= "" then
        reschedule_creator(row.creator_sid)
    end
    local ply = player.GetBySteamID64(row.creator_sid or "")
    if IsValid(ply) then MH.Api.SendSnapshot(ply, 0) end
end

timer.Create("mh_proc_tick", 1, 0, function() MH.Proc.Tick() end)
