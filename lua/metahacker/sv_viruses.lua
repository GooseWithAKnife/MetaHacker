MH = MH or {}
MH.Virus = {}

local function now() return os.time() end

local VIRUS_TYPES = { [8] = "spam", [9] = "warez", [20] = "miner" }

function MH.Virus.CollectFor(sid, accNum)
    local rows = MH.DB.Query(
        "SELECT v.id, v.soft_type, v.soft_version, v.last_collect, v.server_id, " ..
        "s.cpu_tier, s.net_tier, s.ip AS host_ip, s.name AS host_name " ..
        "FROM mh_software v LEFT JOIN mh_servers s ON s.id = v.server_id " ..
        "WHERE v.owner_sid = " .. MH.DB.Esc(sid) ..
        " AND v.installed = 1 AND v.soft_type IN (8, 9, 20)") or {}
    local nowT = now()
    local cashTotal = 0
    local btcTotal = 0.0
    local details = {}
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
            local entry = {
                host_ip = tostring(r.host_ip or "?"),
                host_name = tostring(r.host_name or ""),
                soft_type = st,
                work_time = workTime,
                cash = 0,
                btc = 0,
                emails = 0,
                bonus = false,
            }
            if st == 8 then
                local pct = (ver / 1000) * 2 + 1
                local bonus = math.random() < 0.05 and 2 or 1
                local addCash = math.floor((workTime * 0.00000694 * cpuMhz * pct * bonus))
                entry.cash = addCash
                entry.bonus = bonus > 1
                entry.emails = math.floor(workTime * netMbps * 55)
                cashTotal = cashTotal + addCash
            elseif st == 9 then
                local base = ver < 20 and 1 or (ver < 30 and 1.25 or (ver < 40 and 1.5 or (ver < 50 and 1.75 or 2)))
                local sentMult = 0.02 + (ver / 50)
                local addCash = math.floor((workTime * netMbps * base * sentMult) / 60)
                entry.cash = addCash
                cashTotal = cashTotal + addCash
            elseif st == 20 then
                local addBtc = (workTime * cpuMhz * 0.000052085 / 3600)
                entry.btc = addBtc
                btcTotal = btcTotal + addBtc
            end
            table.insert(details, entry)
            MH.DB.Query("UPDATE mh_software SET last_collect = " .. nowT .. " WHERE id = " .. tonumber(r.id))
        end
    end
    local collector = MH.DB.QueryRow(
        "SELECT soft_name, soft_version FROM mh_software WHERE owner_sid = " .. MH.DB.Esc(sid) ..
        " AND soft_type = 11 AND installed = 1 ORDER BY soft_version DESC LIMIT 1")
    local colV = collector and tonumber(collector.soft_version) or 0
    local colName = collector and tostring(collector.soft_name or "Collector") or nil
    local colBonusPct = 0
    if colV > 0 then
        colBonusPct = colV / 10
        cashTotal = math.floor(cashTotal * (1 + colV / 1000))
        btcTotal = btcTotal * (1 + colV / 1000)
    end
    local depositBankIp = nil
    if cashTotal > 0 then
        local depositedToBank = false
        if accNum and accNum ~= "" then
            local acc = MH.DB.QueryRow(
                "SELECT b.id, b.owner_sid, s.ip AS bank_ip FROM mh_banks b " ..
                "LEFT JOIN mh_servers s ON s.id = b.bank_npc " ..
                "WHERE b.acc_num = " .. MH.DB.Esc(accNum) ..
                " AND b.owner_sid = " .. MH.DB.Esc(sid))
            if acc then
                MH.DB.Query("UPDATE mh_banks SET cash = cash + " .. cashTotal ..
                    " WHERE id = " .. tonumber(acc.id))
                depositedToBank = true
                depositBankIp = tostring(acc.bank_ip or "")
            end
        end
        if not depositedToBank then
            MH.State.AddCash(sid, cashTotal, "virus data collection")
        end
    end
    if btcTotal > 0 then
        MH.DB.Query("UPDATE mh_players SET bitcoin = bitcoin + " .. btcTotal .. " WHERE sid64 = " .. MH.DB.Esc(sid))
    end
    local collectRep = math.floor(btcTotal * 600) + math.floor(cashTotal * 0.1)
    if collectRep > 0 then
        MH.DB.Query("UPDATE mh_players SET exp = exp + " .. collectRep ..
            " WHERE sid64 = " .. MH.DB.Esc(sid))
    end
    if #details > 0 then
        local summary = {
            stamp = nowT,
            cash_total = cashTotal,
            btc_total = btcTotal,
            visited = #rows,
            account = accNum,
            bank_ip = depositBankIp,
            collector_name = colName,
            collector_version = colV,
            collector_bonus_pct = colBonusPct,
            details = details,
        }
        MH.DB.Query("UPDATE mh_players SET last_collect_stamp = " .. nowT ..
            ", last_collect_cash = " .. cashTotal ..
            ", last_collect_btc = " .. string.format("%.7f", btcTotal) ..
            ", last_collect_visited = " .. #rows ..
            ", last_collect_acc = " .. MH.DB.Esc(accNum or "") ..
            ", last_collect_json = " .. MH.DB.Esc(util.TableToJSON(summary)) ..
            " WHERE sid64 = " .. MH.DB.Esc(sid))
    end
    local primary = MH.State.GetServersFor(sid)[1]
    if primary and #details > 0 then
        local collectLine = "localhost collected money"
        if colName then
            collectLine = collectLine .. " using " .. colName ..
                " (" .. MH.Data.DotVersion(colV) .. ")"
        end
        MH.State.AppendLog(primary.id, collectLine)
        for _, d in ipairs(details) do
            if d.soft_type == 8 and d.cash > 0 then
                MH.State.AppendLog(primary.id,
                    "Server [" .. d.host_ip .. "] mailed " .. d.emails ..
                    " emails, generating $" .. d.cash)
            elseif d.soft_type == 9 and d.cash > 0 then
                MH.State.AppendLog(primary.id,
                    "Server [" .. d.host_ip .. "] seeded warez, generating $" .. d.cash)
            elseif d.soft_type == 20 and d.btc > 0 then
                MH.State.AppendLog(primary.id,
                    "Server [" .. d.host_ip .. "] mined " ..
                    string.format("%.7f", d.btc) .. " BTC")
            end
        end
        if cashTotal > 0 and depositBankIp then
            MH.State.AppendLog(primary.id,
                "$" .. cashTotal .. " were transfered to #" .. accNum ..
                " on bank [" .. depositBankIp .. "]")
        end
    end
    return cashTotal, btcTotal, #details, #rows, {
        details = details,
        collector_name = colName,
        collector_version = colV,
        collector_bonus_pct = colBonusPct,
        account = accNum,
        bank_ip = depositBankIp,
        cash_total = cashTotal,
        btc_total = btcTotal,
        stamp = nowT,
    }
end
