MH = MH or {}
MH.Api = {}

local N = MH.Net.Names

local function send_notify(ply, kind, text)
    net.Start(N.Notify)
    net.WriteString(kind or "info")
    net.WriteString(text or "")
    net.Send(ply)
end

local SNAPSHOT_CHUNK_SIZE = 32000
local snapshot_seq = 0
local function send_snapshot(ply, focusServerId)
    local snap = MH.State.SnapshotFor(ply)
    local json = util.TableToJSON(snap)
    local compressed = util.Compress(json) or json
    local total = #compressed
    local chunks = math.max(1, math.ceil(total / SNAPSHOT_CHUNK_SIZE))
    snapshot_seq = snapshot_seq + 1
    local seq = snapshot_seq
    for i = 1, chunks do
        local a = (i - 1) * SNAPSHOT_CHUNK_SIZE + 1
        local b = math.min(i * SNAPSHOT_CHUNK_SIZE, total)
        local part = string.sub(compressed, a, b)
        net.Start(N.StateSync)
        net.WriteUInt(seq, 32)
        net.WriteUInt(chunks, 16)
        net.WriteUInt(i, 16)
        net.WriteUInt(focusServerId or 0, 32)
        net.WriteUInt(#part, 32)
        net.WriteData(part, #part)
        net.Send(ply)
    end
end

MH.Api.SendNotify = send_notify
MH.Api.SendSnapshot = send_snapshot

local Handlers = {}

Handlers.buy_hardware = function(ply, args)
    local serverId = tonumber(args.server_id or 0)
    local kind = args.kind
    local srv = MH.State.GetServerById(serverId)
    if not srv or srv.owner_sid ~= ply:SteamID64() then
        send_notify(ply, "error", "Not your server")
        return
    end
    local tierCol = kind .. "_tier"
    local curIdx = tonumber(srv[tierCol] or 1) or 1
    local tiers = MH.Data.Hardware[kind]
    if not tiers then
        send_notify(ply, "error", "Unknown hardware kind")
        return
    end
    local nextTier = tiers[curIdx + 1]
    if not nextTier then
        send_notify(ply, "warn", "Already at top tier")
        return
    end
    local p = MH.State.GetPlayer(ply:SteamID64())
    local cash = tonumber(p and p.cash or 0) or 0
    if cash < nextTier.price then
        send_notify(ply, "error", "Not enough cash ($" .. nextTier.price .. ")")
        return
    end
    MH.State.SpendCash(ply:SteamID64(), nextTier.price,
        string.upper(kind) .. " upgrade: " .. nextTier.name, serverId)
    MH.DB.Query("UPDATE mh_servers SET " .. tierCol .. " = " .. (curIdx + 1) ..
        " WHERE id = " .. serverId)
    MH.State.AppendLog(serverId, "Upgraded " .. string.upper(kind) .. " to " .. nextTier.name)
    local buyRep = 5 + math.floor(nextTier.price / 10)
    if kind == "net" then buyRep = buyRep * 2 end
    MH.DB.Query("UPDATE mh_players SET exp = exp + " .. buyRep ..
        " WHERE sid64 = " .. MH.DB.Esc(ply:SteamID64()))
    send_notify(ply, "ok", "Installed " .. nextTier.name)
    send_snapshot(ply, serverId)
end

Handlers.buy_server = function(ply, args)
    local sid = ply:SteamID64()
    local count = MH.State.CountServers(sid)
    local price = MH.Data.PCPrice(count)
    local p = MH.State.GetPlayer(sid)
    local cash = tonumber(p and p.cash or 0) or 0
    if count >= 1 and cash < price then
        send_notify(ply, "error", "Not enough cash ($" .. price .. ")")
        return
    end
    local id = MH.State.CreateServer(sid, "Server#" .. (count + 1))
    if count >= 1 then
        MH.State.SpendCash(sid, price, "New server allocation (Server#" .. (count + 1) .. ")", id)
    end
    local slot = count + 1
    local serverRep = slot == 2 and 100 or (slot == 3 and 500 or (500 * slot))
    MH.DB.Query("UPDATE mh_players SET exp = exp + " .. serverRep ..
        " WHERE sid64 = " .. MH.DB.Esc(sid))
    send_notify(ply, "ok", "New server allocated")
    send_snapshot(ply, id)
end

Handlers.refresh = function(ply, args)
    send_snapshot(ply, tonumber(args.server_id or 0))
end

local function owned_server(ply, serverId)
    local srv = MH.State.GetServerById(serverId)
    if not srv or srv.owner_sid ~= ply:SteamID64() then return nil end
    return srv
end

Handlers.license = function(ply, args)
    local sid = ply:SteamID64()
    local softId = tonumber(args.soft_id or 0)
    local soft = MH.DB.QueryRow("SELECT * FROM mh_software WHERE id = " .. softId)
    if not soft then send_notify(ply, "error", "No such file") return end
    local srv = owned_server(ply, tonumber(soft.server_id))
    if not srv then send_notify(ply, "error", "That file is not on one of your servers") return end
    local softType = tonumber(soft.soft_type)
    local softMeta = MH.Data.Soft[softType] or {}
    if not softMeta.research or softMeta.research <= 0 then
        send_notify(ply, "error", "This software cannot be licensed")
        return
    end
    local currentLicense = tostring(soft.licensed_to or "")
    if currentLicense == "NULL" then currentLicense = "" end
    if currentLicense ~= "" then
        if currentLicense == sid then
            send_notify(ply, "error", "This file is already licensed to you")
        else
            send_notify(ply, "error", "This file is already licensed. Only unlicensed files can be licensed.")
        end
        return
    end
    local name = tostring(args.name or ""):Trim():sub(1, 32)
    if name == "" then send_notify(ply, "error", "Give the licensed file a name") return end
    if not name:match("^[%w _%-]+$") then
        send_notify(ply, "error", "Name may only contain letters, numbers, spaces, underscore, hyphen")
        return
    end
    local curV = tonumber(soft.soft_version) or 1
    local cost = MH.Data.LicenseFee(softType, curV)
    local p = MH.State.GetPlayer(sid)
    local cash = tonumber(p and p.cash or 0) or 0
    if cash < cost then
        send_notify(ply, "error", "Licensing costs $" .. cost)
        return
    end
    MH.State.SpendCash(sid, cost,
        "License: " .. (softMeta.name or "software") .. " (" .. name .. ")", srv.id)
    MH.DB.Query("UPDATE mh_software SET licensed_to = " .. MH.DB.Esc(sid) ..
        ", soft_name = " .. MH.DB.Esc(name) ..
        " WHERE id = " .. softId)
    MH.State.AppendLog(srv.id, "Licensed " .. (softMeta.name or "file") .. " as " .. name .. (softMeta.ext or ""))
    send_notify(ply, "ok", "Licensed as " .. name .. (softMeta.ext or ""))
    send_snapshot(ply, srv.id)
end

Handlers.research = function(ply, args)
    local sid = ply:SteamID64()
    local softId = tonumber(args.soft_id or 0)
    local soft = MH.DB.QueryRow("SELECT * FROM mh_software WHERE id = " .. softId)
    if not soft then send_notify(ply, "error", "No such file") return end
    local srv = owned_server(ply, tonumber(soft.server_id))
    if not srv then send_notify(ply, "error", "That file is not on one of your servers") return end
    local softType = tonumber(soft.soft_type)
    if not MH.Data.Soft[softType] then send_notify(ply, "error", "Unknown software type") return end
    local rowLicense = tostring(soft.licensed_to or "")
    if rowLicense == "NULL" then rowLicense = "" end
    if rowLicense ~= sid then
        send_notify(ply, "error", "You must license this file before researching it")
        return
    end
    local curV = tonumber(soft.soft_version) or 0
    local cost = MH.Proc.ResearchCost(softType, curV)
    local p = MH.State.GetPlayer(sid)
    local cash = tonumber(p and p.cash or 0) or 0
    if cash < cost then
        send_notify(ply, "error", "Research costs $" .. cost)
        return
    end
    MH.State.SpendCash(sid, cost,
        "Research: " .. MH.Data.SoftName(softType) .. " v" .. MH.Data.DotVersion(curV + 1), srv.id)
    local nextV = curV + 1
    local dur = MH.Data.Dur.research(nextV)
    MH.Proc.Spawn({
        creator_sid = sid,
        local_server = srv.id, victim_server = 0,
        action = "research", soft_id = softId,
        duration = dur, cpu_usage = 50,
    })
    send_notify(ply, "ok", "Research started: " .. MH.Data.SoftName(softType) .. " (" .. dur .. "s, $" .. cost .. ")")
    send_snapshot(ply, srv.id)
end

Handlers.install_toggle = function(ply, args)
    local softId = tonumber(args.soft_id or 0)
    local row = MH.DB.QueryRow("SELECT * FROM mh_software WHERE id = " .. softId)
    if not row then return end
    local srv = owned_server(ply, tonumber(row.server_id))
    if not srv then send_notify(ply, "error", "Not your server") return end
    local newState = tonumber(row.installed) == 1 and 0 or 1
    MH.DB.Query("UPDATE mh_software SET installed = " .. newState .. " WHERE id = " .. softId)
    send_snapshot(ply, srv.id)
end

local IP_LOOKUP_WINDOW = 60
local IP_LOOKUP_LIMIT = 30
local IP_LOOKUP_AUTOBAN_HITS = 5
local ip_lookup_log = {}
local ip_lookup_strikes = {}

local function check_ip_lookup_rate(ply)
    local sid = ply:SteamID64()
    local nowT = os.time()
    local log = ip_lookup_log[sid] or {}
    local fresh = {}
    for _, t in ipairs(log) do
        if (nowT - t) < IP_LOOKUP_WINDOW then fresh[#fresh + 1] = t end
    end
    fresh[#fresh + 1] = nowT
    ip_lookup_log[sid] = fresh
    if #fresh > IP_LOOKUP_LIMIT then
        ip_lookup_strikes[sid] = (ip_lookup_strikes[sid] or 0) + 1
        MH.DB.Query("UPDATE mh_players SET abuse_cmd_hits = COALESCE(abuse_cmd_hits, 0) + 1 WHERE sid64 = " ..
            MH.DB.Esc(sid))
        if MH.Api and MH.Api.LogAbuse then
            MH.Api.LogAbuse(sid, "ip_sweep", #fresh .. " IP lookups in " .. IP_LOOKUP_WINDOW .. "s")
        end
        if ip_lookup_strikes[sid] >= IP_LOOKUP_AUTOBAN_HITS and not ply:IsSuperAdmin() then
            MH.State.BanSid(sid, "Autoban: IP sweep (" .. ip_lookup_strikes[sid] .. " strikes)", "console")
            send_notify(ply, "error", "You have been automatically banned for IP sweeping.")
            MH.Log.warn("abuse", "autoban", sid .. " autobanned for IP sweep")
        else
            send_notify(ply, "error", "Rate limit: slow down the IP lookups.")
        end
        return false
    end
    return true
end

Handlers.scan_ip = function(ply, args)
    local ip = tostring(args.ip or "")
    if ip == "" then send_notify(ply, "error", "No IP") return end
    if not check_ip_lookup_rate(ply) then return end
    local srv = MH.State.GetServersFor(ply:SteamID64())[1]
    if not srv then send_notify(ply, "error", "No server") return end
    local target = MH.DB.QueryRow("SELECT id FROM mh_servers WHERE ip = " .. MH.DB.Esc(ip))
    if not target then send_notify(ply, "warn", "No reply from " .. ip) return end
    local portScan = MH.DB.QueryValue("SELECT MAX(soft_version) FROM mh_software WHERE server_id = " ..
        tonumber(srv.id) .. " AND soft_type = 3 AND installed = 1")
    if (tonumber(portScan) or 0) <= 0 then
        send_notify(ply, "error", "You need a running Port Scan to scan")
        return
    end
    MH.State.MarkDiscovered(ply:SteamID64(), tonumber(target.id))
    MH.Proc.Spawn({
        creator_sid = ply:SteamID64(),
        local_server = srv.id, victim_server = tonumber(target.id),
        action = "scan", info = ip, duration = MH.Data.Dur.scan(), cpu_usage = 10,
    })
    send_notify(ply, "ok", "Scanning " .. ip)
    send_snapshot(ply, srv.id)
end

local ATTACK_METHODS = {
    bruteforce  = { soft_type = 1,  soft_name = "Cracker",     defender_type = 2, defender_name = "Hasher",   kind = "bf" },
    hasher      = { soft_type = 2,  soft_name = "Hasher",      defender_type = 1, defender_name = "Cracker",  kind = "bf" },
    ftp_exploit = { soft_type = 13, soft_name = "FTP Exploit", defender_type = 4, defender_name = "Firewall", kind = "xp" },
    ssh_exploit = { soft_type = 14, soft_name = "SSH Exploit", defender_type = 4, defender_name = "Firewall", kind = "xp" },
}

Handlers.crack_ip = function(ply, args)
    local ip = tostring(args.ip or "")
    local method = tostring(args.method or "bruteforce")
    local cfg = ATTACK_METHODS[method] or ATTACK_METHODS.bruteforce
    local srv = MH.State.GetServersFor(ply:SteamID64())[1]
    if not srv then send_notify(ply, "error", "No server") return end
    local target = MH.DB.QueryRow("SELECT id, owner_sid FROM mh_servers WHERE ip = " .. MH.DB.Esc(ip))
    if not target then send_notify(ply, "warn", "No reply from " .. ip) return end
    if target.owner_sid == ply:SteamID64() then
        send_notify(ply, "error", "You cannot hack yourself")
        return
    end
    local victimEarly = MH.State.GetServerById(tonumber(target.id))
    local existingHack = MH.DB.QueryRow("SELECT discovered_pass FROM mh_hacked WHERE owner_sid = " ..
        MH.DB.Esc(ply:SteamID64()) .. " AND target_server = " .. tonumber(target.id) .. " LIMIT 1")
    if existingHack and victimEarly and
        tostring(existingHack.discovered_pass or "") == tostring(victimEarly.root_pass or "") then
        MH.DB.Query("INSERT OR REPLACE INTO mh_internet (owner_sid, target_server, authed, auth_user, stamp) VALUES (" ..
            MH.DB.Esc(ply:SteamID64()) .. ", " .. tonumber(target.id) .. ", 1, 'root', " .. os.time() .. ")")
        MH.State.AppendLog(tonumber(target.id), "User logged in from " .. MH.State.AttackerIP(ply:SteamID64()))
        send_notify(ply, "ok", "Credentials cached. Logged in to " .. ip)
        send_snapshot(ply, srv.id)
        return
    end
    local attackerSoft = MH.DB.QueryRow("SELECT soft_version FROM mh_software WHERE server_id = " .. tonumber(srv.id) ..
        " AND soft_type = " .. cfg.soft_type .. " ORDER BY soft_version DESC LIMIT 1")
    local attVer = attackerSoft and tonumber(attackerSoft.soft_version) or 0
    if attVer <= 0 then
        send_notify(ply, "error", "No " .. cfg.soft_name .. " installed")
        return
    end
    local victim = MH.State.GetServerById(tonumber(target.id))
    if cfg.kind == "xp" and tostring(victim.name or "") == "MSA" then
        send_notify(ply, "error", "It's impossible to exploit the MSA. You should try to perform a bruteforce attack instead.")
        return
    end
    local defSoft = MH.DB.QueryRow("SELECT soft_version FROM mh_software WHERE server_id = " .. tonumber(victim.id) ..
        " AND soft_type = " .. cfg.defender_type .. " ORDER BY soft_version DESC LIMIT 1")
    local defVer = defSoft and tonumber(defSoft.soft_version) or 0
    local dur
    if cfg.kind == "xp" then
        dur = MH.Data.Dur.exploit()
    else
        if attVer < defVer then
            return
        end
        dur = MH.Data.Dur.crack(attVer, defVer)
    end
    MH.Proc.Spawn({
        creator_sid = ply:SteamID64(),
        local_server = srv.id, victim_server = tonumber(target.id),
        action = "crack", info = ip, duration = dur, cpu_usage = 80,
    })
    send_notify(ply, "ok", cfg.soft_name .. " attack on " .. ip .. " (" .. dur .. "s)")
    send_snapshot(ply, srv.id)
end

local BANK_REGISTER_COST = {
    ["First International Bank"] = 0,
    ["HEBC Bank"] = 500,
    ["American Express Bank"] = 5000,
    ["Swiss International Bank"] = 20000,
    ["Ultimate Bank"] = 100000,
}

Handlers.bank_create = function(ply, args)
    local sid = ply:SteamID64()
    local bankNpc = tonumber(args.bank_id or 0) or 0
    if bankNpc <= 0 then send_notify(ply, "error", "No bank selected") return end
    local bank = MH.DB.QueryRow("SELECT id, name FROM mh_servers WHERE id = " .. bankNpc ..
        " AND is_npc = 1 AND LOWER(name) LIKE '%bank%'")
    if not bank then send_notify(ply, "error", "Not a valid bank") return end
    local existing = MH.DB.QueryValue("SELECT id FROM mh_banks WHERE bank_npc = " .. bankNpc ..
        " AND owner_sid = " .. MH.DB.Esc(sid) .. " LIMIT 1")
    if existing then send_notify(ply, "error", "You already have an account at " .. tostring(bank.name)) return end
    local cost = BANK_REGISTER_COST[tostring(bank.name)] or 1000
    if cost > 0 then
        local p = MH.State.GetPlayer(sid)
        local cash = tonumber(p and p.cash or 0) or 0
        if cash < cost then
            send_notify(ply, "error", "Not enough cash. Registration costs $" .. MH.Data.FmtCash(cost))
            return
        end
        MH.State.SpendCash(sid, cost, "Bank registration at " .. tostring(bank.name), 0)
    end
    local acc = tostring(math.random(111111111, 999999999))
    local pass = MH.State.GenPass(6)
    MH.DB.Query("INSERT INTO mh_banks (bank_npc, acc_num, acc_pass, owner_sid, cash, created) VALUES (" ..
        bankNpc .. ", " .. MH.DB.Esc(acc) .. ", " .. MH.DB.Esc(pass) ..
        ", " .. MH.DB.Esc(sid) .. ", 0, " .. os.time() .. ")")
    MH.State.AppendLog(bankNpc, "New account registered: " .. acc .. " by " .. MH.State.AttackerIP(sid))
    MH.State.CheckSourcenetAccountOpened(sid)
    send_notify(ply, "ok", "Opened account at " .. tostring(bank.name) .. ": " .. acc .. " pass " .. pass)
    send_snapshot(ply, 0)
end

Handlers.bank_transfer = function(ply, args)
    local fromAcc = tostring(args.from or "")
    local fromPass = tostring(args.pass or "")
    local toAcc = tostring(args.to or "")
    local amount = math.floor(tonumber(args.amount or 0) or 0)
    if amount <= 0 then send_notify(ply, "error", "Bad amount") return end
    local src = MH.DB.QueryRow("SELECT * FROM mh_banks WHERE acc_num = " .. MH.DB.Esc(fromAcc))
    local dst = MH.DB.QueryRow("SELECT * FROM mh_banks WHERE acc_num = " .. MH.DB.Esc(toAcc))
    if not src or not dst then send_notify(ply, "error", "Account not found") return end
    if src.acc_pass ~= fromPass then send_notify(ply, "error", "Bad password") return end
    if tonumber(src.cash) < amount then send_notify(ply, "error", "Insufficient funds") return end
    MH.DB.Query("UPDATE mh_banks SET cash = cash - " .. amount .. " WHERE id = " .. tonumber(src.id))
    MH.DB.Query("UPDATE mh_banks SET cash = cash + " .. amount .. " WHERE id = " .. tonumber(dst.id))
    MH.State.CheckSourcenetAlert(ply:SteamID64(), amount)
    local transferRep = 200 + math.floor(amount / 15)
    MH.DB.Query("UPDATE mh_players SET exp = exp + " .. transferRep ..
        " WHERE sid64 = " .. MH.DB.Esc(ply:SteamID64()))
    send_notify(ply, "ok", "Transferred $" .. amount .. " to " .. toAcc)
    send_snapshot(ply, 0)
end

Handlers.bank_collect = function(ply, args)
    local sid = ply:SteamID64()
    local accNum = tostring(args.acc or "")
    local src = MH.DB.QueryRow("SELECT * FROM mh_banks WHERE acc_num = " .. MH.DB.Esc(accNum) ..
        " AND owner_sid = " .. MH.DB.Esc(sid))
    if not src then send_notify(ply, "error", "Not your account") return end
    local amount = tonumber(src.cash) or 0
    if amount <= 0 then send_notify(ply, "warn", "Account empty") return end
    MH.DB.Query("UPDATE mh_banks SET cash = 0 WHERE id = " .. tonumber(src.id))
    MH.State.AddCash(sid, amount, "withdrawal from account " .. accNum)
    MH.State.CheckSourcenetAlert(sid, amount)
    send_notify(ply, "ok", "Withdrew $" .. amount)
    send_snapshot(ply, 0)
end

local BTC_BUY_RATE = MH.Data.BtcBuyRate or 81650
local BTC_SELL_RATE = MH.Data.BtcSellRate or 81624

local function resolve_recipient(target)
    target = tostring(target or ""):Trim()
    if target == "" then return nil end
    if target:match("^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$") then
        local hit = MH.DB.QueryValue("SELECT sid64 FROM mh_players WHERE sid64 = " .. MH.DB.Esc(target))
        if hit then return target end
    end
    local byNick = MH.DB.QueryValue("SELECT sid64 FROM mh_players WHERE nick = " .. MH.DB.Esc(target) .. " LIMIT 1")
    if byNick then return byNick end
    return nil
end

MH.BtcSessions = MH.BtcSessions or {}

local function btc_logged_in(sid)
    return MH.BtcSessions[sid] == true
end

local BTC_MIN_TX = 0.1

Handlers.btc_buy = function(ply, args)
    local sid = ply:SteamID64()
    if not btc_logged_in(sid) then send_notify(ply, "error", "Please login first") return end
    local cashSpend = math.floor(tonumber(args.cash or 0) or 0)
    if cashSpend <= 0 then send_notify(ply, "error", "Bad numbers") return end
    if (cashSpend / BTC_BUY_RATE) < BTC_MIN_TX then
        send_notify(ply, "error", "Minimum transaction is " .. BTC_MIN_TX .. " BTC ($" ..
            MH.Data.FmtCash(math.ceil(BTC_BUY_RATE * BTC_MIN_TX)) .. ")")
        return
    end
    local p = MH.State.GetPlayer(sid)
    if (tonumber(p.cash) or 0) < cashSpend then send_notify(ply, "error", "Not enough cash") return end
    local btc = cashSpend / BTC_BUY_RATE
    MH.State.SpendCash(sid, cashSpend,
        "Bitcoin purchase (" .. string.format("%.7f", btc) .. " BTC)", 0)
    MH.DB.Query("UPDATE mh_players SET bitcoin = bitcoin + " ..
        string.format("%.7f", btc) .. " WHERE sid64 = " .. MH.DB.Esc(sid))
    MH.State.AwardBadge(sid, "first_btc")
    send_notify(ply, "ok", "Bought " .. string.format("%.7f", btc) .. " BTC")
    send_snapshot(ply, 0)
end

Handlers.bank_change_pass = function(ply, args)
    local sid = ply:SteamID64()
    local acc = tostring(args.acc or "")
    local row = MH.DB.QueryRow("SELECT * FROM mh_banks WHERE acc_num = " .. MH.DB.Esc(acc) ..
        " AND owner_sid = " .. MH.DB.Esc(sid))
    if not row then send_notify(ply, "error", "Not your account") return end
    local newPass = MH.State.GenPass(6)
    MH.DB.Query("UPDATE mh_banks SET acc_pass = " .. MH.DB.Esc(newPass) ..
        " WHERE id = " .. tonumber(row.id))
    send_notify(ply, "ok", "New password: " .. newPass)
    send_snapshot(ply, 0)
end

Handlers.bank_close = function(ply, args)
    local sid = ply:SteamID64()
    local acc = tostring(args.acc or "")
    local row = MH.DB.QueryRow("SELECT * FROM mh_banks WHERE acc_num = " .. MH.DB.Esc(acc) ..
        " AND owner_sid = " .. MH.DB.Esc(sid))
    if not row then send_notify(ply, "error", "Not your account") return end
    local refund = tonumber(row.cash or 0) or 0
    local closedAcc = tostring(row.acc_num or "")
    if refund > 0 then MH.State.AddCash(sid, refund, "closed account " .. closedAcc) end
    MH.DB.Query("DELETE FROM mh_banks WHERE id = " .. tonumber(row.id))
    send_notify(ply, "ok", "Account closed. $" .. refund .. " moved to your default account.")
    send_snapshot(ply, 0)
end

Handlers.btc_transfer = function(ply, args)
    local sid = ply:SteamID64()
    if not btc_logged_in(sid) then send_notify(ply, "error", "Please login first") return end
    local to = resolve_recipient(args.to)
    if not to then send_notify(ply, "error", "Recipient not found") return end
    if to == sid then send_notify(ply, "error", "Cannot transfer to yourself") return end
    local amount = tonumber(args.amount or 0) or 0
    if amount <= 0 then send_notify(ply, "error", "Bad amount") return end
    if amount < BTC_MIN_TX then
        send_notify(ply, "error", "Minimum transaction is " .. BTC_MIN_TX .. " BTC")
        return
    end
    local p = MH.State.GetPlayer(sid)
    if (tonumber(p and p.bitcoin or 0) or 0) < amount then send_notify(ply, "error", "Not enough BTC") return end
    MH.DB.Query("UPDATE mh_players SET bitcoin = bitcoin - " .. string.format("%.7f", amount) ..
        " WHERE sid64 = " .. MH.DB.Esc(sid))
    MH.DB.Query("UPDATE mh_players SET bitcoin = bitcoin + " .. string.format("%.7f", amount) ..
        " WHERE sid64 = " .. MH.DB.Esc(to))
    send_notify(ply, "ok", "Sent " .. string.format("%.7f", amount) .. " BTC")
    send_snapshot(ply, 0)
end

Handlers.btc_sell = function(ply, args)
    local sid = ply:SteamID64()
    if not btc_logged_in(sid) then send_notify(ply, "error", "Please login first") return end
    local amount = tonumber(args.amount or 0) or 0
    if amount <= 0 then send_notify(ply, "error", "Bad amount") return end
    if amount < BTC_MIN_TX then
        send_notify(ply, "error", "Minimum transaction is " .. BTC_MIN_TX .. " BTC")
        return
    end
    local p = MH.State.GetPlayer(sid)
    if (tonumber(p and p.bitcoin or 0) or 0) < amount then send_notify(ply, "error", "Not enough BTC") return end
    local cash = math.floor(amount * BTC_SELL_RATE)
    MH.DB.Query("UPDATE mh_players SET bitcoin = bitcoin - " .. string.format("%.7f", amount) ..
        " WHERE sid64 = " .. MH.DB.Esc(sid))
    MH.State.AddCash(sid, cash, "Bitcoin sale (" .. string.format("%.7f", amount) .. " BTC)")
    send_notify(ply, "ok", "Sold " .. string.format("%.7f", amount) .. " BTC for $" .. cash)
    send_snapshot(ply, 0)
end

Handlers.doom_launch = function(ply, args)
    local sid = ply:SteamID64()
    local targetId = tonumber(args.target_server or 0) or 0
    local doom = MH.DB.QueryRow("SELECT * FROM mh_software WHERE id = " .. tonumber(args.soft_id or 0) ..
        " AND owner_sid = " .. MH.DB.Esc(sid) .. " AND soft_type IN (29, 96)")
    if not doom then send_notify(ply, "error", "No Doom virus of yours on that target") return end
    if tonumber(doom.server_id) ~= targetId then send_notify(ply, "error", "Doom is not installed on this target") return end
    local srv = MH.DB.QueryRow("SELECT * FROM mh_servers WHERE id = " .. targetId)
    if not srv then return end
    if tonumber(srv.doom_status or 0) == 1 then send_notify(ply, "error", "Doom already released from this server") return end
    MH.DB.Query("UPDATE mh_servers SET doom_status = 1, doom_owner_sid = " .. MH.DB.Esc(sid) ..
        " WHERE id = " .. targetId)
    local myServer = MH.State.GetServersFor(sid)[1]
    MH.Proc.Spawn({
        creator_sid = sid,
        local_server = (myServer and myServer.id) or 0,
        victim_server = targetId,
        action = "DOOM_SPREAD", soft_id = tonumber(doom.soft_version or 1),
        info = tostring(srv.ip or ""),
        duration = 180, cpu_usage = 10, net_usage = 30,
    })
    MH.State.AppendLog(targetId, "DOOM virus released")
    MH.State.AddNews((MH.DB.QueryValue("SELECT nick FROM mh_players WHERE sid64 = " .. MH.DB.Esc(sid)) or "someone") ..
        " unleashed DOOM from " .. tostring(srv.ip or "?"))
    send_notify(ply, "warn", "DOOM released. The world is going to notice.")
    send_snapshot(ply, 0)
end

local function bump_virus_count(sid)
    MH.DB.Query("UPDATE mh_players SET virus_installs = virus_installs + 1 WHERE sid64 = " .. MH.DB.Esc(sid))
end

Handlers.virus_install = function(ply, args)
    local sid = ply:SteamID64()
    local targetId = tonumber(args.target_server or 0)
    local softType = tonumber(args.soft_type or 0)
    if not ({[8]=1,[9]=1,[10]=1,[11]=1,[20]=1})[softType] then send_notify(ply, "error", "Not a virus") return end
    local hacked = MH.DB.QueryRow("SELECT id FROM mh_hacked WHERE owner_sid = " .. MH.DB.Esc(sid) ..
        " AND target_server = " .. targetId)
    if not hacked then send_notify(ply, "error", "You have not hacked that target") return end
    local existing = MH.DB.QueryValue("SELECT 1 FROM mh_software WHERE server_id = " .. targetId ..
        " AND owner_sid = " .. MH.DB.Esc(sid) .. " AND soft_type = " .. softType .. " LIMIT 1")
    if existing then
        send_notify(ply, "error", "You already have that virus installed on this host")
        return
    end
    local mySoft = MH.DB.QueryRow("SELECT MAX(soft_version) AS v FROM mh_software WHERE owner_sid = " .. MH.DB.Esc(sid) ..
        " AND soft_type = " .. softType)
    local ver = mySoft and tonumber(mySoft.v) or 0
    if ver <= 0 then send_notify(ply, "error", "You do not own that virus") return end
    local meta = MH.Data.Soft[softType]
    MH.DB.Query("INSERT INTO mh_software (server_id, owner_sid, soft_type, soft_version, soft_name, soft_size, soft_ram, installed, hidden, last_collect) VALUES (" ..
        targetId .. ", " .. MH.DB.Esc(sid) .. ", " .. softType .. ", " .. ver ..
        ", " .. MH.DB.Esc(meta.name) .. ", 10, 32, 1, 1, " .. os.time() .. ")")
    MH.State.AwardBadge(sid, "first_virus")
    bump_virus_count(sid)
    send_notify(ply, "ok", "Installed " .. meta.name .. " v" .. MH.Data.DotVersion(ver))
    send_snapshot(ply, 0)
end

Handlers.virus_collect = function(ply, args)
    local sid = ply:SteamID64()
    local accNum = tostring(args.account or "")
    local installed = tonumber(MH.DB.QueryValue(
        "SELECT COUNT(*) FROM mh_software WHERE owner_sid = " .. MH.DB.Esc(sid) ..
        " AND installed = 1 AND soft_type IN (8, 9, 20)")) or 0
    if installed == 0 then
        send_notify(ply, "warn", "No viruses installed to collect from")
        return
    end
    local cash, btc, ready, total = MH.Virus.CollectFor(sid, accNum ~= "" and accNum or nil)
    if total > 0 and ready == 0 then
        send_notify(ply, "error", "All servers were ignored because they did not match the minimum collect time")
        return
    end
    if (tonumber(btc) or 0) > 0 then MH.State.AwardBadge(sid, "first_btc") end
    send_notify(ply, "ok", "Collected $" .. tostring(cash) .. " and " .. string.format("%.7f", btc) ..
        " BTC from " .. ready .. " viruses")
    send_snapshot(ply, 0)
end

local MISSION_TYPES_EXPLOIT = {
    { mtype = 50, title = "Steal classified data", prizeMin = 1000000, prizeMax = 1000000,
      briefing = "The payoff of a lifetime. A sealed data set on a hardened target. Hack in, pull the archive, come back with it intact. This is not a drill.\n\nSteps:\n1. The target is MSA, if it exists in your discovered IPs. Scan it, Bruteforce it.\n2. Once logged in, download any file from the target.\n3. Press Complete here when the archive is on your rig.\n\nNo retries if you get burned. Choose the moment carefully." },
    { mtype = 51, title = "Exploit", prizeMin = 1000000, prizeMax = 1000000,
      briefing = "A million-dollar contract. The client wants a sanctioned exploit against a government-grade firewall.\n\nSteps:\n1. Use an FTP or SSH Exploit soft against a target your Scan has flagged VULNERABLE.\n2. Log in, delete at least one file, log out.\n3. Press Complete.\n\nUse the Scan output on the Internet tab to pick the right target." },
}

local MISSION_TYPES = {
    { mtype = 1, title = "Delete a software",   prizeMin = 300,  prizeMax = 2500,
      briefing = "A client needs a specific piece of software gone from a target server.\n\nSteps:\n1. Open the Internet tab and point your browser at the target IP.\n2. If you do not have the root password, Bruteforce the target until it is yours.\n3. Log in and open the Softwares panel on the remote machine.\n4. Delete the file.\n\nWhen it is gone, come back to Missions and press Complete to collect the prize." },
    { mtype = 2, title = "Steal a software",    prizeMin = 500,  prizeMax = 4000,
      briefing = "The client wants a copy of a target's software, intact.\n\nSteps:\n1. Hack the target server from the Internet tab.\n2. Once logged in, locate the file on the remote disk.\n3. Download it to your local disk.\n\nWhen the file is on your rig, press Complete on this mission." },
    { mtype = 3, title = "Check bank status",   prizeMin = 400,  prizeMax = 3500,
      briefing = "The client wants to know how much money sits in a particular account at the target bank.\n\nSteps:\n1. Hack the target bank's server from the Internet tab.\n2. The crack will capture one of its account credentials into your Hacked Database.\n3. Open the account overview and read the balance.\n\nPress Complete to report back." },
    { mtype = 4, title = "Transfer money",      prizeMin = 600,  prizeMax = 6000,
      briefing = "Divert funds out of the target and into your own wallet.\n\nSteps:\n1. Hack the target bank.\n2. Captured credentials land in your Hacked Database under Bank Accounts.\n3. Siphon the balance to your wallet.\n\nPress Complete when the money has moved. Expect a Sourcenet alert if the amount is big." },
    { mtype = 5, title = "DDoS a server",       prizeMin = 1000, prizeMax = 10000,
      briefing = "The client wants a competitor's servers knocked offline. Hit the target with a DDoS until its HP drops to zero.\n\nSteps:\n1. Earn DDoS Security (cert 5) and plant three or more active DDoS viruses on servers you own.\n2. Open Hacked Database -> DDoS and target the mission server.\n3. Each DDoS run chips at the target's HP. Keep hammering it until it reads offline.\n\nPress Complete once the server is down." },
}
MH.MissionTypes = MISSION_TYPES

local function mission_title(mtype)
    for _, m in ipairs(MISSION_TYPES) do if m.mtype == mtype then return m.title end end
    if mtype >= 80 and mtype <= 84 then return "Tutorial mission" end
    if mtype == 50 or mtype == 51 then return "Exploit" end
    return "Mission #" .. tostring(mtype)
end
MH.MissionTitle = mission_title

Handlers.log_edit_submit = function(ply, args)
    local srv = owned_server(ply, tonumber(args.server_id or 0))
    if not srv then send_notify(ply, "error", "Not your server") return end
    local busy = MH.DB.QueryValue("SELECT 1 FROM mh_processes WHERE action IN ('E_LOG','D_LOG') " ..
        "AND local_server = " .. tonumber(srv.id) .. " LIMIT 1")
    if busy then send_notify(ply, "error", "A log process is already running") return end
    local content = tostring(args.content or "")
    local current = MH.State.ReadLog(tonumber(srv.id))
    if content == current then send_notify(ply, "warn", "Identical log, no change") return end
    MH.DB.Query("INSERT INTO mh_tmp_log (server_id, content, author_sid, stamp) VALUES (" ..
        tonumber(srv.id) .. ", " .. MH.DB.Esc(content) .. ", " ..
        MH.DB.Esc(ply:SteamID64()) .. ", " .. os.time() .. ")")
    local tmpId = tonumber(MH.DB.QueryValue("SELECT last_insert_rowid()"))
    local dur = MH.Data.Dur.edit_log(#current, #content, MH.Data.ServerCPU(srv), true)
    MH.Proc.Spawn({
        creator_sid = ply:SteamID64(),
        local_server = srv.id, victim_server = 0,
        action = "E_LOG", soft_id = tmpId, info = "",
        duration = dur, cpu_usage = 40,
    })
    send_notify(ply, "ok", "Editing log (" .. dur .. "s)")
    send_snapshot(ply, srv.id)
end

Handlers.log_delete_all = function(ply, args)
    local srv = owned_server(ply, tonumber(args.server_id or 0))
    if not srv then send_notify(ply, "error", "Not your server") return end
    local busy = MH.DB.QueryValue("SELECT 1 FROM mh_processes WHERE action IN ('E_LOG','D_LOG') " ..
        "AND local_server = " .. tonumber(srv.id) .. " LIMIT 1")
    if busy then send_notify(ply, "error", "A log process is already running") return end
    local curLen = #MH.State.ReadLog(tonumber(srv.id))
    local dur = MH.Data.Dur.edit_log(curLen, 0, MH.Data.ServerCPU(srv), true)
    MH.Proc.Spawn({
        creator_sid = ply:SteamID64(),
        local_server = srv.id, victim_server = 0,
        action = "D_LOG", soft_id = 0, info = "",
        duration = dur, cpu_usage = 20,
    })
    send_notify(ply, "ok", "Deleting log (" .. dur .. "s)")
    send_snapshot(ply, srv.id)
end

local function owned_process(ply, pid)
    local row = MH.DB.QueryRow("SELECT * FROM mh_processes WHERE id = " .. tonumber(pid))
    if not row or row.creator_sid ~= ply:SteamID64() then return nil end
    return row
end

Handlers.proc_pause = function(ply, args)
    local row = owned_process(ply, tonumber(args.pid or 0))
    if not row then send_notify(ply, "error", "No such process") return end
    if MH.Proc.Pause(row.id) then send_notify(ply, "ok", "Paused") else send_notify(ply, "warn", "Already paused") end
    send_snapshot(ply, 0)
end

Handlers.proc_resume = function(ply, args)
    local row = owned_process(ply, tonumber(args.pid or 0))
    if not row then send_notify(ply, "error", "No such process") return end
    if MH.Proc.Resume(row.id) then send_notify(ply, "ok", "Resumed") else send_notify(ply, "warn", "Not paused") end
    send_snapshot(ply, 0)
end

Handlers.proc_delete = function(ply, args)
    local row = owned_process(ply, tonumber(args.pid or 0))
    if not row then send_notify(ply, "error", "No such process") return end
    MH.Proc.Cancel(row.id)
    send_notify(ply, "ok", "Cancelled")
    send_snapshot(ply, 0)
end

Handlers.proc_complete = function(ply, args)
    local row = owned_process(ply, tonumber(args.pid or 0))
    if not row then send_notify(ply, "error", "No such process") return end
    local sid = ply:SteamID64()
    local nowT = os.time()
    local timeEnd = tonumber(row.time_end or 0) or 0
    local paused = (tonumber(row.paused_remaining or 0) or 0) > 0
    local isNatural = (not paused) and timeEnd > 0 and nowT >= timeEnd
    if isNatural then
        MH.Proc.Complete(row.id)
        send_notify(ply, "ok", "Process completed")
    else
        if tostring(row.action or "") == "DOOM_SPREAD" then
            send_notify(ply, "error", "Doom virus spread cannot be fast-finished")
            return
        end
        if tostring(row.action or "") == "crack" then
            local victimId = tonumber(row.victim_server or 0) or 0
            local victim = victimId > 0 and MH.State.GetServerById(victimId) or nil
            if victim and tonumber(victim.is_npc or 0) ~= 1 then
                send_notify(ply, "error", "Cracks against players cannot be fast-finished")
                return
            end
        end
        local p = MH.State.GetPlayer(sid)
        local burn = 0.5
        if (tonumber(p and p.bitcoin or 0) or 0) < burn then
            send_notify(ply, "error", "Fast-finish costs 0.5 BTC. Buy BTC first.")
            return
        end
        MH.DB.Query("UPDATE mh_players SET bitcoin = bitcoin - " .. string.format("%.7f", burn) ..
            " WHERE sid64 = " .. MH.DB.Esc(sid))
        local wallet = MH.DB.QueryRow("SELECT address FROM mh_btc_wallets WHERE owner_sid = " .. MH.DB.Esc(sid))
        local walletAddr = (wallet and wallet.address) and tostring(wallet.address) or "unknown"
        local primary = MH.State.GetServersFor(sid)[1]
        if primary then
            MH.State.AppendLog(primary.id,
                "localhost spent " .. string.format("%.7f", burn) .. " BTC to fast-finish process from wallet " .. walletAddr)
        end
        MH.Proc.Complete(row.id)
        send_notify(ply, "ok", "Fast-finished (-0.5 BTC)")
    end
    send_snapshot(ply, 0)
end

local SOFT_ACTIONS = {
    delete    = { proc = "SOFT_DELETE",    cpu = 15, label = "Deleting",
                  dur = function(soft, cpu, isLocal) return MH.Data.Dur.delete(soft.soft_size, cpu, isLocal) end },
    hide      = { proc = "SOFT_HIDE",      cpu = 25, label = "Hiding",      needs = { 5, "Hider" },
                  dur = function(soft, cpu, isLocal) return MH.Data.Dur.hide(soft.soft_size, cpu, isLocal) end },
    seek      = { proc = "SOFT_SEEK",      cpu = 25, label = "Seeking",     needs = { 6, "Seeker" },
                  dur = function(soft, cpu, isLocal) return MH.Data.Dur.seek(soft.soft_size, cpu, soft.soft_version, isLocal) end },
    uninstall = { proc = "SOFT_UNINSTALL", cpu = 15, label = "Uninstalling",
                  dur = function(soft, cpu, isLocal) return MH.Data.Dur.uninstall(soft.soft_size, cpu, isLocal) end },
    install   = { proc = "SOFT_INSTALL",   cpu = 15, label = "Installing",
                  dur = function(soft, cpu, isLocal) return MH.Data.Dur.install(soft.soft_size, cpu, isLocal) end },
}

local function require_tool(ply, actorServerId, cfg, action, scope)
    if not cfg.needs then return true end
    local toolType, toolName = cfg.needs[1], cfg.needs[2]
    local owned = MH.DB.QueryValue("SELECT MAX(soft_version) FROM mh_software WHERE server_id = " ..
        tonumber(actorServerId) .. " AND soft_type = " .. toolType .. " AND installed = 1")
    if not owned or tonumber(owned) <= 0 then
        local scopeTxt = scope == "remote" and " on your rig to " .. action .. " remotely" or " to " .. action
        send_notify(ply, "error", "You need a running " .. toolName .. scopeTxt)
        return false
    end
    return true
end

local VIRUS_TYPES = { [8] = true, [9] = true, [10] = true, [11] = true, [12] = true, [20] = true }
local SYSTEM_TYPES = { [19] = true, [29] = true, [96] = true }

Handlers.soft_action = function(ply, args)
    local softId = tonumber(args.soft_id or 0)
    local action = tostring(args.action or "")
    local cfg = SOFT_ACTIONS[action]
    if not cfg then send_notify(ply, "error", "Unknown action") return end
    local soft = MH.DB.QueryRow("SELECT * FROM mh_software WHERE id = " .. softId)
    if not soft then send_notify(ply, "error", "No such file") return end
    local srv = owned_server(ply, tonumber(soft.server_id))
    if not srv then send_notify(ply, "error", "Not your server") return end
    local st = tonumber(soft.soft_type)
    if action == "delete" and SYSTEM_TYPES[st] then send_notify(ply, "error", "System file, cannot delete") return end
    if action == "uninstall" and VIRUS_TYPES[st] then send_notify(ply, "error", "Virus, cannot uninstall") return end
    if not require_tool(ply, srv.id, cfg, action, "local") then return end
    local cpu = MH.Data.ServerCPU(srv)
    local dur = cfg.dur(soft, cpu, true)
    MH.Proc.Spawn({
        creator_sid = ply:SteamID64(),
        local_server = srv.id, victim_server = 0,
        action = cfg.proc, soft_id = softId, info = "",
        duration = dur, cpu_usage = cfg.cpu,
    })
    send_notify(ply, "ok", cfg.label .. " " .. (soft.soft_name or "file"))
    send_snapshot(ply, srv.id)
end

Handlers.soft_rename = function(ply, args)
    local softId = tonumber(args.soft_id or 0)
    local newName = tostring(args.name or ""):sub(1, 32)
    if newName == "" then send_notify(ply, "error", "Name required") return end
    local soft = MH.DB.QueryRow("SELECT * FROM mh_software WHERE id = " .. softId)
    if not soft then return end
    local srv = owned_server(ply, tonumber(soft.server_id))
    if not srv then send_notify(ply, "error", "Not your server") return end
    MH.DB.Query("UPDATE mh_software SET soft_name = " .. MH.DB.Esc(newName) ..
        " WHERE id = " .. softId)
    send_notify(ply, "ok", "Renamed")
    send_snapshot(ply, srv.id)
end

local MAIL_RATE_WINDOW = 60
local MAIL_RATE_LIMIT = 5
local MAIL_FLOOD_WINDOW = 600
local MAIL_FLOOD_LIMIT = 30
local MAIL_BODY_MAX = 2048
local MAIL_SUBJECT_MAX = 120
local mail_rate_log = {}
local mail_flood_log = {}

local MAIL_CAPTCHA_ICONS = {
    house       = { "a home", "a dwelling", "a residence" },
    car         = { "a vehicle", "an automobile", "a motor car" },
    cup         = { "a drinking vessel", "a mug", "something you sip from" },
    lightning   = { "a thunderbolt", "a spark", "a stroke of lightning" },
    cake        = { "a birthday pastry", "something you blow candles on", "a frosted dessert" },
    star        = { "a shining celestial body", "something you wish upon", "a five-point shape" },
    heart       = { "a symbol of love", "the organ that beats", "a valentine shape" },
    weather_sun = { "the daytime star", "something that gives us daylight", "the brightest thing in the sky" },
    bell        = { "a bell", "a hanging ringer with a clapper inside", "a cartoon jingle bell" },
    clock       = { "something that tells the time", "a timepiece", "something with hour and minute hands" },
    key         = { "something that unlocks a door", "something that opens a lock", "the thing you turn in an ignition" },
    book        = { "something you read", "a bound set of pages", "a novel" },
}
local MAIL_CAPTCHA_ICON_LIST = {}
for name, _ in pairs(MAIL_CAPTCHA_ICONS) do MAIL_CAPTCHA_ICON_LIST[#MAIL_CAPTCHA_ICON_LIST + 1] = name end
MH.MailCaptchas = MH.MailCaptchas or {}
local MAIL_CAPTCHA_TTL = 180

local function gen_captcha_token()
    return util.CRC(tostring(os.time()) .. "_" .. tostring(math.random(1, 1e9)) .. "_" .. tostring(math.random(1, 1e9))) ..
        util.CRC(tostring(SysTime()) .. "_" .. tostring(math.random(1, 1e9)))
end

local function issue_mail_captcha(ply)
    local sid = ply:SteamID64()
    local pool = {}
    for i, name in ipairs(MAIL_CAPTCHA_ICON_LIST) do pool[i] = name end
    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local choices = { pool[1], pool[2], pool[3], pool[4] }
    local targetIdx = math.random(1, 4)
    local targetName = choices[targetIdx]
    local prompts = MAIL_CAPTCHA_ICONS[targetName] or { targetName }
    local prompt = prompts[math.random(1, #prompts)]
    local token = gen_captcha_token()
    MH.MailCaptchas[sid] = {
        token = token,
        choices = choices,
        target_idx = targetIdx,
        stamp = os.time(),
    }
    net.Start(N.MailCaptcha)
    net.WriteString(token)
    net.WriteString(prompt)
    net.WriteUInt(4, 8)
    for _, name in ipairs(choices) do net.WriteString(name) end
    net.Send(ply)
end

Handlers.mail_captcha_request = function(ply, args)
    issue_mail_captcha(ply)
end

Handlers.mail_send = function(ply, args)
    local sid = ply:SteamID64()
    local mailBanned, mailBanReason = MH.State.IsMailBanned(sid)
    if mailBanned then
        send_notify(ply, "error", "You are banned from sending mail: " .. (mailBanReason or ""))
        return
    end
    local challenge = MH.MailCaptchas[sid]
    local token = tostring(args.captcha_token or "")
    local choiceIdx = tonumber(args.captcha_choice or 0) or 0
    if not challenge or challenge.token ~= token or (os.time() - challenge.stamp) > MAIL_CAPTCHA_TTL then
        send_notify(ply, "error", "Captcha expired. Please try again.")
        issue_mail_captcha(ply)
        return
    end
    if choiceIdx ~= challenge.target_idx then
        send_notify(ply, "error", "Wrong captcha. Try again.")
        MH.MailCaptchas[sid] = nil
        issue_mail_captcha(ply)
        return
    end
    MH.MailCaptchas[sid] = nil
    local nowT = os.time()
    local log = mail_rate_log[sid] or {}
    local fresh = {}
    for _, t in ipairs(log) do if (nowT - t) < MAIL_RATE_WINDOW then fresh[#fresh + 1] = t end end
    if #fresh >= MAIL_RATE_LIMIT then
        send_notify(ply, "error", "Mail rate limit (" .. MAIL_RATE_LIMIT .. " per " .. MAIL_RATE_WINDOW .. "s)")
        mail_rate_log[sid] = fresh
        MH.DB.Query("UPDATE mh_players SET abuse_mail_hits = COALESCE(abuse_mail_hits, 0) + 1 WHERE sid64 = " ..
            MH.DB.Esc(sid))
        if MH.Api and MH.Api.LogAbuse then MH.Api.LogAbuse(sid, "mail_rate", "mail flood") end
        return
    end
    local to = resolve_recipient(args.to)
    if not to then send_notify(ply, "error", "Recipient not found") return end
    if to == sid then send_notify(ply, "error", "You cannot mail yourself") return end
    local subject = tostring(args.subject or ""):sub(1, MAIL_SUBJECT_MAX)
    local body = tostring(args.body or "")
    if subject == "" or body == "" then send_notify(ply, "error", "Subject and body required") return end
    if subject:find("[^azAZ09.,!?%s_%-$()\"'A-Za-z]") then
        send_notify(ply, "error", "Subject contains disallowed characters")
        return
    end
    if #body > MAIL_BODY_MAX then
        send_notify(ply, "error", "Body too long (max " .. MAIL_BODY_MAX .. " chars)")
        return
    end
    local lineCount = 1
    for _ in string.gmatch(body, "\n") do lineCount = lineCount + 1 end
    if lineCount > 60 then
        send_notify(ply, "error", "Body has too many lines")
        return
    end
    fresh[#fresh + 1] = nowT
    mail_rate_log[sid] = fresh
    local floodLog = mail_flood_log[sid] or {}
    local floodFresh = {}
    for _, t in ipairs(floodLog) do if (nowT - t) < MAIL_FLOOD_WINDOW then floodFresh[#floodFresh + 1] = t end end
    floodFresh[#floodFresh + 1] = nowT
    mail_flood_log[sid] = floodFresh
    if #floodFresh > MAIL_FLOOD_LIMIT and not ply:IsSuperAdmin() then
        MH.State.MailBanSid(sid, "Autoban: " .. #floodFresh .. " mails in " .. MAIL_FLOOD_WINDOW .. "s", "console")
        send_notify(ply, "error", "You have been banned from sending mail for flooding.")
        if MH.Api and MH.Api.LogAbuse then
            MH.Api.LogAbuse(sid, "mail_flood_autoban", #floodFresh .. " mails in " .. MAIL_FLOOD_WINDOW .. "s")
        end
        MH.Log.warn("abuse", "mail_autoban", sid .. " mail-banned for flood (" .. #floodFresh .. ")")
        return
    end
    MH.DB.Query("INSERT INTO mh_mail (to_sid, from_sid, subject, body, stamp, seen, is_deleted) VALUES (" ..
        MH.DB.Esc(to) .. ", " .. MH.DB.Esc(sid) .. ", " .. MH.DB.Esc(subject) .. ", " ..
        MH.DB.Esc(body) .. ", " .. nowT .. ", 0, 0)")
    MH.DB.Query("UPDATE mh_players SET total_mails_sent = COALESCE(total_mails_sent, 0) + 1 WHERE sid64 = " ..
        MH.DB.Esc(sid))
    MH.State.CheckSocialFirstMail(sid)
    send_notify(ply, "ok", "Message sent")
    send_snapshot(ply, 0)
    local rcpt = player.GetBySteamID64(to)
    if IsValid(rcpt) then
        send_notify(rcpt, "info", "New mail from " .. ply:Nick())
        send_snapshot(rcpt, 0)
    end
end

Handlers.mail_delete = function(ply, args)
    local sid = ply:SteamID64()
    local mid = tonumber(args.mail_id or 0)
    MH.DB.Query("UPDATE mh_mail SET is_deleted = 1 WHERE id = " .. mid ..
        " AND to_sid = " .. MH.DB.Esc(sid))
    send_snapshot(ply, 0)
end

local function net_upsert(sid, targetId, authed, authUser)
    MH.DB.Query("INSERT OR REPLACE INTO mh_internet (owner_sid, target_server, authed, auth_user, stamp) VALUES (" ..
        MH.DB.Esc(sid) .. ", " .. tonumber(targetId or 0) .. ", " .. (authed and 1 or 0) ..
        ", " .. MH.DB.Esc(authUser or "root") .. ", " .. os.time() .. ")")
end

local function net_current(sid)
    local row = MH.DB.QueryRow("SELECT * FROM mh_internet WHERE owner_sid = " .. MH.DB.Esc(sid))
    if not row then return nil end
    return tonumber(row.target_server), tonumber(row.authed or 0) == 1
end

Handlers.internet_goto = function(ply, args)
    local sid = ply:SteamID64()
    local ip = tostring(args.ip or ""):Trim()
    if ip == "" then send_notify(ply, "error", "No IP") return end
    if not check_ip_lookup_rate(ply) then return end
    local target = MH.DB.QueryRow("SELECT id, name FROM mh_servers WHERE ip = " .. MH.DB.Esc(ip))
    if not target then send_notify(ply, "warn", "No reply from " .. ip) return end
    net_upsert(sid, tonumber(target.id), false)
    MH.State.MarkDiscovered(sid, tonumber(target.id))
    send_notify(ply, "ok", "Pointed browser at " .. ip)
    send_snapshot(ply, 0)
end

Handlers.btc_internet_login = function(ply, args)
    local sid = ply:SteamID64()
    local ip = tostring(args.ip or "")
    local addr = tostring(args.addr or "")
    local key = tostring(args.key or "")
    if addr == "" or key == "" then send_notify(ply, "error", "Missing credentials") return end
    local target = MH.DB.QueryRow("SELECT id, name FROM mh_servers WHERE ip = " .. MH.DB.Esc(ip))
    if not target or tostring(target.name) ~= "Bitcoin Market" then
        send_notify(ply, "error", "Not a Bitcoin Market")
        return
    end
    local wallet = MH.DB.QueryRow("SELECT address, priv_key FROM mh_btc_wallets WHERE address = " .. MH.DB.Esc(addr))
    if not wallet or tostring(wallet.priv_key) ~= key then
        send_notify(ply, "error", "Login failed")
        return
    end
    local primary = MH.State.GetServersFor(sid)[1]
    if primary then
        MH.State.AppendLog(primary.id,
            "localhost logged in to [" .. ip .. "] on account " .. addr ..
            " using key " .. key)
    end
    MH.BtcSessions[sid] = true
    send_notify(ply, "ok", "Logged in to wallet")
    send_snapshot(ply, 0)
end

Handlers.btc_internet_logout = function(ply, args)
    local sid = ply:SteamID64()
    MH.BtcSessions[sid] = nil
    send_notify(ply, "ok", "Logged out of wallet")
    send_snapshot(ply, 0)
end

Handlers.internet_login = function(ply, args)
    local sid = ply:SteamID64()
    local targetId, _ = net_current(sid)
    if not targetId then send_notify(ply, "error", "No target") return end
    local target = MH.State.GetServerById(targetId)
    if not target then send_notify(ply, "error", "Target gone") return end
    local user = tostring(args.user or "root"):lower()
    local pass = tostring(args.pass or "")
    local myServerForLog = MH.State.GetServersFor(sid)[1]
    if user == "download" then
        if target.name == "Download Center" and pass == "download" then
            net_upsert(sid, targetId, true, "download")
            if myServerForLog then
                MH.State.AppendLog(myServerForLog.id,
                    "localhost logged in to [" .. tostring(target.ip) .. "] as download")
            end
            send_notify(ply, "ok", "Logged in as download")
            send_snapshot(ply, 0)
            return
        end
        send_notify(ply, "error", "Login failed")
        return
    end
    if user ~= "root" then send_notify(ply, "error", "Unknown user") return end
    if pass ~= tostring(target.root_pass) then
        send_notify(ply, "error", "Login failed")
        return
    end
    net_upsert(sid, targetId, true, "root")
    MH.State.AppendLog(targetId, "User logged in from " .. MH.State.AttackerIP(sid))
    if myServerForLog then
        MH.State.AppendLog(myServerForLog.id,
            "localhost logged in to [" .. tostring(target.ip) .. "] as root")
    end
    send_notify(ply, "ok", "Logged in to " .. target.ip)
    local myServer = MH.State.GetServersFor(sid)[1]
    local attV = tonumber(MH.DB.QueryValue(
        "SELECT MAX(soft_version) FROM mh_software WHERE server_id = " .. tonumber(myServer and myServer.id or 0) ..
        " AND soft_type = 1")) or 0
    local defV = tonumber(MH.DB.QueryValue(
        "SELECT MAX(soft_version) FROM mh_software WHERE server_id = " .. targetId ..
        " AND soft_type = 2")) or 0
    local rep = math.max(5, 15 - (attV - defV))
    MH.DB.Query("UPDATE mh_players SET exp = exp + " .. rep .. " WHERE sid64 = " .. MH.DB.Esc(sid))
    MH.State.CheckFBIThresholds(sid)
    send_snapshot(ply, 0)
end

Handlers.internet_logout = function(ply, args)
    local sid = ply:SteamID64()
    local targetId = tonumber(MH.DB.QueryValue(
        "SELECT target_server FROM mh_internet WHERE owner_sid = " .. MH.DB.Esc(sid))) or 0
    if targetId > 0 then
        MH.DB.Query("UPDATE mh_internet SET authed = 0, stamp = " .. os.time() ..
            " WHERE owner_sid = " .. MH.DB.Esc(sid))
    else
        MH.DB.Query("DELETE FROM mh_internet WHERE owner_sid = " .. MH.DB.Esc(sid))
    end
    send_snapshot(ply, 0)
end

Handlers.internet_log_edit_submit = function(ply, args)
    local sid = ply:SteamID64()
    local targetId, authed = net_current(sid)
    if not targetId or not authed then send_notify(ply, "error", "Not logged in to a target") return end
    local busy = MH.DB.QueryValue("SELECT 1 FROM mh_processes WHERE action IN ('E_LOG','D_LOG') " ..
        "AND local_server = " .. targetId .. " LIMIT 1")
    if busy then send_notify(ply, "error", "A log process is already running on target") return end
    local content = tostring(args.content or "")
    local current = MH.State.ReadLog(targetId)
    if content == current then send_notify(ply, "warn", "Identical log, no change") return end
    MH.DB.Query("INSERT INTO mh_tmp_log (server_id, content, author_sid, stamp) VALUES (" ..
        targetId .. ", " .. MH.DB.Esc(content) .. ", " .. MH.DB.Esc(sid) .. ", " .. os.time() .. ")")
    local tmpId = tonumber(MH.DB.QueryValue("SELECT last_insert_rowid()"))
    local myServer = MH.State.GetServersFor(sid)[1]
    local dur = MH.Data.Dur.edit_log(#current, #content, MH.Data.ServerCPU(myServer), false)
    MH.Proc.Spawn({
        creator_sid = sid,
        local_server = targetId, victim_server = targetId,
        action = "E_LOG", soft_id = tmpId, info = "",
        duration = dur, cpu_usage = 30,
    })
    send_notify(ply, "ok", "Editing remote log")
    send_snapshot(ply, 0)
end

Handlers.internet_log_delete_all = function(ply, args)
    local sid = ply:SteamID64()
    local targetId, authed = net_current(sid)
    if not targetId or not authed then send_notify(ply, "error", "Not logged in to a target") return end
    local busy = MH.DB.QueryValue("SELECT 1 FROM mh_processes WHERE action IN ('E_LOG','D_LOG') " ..
        "AND local_server = " .. targetId .. " LIMIT 1")
    if busy then send_notify(ply, "error", "A log process is already running on target") return end
    local myServer = MH.State.GetServersFor(sid)[1]
    local curLen = #MH.State.ReadLog(targetId)
    local dur = MH.Data.Dur.edit_log(curLen, 0, MH.Data.ServerCPU(myServer), false)
    MH.Proc.Spawn({
        creator_sid = sid,
        local_server = targetId, victim_server = targetId,
        action = "D_LOG", soft_id = 0, info = "",
        duration = dur, cpu_usage = 20,
    })
    send_notify(ply, "ok", "Wiping remote log")
    send_snapshot(ply, 0)
end

Handlers.hacked_remove = function(ply, args)
    local sid = ply:SteamID64()
    local hid = tonumber(args.hacked_id or 0)
    MH.DB.Query("DELETE FROM mh_hacked WHERE id = " .. hid ..
        " AND owner_sid = " .. MH.DB.Esc(sid))
    send_snapshot(ply, 0)
end

Handlers.hacked_bank_forget = function(ply, args)
    local sid = ply:SteamID64()
    local hid = tonumber(args.hacked_bank_id or 0)
    MH.DB.Query("DELETE FROM mh_hacked_banks WHERE id = " .. hid ..
        " AND owner_sid = " .. MH.DB.Esc(sid))
    send_snapshot(ply, 0)
end

Handlers.hacked_bank_withdraw = function(ply, args)
    local sid = ply:SteamID64()
    local hid = tonumber(args.hacked_bank_id or 0)
    local row = MH.DB.QueryRow("SELECT * FROM mh_hacked_banks WHERE id = " .. hid ..
        " AND owner_sid = " .. MH.DB.Esc(sid))
    if not row then send_notify(ply, "error", "No such captured account") return end
    local src = MH.DB.QueryRow("SELECT * FROM mh_banks WHERE acc_num = " .. MH.DB.Esc(row.acc_num))
    if not src then send_notify(ply, "error", "Account no longer exists") return end
    if src.acc_pass ~= row.acc_pass then
        send_notify(ply, "warn", "The password has changed, forgetting captured credential")
        MH.DB.Query("DELETE FROM mh_hacked_banks WHERE id = " .. hid)
        send_snapshot(ply, 0)
        return
    end
    local take = tonumber(src.cash or 0) or 0
    if take <= 0 then send_notify(ply, "warn", "Account is empty") return end
    MH.DB.Query("UPDATE mh_banks SET cash = 0 WHERE id = " .. tonumber(src.id))
    MH.State.AddCash(sid, take, "siphon from hacked account " .. tostring(row.acc_num))
    MH.DB.Query("UPDATE mh_players SET money_earned = money_earned + " .. take ..
        " WHERE sid64 = " .. MH.DB.Esc(sid))
    MH.State.CheckSourcenetAlert(sid, take)
    MH.State.CheckMissionProgress(sid, "bank_transfer", { target_server = tonumber(src.bank_npc) })
    MH.State.AwardBadge(sid, "first_bank_steal")
    local attackerIp = MH.State.AttackerIP(sid)
    MH.State.AppendLog(tonumber(src.bank_npc),
        "[" .. attackerIp .. "] transfered $" .. take ..
        " from #" .. tostring(row.acc_num) .. " to [" .. attackerIp .. "]")
    local primary = MH.State.GetServersFor(sid)[1]
    if primary then
        MH.State.AppendLog(primary.id,
            "localhost transfered $" .. take ..
            " from #" .. tostring(row.acc_num) ..
            " on bank [" .. tostring(row.bank_ip or "?") .. "] to localhost")
    end
    send_notify(ply, "ok", "Siphoned $" .. take .. " from " .. row.acc_num)
    send_snapshot(ply, 0)
end

Handlers.mail_mark_read = function(ply, args)
    local sid = ply:SteamID64()
    local mid = tonumber(args.mail_id or 0)
    MH.DB.Query("UPDATE mh_mail SET seen = 1 WHERE id = " .. mid ..
        " AND to_sid = " .. MH.DB.Esc(sid))
end

Handlers.server_rename = function(ply, args)
    local srv = owned_server(ply, tonumber(args.server_id or 0))
    if not srv then send_notify(ply, "error", "Not your server") return end
    local nm = tostring(args.name or ""):sub(1, 32)
    if nm == "" then send_notify(ply, "error", "Name required") return end
    MH.DB.Query("UPDATE mh_servers SET name = " .. MH.DB.Esc(nm) .. " WHERE id = " .. tonumber(srv.id))
    send_notify(ply, "ok", "Renamed to " .. nm)
    send_snapshot(ply, srv.id)
end

local XHD_PRICES = { 100, 1000, 10000, 50000, 150000, 300000, 500000 }
Handlers.xhd_buy = function(ply, args)
    local srv = owned_server(ply, tonumber(args.server_id or 0))
    if not srv then send_notify(ply, "error", "Not your server") return end
    local owned = tonumber(MH.DB.QueryValue("SELECT COUNT(*) FROM mh_xhds WHERE server_id = " .. tonumber(srv.id))) or 0
    local price = XHD_PRICES[math.min(owned + 1, #XHD_PRICES)]
    local p = MH.State.GetPlayer(ply:SteamID64())
    local cash = tonumber(p and p.cash or 0) or 0
    if cash < price then send_notify(ply, "error", "Not enough cash ($" .. price .. ")") return end
    MH.State.SpendCash(ply:SteamID64(), price, "External HD", srv.id)
    MH.DB.Query("INSERT INTO mh_xhds (server_id, name, cap_tier) VALUES (" ..
        tonumber(srv.id) .. ", 'External HD', 1)")
    MH.DB.Query("UPDATE mh_players SET exp = exp + 100 WHERE sid64 = " .. MH.DB.Esc(ply:SteamID64()))
    MH.State.AppendLog(tonumber(srv.id), "Mounted new external HD")
    send_notify(ply, "ok", "Mounted a new external drive")
    send_snapshot(ply, srv.id)
end

Handlers.xhd_rename = function(ply, args)
    local xid = tonumber(args.xhd_id or 0)
    local row = MH.DB.QueryRow("SELECT * FROM mh_xhds WHERE id = " .. xid)
    if not row then return end
    local srv = owned_server(ply, tonumber(row.server_id))
    if not srv then send_notify(ply, "error", "Not your server") return end
    local nm = tostring(args.name or ""):sub(1, 32)
    if nm == "" then return end
    MH.DB.Query("UPDATE mh_xhds SET name = " .. MH.DB.Esc(nm) .. " WHERE id = " .. xid)
    send_snapshot(ply, srv.id)
end

Handlers.cert_buy = function(ply, args)
    local sid = ply:SteamID64()
    local level = tonumber(args.level or 0)
    local cert = nil
    for _, c in ipairs(MH.Data.Certs) do
        if c.level == level then cert = c break end
    end
    if not cert then send_notify(ply, "error", "Unknown cert") return end
    local p = MH.State.GetPlayer(sid)
    local owned = tonumber(p and p.cert_level or 0) or 0
    if owned >= level then send_notify(ply, "warn", "Already owned") return end
    if owned ~= level - 1 then send_notify(ply, "error", "You must complete the previous cert first") return end
    local cash = tonumber(p.cash or 0) or 0
    if cash < cert.price then send_notify(ply, "error", "Not enough cash ($" .. cert.price .. ")") return end
    MH.State.SpendCash(sid, cert.price, "Certification: " .. tostring(cert.name or ("Level " .. level)), 0)
    MH.DB.Query("UPDATE mh_players SET cert_level = " .. level ..
        ", exp = exp + " .. (MH.Data.Rep.CERT or 100) ..
        " WHERE sid64 = " .. MH.DB.Esc(sid))
    MH.State.CheckFBIThresholds(sid)
    MH.State.CheckEmployersFirstJob(sid)
    MH.State.CheckEmployersRecruit(sid)
    MH.State.SendCertServiceIntro(sid, level)
    if level == 1 then MH.State.SendTutorialDoomMail(sid) end
    if level == 5 then
        local nick = MH.DB.QueryValue("SELECT nick FROM mh_players WHERE sid64 = " .. MH.DB.Esc(sid)) or "someone"
        MH.State.AddNews(nick .. " earned the final DDoS Security certification")
    end
    send_notify(ply, "ok", "Completed: " .. cert.name)
    send_snapshot(ply, 0)
end

Handlers.av_scan = function(ply, args)
    local sid = ply:SteamID64()
    local scope = tostring(args.scope or "local")
    local myServer = MH.State.GetServersFor(sid)[1]
    if not myServer then send_notify(ply, "error", "No server") return end
    local avVer = tonumber(MH.DB.QueryValue(
        "SELECT MAX(soft_version) FROM mh_software WHERE server_id = " .. tonumber(myServer.id) ..
        " AND soft_type = 7 AND installed = 1")) or 0
    if avVer <= 0 then send_notify(ply, "error", "No Antivirus installed") return end
    local scanServer
    if scope == "remote" then
        local targetId, authUser = remote_target(ply)
        if not targetId then send_notify(ply, "error", "Not logged in to a target") return end
        if authUser ~= "root" then send_notify(ply, "error", "Not permitted as this user") return end
        scanServer = targetId
    else
        local serverId = tonumber(args.server_id or myServer.id)
        local srv = owned_server(ply, serverId)
        if not srv then send_notify(ply, "error", "Not your server") return end
        scanServer = tonumber(srv.id)
    end
    MH.Proc.Spawn({
        creator_sid = sid,
        local_server = myServer.id, victim_server = scanServer,
        action = "AV_SCAN", soft_id = avVer, info = tostring(scope),
        duration = MH.Data.Dur.av(), cpu_usage = 60,
    })
    send_notify(ply, "ok", "Antivirus scan launched")
    send_snapshot(ply, 0)
end

Handlers.ddos_launch = function(ply, args)
    local sid = ply:SteamID64()
    local p = MH.State.GetPlayer(sid)
    if (tonumber(p and p.cert_level or 0) or 0) < 4 then
        send_notify(ply, "error", "Requires DDoS Security (cert 4)")
        return
    end
    local ip = tostring(args.ip or "")
    if ip == "" then send_notify(ply, "error", "No target") return end
    local target = MH.DB.QueryRow("SELECT id, name FROM mh_servers WHERE ip = " .. MH.DB.Esc(ip))
    if not target then send_notify(ply, "warn", "No reply from " .. ip) return end
    local power = tonumber(MH.DB.QueryValue(
        "SELECT COALESCE(SUM(soft_version), 0) FROM mh_software " ..
        "WHERE owner_sid = " .. MH.DB.Esc(sid) ..
        " AND soft_type = 10 AND installed = 1")) or 0
    if power <= 0 then send_notify(ply, "error", "No active DDoS viruses") return end
    local srv = MH.State.GetServersFor(sid)[1]
    if not srv then send_notify(ply, "error", "No server") return end
    MH.Proc.Spawn({
        creator_sid = sid, local_server = srv.id, victim_server = tonumber(target.id),
        action = "DDOS", soft_id = power, info = ip, duration = 40, cpu_usage = 0, net_usage = 80,
    })
    send_notify(ply, "warn", "DDoS launched against " .. ip .. " (power " .. power .. ")")
    send_snapshot(ply, 0)
end

local function remote_target(ply)
    local row = MH.DB.QueryRow("SELECT * FROM mh_internet WHERE owner_sid = " .. MH.DB.Esc(ply:SteamID64()))
    if not row or tonumber(row.authed or 0) ~= 1 then return nil end
    return tonumber(row.target_server), tostring(row.auth_user or "root")
end

Handlers.remote_soft_action = function(ply, args)
    local targetId, authUser = remote_target(ply)
    if not targetId then send_notify(ply, "error", "Not logged in to a target") return end
    if authUser ~= "root" then send_notify(ply, "error", "Not permitted as this user") return end
    local softId = tonumber(args.soft_id or 0)
    local action = tostring(args.action or "")
    local soft = MH.DB.QueryRow("SELECT * FROM mh_software WHERE id = " .. softId ..
        " AND server_id = " .. targetId)
    if not soft then send_notify(ply, "error", "File not on target") return end
    local cfg = SOFT_ACTIONS[action]
    if not cfg then send_notify(ply, "error", "Unknown action") return end
    local st = tonumber(soft.soft_type)
    if action == "delete" and SYSTEM_TYPES[st] then send_notify(ply, "error", "System file, cannot delete") return end
    if st == 26 then send_notify(ply, "error", "Riddle files cannot be modified") return end
    local myServer = MH.State.GetServersFor(ply:SteamID64())[1]
    if not myServer then send_notify(ply, "error", "No local server") return end
    if tonumber(soft.hidden or 0) == 1 and action ~= "seek" then
        local hv = tonumber(soft.hidden_version or 0) or 0
        local mySeek = tonumber(MH.DB.QueryValue(
            "SELECT MAX(soft_version) FROM mh_software WHERE server_id = " .. tonumber(myServer.id) ..
            " AND soft_type = 6 AND installed = 1")) or 0
        if hv > mySeek then
            send_notify(ply, "error", "File is hidden; a stronger Seeker is required to see it")
            return
        end
    end
    if not require_tool(ply, myServer.id, cfg, action, "remote") then return end
    local cpu = MH.Data.ServerCPU(myServer)
    local dur = cfg.dur(soft, cpu, false)
    MH.Proc.Spawn({
        creator_sid = ply:SteamID64(),
        local_server = myServer.id,
        victim_server = targetId,
        action = cfg.proc, soft_id = softId, info = "",
        duration = dur, cpu_usage = cfg.cpu,
    })
    send_notify(ply, "ok", cfg.label .. " on remote: " .. (soft.soft_name or "file"))
    send_snapshot(ply, 0)
end

local function net_mbps_for(serverId)
    local srv = MH.State.GetServerById(tonumber(serverId or 0))
    if not srv then return 1 end
    local tier = MH.Data.Hardware.net[tonumber(srv.net_tier) or 1] or MH.Data.Hardware.net[1]
    return tier.mbps or 1
end

local function xfer_duration_dl(sizeMb, attackerServerId, targetId)
    return MH.Data.Dur.download(sizeMb, net_mbps_for(attackerServerId), net_mbps_for(targetId))
end

local function xfer_duration_up(sizeMb, attackerServerId, targetId)
    return MH.Data.Dur.upload(sizeMb, net_mbps_for(attackerServerId), net_mbps_for(targetId))
end

Handlers.remote_soft_download = function(ply, args)
    local sid = ply:SteamID64()
    local targetId = remote_target(ply)
    if not targetId then send_notify(ply, "error", "Not logged in to a target") return end
    local softId = tonumber(args.soft_id or 0)
    local soft = MH.DB.QueryRow("SELECT * FROM mh_software WHERE id = " .. softId ..
        " AND server_id = " .. targetId)
    if not soft then send_notify(ply, "error", "File not on target") return end
    if tonumber(soft.soft_type) == 26 then send_notify(ply, "error", "Riddle files cannot be downloaded") return end
    local myServer = MH.State.GetServersFor(sid)[1]
    if not myServer then send_notify(ply, "error", "No local server") return end
    local dur = xfer_duration_dl(soft.soft_size, myServer.id, targetId)
    MH.Proc.Spawn({
        creator_sid = sid, local_server = myServer.id, victim_server = targetId,
        action = "SOFT_DOWNLOAD", soft_id = softId, info = tostring(soft.soft_name or ""),
        duration = dur, cpu_usage = 10, net_usage = 90,
    })
    send_notify(ply, "ok", "Downloading " .. (soft.soft_name or "file") .. " (" .. dur .. "s)")
    send_snapshot(ply, 0)
end

Handlers.remote_soft_upload = function(ply, args)
    local sid = ply:SteamID64()
    local targetId, authUser = remote_target(ply)
    if not targetId then send_notify(ply, "error", "Not logged in to a target") return end
    if authUser ~= "root" then send_notify(ply, "error", "Not permitted as this user") return end
    local softId = tonumber(args.soft_id or 0)
    local soft = MH.DB.QueryRow("SELECT * FROM mh_software WHERE id = " .. softId)
    if not soft then send_notify(ply, "error", "File not found") return end
    local myServer = MH.State.GetServersFor(sid)[1]
    if not myServer or tonumber(soft.server_id) ~= tonumber(myServer.id) then
        send_notify(ply, "error", "You do not own that file")
        return
    end
    local dur = xfer_duration_up(soft.soft_size, myServer.id, targetId)
    MH.Proc.Spawn({
        creator_sid = sid, local_server = myServer.id, victim_server = targetId,
        action = "SOFT_UPLOAD", soft_id = softId, info = tostring(soft.soft_name or ""),
        duration = dur, cpu_usage = 10, net_usage = 90,
    })
    send_notify(ply, "ok", "Uploading " .. (soft.soft_name or "file") .. " (" .. dur .. "s)")
    send_snapshot(ply, 0)
end

Handlers.soft_text_create = function(ply, args)
    local sid = ply:SteamID64()
    local srv = owned_server(ply, tonumber(args.server_id or 0))
    if not srv then send_notify(ply, "error", "Not your server") return end
    local name = tostring(args.name or "note"):sub(1, 32)
    local content = tostring(args.content or "")
    MH.DB.Query("INSERT INTO mh_software (server_id, owner_sid, soft_type, soft_version, soft_name, soft_size, soft_ram, installed, hidden, content, last_collect) VALUES (" ..
        tonumber(srv.id) .. ", " .. MH.DB.Esc(sid) .. ", 30, 1, " .. MH.DB.Esc(name) ..
        ", " .. math.max(1, math.ceil(#content / 1024)) .. ", 0, 0, 0, " ..
        MH.DB.Esc(content) .. ", 0)")
    MH.State.AppendLog(tonumber(srv.id), "Created text file: " .. name)
    send_notify(ply, "ok", "Created text file: " .. name)
    send_snapshot(ply, srv.id)
end

Handlers.remote_soft_text_create = function(ply, args)
    local sid = ply:SteamID64()
    local targetId, authUser = remote_target(ply)
    if not targetId then send_notify(ply, "error", "Not logged in to a target") return end
    if authUser ~= "root" then send_notify(ply, "error", "Not permitted as this user") return end
    local name = tostring(args.name or "note"):sub(1, 32)
    local content = tostring(args.content or "")
    MH.DB.Query("INSERT INTO mh_software (server_id, owner_sid, soft_type, soft_version, soft_name, soft_size, soft_ram, installed, hidden, content, last_collect) VALUES (" ..
        tonumber(targetId) .. ", " .. MH.DB.Esc(sid) .. ", 30, 1, " .. MH.DB.Esc(name) ..
        ", " .. math.max(1, math.ceil(#content / 1024)) .. ", 0, 0, 0, " ..
        MH.DB.Esc(content) .. ", 0)")
    MH.State.AppendLog(tonumber(targetId), "Text file created: " .. name)
    send_notify(ply, "ok", "Created text file on target: " .. name)
    send_snapshot(ply, 0)
end

Handlers.remote_folder_create = function(ply)
    send_notify(ply, "error", "Folder creation is disabled")
end

Handlers.soft_text_edit = function(ply, args)
    local sid = ply:SteamID64()
    local softId = tonumber(args.soft_id or 0)
    local soft = MH.DB.QueryRow("SELECT * FROM mh_software WHERE id = " .. softId)
    if not soft then return end
    if tonumber(soft.soft_type) ~= 30 then send_notify(ply, "error", "Not a text file") return end
    local srv = owned_server(ply, tonumber(soft.server_id))
    local targetId = remote_target(ply)
    local isRemote = not srv and tonumber(soft.server_id) == targetId
    if not srv and not isRemote then
        send_notify(ply, "error", "No access")
        return
    end
    local content = tostring(args.content or "")
    MH.DB.Query("UPDATE mh_software SET content = " .. MH.DB.Esc(content) ..
        ", soft_size = " .. math.max(1, math.ceil(#content / 1024)) ..
        " WHERE id = " .. softId)
    if isRemote then
        local myServer = MH.State.AttackerServer(sid)
        local attIp = MH.State.AttackerIP(sid)
        local tgt = MH.State.GetServerById(targetId)
        if myServer then MH.State.AppendLog(tonumber(myServer.id), "Edited text file " .. (soft.soft_name or "?") .. " on " .. (tgt and tgt.ip or "?")) end
        MH.State.AppendLog(targetId, "Text file " .. (soft.soft_name or "?") .. " edited by " .. attIp)
    else
        MH.State.AppendLog(tonumber(soft.server_id), "Edited text file " .. (soft.soft_name or "?"))
    end
    send_notify(ply, "ok", "Saved")
    send_snapshot(ply, 0)
end

Handlers.bank_internet_hack_acc = function(ply, args)
    local sid = ply:SteamID64()
    if not check_ip_lookup_rate(ply) then return end
    local ip = tostring(args.ip or "")
    local accNum = tostring(args.acc or "")
    local bank = MH.DB.QueryRow("SELECT id, name FROM mh_servers WHERE ip = " .. MH.DB.Esc(ip) ..
        " AND is_npc = 1 AND LOWER(name) LIKE '%bank%'")
    if not bank then send_notify(ply, "error", "Not a bank") return end
    local netRow = MH.DB.QueryRow("SELECT authed, auth_user FROM mh_internet WHERE owner_sid = " .. MH.DB.Esc(sid) ..
        " AND target_server = " .. tonumber(bank.id))
    if not netRow or tonumber(netRow.authed or 0) ~= 1 or tostring(netRow.auth_user or "root") ~= "root" then
        send_notify(ply, "error", "You must be logged in as root on the bank first")
        return
    end
    local acc = MH.DB.QueryRow("SELECT * FROM mh_banks WHERE acc_num = " .. MH.DB.Esc(accNum) ..
        " AND bank_npc = " .. tonumber(bank.id))
    if not acc then send_notify(ply, "error", "Account not found at this bank") return end
    local srv = MH.State.GetServersFor(sid)[1]
    if not srv then send_notify(ply, "error", "No server") return end
    local attV = tonumber(MH.DB.QueryValue("SELECT MAX(soft_version) FROM mh_software WHERE server_id = " ..
        tonumber(srv.id) .. " AND soft_type = 1")) or 0
    if attV <= 0 then send_notify(ply, "error", "No Cracker installed") return end
    local defV = tonumber(MH.DB.QueryValue("SELECT MAX(soft_version) FROM mh_software WHERE server_id = " ..
        tonumber(bank.id) .. " AND soft_type = 2")) or 0
    if attV < defV then
        send_notify(ply, "error", "Your Cracker is not strong enough to break this bank's Hasher")
        return
    end
    local dur = MH.Data.Dur.crack(attV, defV)
    MH.Proc.Spawn({
        creator_sid = sid, local_server = srv.id, victim_server = tonumber(bank.id),
        action = "BANK_ACC_CRACK", info = ip .. " #" .. accNum, duration = dur, cpu_usage = 70,
    })
    send_notify(ply, "ok", "Cracking account " .. accNum .. " (" .. dur .. "s)")
    send_snapshot(ply, 0)
end

Handlers.bank_internet_login = function(ply, args)
    local sid = ply:SteamID64()
    local ip = tostring(args.ip or "")
    local accNum = tostring(args.acc or "")
    local pass = tostring(args.pass or "")
    local bank = MH.DB.QueryRow("SELECT id FROM mh_servers WHERE ip = " .. MH.DB.Esc(ip) ..
        " AND is_npc = 1 AND LOWER(name) LIKE '%bank%'")
    if not bank then send_notify(ply, "error", "Not a bank") return end
    local acc = MH.DB.QueryRow("SELECT * FROM mh_banks WHERE acc_num = " .. MH.DB.Esc(accNum) ..
        " AND bank_npc = " .. tonumber(bank.id))
    if not acc or acc.acc_pass ~= pass then
        send_notify(ply, "error", "Login failed")
        return
    end
    MH.DB.Query("INSERT OR REPLACE INTO mh_bank_session (owner_sid, bank_server_id, acc_num, stamp) VALUES (" ..
        MH.DB.Esc(sid) .. ", " .. tonumber(bank.id) .. ", " .. MH.DB.Esc(accNum) ..
        ", " .. os.time() .. ")")
    local primary = MH.State.GetServersFor(sid)[1]
    if primary then
        MH.State.AppendLog(primary.id,
            "localhost logged on account #" .. accNum .. " on bank [" .. ip .. "]")
    end
    send_notify(ply, "ok", "Logged in to account " .. accNum)
    send_snapshot(ply, 0)
end

Handlers.bank_internet_logout = function(ply, args)
    MH.DB.Query("DELETE FROM mh_bank_session WHERE owner_sid = " .. MH.DB.Esc(ply:SteamID64()))
    send_snapshot(ply, 0)
end

Handlers.bank_internet_register = function(ply, args)
    local sid = ply:SteamID64()
    local ip = tostring(args.ip or "")
    local bank = MH.DB.QueryRow("SELECT id, name FROM mh_servers WHERE ip = " .. MH.DB.Esc(ip) ..
        " AND is_npc = 1 AND LOWER(name) LIKE '%bank%'")
    if not bank then send_notify(ply, "error", "Not a bank") return end
    local existing = MH.DB.QueryValue("SELECT id FROM mh_banks WHERE bank_npc = " .. tonumber(bank.id) ..
        " AND owner_sid = " .. MH.DB.Esc(sid))
    if existing then send_notify(ply, "error", "You already have an account here") return end
    local accNum = tostring(math.random(111111111, 999999999))
    local pass = MH.State.GenPass(6)
    MH.DB.Query("INSERT INTO mh_banks (bank_npc, acc_num, acc_pass, owner_sid, cash, created) VALUES (" ..
        tonumber(bank.id) .. ", " .. MH.DB.Esc(accNum) .. ", " .. MH.DB.Esc(pass) ..
        ", " .. MH.DB.Esc(sid) .. ", 0, " .. os.time() .. ")")
    MH.State.CheckSourcenetAccountOpened(sid)
    MH.DB.Query("INSERT OR REPLACE INTO mh_bank_session (owner_sid, bank_server_id, acc_num, stamp) VALUES (" ..
        MH.DB.Esc(sid) .. ", " .. tonumber(bank.id) .. ", " .. MH.DB.Esc(accNum) ..
        ", " .. os.time() .. ")")
    send_notify(ply, "ok", "Opened account " .. accNum .. " at " .. tostring(bank.name) .. ". Logged in.")
    send_snapshot(ply, 0)
end

Handlers.bank_internet_transfer = function(ply, args)
    local sid = ply:SteamID64()
    local sess = MH.DB.QueryRow("SELECT * FROM mh_bank_session WHERE owner_sid = " .. MH.DB.Esc(sid))
    if not sess then send_notify(ply, "error", "Not logged in to a bank account") return end
    local src = MH.DB.QueryRow("SELECT * FROM mh_banks WHERE acc_num = " .. MH.DB.Esc(sess.acc_num))
    if not src then send_notify(ply, "error", "Session account missing") return end
    local toAcc = tostring(args.to or "")
    local amount = math.floor(tonumber(args.amount or 0) or 0)
    if amount <= 0 then send_notify(ply, "error", "Bad amount") return end
    if tonumber(src.cash) < amount then send_notify(ply, "error", "Insufficient funds") return end
    local dst = MH.DB.QueryRow("SELECT * FROM mh_banks WHERE acc_num = " .. MH.DB.Esc(toAcc))
    if not dst then send_notify(ply, "error", "Destination account not found") return end
    MH.DB.Query("UPDATE mh_banks SET cash = cash - " .. amount .. " WHERE id = " .. tonumber(src.id))
    MH.DB.Query("UPDATE mh_banks SET cash = cash + " .. amount .. " WHERE id = " .. tonumber(dst.id))
    MH.State.CheckSourcenetAlert(sid, amount)
    local transferRep = 200 + math.floor(amount / 15)
    MH.DB.Query("UPDATE mh_players SET exp = exp + " .. transferRep ..
        ", money_transferred = money_transferred + " .. amount ..
        " WHERE sid64 = " .. MH.DB.Esc(sid))
    MH.State.CheckMissionProgress(sid, "bank_transfer", { target_server = tonumber(src.bank_npc) })
    if amount >= 100000 then
        local nick = MH.DB.QueryValue("SELECT nick FROM mh_players WHERE sid64 = " .. MH.DB.Esc(sid)) or "someone"
        MH.State.AddNews(nick .. " moved $" .. amount .. " through a bank")
    end
    if amount >= 25000 then
        MH.State.SendSystemMailOnce(sid, "FBI", "Big-ticket transfer flagged",
            "A high-value transfer tied to your handle just crossed the audit threshold. We are now opening a file on you.\n\n- Field Office")
    end
    if amount >= 250000 then
        MH.State.SendSystemMailOnce(sid, "FBI", "Priority flag: large wire",
            "A quarter-million-dollar transfer has pushed you to the top of the priority list. Field agents are being dispatched.\n\n- Field Office")
    end
    local attIp = MH.State.AttackerIP(sid)
    local myServer = MH.State.AttackerServer(sid)
    if myServer then
        MH.State.AppendLog(tonumber(myServer.id), "Transferred $" .. amount .. " from " .. sess.acc_num .. " to " .. toAcc)
    end
    MH.State.AppendLog(tonumber(src.bank_npc), "Transfer out: $" .. amount .. " from " .. sess.acc_num .. " to " .. toAcc .. " by " .. attIp)
    if tonumber(src.bank_npc) ~= tonumber(dst.bank_npc) then
        MH.State.AppendLog(tonumber(dst.bank_npc), "Transfer in: $" .. amount .. " from " .. sess.acc_num .. " to " .. toAcc)
    end
    if src.owner_sid ~= sid then
        local victim = src.owner_sid
        MH.State.AddNotification(victim, "theft",
            "Transfer of $" .. amount .. " out of your account " .. sess.acc_num)
    end
    send_notify(ply, "ok", "Transferred $" .. amount)
    send_snapshot(ply, 0)
end

local BANK_PASS_COOLDOWN = 600

Handlers.bank_internet_change_pass = function(ply, args)
    local sid = ply:SteamID64()
    local sess = MH.DB.QueryRow("SELECT * FROM mh_bank_session WHERE owner_sid = " .. MH.DB.Esc(sid))
    if not sess then send_notify(ply, "error", "Not logged in to a bank account") return end
    local src = MH.DB.QueryRow("SELECT * FROM mh_banks WHERE acc_num = " .. MH.DB.Esc(sess.acc_num))
    if not src then return end
    local nowT = os.time()
    local last = tonumber(src.last_pass_change or 0) or 0
    if last > 0 and (nowT - last) < BANK_PASS_COOLDOWN then
        local wait = BANK_PASS_COOLDOWN - (nowT - last)
        send_notify(ply, "error", "Password change cooldown: " .. math.ceil(wait) .. "s")
        return
    end
    local newPass = MH.State.GenPass(6)
    MH.DB.Query("UPDATE mh_banks SET acc_pass = " .. MH.DB.Esc(newPass) ..
        ", last_pass_change = " .. nowT ..
        " WHERE id = " .. tonumber(src.id))
    MH.State.AppendLog(tonumber(src.bank_npc), "Password changed on account " .. sess.acc_num .. " by " .. MH.State.AttackerIP(sid))
    if src.owner_sid ~= sid then
        MH.State.AddNotification(src.owner_sid, "pass_changed",
            "Password changed on your account " .. sess.acc_num)
        MH.State.CheckSourcenetPasswordTamper(sid)
    end
    send_notify(ply, "ok", "New password: " .. newPass)
    send_snapshot(ply, 0)
end

Handlers.bank_internet_close = function(ply, args)
    local sid = ply:SteamID64()
    local sess = MH.DB.QueryRow("SELECT * FROM mh_bank_session WHERE owner_sid = " .. MH.DB.Esc(sid))
    if not sess then send_notify(ply, "error", "Not logged in") return end
    local src = MH.DB.QueryRow("SELECT * FROM mh_banks WHERE acc_num = " .. MH.DB.Esc(sess.acc_num))
    if not src then return end
    if src.owner_sid == sid then
        local refund = tonumber(src.cash or 0) or 0
        if refund > 0 then MH.State.AddCash(sid, refund, "closed account " .. tostring(sess.acc_num)) end
    else
        MH.State.AddNotification(src.owner_sid, "closed",
            "Your account " .. sess.acc_num .. " was closed by an intruder")
    end
    MH.State.AppendLog(tonumber(src.bank_npc), "Account " .. sess.acc_num .. " closed by " .. MH.State.AttackerIP(sid))
    MH.DB.Query("DELETE FROM mh_banks WHERE id = " .. tonumber(src.id))
    MH.DB.Query("DELETE FROM mh_bank_session WHERE owner_sid = " .. MH.DB.Esc(sid))
    send_notify(ply, "ok", "Account closed")
    send_snapshot(ply, 0)
end

Handlers.notification_dismiss = function(ply, args)
    MH.DB.Query("UPDATE mh_notifications SET seen = 1 WHERE owner_sid = " ..
        MH.DB.Esc(ply:SteamID64()))
    send_snapshot(ply, 0)
end

Handlers.ddos_launch_internal = Handlers.ddos_launch

Handlers.pwd_reset = function(ply, args)
    local sid = ply:SteamID64()
    local srv = MH.State.GetServersFor(sid)[1]
    if not srv then send_notify(ply, "error", "No server") return end
    local ready, wait = MH.State.PwdResetReady(sid)
    if not ready then
        send_notify(ply, "error", "Password reset cooldown: " .. math.ceil(wait) .. "s")
        return
    end
    local price = MH.State.PwdResetPrice(sid)
    local p = MH.State.GetPlayer(sid)
    local cash = tonumber(p and p.cash or 0) or 0
    if price > 0 and cash < price then
        send_notify(ply, "error", "Not enough cash. Password reset costs $" .. price)
        return
    end
    if price > 0 then MH.State.SpendCash(sid, price, "Root password reset", srv.id) end
    MH.Proc.Spawn({
        creator_sid = sid, local_server = srv.id, victim_server = 0,
        action = "RESET_PWD", soft_id = 0, info = tostring(srv.id),
        duration = 20, cpu_usage = 40,
    })
    send_notify(ply, "ok", "Resetting root password (20s)")
    send_snapshot(ply, srv.id)
end

local PUZZLE_ANSWERS = {
    [2]  = { "hack" },
    [3]  = { "10110", "0b10110", "00010110" },
    [4]  = { "echo" },
    [6]  = { "packet", "packets", "a packet" },
    [7]  = { "40", "40s", "40 seconds" },
    [8]  = { "443" },
    [9]  = { "31" },
    [10] = { "10", "ten" },
    [12] = { "23" },
    [13] = { "4", "four" },
    [14] = { "53" },
    [15] = { "14" },
    [16] = { "hack" },
    [17] = { "57005" },
    [18] = { "16", "sixteen" },
    [19] = { "1024" },
    [20] = { "/etc/fstab", "fstab", "/proc/mounts", "mounts" },
    [22] = { "11111111", "0b11111111" },
    [23] = { "sha1", "sha-1" },
    [24] = { "1969" },
    [25] = { "pwd" },
    [26] = { "4", "four" },
    [27] = { "25" },
    [28] = { "1024" },
    [29] = { "80" },
    [31] = { "127.0.0.1" },
    [32] = { "hex" },
    [33] = { "1111", "0b1111" },
    [34] = { "base64", "base-64" },
    [35] = { "cipher" },
    [36] = { "rats" },
    [37] = { "iter", "i" },
    [39] = { "syn" },
    [40] = { "255" },
    [41] = { "kill" },
    [42] = { "5040" },
    [43] = { "0110", "110", "0b0110", "0b110", "6" },
    [44] = { "144" },
    [45] = { "go", "golang" },
    [46] = { "horse", "trojan horse", "wooden horse" },
}

MH.PuzzleTokens = MH.PuzzleTokens or {}
local PUZZLE_TOKEN_TTL = 1800

local function gen_puzzle_token()
    return util.CRC(tostring(os.time()) .. "_" .. tostring(math.random(1, 1e9)) .. "_" .. tostring(math.random(1, 1e9))) ..
        util.CRC(tostring(SysTime()) .. "_" .. tostring(math.random(1, 1e9)))
end

Handlers.puzzle_start = function(ply, args)
    local sid = ply:SteamID64()
    local pid = tonumber(args.puzzle_id or 0) or 0
    if pid <= 0 then send_notify(ply, "error", "Bad puzzle id") return end
    local puzzle
    for _, p in ipairs(MH.Data.Puzzles or {}) do
        if tonumber(p.id) == pid then puzzle = p break end
    end
    if not puzzle then send_notify(ply, "error", "Unknown puzzle") return end
    if pid > 1 and not MH.State.IsPuzzleSolved(sid, pid - 1) then
        send_notify(ply, "error", "You have not cleared the previous puzzle yet")
        return
    end
    if MH.State.IsPuzzleSolved(sid, pid) then
        send_notify(ply, "warn", "You already solved this one")
        return
    end
    local token = gen_puzzle_token()
    MH.PuzzleTokens[sid] = {
        token = token,
        puzzle_id = pid,
        kind = tostring(puzzle.kind or "qa"),
        stamp = os.time(),
    }
    net.Start(N.PuzzleToken)
    net.WriteUInt(pid, 16)
    net.WriteString(token)
    net.Send(ply)
end

Handlers.puzzle_solve = function(ply, args)
    local sid = ply:SteamID64()
    local pid = tonumber(args.puzzle_id or 0) or 0
    local puzzle
    for _, p in ipairs(MH.Data.Puzzles or {}) do
        if tonumber(p.id) == pid then puzzle = p break end
    end
    if not puzzle then send_notify(ply, "error", "Unknown puzzle") return end
    if pid > 1 and not MH.State.IsPuzzleSolved(sid, pid - 1) then
        send_notify(ply, "error", "You have not cleared the previous puzzle yet")
        return
    end
    if MH.State.IsPuzzleSolved(sid, pid) then
        send_notify(ply, "warn", "You already solved this one")
        return
    end
    local challenge = MH.PuzzleTokens[sid]
    local token = tostring(args.token or "")
    if not challenge or challenge.token ~= token or challenge.puzzle_id ~= pid
        or (os.time() - challenge.stamp) > PUZZLE_TOKEN_TTL then
        send_notify(ply, "error", "Puzzle session expired. Reopen the puzzle.")
        return
    end
    local kind = tostring(puzzle.kind or "qa")
    if kind == "qa" then
        local given = string.lower(string.Trim(tostring(args.answer or "")))
        if given == "" then send_notify(ply, "error", "Enter an answer") return end
        local ok = false
        for _, a in ipairs(PUZZLE_ANSWERS[pid] or {}) do
            if given == string.lower(tostring(a)) then ok = true break end
        end
        if not ok then
            send_notify(ply, "error", "Wrong answer")
            return
        end
    else
        if tostring(args.kind or "") ~= kind then
            send_notify(ply, "error", "Wrong submission type")
            return
        end
        if not args.done then
            send_notify(ply, "error", "Puzzle not complete")
            return
        end
    end
    MH.PuzzleTokens[sid] = nil
    MH.State.RecordPuzzleSolve(sid, pid)
    MH.DB.Query("UPDATE mh_players SET puzzles_solved = puzzles_solved + 1" ..
        ", exp = exp + 25 WHERE sid64 = " .. MH.DB.Esc(sid))
    local nextNpc = MH.State.GetPuzzleNPC(pid + 1)
    if nextNpc then
        MH.State.MarkDiscovered(sid, tonumber(nextNpc.id))
        send_notify(ply, "ok", "Puzzle solved. Next puzzle at " .. nextNpc.ip)
    else
        send_notify(ply, "ok", "Puzzle solved")
    end
    local whoisUnlock = { [10] = "WHOIS2", [28] = "WHOIS3", [35] = "WHOIS4" }
    local wkey = whoisUnlock[pid]
    if wkey then
        local wrow = MH.State.GetSpecialNPC(wkey)
        if wrow then
            MH.State.MarkDiscovered(sid, tonumber(wrow.id))
            send_notify(ply, "ok", "Discovered " .. wrow.name .. " at " .. wrow.ip)
        end
        if wkey == "WHOIS2" then
            local btc = MH.State.GetSpecialNPC("BITCOIN")
            if btc then
                MH.State.MarkDiscovered(sid, tonumber(btc.id))
                MH.State.SendSystemMailOnce(sid, "Employers", "Bitcoin market is up",
                    "You are in the real stuff now. Transfers from banks will pull FBI attention past certain thresholds. Convert the heat into BTC and the trail gets a lot colder.\n\n" ..
                    "Bitcoin Market\n" ..
                    "IP: " .. btc.ip .. "\n" ..
                    "Deposit cash, buy BTC, hold or move it to another wallet. BTC transfers do not light up Sourcenet.\n\n" ..
                    "- Employers")
            end
        end
    end
    send_snapshot(ply, 0)
end

Handlers.ip_reset = function(ply, args)
    local sid = ply:SteamID64()
    local srv = MH.State.GetServersFor(sid)[1]
    if not srv then send_notify(ply, "error", "No server") return end
    local ready, wait = MH.State.IPResetReady(sid)
    if not ready then
        send_notify(ply, "error", "Cooldown active. Try again in " .. math.ceil(wait) .. "s")
        return
    end
    local price = MH.State.IPResetPrice(sid)
    local p = MH.State.GetPlayer(sid)
    local cash = tonumber(p and p.cash or 0) or 0
    if price > 0 and cash < price then
        send_notify(ply, "error", "Not enough cash. IP reset costs $" .. price)
        return
    end
    if price > 0 then MH.State.SpendCash(sid, price, "IP reset", srv.id) end
    MH.Proc.Spawn({
        creator_sid = sid, local_server = srv.id, victim_server = 0,
        action = "RESET_IP", soft_id = 0, info = tostring(srv.id),
        duration = 30, cpu_usage = 50,
    })
    send_notify(ply, "ok", "Resetting IP (30s)")
    send_snapshot(ply, srv.id)
end

local MISSION_LEVEL_POOL = { [1] = 50, [2] = 30, [3] = 25 }
local MISSION_LEVEL_MULT = { [1] = 1.0, [2] = 1.25, [3] = 1.5 }

local function pick_mission_target(mtype)
    local filter
    if mtype == 3 or mtype == 4 then
        filter = " AND LOWER(name) LIKE '%bank%'"
    elseif mtype == 50 then
        filter = " AND name = 'MSA'"
    else
        filter = " AND " .. MH.State.MissionTargetExcludeSQL() ..
                 " AND LOWER(name) NOT LIKE '%bank%'"
    end
    return tonumber(MH.DB.QueryValue(
        "SELECT id FROM mh_servers WHERE is_npc = 1" .. filter ..
        " ORDER BY RANDOM() LIMIT 1")) or 0
end

local function pick_mission_soft(targetId, mtype)
    local row
    if mtype == 1 then
        row = MH.DB.QueryRow("SELECT id, soft_type, soft_name, soft_version FROM mh_software " ..
            "WHERE server_id = " .. tonumber(targetId) ..
            " AND soft_type NOT IN (2, 26) ORDER BY RANDOM() LIMIT 1")
    else
        row = MH.DB.QueryRow("SELECT id, soft_type, soft_name, soft_version FROM mh_software " ..
            "WHERE server_id = " .. tonumber(targetId) ..
            " AND soft_type NOT IN (26) ORDER BY RANDOM() LIMIT 1")
    end
    return row
end

local function pretty_soft_name(row)
    local meta = MH.Data.Soft[tonumber(row.soft_type or 0)] or {}
    local name = tostring(row.soft_name or meta.name or "file")
    local ext = tostring(meta.ext or "")
    local v = tonumber(row.soft_version or 0) or 0
    local verStr = v > 0 and (" v" .. MH.Data.DotVersion(v)) or ""
    return name .. ext .. verStr
end

function MH.MissionBoardRegen()
    MH.DB.Query("DELETE FROM mh_missions WHERE status = 0 AND (assigned_sid IS NULL OR assigned_sid = '')")
    local hirerId = tonumber(MH.DB.QueryValue("SELECT id FROM mh_servers WHERE name = 'Employers' LIMIT 1")) or 0
    if hirerId <= 0 then return end
    local now = os.time()
    for level = 1, 3 do
        local target = MISSION_LEVEL_POOL[level]
        local mult = MISSION_LEVEL_MULT[level]
        local generated = 0
        local attempts = 0
        local attemptCap = target * 20
        local seen = {}
        while generated < target and attempts < attemptCap do
            attempts = attempts + 1
            local pool = MISSION_TYPES
            if level == 3 and math.random(1, 25) == 1 then pool = MISSION_TYPES_EXPLOIT end
            local pick = pool[math.random(1, #pool)]
            local prize = math.floor(math.random(pick.prizeMin, pick.prizeMax) * mult)
            local tid = pick_mission_target(pick.mtype)
            if tid > 0 then
                local key = pick.mtype .. ":" .. tid
                if not seen[key] then
                    local briefing = tostring(pick.briefing or "")
                    local infoStr = ""
                    local info = ""
                    if pick.mtype == 1 or pick.mtype == 2 then
                        local softRow = pick_mission_soft(tid, pick.mtype)
                        if softRow then
                            local label = pretty_soft_name(softRow)
                            briefing = briefing .. "\n\nTarget file: " .. label
                            infoStr = tostring(softRow.soft_name or "")
                            info = tostring(softRow.soft_type or "")
                        else
                            briefing = briefing .. "\n\nTarget file: any file on the server"
                        end
                    elseif pick.mtype == 3 or pick.mtype == 4 then
                        local bank = MH.DB.QueryRow("SELECT id, name, ip FROM mh_servers WHERE id = " .. tid)
                        local acc = MH.DB.QueryRow(
                            "SELECT acc_num FROM mh_banks WHERE bank_npc = " .. tid ..
                            " AND owner_sid LIKE 'npc:%' ORDER BY RANDOM() LIMIT 1")
                        if bank then
                            briefing = briefing .. "\n\nTarget bank: " .. tostring(bank.name) ..
                                " (" .. tostring(bank.ip) .. ")"
                        end
                        if acc then
                            briefing = briefing .. "\nTarget account: #" .. tostring(acc.acc_num)
                            infoStr = tostring(acc.acc_num)
                        end
                    end
                    seen[key] = true
                    MH.DB.Query("INSERT INTO mh_missions (assigned_sid, mtype, target_server, prize, status, created, briefing, level, hirer_server, info, info_str) VALUES (" ..
                        "'', " .. pick.mtype .. ", " .. tid .. ", " .. prize ..
                        ", 0, " .. now .. ", " .. MH.DB.Esc(briefing) .. ", " .. level .. ", " .. hirerId ..
                        ", " .. MH.DB.Esc(info) .. ", " .. MH.DB.Esc(infoStr) .. ")")
                    generated = generated + 1
                end
            end
        end
    end
end

MH.MissionAutoGen = MH.MissionBoardRegen

timer.Create("mh_mission_cron", 900, 0, function()
    MH.MissionBoardRegen()
end)

hook.Add("InitPostEntity", "mh_mission_board_seed", function()
    timer.Simple(5, function()
        local count = tonumber(MH.DB.QueryValue("SELECT COUNT(*) FROM mh_missions WHERE status = 0")) or 0
        if count < 10 then MH.MissionBoardRegen() end
        local stale = MH.DB.Query(
            "SELECT m.id, m.mtype, m.target_server, m.briefing, s.name AS bank_name, s.ip AS bank_ip " ..
            "FROM mh_missions m INNER JOIN mh_servers s ON s.id = m.target_server " ..
            "WHERE m.mtype IN (3, 4) AND m.briefing NOT LIKE '%Target bank:%'") or {}
        for _, m in ipairs(stale) do
            local acc = MH.DB.QueryRow(
                "SELECT acc_num FROM mh_banks WHERE bank_npc = " .. tonumber(m.target_server) ..
                " AND owner_sid LIKE 'npc:%' ORDER BY RANDOM() LIMIT 1")
            local extra = "\n\nTarget bank: " .. tostring(m.bank_name) .. " (" .. tostring(m.bank_ip) .. ")"
            if acc then extra = extra .. "\nTarget account: #" .. tostring(acc.acc_num) end
            MH.DB.Query("UPDATE mh_missions SET briefing = " .. MH.DB.Esc(tostring(m.briefing or "") .. extra) ..
                (acc and (", info_str = " .. MH.DB.Esc(tostring(acc.acc_num))) or "") ..
                " WHERE id = " .. tonumber(m.id))
        end
    end)
end)

Handlers.mission_accept = function(ply, args)
    local sid = ply:SteamID64()
    local p = MH.State.GetPlayer(sid)
    if (tonumber(p and p.cert_level or 0) or 0) < 2 then
        send_notify(ply, "error", "Finish Hacking 101 (cert 2) before accepting a mission")
        return
    end
    local mid = tonumber(args.mission_id or 0)
    local row = MH.DB.QueryRow("SELECT * FROM mh_missions WHERE id = " .. mid)
    if not row then send_notify(ply, "error", "No such mission") return end
    if tonumber(row.status) ~= 0 then send_notify(ply, "error", "Mission already taken") return end
    local preassigned = row.assigned_sid and row.assigned_sid ~= "" and row.assigned_sid ~= sid
    if preassigned then send_notify(ply, "error", "Mission is reserved for another player") return end
    local isBoardPick = (row.assigned_sid == nil or row.assigned_sid == "")
    if isBoardPick then
        local crackerV = tonumber(MH.DB.QueryValue(
            "SELECT MAX(sw.soft_version) FROM mh_software sw " ..
            "INNER JOIN mh_servers sv ON sv.id = sw.server_id " ..
            "WHERE sv.owner_sid = " .. MH.DB.Esc(sid) .. " AND sw.soft_type = 1")) or 0
        local playerTier = 1
        if crackerV >= 60 then playerTier = 3
        elseif crackerV >= 30 then playerTier = 2 end
        local missionLevel = tonumber(row.level) or 1
        if missionLevel ~= playerTier then
            send_notify(ply, "error",
                "This mission is tier " .. missionLevel .. ". Your current tier (based on Cracker) is " .. playerTier .. ".")
            return
        end
    end
    local existingActive = tonumber(MH.DB.QueryValue("SELECT COUNT(*) FROM mh_missions WHERE assigned_sid = " ..
        MH.DB.Esc(sid) .. " AND status = 1")) or 0
    if existingActive >= 1 then send_notify(ply, "warn", "Finish your current mission first") return end
    local extraSets = ""
    local acceptMsg = "Mission accepted: " .. mission_title(tonumber(row.mtype))
    if tonumber(row.mtype) == 3 then
        local acct = MH.DB.QueryRow("SELECT acc_num FROM mh_banks WHERE bank_npc = " ..
            tonumber(row.target_server) .. " ORDER BY RANDOM() LIMIT 1")
        if acct and acct.acc_num then
            local newBrief = tostring(row.briefing or "") ..
                "\n\nTarget account: " .. tostring(acct.acc_num)
            extraSets = ", briefing = " .. MH.DB.Esc(newBrief) ..
                ", info_str = " .. MH.DB.Esc(tostring(acct.acc_num))
            acceptMsg = acceptMsg .. " (account " .. tostring(acct.acc_num) .. ")"
        end
    end
    MH.DB.Query("UPDATE mh_missions SET status = 1, assigned_sid = " .. MH.DB.Esc(sid) ..
        ", accepted_at = " .. os.time() .. extraSets ..
        " WHERE id = " .. mid)
    send_notify(ply, "ok", acceptMsg)
    send_snapshot(ply, 0)
end

Handlers.mission_abort = function(ply, args)
    local sid = ply:SteamID64()
    local mid = tonumber(args.mission_id or 0)
    local row = MH.DB.QueryRow("SELECT * FROM mh_missions WHERE id = " .. mid ..
        " AND assigned_sid = " .. MH.DB.Esc(sid))
    if not row then send_notify(ply, "error", "No such mission") return end
    if tonumber(row.mtype) >= 49 then send_notify(ply, "error", "This mission cannot be aborted") return end
    if tonumber(row.status) ~= 1 then send_notify(ply, "error", "Mission not active") return end
    local p = MH.State.GetPlayer(sid)
    local newExp = math.floor((tonumber(p.exp or 0) or 0) * 0.9)
    MH.DB.Query("UPDATE mh_players SET exp = " .. newExp .. " WHERE sid64 = " .. MH.DB.Esc(sid))
    MH.DB.Query("UPDATE mh_missions SET status = -1, finished = " .. os.time() .. " WHERE id = " .. mid)
    send_notify(ply, "warn", "Mission aborted. Reputation decayed by 10 percent.")
    send_snapshot(ply, 0)
end

Handlers.mission_complete = function(ply, args)
    local sid = ply:SteamID64()
    local mid = tonumber(args.mission_id or 0)
    local row = MH.DB.QueryRow("SELECT * FROM mh_missions WHERE id = " .. mid ..
        " AND assigned_sid = " .. MH.DB.Esc(sid))
    if not row then send_notify(ply, "error", "No such mission") return end
    if tonumber(row.status) ~= 2 then send_notify(ply, "error", "Mission not ready to finalize") return end
    if tonumber(row.mtype) == 3 then
        local reportAmount = math.floor(tonumber(args.amount or 0) or 0)
        if reportAmount <= 0 then
            send_notify(ply, "error", "Report the account balance you observed")
            return
        end
        local targetAcc = tostring(row.info_str or "")
        local acc
        if targetAcc ~= "" then
            acc = MH.DB.QueryRow("SELECT cash FROM mh_banks WHERE bank_npc = " ..
                tonumber(row.target_server) .. " AND acc_num = " .. MH.DB.Esc(targetAcc) .. " LIMIT 1")
        end
        if not acc then
            acc = MH.DB.QueryRow(
                "SELECT cash FROM mh_banks WHERE bank_npc = " .. tonumber(row.target_server) ..
                " ORDER BY cash DESC LIMIT 1")
        end
        local actual = acc and tonumber(acc.cash) or 0
        local tolerance = math.max(100, math.floor(actual * 0.1))
        if math.abs(reportAmount - actual) > tolerance then
            send_notify(ply, "error", "Your reported balance is off. Try again.")
            return
        end
    end
    local prize = tonumber(row.prize) or 0
    MH.State.AddCash(sid, prize, "mission reward (" .. mission_title(tonumber(row.mtype)) .. ")")
    local addRep = 50 + math.floor(prize * 0.05)
    MH.DB.Query("UPDATE mh_players SET exp = exp + " .. addRep ..
        ", mission_count = mission_count + 1, money_earned = money_earned + " .. prize ..
        " WHERE sid64 = " .. MH.DB.Esc(sid))
    MH.DB.Query("UPDATE mh_missions SET status = 3, finished = " .. os.time() .. " WHERE id = " .. mid)
    MH.State.CheckFBIThresholds(sid)
    MH.State.AwardBadge(sid, "first_mission")
    local tgt = tonumber(row.target_server or 0) or 0
    if tgt > 0 and MH.State.RestoreNPCSoftware then
        MH.State.RestoreNPCSoftware(tgt)
    end
    send_notify(ply, "ok", "Mission complete: +$" .. prize .. " and +" .. addRep .. " rep")
    local totalFinished = tonumber(MH.DB.QueryValue(
        "SELECT COUNT(*) FROM mh_missions WHERE assigned_sid = " .. MH.DB.Esc(sid) ..
        " AND status = 3")) or 0
    if totalFinished == 1 then
        MH.State.SendSystemMailOnce(sid, "Employers", "Good work",
            "Clean job. Payment landed in your wallet, reputation ticked up.\n\n" ..
            "You are on the board now. Open Missions and you will see new contracts posted at your current tier. Pick one, read the briefing, hit Accept.\n\n" ..
            "Your tier moves with your Cracker version:\n" ..
            "- Cracker below v3.0: tier 1\n" ..
            "- Cracker v3.0 to v5.9: tier 2\n" ..
            "- Cracker v6.0 and up: tier 3\n\n" ..
            "Better Cracker, better paychecks.\n\n" ..
            "- The Employers")
    end
    send_snapshot(ply, 0)
end

Handlers.admin_ban = function(ply, args)
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        send_notify(ply, "error", "Superadmin only")
        return
    end
    local target = tostring(args.sid64 or ""):Trim()
    if not target:match("^%d+$") or #target < 10 then
        send_notify(ply, "error", "Invalid SteamID64")
        return
    end
    local reason = tostring(args.reason or ""):sub(1, 200)
    if reason == "" then reason = "No reason given" end
    MH.State.BanSid(target, reason, ply:SteamID64())
    send_notify(ply, "ok", "Banned " .. target)
    local victim = player.GetBySteamID64(target)
    if IsValid(victim) then
        send_notify(victim, "error", "You have been banned from Metahacker: " .. reason)
    end
    send_snapshot(ply, 0)
end

Handlers.admin_unban = function(ply, args)
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        send_notify(ply, "error", "Superadmin only")
        return
    end
    local target = tostring(args.sid64 or ""):Trim()
    if target == "" then send_notify(ply, "error", "Invalid SteamID64") return end
    MH.State.UnbanSid(target)
    send_notify(ply, "ok", "Unbanned " .. target)
    send_snapshot(ply, 0)
end

Handlers.admin_wipe_mail_from = function(ply, args)
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        send_notify(ply, "error", "Superadmin only")
        return
    end
    local target = tostring(args.sid64 or ""):Trim()
    if not target:match("^%d+$") or #target < 10 then
        send_notify(ply, "error", "Invalid SteamID64")
        return
    end
    local before = tonumber(MH.DB.QueryValue(
        "SELECT COUNT(*) FROM mh_mail WHERE from_sid = " .. MH.DB.Esc(target))) or 0
    MH.DB.Query("DELETE FROM mh_mail WHERE from_sid = " .. MH.DB.Esc(target))
    send_notify(ply, "ok", "Wiped " .. before .. " mails from " .. target)
    MH.Log.warn("admin", "wipe_mail_from", ply:Nick() .. " wiped " .. before .. " mails from " .. target)
    send_snapshot(ply, 0)
end

Handlers.admin_wipe_user_mail = function(ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        send_notify(ply, "error", "Superadmin only")
        return
    end
    local before = tonumber(MH.DB.QueryValue(
        "SELECT COUNT(*) FROM mh_mail WHERE from_sid GLOB '[0-9]*' AND LENGTH(from_sid) >= 15")) or 0
    MH.DB.Query("DELETE FROM mh_mail WHERE from_sid GLOB '[0-9]*' AND LENGTH(from_sid) >= 15")
    send_notify(ply, "ok", "Wiped " .. before .. " user-to-user mails")
    MH.Log.warn("admin", "wipe_user_mail", ply:Nick() .. " wiped " .. before .. " user-to-user mails")
    send_snapshot(ply, 0)
end

Handlers.admin_refresh_missions = function(ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        send_notify(ply, "error", "Superadmin only")
        return
    end
    if MH.MissionBoardRegen then MH.MissionBoardRegen() end
    local newCount = tonumber(MH.DB.QueryValue(
        "SELECT COUNT(*) FROM mh_missions WHERE status = 0 AND (assigned_sid IS NULL OR assigned_sid = '')")) or 0
    for _, p in ipairs(player.GetAll()) do
        MH.Api.SendSnapshot(p, 0)
    end
    send_notify(ply, "ok", "Mission board refreshed: " .. newCount .. " missions")
    MH.Log.info("admin", "refresh_missions", (ply:Nick() or "?") ..
        " refreshed mission board (" .. newCount .. " missions)")
end

Handlers.admin_mail_ban = function(ply, args)
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        send_notify(ply, "error", "Superadmin only")
        return
    end
    local target = tostring(args.sid64 or ""):Trim()
    if not target:match("^%d+$") or #target < 10 then
        send_notify(ply, "error", "Invalid SteamID64")
        return
    end
    local reason = tostring(args.reason or ""):sub(1, 200)
    if reason == "" then reason = "No reason given" end
    MH.State.MailBanSid(target, reason, ply:SteamID64())
    send_notify(ply, "ok", "Mail-banned " .. target)
    local victim = player.GetBySteamID64(target)
    if IsValid(victim) then
        send_notify(victim, "error", "You have been banned from sending mail: " .. reason)
    end
    send_snapshot(ply, 0)
end

Handlers.admin_mail_unban = function(ply, args)
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        send_notify(ply, "error", "Superadmin only")
        return
    end
    local target = tostring(args.sid64 or ""):Trim()
    if target == "" then send_notify(ply, "error", "Invalid SteamID64") return end
    MH.State.MailUnbanSid(target)
    send_notify(ply, "ok", "Mail-unbanned " .. target)
    send_snapshot(ply, 0)
end

Handlers.admin_reset_abuse = function(ply, args)
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        send_notify(ply, "error", "Superadmin only")
        return
    end
    local target = tostring(args.sid64 or ""):Trim()
    if target == "" then
        MH.DB.Query("UPDATE mh_players SET abuse_cmd_hits = 0, abuse_mail_hits = 0, last_abuse_stamp = 0, " ..
            "total_cmds = 0, total_mails_sent = 0")
        MH.DB.Query("DELETE FROM mh_abuse_log")
        send_notify(ply, "ok", "Reset all abuse stats")
    else
        MH.DB.Query("UPDATE mh_players SET abuse_cmd_hits = 0, abuse_mail_hits = 0, last_abuse_stamp = 0, " ..
            "total_cmds = 0, total_mails_sent = 0 WHERE sid64 = " .. MH.DB.Esc(target))
        MH.DB.Query("DELETE FROM mh_abuse_log WHERE sid64 = " .. MH.DB.Esc(target))
        send_notify(ply, "ok", "Reset abuse stats for " .. target)
    end
    send_snapshot(ply, 0)
end

net.Receive(N.OpenOS, function(_, ply)
    local sid = ply:SteamID64()
    local banned, banReason = MH.State.IsBanned(sid)
    if banned then
        send_notify(ply, "error", "You are banned from Metahacker: " .. (banReason or ""))
        return
    end
    if MH.State.CountServers(sid) == 0 then
        MH.State.CreateServer(sid, "Server#1")
    end
    local hasInternet = MH.DB.QueryValue("SELECT 1 FROM mh_internet WHERE owner_sid = " .. MH.DB.Esc(sid))
    if not hasInternet then
        local dir = MH.State.GetSpecialNPC("DIRECTORY")
        if dir then
            MH.DB.Query("INSERT OR REPLACE INTO mh_internet (owner_sid, target_server, authed, stamp) VALUES (" ..
                MH.DB.Esc(sid) .. ", " .. tonumber(dir.id) .. ", 0, " .. os.time() .. ")")
            MH.State.MarkDiscovered(sid, tonumber(dir.id))
        end
    end
    send_snapshot(ply, 0)
end)

local CMD_RATE_WINDOW = 5
local CMD_RATE_LIMIT = 20
local CMD_RATE_AUTOBAN_HITS = 5
local cmd_rate_log = {}
local cmd_rate_hits_mem = {}

local function log_abuse(sid, kind, info)
    MH.DB.Query("INSERT INTO mh_abuse_log (sid64, kind, info, stamp) VALUES (" ..
        MH.DB.Esc(tostring(sid)) .. ", " .. MH.DB.Esc(tostring(kind)) .. ", " ..
        MH.DB.Esc(tostring(info or "")) .. ", " .. os.time() .. ")")
    MH.DB.Query("UPDATE mh_players SET last_abuse_stamp = " .. os.time() ..
        " WHERE sid64 = " .. MH.DB.Esc(tostring(sid)))
end
MH.Api.LogAbuse = log_abuse

net.Receive(N.Command, function(_, ply)
    local sid = ply:SteamID64()
    local banned, banReason = MH.State.IsBanned(sid)
    if banned then
        send_notify(ply, "error", "You are banned from Metahacker: " .. (banReason or ""))
        return
    end
    local nowT = os.time()
    local log = cmd_rate_log[sid] or {}
    local fresh = {}
    for _, t in ipairs(log) do if (nowT - t) < CMD_RATE_WINDOW then fresh[#fresh + 1] = t end end
    fresh[#fresh + 1] = nowT
    cmd_rate_log[sid] = fresh
    if #fresh > CMD_RATE_LIMIT then
        cmd_rate_hits_mem[sid] = (cmd_rate_hits_mem[sid] or 0) + 1
        MH.DB.Query("UPDATE mh_players SET abuse_cmd_hits = COALESCE(abuse_cmd_hits, 0) + 1 WHERE sid64 = " ..
            MH.DB.Esc(sid))
        log_abuse(sid, "cmd_rate", "#" .. #fresh .. " cmds in " .. CMD_RATE_WINDOW .. "s")
        if cmd_rate_hits_mem[sid] >= CMD_RATE_AUTOBAN_HITS and not ply:IsSuperAdmin() then
            MH.State.BanSid(sid, "Autoban: command rate abuse (" .. cmd_rate_hits_mem[sid] .. " strikes)", "console")
            send_notify(ply, "error", "You have been automatically banned for command spam.")
            MH.Log.warn("abuse", "autoban", sid .. " autobanned for cmd spam")
        else
            send_notify(ply, "error", "Rate limit: slow down.")
        end
        return
    end
    MH.DB.Query("UPDATE mh_players SET total_cmds = COALESCE(total_cmds, 0) + 1 WHERE sid64 = " ..
        MH.DB.Esc(sid))
    local cmd = net.ReadString()
    local argsJson = net.ReadString()
    local args = util.JSONToTable(argsJson or "") or {}
    local h = Handlers[cmd]
    if not h then
        send_notify(ply, "error", "Unknown command: " .. tostring(cmd))
        return
    end
    local ok, err = pcall(h, ply, args)
    if not ok then
        MH.Log.error("api", cmd, tostring(err))
        send_notify(ply, "error", "Server error running " .. cmd)
    end
end)

concommand.Add("mh_ban", function(ply, _, argv)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("[Metahacker] Superadmin only.")
        return
    end
    local target = tostring(argv[1] or ""):Trim()
    if not target:match("^%d+$") or #target < 10 then
        local msg = "[Metahacker] Usage: mh_ban <sid64> [reason]"
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end
    local reason = table.concat(argv, " ", 2)
    if reason == "" then reason = "No reason given" end
    MH.State.BanSid(target, reason, IsValid(ply) and ply:SteamID64() or "console")
    local msg = "[Metahacker] Banned " .. target .. ": " .. reason
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)

concommand.Add("mh_unban", function(ply, _, argv)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("[Metahacker] Superadmin only.")
        return
    end
    local target = tostring(argv[1] or ""):Trim()
    if target == "" then
        local msg = "[Metahacker] Usage: mh_unban <sid64>"
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end
    MH.State.UnbanSid(target)
    local msg = "[Metahacker] Unbanned " .. target
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)

concommand.Add("mh_mail_ban", function(ply, _, argv)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("[Metahacker] Superadmin only.")
        return
    end
    local target = tostring(argv[1] or ""):Trim()
    if not target:match("^%d+$") or #target < 10 then
        local msg = "[Metahacker] Usage: mh_mail_ban <sid64> [reason]"
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end
    local reason = table.concat(argv, " ", 2)
    if reason == "" then reason = "No reason given" end
    MH.State.MailBanSid(target, reason, IsValid(ply) and ply:SteamID64() or "console")
    local msg = "[Metahacker] Mail-banned " .. target .. ": " .. reason
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)

concommand.Add("mh_mail_unban", function(ply, _, argv)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("[Metahacker] Superadmin only.")
        return
    end
    local target = tostring(argv[1] or ""):Trim()
    if target == "" then
        local msg = "[Metahacker] Usage: mh_mail_unban <sid64>"
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end
    MH.State.MailUnbanSid(target)
    local msg = "[Metahacker] Mail-unbanned " .. target
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)

concommand.Add("mh_round_end", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("[Metahacker] Superadmin only.")
        return
    end
    local roundTables = {
        "mh_servers", "mh_software", "mh_processes", "mh_banks", "mh_server_log",
        "mh_tmp_log", "mh_missions", "mh_hacked", "mh_hacked_banks", "mh_xhds",
        "mh_internet", "mh_bank_session", "mh_notifications", "mh_discovered", "mh_news",
        "mh_puzzle_solves",
    }
    for _, t in ipairs(roundTables) do sql.Query("DROP TABLE IF EXISTS " .. t) end
    sql.Query("UPDATE mh_players SET cash = 0, bitcoin = 0, cert_level = 0, ip_resets = 0, last_ip_reset = 0, pwd_resets = 0, last_pwd_reset = 0, last_puzzle = 0, puzzles_solved = 0, exp = 0")
    MH.DB.Init()
    timer.Simple(0.1, function()
        if MH.State and MH.State.SeedNPCs then MH.State.SeedNPCs() end
        for _, p in ipairs(player.GetAll()) do
            if MH.State.EnsurePlayer then MH.State.EnsurePlayer(p) end
            local sid = p:SteamID64()
            local acc = MH.State.EnsureDefaultBankAccount(sid)
            if acc then
                MH.DB.Query("UPDATE mh_banks SET cash = " .. tonumber(MH.Data.StartingCash or 0) ..
                    " WHERE id = " .. tonumber(acc.id))
            end
        end
    end)
    local msg = "[Metahacker] Round ended. Per-round state wiped, badges and nicks preserved."
    if IsValid(ply) then ply:ChatPrint(msg) end
    MH.Log.info("admin", "round_end", "Round ended" .. (IsValid(ply) and (" (by " .. ply:Nick() .. ")") or " (console)"))
end)

concommand.Add("mh_wipe_all", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("[Metahacker] Superadmin only.")
        return
    end
    local tables = {
        "mh_players", "mh_servers", "mh_software", "mh_processes",
        "mh_banks", "mh_btc_wallets", "mh_log", "mh_server_log",
        "mh_tmp_log", "mh_mail", "mh_missions", "mh_clans",
        "mh_clan_users", "mh_hacked", "mh_hacked_banks", "mh_xhds",
        "mh_internet", "mh_bank_session", "mh_notifications",
        "mh_discovered", "mh_news", "mh_puzzle_solves",
    }
    for _, t in ipairs(tables) do
        sql.Query("DROP TABLE IF EXISTS " .. t)
    end
    MH.DB.Init()
    timer.Simple(0.1, function()
        if MH.State and MH.State.SeedNPCs then MH.State.SeedNPCs() end
        for _, p in ipairs(player.GetAll()) do
            if MH.State.EnsurePlayer then MH.State.EnsurePlayer(p) end
            MH.Api.SendSnapshot(p, 0)
        end
    end)
    local msg = "[Metahacker] Wiped " .. #tables .. " tables, reinitialized schema, reseeding NPCs, re-initialized online players."
    if IsValid(ply) then ply:ChatPrint(msg) end
    MH.Log.info("admin", "wipe", "Wiped all data" .. (IsValid(ply) and (" (by " .. ply:Nick() .. ")") or " (console)"))
end)

concommand.Add("mh_migratecash", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("[Metahacker] Superadmin only.")
        return
    end
    if not (MH.State and MH.State.MigrateCashToDefaultBank) then
        local msg = "[Metahacker] Migration function not loaded."
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end
    local moved = MH.State.MigrateCashToDefaultBank() or 0
    for _, p in ipairs(player.GetAll()) do
        MH.Api.SendSnapshot(p, 0)
    end
    local msg = "[Metahacker] Migrated cash to default bank for " .. moved .. " players."
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    MH.Log.info("admin", "migrate_cash", msg ..
        (IsValid(ply) and (" (by " .. ply:Nick() .. ")") or " (console)"))
end)

concommand.Add("mh_refreshmissions", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("[Metahacker] Superadmin only.")
        return
    end
    if MH.MissionBoardRegen then MH.MissionBoardRegen() end
    local eligible = tonumber(MH.DB.QueryValue(
        "SELECT COUNT(DISTINCT assigned_sid) FROM mh_missions WHERE status = 3")) or 0
    local newCount = tonumber(MH.DB.QueryValue(
        "SELECT COUNT(*) FROM mh_missions WHERE status = 0 AND (assigned_sid IS NULL OR assigned_sid = '')")) or 0
    for _, p in ipairs(player.GetAll()) do
        MH.Api.SendSnapshot(p, 0)
    end
    local msg = "[Metahacker] Refreshed mission board: " .. newCount ..
        " new missions, " .. eligible .. " eligible players notified."
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    MH.Log.info("admin", "refresh_missions", msg)
end)

concommand.Add("mh_reroll", function(ply, _, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("[Metahacker] Superadmin only.")
        return
    end
    local name = tostring(args and args[1] or "")
    if name == "" then
        local msg = "[Metahacker] Usage: mh_reroll <nick or SteamID64>"
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end
    local target
    if string.match(name, "^%d+$") and #name >= 17 then
        target = MH.DB.QueryRow("SELECT sid64, nick FROM mh_players WHERE sid64 = " .. MH.DB.Esc(name))
    end
    if not target then
        target = MH.DB.QueryRow("SELECT sid64, nick FROM mh_players WHERE LOWER(nick) = LOWER(" .. MH.DB.Esc(name) .. ")")
    end
    if not target then
        local msg = "[Metahacker] No player found matching '" .. name .. "'"
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end
    local sid = target.sid64
    local row = MH.DB.QueryRow("SELECT * FROM mh_missions WHERE assigned_sid = " .. MH.DB.Esc(sid) ..
        " AND mtype = 1 AND status IN (0, 1) ORDER BY created ASC LIMIT 1")
    if not row then
        local msg = "[Metahacker] " .. tostring(target.nick) .. " has no pending first-job mission."
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end
    local newTarget = MH.DB.QueryRow(
        "SELECT id, ip, name FROM mh_servers WHERE is_npc = 1 " ..
        "AND LOWER(name) NOT LIKE '%bank%' " ..
        "AND " .. MH.State.MissionTargetExcludeSQL() .. " " ..
        "AND id != " .. tonumber(row.target_server or 0) .. " " ..
        "ORDER BY RANDOM() LIMIT 1")
    if not newTarget then
        local msg = "[Metahacker] No alternate NPC targets available."
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end
    local briefing =
        "Your very first contract. The target is " .. newTarget.ip .. " (" .. newTarget.name .. ").\n\n" ..
        "Steps:\n" ..
        "1. Open the Internet tab, type " .. newTarget.ip .. " into the address bar, press Go.\n" ..
        "2. Press Bruteforce. A hack process starts. Watch it count down in Task Manager.\n" ..
        "3. When it completes, the password lands in your Hacked Database. Come back to Internet and press Login with that password.\n" ..
        "4. On the remote machine, open the Softwares panel and delete any file.\n" ..
        "5. Come back here and press Complete to collect the prize."
    MH.DB.Query("UPDATE mh_missions SET target_server = " .. tonumber(newTarget.id) ..
        ", briefing = " .. MH.DB.Esc(briefing) ..
        " WHERE id = " .. tonumber(row.id))
    local msg = "[Metahacker] Rerolled " .. tostring(target.nick) .. "'s first mission to " ..
        newTarget.name .. " (" .. newTarget.ip .. ")"
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    local onlinePly = player.GetBySteamID64(sid)
    if IsValid(onlinePly) then MH.Api.SendSnapshot(onlinePly, 0) end
end)

concommand.Add("mh_cleanup_dupes", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local sid = ply:SteamID64()
    local keep = MH.DB.QueryValue("SELECT MIN(id) FROM mh_servers WHERE owner_sid = " .. MH.DB.Esc(sid))
    if not keep then
        ply:ChatPrint("[Metahacker] No servers to clean up.")
        return
    end
    local victims = MH.DB.Query("SELECT id FROM mh_servers WHERE owner_sid = " ..
        MH.DB.Esc(sid) .. " AND id != " .. tonumber(keep)) or {}
    for _, row in ipairs(victims) do
        local vid = tonumber(row.id)
        MH.DB.Query("DELETE FROM mh_software  WHERE server_id = " .. vid)
        MH.DB.Query("DELETE FROM mh_processes WHERE local_server = " .. vid .. " OR victim_server = " .. vid)
        MH.DB.Query("DELETE FROM mh_log       WHERE server_id = " .. vid)
        MH.DB.Query("DELETE FROM mh_hacked    WHERE target_server = " .. vid)
        MH.DB.Query("DELETE FROM mh_servers   WHERE id = " .. vid)
    end
    ply:ChatPrint("[Metahacker] Removed " .. #victims .. " duplicate servers, kept #" .. tonumber(keep) .. ".")
    MH.Api.SendSnapshot(ply, tonumber(keep))
end)

