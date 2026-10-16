MH = MH or {}
MH.Virus = {}

local function now() return os.time() end

local VIRUS_TYPES = { [8] = "spam", [9] = "warez", [20] = "miner" }

function MH.Virus.CollectFor(sid)
    local rows = MH.DB.Query(
        "SELECT v.id, v.soft_type, v.soft_version, v.last_collect, v.server_id, " ..
        "s.cpu_tier, s.net_tier " ..
        "FROM mh_software v LEFT JOIN mh_servers s ON s.id = v.server_id " ..
        "WHERE v.owner_sid = " .. MH.DB.Esc(sid) ..
        " AND v.installed = 1 AND v.soft_type IN (8, 9, 20)") or {}
    local nowT = now()
    local cashTotal = 0
    local btcTotal = 0.0
    for _, r in ipairs(rows) do
        local last = tonumber(r.last_collect) or 0
        local workTime = last == 0 and 600 or (nowT - last)
        if workTime >= 600 then
            local st = tonumber(r.soft_type)
            local ver = tonumber(r.soft_version) or 1
            local cpuTier = tonumber(r.cpu_tier) or 1
            local netTier = tonumber(r.net_tier) or 1
            local cpuMhz = MH.Data.Hardware.cpu[cpuTier].mhz
            local netMbps = MH.Data.Hardware.net[netTier].mbps
            if st == 8 then
                local pct = (ver / 1000) * 2 + 1
                local bonus = math.random() < 0.05 and 2 or 1
                cashTotal = cashTotal + math.floor((workTime * 0.00000694 * cpuMhz * pct * bonus))
            elseif st == 9 then
                local base = ver < 20 and 1 or (ver < 30 and 1.25 or (ver < 40 and 1.5 or (ver < 50 and 1.75 or 2)))
                local sentMult = 0.02 + (ver / 50)
                cashTotal = cashTotal + math.floor((workTime * netMbps * base * sentMult) / 60)
            elseif st == 20 then
                btcTotal = btcTotal + (workTime * cpuMhz * 0.000052085 / 3600)
            end
            MH.DB.Query("UPDATE mh_software SET last_collect = " .. nowT .. " WHERE id = " .. tonumber(r.id))
        end
    end
    local collector = MH.DB.QueryRow("SELECT MAX(soft_version) AS v FROM mh_software WHERE owner_sid = " .. MH.DB.Esc(sid) ..
        " AND soft_type = 11 AND installed = 1")
    local colV = collector and tonumber(collector.v) or 0
    if colV > 0 then
        cashTotal = math.floor(cashTotal * (1 + colV / 1000))
        btcTotal = btcTotal * (1 + colV / 1000)
    end
    if cashTotal > 0 then
        MH.State.AddCash(sid, cashTotal, "virus data collection")
    end
    if btcTotal > 0 then
        MH.DB.Query("UPDATE mh_players SET bitcoin = bitcoin + " .. btcTotal .. " WHERE sid64 = " .. MH.DB.Esc(sid))
    end
    local collectRep = math.floor(btcTotal * 600) + math.floor(cashTotal * 0.1)
    if collectRep > 0 then
        MH.DB.Query("UPDATE mh_players SET exp = exp + " .. collectRep ..
            " WHERE sid64 = " .. MH.DB.Esc(sid))
    end
    return cashTotal, btcTotal, #rows
end
