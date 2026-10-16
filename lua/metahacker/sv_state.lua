MH = MH or {}
MH.State = {}

local function now() return os.time() end

local function gen_ip()
    for _ = 1, 20 do
        local ip = math.random(1, 254) .. "." .. math.random(0, 254) .. "." .. math.random(0, 254) .. "." .. math.random(1, 254)
        local hit = MH.DB.QueryValue("SELECT id FROM mh_servers WHERE ip = " .. MH.DB.Esc(ip))
        if not hit then return ip end
    end
    return "10." .. math.random(0, 254) .. "." .. math.random(0, 254) .. "." .. math.random(1, 254)
end

local function gen_pass(len)
    len = len or 10
    local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    local t = {}
    for i = 1, len do
        local idx = math.random(1, #chars)
        t[i] = chars:sub(idx, idx)
    end
    return table.concat(t)
end

MH.State.GenIP = gen_ip
MH.State.GenPass = gen_pass

local WELCOME_SUBJECT = "Welcome to MetaHacker!"
local WELCOME_BTC_GIFT = 1.337

local function build_welcome_body(nick)
    return string.format([[Greetings, %s.

Thanks for trying out MetaHacker. I am very excited for you to be trying this out, and congratulations on getting this far already. There is a lot more to do in the game than meets the eye, so if you get stuck do not hesitate to ask around.

Before you do anything else, head to the University tab and open the Certifications sub-tab. The first few certs are free and the tutorial they walk you through covers every system in the OS. Treat it as the manual. The rest of the game will make a lot more sense after.

By the way, I just sent you %.3f BTC. You can see it on the Finances page. Enjoy.

Pardon the pun, but we hope you have a great experience here.

Happy hacking.
- RakTheGoose]], tostring(nick or "operator"), WELCOME_BTC_GIFT)
end

function MH.State.SendSystemMail(toSid, fromKey, subject, body)
    MH.DB.Query("INSERT INTO mh_mail (to_sid, from_sid, subject, body, stamp, seen, is_deleted) VALUES (" ..
        MH.DB.Esc(toSid) .. ", " .. MH.DB.Esc(fromKey) .. ", " .. MH.DB.Esc(subject) .. ", " ..
        MH.DB.Esc(body) .. ", " .. os.time() .. ", 0, 0)")
    local rcpt = player.GetBySteamID64(toSid)
    if IsValid(rcpt) and MH.Api and MH.Api.SendSnapshot then
        MH.Api.SendSnapshot(rcpt, 0)
    end
end

function MH.State.HasReceivedSystemMail(toSid, fromKey, subject)
    local hit = MH.DB.QueryValue("SELECT 1 FROM mh_mail WHERE to_sid = " .. MH.DB.Esc(toSid) ..
        " AND from_sid = " .. MH.DB.Esc(fromKey) .. " AND subject = " .. MH.DB.Esc(subject) .. " LIMIT 1")
    return hit ~= nil
end

function MH.State.SendSystemMailOnce(toSid, fromKey, subject, body)
    if MH.State.HasReceivedSystemMail(toSid, fromKey, subject) then return false end
    MH.State.SendSystemMail(toSid, fromKey, subject, body)
    return true
end

local FBI_THRESHOLDS = {
    { exp = 500,   subject = "Person of interest",     body = "This is a courtesy notice. You have made it onto a watch list. We are now paying attention. Keep that in mind the next time you consider something stupid.\n\n- Field Office" },
    { exp = 2500,  subject = "Wanted: minor bounty",   body = "A standing bounty has been placed on your handle. The amount is modest for now. It will not stay modest.\n\n- Field Office" },
    { exp = 10000, subject = "Wanted: major bounty",   body = "Your bounty has been upgraded to major. Field agents are being briefed. Clean your rig, cover your logs, and stop leaving fingerprints.\n\n- Field Office" },
    { exp = 50000, subject = "Priority target",        body = "You are now a priority. A task force has been assigned. If we were you, we would already be running.\n\n- Field Office" },
}

function MH.State.CheckFBIThresholds(sid)
    local p = MH.State.GetPlayer(sid)
    if not p then return end
    local exp = tonumber(p.exp or 0) or 0
    for _, t in ipairs(FBI_THRESHOLDS) do
        if exp >= t.exp then
            MH.State.SendSystemMailOnce(sid, "FBI", t.subject, t.body)
        end
    end
end

function MH.State.CheckSourcenetAlert(sid, amount)
    MH.State.SendSystemMailOnce(sid, "Sourcenet",
        "Transfer activity flagged",
        "A money transfer tied to your activity has been catalogued. We log every one of these now. Larger ones travel further up the chain.\n\n- Sourcenet Compliance")
    MH.State.CheckFBIThresholds(sid)
end

function MH.State.CheckSourcenetPasswordTamper(sid)
    MH.State.SendSystemMailOnce(sid, "Sourcenet",
        "Credential tampering detected",
        "You changed credentials on an account that is not yours. The old owner was notified. The incident is on file.\n\n- Sourcenet Compliance")
end

function MH.State.CheckSourcenetAccountOpened(sid)
    MH.State.SendSystemMailOnce(sid, "Sourcenet",
        "Account activity noted",
        "A new bank account was opened in your name. Compliance has catalogued the event. Future deposits above the audit threshold will be reviewed, as will anomalies in the pattern of your deposits.\n\n- Sourcenet Compliance")
end

function MH.State.CheckSourcenetSoftwareDeleted(sid)
    MH.State.SendSystemMailOnce(sid, "Sourcenet",
        "File deletion flagged",
        "You have deleted a software file on a machine we were monitoring. The deletion is irreversible on our side as well. Investigators have been notified. Think twice before the next one.\n\n- Sourcenet Compliance")
end

function MH.State.CheckEmployersMSAHit(sid)
    MH.State.SendSystemMailOnce(sid, "Employers",
        "Delivery confirmed",
        "You pulled it off. The payload is in the right hands. Expect $25,000 to land in whichever account you check first - call it hazard pay. Keep your head down for a while. The retaliation window is open.\n\n- The Employers")
    MH.State.AddCash(sid, 25000, "MSA hazard pay")
end

function MH.State.SendCertServiceIntro(sid, level)
    level = tonumber(level or 0) or 0
    if level == 1 then
        local dc = MH.State.GetSpecialNPC("DC")
        if dc then
            MH.State.MarkDiscovered(sid, tonumber(dc.id))
            MH.State.SendSystemMailOnce(sid, "Employers", "You need software",
                "Congrats on cert 1. One thing before you go further: your rig is empty. No cracker, no hasher, no antivirus. Nothing.\n\n" ..
                "Head to the Download Center. It is a public mirror for the baseline tools everyone starts with. Grab a Cracker at least, a Hasher if you want to not get rolled, and anything else that looks useful.\n\n" ..
                "Download Center\n" ..
                "IP: " .. dc.ip .. "\n" ..
                "Login as user " .. '"download"' .. ", password " .. '"download"' .. ".\n\n" ..
                "Also, there is a Public Directory at 1.1.1.1 that lists the IPs of every public service. Bookmark it. Open the Internet tab, type 1.1.1.1 in the address bar, press Go.\n\n" ..
                "- Employers")
        end
    elseif level == 2 then
        local isp = MH.State.GetSpecialNPC("ISP")
        local puzzle1 = MH.State.GetPuzzleNPC(1)
        if isp then MH.State.MarkDiscovered(sid, tonumber(isp.id)) end
        if puzzle1 then MH.State.MarkDiscovered(sid, tonumber(puzzle1.id)) end
        local parts = { "Hacking 101 is done. Two more public services worth knowing about.\n" }
        if isp then
            parts[#parts + 1] = "ISP\n" ..
                "IP: " .. isp.ip .. "\n" ..
                "If your IP gets burned by the FBI, hit the ISP and run Reset IP. First reset is free, after that it scales with how many times you have done it. Same page runs Password Reset for an account you lost control of.\n"
        end
        if puzzle1 then
            parts[#parts + 1] = "Puzzle 1\n" ..
                "IP: " .. puzzle1.ip .. "\n" ..
                "A one-shot chain of puzzles. Each solve awards reputation and reveals the IP of the next puzzle in the chain. Start here.\n"
        end
        parts[#parts + 1] = "\n- Employers"
        MH.State.SendSystemMailOnce(sid, "Employers", "ISP and the puzzle box", table.concat(parts, "\n"))
    elseif level == 4 then
        MH.State.SendSystemMailOnce(sid, "Employers", "Permission to make noise",
            "DDoS Security cert cleared. You can now plant DDoS viruses on servers you own and chain them against a target. Three or more active DDoS viruses on your rig unlocks a DDoS run from the Hacked Database.\n\n" ..
            "Reserve DDoS for targets you cannot crack with a straight bruteforce. It is loud and expensive.\n\n" ..
            "- Employers")
    end
end

function MH.State.CheckEmployersFirstJob(sid)
    local p = MH.State.GetPlayer(sid)
    if not p then return end
    if (tonumber(p.cert_level or 0) or 0) < 1 then return end
    local subject = "Your first job"
    if MH.State.HasReceivedSystemMail(sid, "Employers", subject) then return end
    local target = MH.DB.QueryRow(
        "SELECT id, ip, name FROM mh_servers WHERE is_npc = 1 " ..
        "AND LOWER(name) NOT LIKE '%bank%' " ..
        "AND " .. MH.State.MissionTargetExcludeSQL() .. " " ..
        "ORDER BY RANDOM() LIMIT 1")
    if not target then return end
    local briefing =
        "Your very first contract. The target is " .. target.ip .. " (" .. target.name .. ").\n\n" ..
        "Steps:\n" ..
        "1. Open the Internet tab, type " .. target.ip .. " into the address bar, press Go.\n" ..
        "2. Press Bruteforce. A hack process starts. Watch it count down in Task Manager.\n" ..
        "3. When it completes, the password lands in your Hacked Database. Come back to Internet and press Login with that password.\n" ..
        "4. On the remote machine, open the Softwares panel and delete any file.\n" ..
        "5. Come back here and press Complete to collect the prize."
    local hirerId = tonumber(MH.DB.QueryValue("SELECT id FROM mh_servers WHERE name = 'Employers' LIMIT 1")) or 0
    MH.DB.Query("INSERT INTO mh_missions (assigned_sid, mtype, target_server, prize, status, created, briefing, hirer_server) VALUES (" ..
        MH.DB.Esc(sid) .. ", 1, " .. tonumber(target.id) .. ", 500, 0, " .. os.time() ..
        ", " .. MH.DB.Esc(briefing) .. ", " .. hirerId .. ")")
    MH.State.SendSystemMailOnce(sid, "Employers", subject,
        "Congratulations on your first certification. We have a job lined up for you already.\n\n" ..
        "Target: " .. target.name .. "\n" ..
        "IP: " .. target.ip .. "\n\n" ..
        "Open your Missions tab, accept the contract, and read the briefing. It walks you through the full flow from scan to delete.\n\n" ..
        "- The Employers")
end

function MH.State.CheckEmployersRecruit(sid)
    local p = MH.State.GetPlayer(sid)
    if not p then return end
    local certs = tonumber(p.cert_level or 0) or 0
    if certs < 3 then return end
    local hq = MH.State.GetSpecialNPC("EMPLOYERS")
    local hqRef = hq and (" You can find us at " .. tostring(hq.ip) .. " when you are ready.") or ""
    MH.State.SendSystemMailOnce(sid, "Employers",
        "A quiet offer",
        "Your work has reached a desk it probably should not have. We have a job that needs doing and a reason not to put it on the record. If you are interested, keep hacking the way you have been. The right target will find its way onto your list." .. hqRef ..
        "\n\n- The Employers")
    if certs >= 5 then
        local msa = MH.State.GetSpecialNPC("MSA")
        local msaRef = msa and (" Target IP: " .. tostring(msa.ip) .. ". Do not get caught.") or ""
        MH.State.SendSystemMailOnce(sid, "Employers",
            "Contract: Doom",
            "You have proven you can handle yourself. There is a payload on an MSA server that we need pulled, intact. Call it Doom. We suspect you already know what it does." .. msaRef ..
            "\n\n- The Employers")
    end
end

function MH.State.CheckSocialFirstMail(sid)
    local sent = tonumber(MH.DB.QueryValue(
        "SELECT COUNT(*) FROM mh_mail WHERE from_sid = " .. MH.DB.Esc(sid))) or 0
    if sent < 1 then return end
    MH.State.SendSystemMailOnce(sid, "Social",
        "Your network just grew",
        "Nice. Sending your first message means someone out there knows your handle now. Keep making friends. Keep making enemies. Both are useful.\n\n- Social")
end

local BADGES = {
    first_hack        = { subject = "Badge unlocked: First Hack",      body = "You cracked your first target. The rest get easier. Or harder. Depends on the target." },
    first_mission     = { subject = "Badge unlocked: Mission Runner",  body = "You finalized your first contract. Reputation and rent, in that order." },
    first_virus       = { subject = "Badge unlocked: Infected",        body = "First virus planted. Collect regularly or someone else will clean it up." },
    first_btc         = { subject = "Badge unlocked: Satoshi Jr",      body = "First Bitcoin credited to your wallet. The rate is whatever you say it is." },
    first_bank_steal  = { subject = "Badge unlocked: Siphon",          body = "First time draining a captured bank account. Expect regulators to notice." },
}

function MH.State.AwardBadge(sid, key)
    local b = BADGES[key]
    if not b then return end
    MH.State.SendSystemMailOnce(sid, "BadgeAdvisor", b.subject, b.body)
end

local MISSION_EVENT_MATCH = {
    soft_delete = 1,
    soft_download = 2,
    bank_credential = 3,
    bank_transfer = 4,
    server_wiped = 5,
}

function MH.State.CheckMissionProgress(sid, event, ctx)
    ctx = ctx or {}
    local wantType = MISSION_EVENT_MATCH[event]
    if not wantType then return end
    local targetId = tonumber(ctx.target_server or 0) or 0
    local rows = MH.DB.Query(
        "SELECT * FROM mh_missions WHERE assigned_sid = " .. MH.DB.Esc(sid) ..
        " AND status = 1 AND mtype = " .. wantType ..
        (targetId > 0 and (" AND target_server = " .. targetId) or "")) or {}
    for _, m in ipairs(rows) do
        local required = tostring(m.info_str or "")
        local ok = true
        if (wantType == 1 or wantType == 2) and required ~= "" then
            ok = tostring(ctx.soft_name or "") == required
        end
        if ok then
            MH.DB.Query("UPDATE mh_missions SET status = 2 WHERE id = " .. tonumber(m.id))
        end
    end
end

function MH.State.AddNotification(sid, kind, text)
    MH.DB.Query("INSERT INTO mh_notifications (owner_sid, kind, text, stamp, seen) VALUES (" ..
        MH.DB.Esc(sid) .. ", " .. MH.DB.Esc(kind) .. ", " .. MH.DB.Esc(text) ..
        ", " .. now() .. ", 0)")
end

function MH.State.AttackerIP(sid)
    local srv = MH.State.GetServersFor(sid)[1]
    return srv and tostring(srv.ip or "unknown") or "unknown"
end

function MH.State.AttackerServer(sid)
    return MH.State.GetServersFor(sid)[1]
end

function MH.State.AddNews(text)
    MH.DB.Query("INSERT INTO mh_news (text, stamp) VALUES (" ..
        MH.DB.Esc(text) .. ", " .. now() .. ")")
    local count = tonumber(MH.DB.QueryValue("SELECT COUNT(*) FROM mh_news")) or 0
    if count > 50 then
        MH.DB.Query("DELETE FROM mh_news WHERE id IN (SELECT id FROM mh_news ORDER BY stamp ASC LIMIT " .. (count - 50) .. ")")
    end
end

function MH.State.MarkDiscovered(sid, serverId)
    serverId = tonumber(serverId or 0) or 0
    if serverId <= 0 then return end
    MH.DB.Query("INSERT OR REPLACE INTO mh_discovered (owner_sid, server_id, stamp) VALUES (" ..
        MH.DB.Esc(sid) .. ", " .. serverId .. ", " .. now() .. ")")
end

function MH.State.EnsureWelcomeMail(sid, nick)
    local existing = MH.DB.QueryValue(
        "SELECT id FROM mh_mail WHERE to_sid = " .. MH.DB.Esc(sid) ..
        " AND from_sid = 'RakTheGoose' AND subject = " .. MH.DB.Esc(WELCOME_SUBJECT) .. " LIMIT 1")
    if existing then return end
    MH.DB.Query("INSERT INTO mh_mail (to_sid, from_sid, subject, body, stamp, seen) VALUES (" ..
        MH.DB.Esc(sid) .. ", 'RakTheGoose', " .. MH.DB.Esc(WELCOME_SUBJECT) .. ", " ..
        MH.DB.Esc(build_welcome_body(nick)) .. ", " .. now() .. ", 0)")
    MH.DB.Query("UPDATE mh_players SET bitcoin = bitcoin + " .. WELCOME_BTC_GIFT ..
        " WHERE sid64 = " .. MH.DB.Esc(sid))
    MH.Log.info("state", "welcome_mail", "Sent welcome to " .. sid)
end

local function gen_btc_address()
    local chars = "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHJKLMNPQRSTUVWXYZ"
    local out = { "1" }
    for _ = 1, 33 do
        local idx = math.random(1, #chars)
        out[#out + 1] = chars:sub(idx, idx)
    end
    return table.concat(out)
end

function MH.State.EnsurePlayer(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local sid = ply:SteamID64()
    local nick = ply:Nick()
    local row = MH.DB.QueryRow("SELECT sid64, btc_address, cash FROM mh_players WHERE sid64 = " .. MH.DB.Esc(sid))
    if row then
        MH.DB.Query("UPDATE mh_players SET nick = " .. MH.DB.Esc(nick) ..
            ", last_login = " .. now() .. " WHERE sid64 = " .. MH.DB.Esc(sid))
        if not row.btc_address or row.btc_address == "" then
            MH.DB.Query("UPDATE mh_players SET btc_address = " .. MH.DB.Esc(gen_btc_address()) ..
                " WHERE sid64 = " .. MH.DB.Esc(sid))
        end
        local legacyCash = tonumber(row.cash or 0) or 0
        if legacyCash > 0 then
            local acc = MH.State.EnsureDefaultBankAccount(sid)
            if acc then
                MH.DB.Query("UPDATE mh_banks SET cash = cash + " .. legacyCash ..
                    " WHERE id = " .. tonumber(acc.id))
                MH.DB.Query("UPDATE mh_players SET cash = 0 WHERE sid64 = " .. MH.DB.Esc(sid))
            end
        else
            MH.State.EnsureDefaultBankAccount(sid)
        end
        MH.State.EnsureWelcomeMail(sid, nick)
        return
    end
    MH.DB.Query("INSERT INTO mh_players (sid64, nick, cash, joined, last_login, btc_address) VALUES (" ..
        MH.DB.Esc(sid) .. ", " .. MH.DB.Esc(nick) .. ", 0" ..
        ", " .. now() .. ", " .. now() .. ", " .. MH.DB.Esc(gen_btc_address()) .. ")")
    local acc = MH.State.EnsureDefaultBankAccount(sid)
    if acc then
        MH.DB.Query("UPDATE mh_banks SET cash = cash + " .. tonumber(MH.Data.StartingCash or 0) ..
            " WHERE id = " .. tonumber(acc.id))
    end
    MH.Log.info("state", "newplayer", nick .. " seeded")
    MH.State.EnsureWelcomeMail(sid, nick)
end

function MH.State.DefaultBankServerId()
    return tonumber(MH.DB.QueryValue(
        "SELECT id FROM mh_servers WHERE name = 'First International Bank' AND is_npc = 1 LIMIT 1")) or 0
end

function MH.State.EnsureDefaultBankAccount(sid)
    local bankId = MH.State.DefaultBankServerId()
    if bankId <= 0 then return nil end
    local existing = MH.DB.QueryRow(
        "SELECT * FROM mh_banks WHERE bank_npc = " .. bankId ..
        " AND owner_sid = " .. MH.DB.Esc(sid) .. " ORDER BY id ASC LIMIT 1")
    if existing then return existing end
    local acc = tostring(math.random(111111111, 999999999))
    local pass = gen_pass(6)
    MH.DB.Query("INSERT INTO mh_banks (bank_npc, acc_num, acc_pass, owner_sid, cash, created) VALUES (" ..
        bankId .. ", " .. MH.DB.Esc(acc) .. ", " .. MH.DB.Esc(pass) ..
        ", " .. MH.DB.Esc(sid) .. ", 0, " .. now() .. ")")
    return MH.DB.QueryRow(
        "SELECT * FROM mh_banks WHERE bank_npc = " .. bankId ..
        " AND owner_sid = " .. MH.DB.Esc(sid) .. " ORDER BY id ASC LIMIT 1")
end

function MH.State.PrimaryAccount(sid)
    return MH.State.EnsureDefaultBankAccount(sid)
end

function MH.State.GetBalance(sid)
    local acc = MH.State.PrimaryAccount(sid)
    return acc and (tonumber(acc.cash) or 0) or 0
end

function MH.State.GetPlayer(sid)
    local row = MH.DB.QueryRow("SELECT * FROM mh_players WHERE sid64 = " .. MH.DB.Esc(sid))
    if row then
        row.cash = MH.State.GetBalance(sid)
    end
    return row
end

function MH.State.AddCash(sid, amount, source, serverId)
    local amt = tonumber(amount or 0) or 0
    if amt == 0 then return end
    local acc = MH.State.EnsureDefaultBankAccount(sid)
    if not acc then return end
    MH.DB.Query("UPDATE mh_banks SET cash = cash + " .. amt ..
        " WHERE id = " .. tonumber(acc.id))
    if amt > 0 then
        local logSrv = tonumber(serverId or 0) or 0
        if logSrv <= 0 then
            local primary = MH.State.GetServersFor(sid)[1]
            if primary then logSrv = tonumber(primary.id) or 0 end
        end
        if logSrv > 0 then
            MH.State.AppendLog(logSrv,
                "Received $" .. amt .. " from " .. tostring(source or "income") ..
                " into account " .. tostring(acc.acc_num))
        end
    end
end

function MH.State.SpendCash(sid, amount, item, serverId)
    local amt = math.floor(tonumber(amount) or 0)
    if amt <= 0 then return true end
    local acc = MH.State.EnsureDefaultBankAccount(sid)
    if not acc then return false end
    local bal = tonumber(acc.cash) or 0
    if bal < amt then return false end
    MH.DB.Query("UPDATE mh_banks SET cash = cash - " .. amt ..
        " WHERE id = " .. tonumber(acc.id))
    local logSrv = tonumber(serverId or 0) or 0
    if logSrv <= 0 then
        local primary = MH.State.GetServersFor(sid)[1]
        if primary then logSrv = tonumber(primary.id) or 0 end
    end
    if logSrv > 0 then
        MH.State.AppendLog(logSrv,
            "Spent $" .. amt .. " on " .. tostring(item or "service") ..
            " from account " .. tostring(acc.acc_num))
    end
    return true
end

function MH.State.MigrateCashToDefaultBank()
    local bankId = MH.State.DefaultBankServerId()
    if bankId <= 0 then return 0 end
    local rows = MH.DB.Query("SELECT sid64, cash FROM mh_players WHERE cash > 0") or {}
    local moved = 0
    for _, r in ipairs(rows) do
        local sid = tostring(r.sid64 or "")
        local amt = tonumber(r.cash or 0) or 0
        if sid ~= "" and amt > 0 then
            local acc = MH.State.EnsureDefaultBankAccount(sid)
            if acc then
                MH.DB.Query("UPDATE mh_banks SET cash = cash + " .. amt ..
                    " WHERE id = " .. tonumber(acc.id))
                MH.DB.Query("UPDATE mh_players SET cash = 0 WHERE sid64 = " .. MH.DB.Esc(sid))
                moved = moved + 1
            end
        end
    end
    return moved
end

local MAX_LOG_LINES = 150
function MH.State.AppendLog(serverId, line)
    if MH.State.IsLogDisabled(serverId) then return end
    local nowT = now()
    local stamp = os.date("[%Y-%m-%d %H:%M:%S]", nowT)
    local newEntry = stamp .. " " .. tostring(line)
    local existing = MH.DB.QueryRow("SELECT content FROM mh_server_log WHERE server_id = " .. tonumber(serverId))
    local merged
    if existing then
        merged = newEntry .. "\n" .. tostring(existing.content or "")
    else
        merged = newEntry
    end
    local lines = string.Explode("\n", merged)
    if #lines > MAX_LOG_LINES then
        local kept = {}
        for i = 1, MAX_LOG_LINES do kept[i] = lines[i] end
        merged = table.concat(kept, "\n")
    end
    MH.DB.Query("INSERT OR REPLACE INTO mh_server_log (server_id, content, last_mod) VALUES (" ..
        tonumber(serverId) .. ", " .. MH.DB.Esc(merged) .. ", " .. nowT .. ")")
end

local LOG_DISABLED_STUB = "This server does not keep logs.\nAll activity is anonymised at the gateway.\nEnjoy your downloads."

function MH.State.ReadLog(serverId)
    if MH.State.IsLogDisabled(serverId) then return LOG_DISABLED_STUB end
    local r = MH.DB.QueryRow("SELECT content FROM mh_server_log WHERE server_id = " .. tonumber(serverId))
    return r and tostring(r.content or "") or ""
end

function MH.State.ReplaceLog(serverId, newContent)
    MH.DB.Query("INSERT OR REPLACE INTO mh_server_log (server_id, content, last_mod) VALUES (" ..
        tonumber(serverId) .. ", " .. MH.DB.Esc(newContent) .. ", " .. now() .. ")")
end

function MH.State.CreateServer(ownerSid, name, ip, entClass, pos)
    ip = ip or gen_ip()
    name = name or ("Server#" .. math.random(100, 999))
    local pass = gen_pass(10)
    local px, py, pz = 0, 0, 0
    if pos then px, py, pz = pos.x, pos.y, pos.z end
    MH.DB.Query("INSERT INTO mh_servers (owner_sid, name, ip, root_pass, ent_class, pos_x, pos_y, pos_z) VALUES (" ..
        MH.DB.Esc(ownerSid) .. ", " .. MH.DB.Esc(name) .. ", " .. MH.DB.Esc(ip) ..
        ", " .. MH.DB.Esc(pass) .. ", " .. MH.DB.Esc(entClass or "metahacker_server") ..
        ", " .. px .. ", " .. py .. ", " .. pz .. ")")
    local id = tonumber(MH.DB.QueryValue("SELECT last_insert_rowid()"))
    MH.State.AppendLog(id, "Localhost logged in")
    return id, ip, pass
end

local NPC_NAMES = {
    "Treas", "DarkMail", "CryptoEx",
    "Yahu", "Chitter", "Rockstarr", "GovDB", "Milit",
    "PornoCo", "Rblix", "Pyoneer",
    "Starbux", "ColaCo", "RouterTech", "FairyFlix",
    "ChipTech", "ViralVid", "SambaMobil", "BigPixelTV",
    "KickShoe", "GreenPlow", "FailSys", "InsaneGames", "iStore",
}

local SPECIAL_NPCS = {
    { key = "DIRECTORY",  name = "First Whois",    cpu_tier = 7,  ram_tier = 4, hdd_tier = 6, net_tier = 5, fixed_ip = "1.1.1.1", hasher_v = 20,  firewall_v = 20 },
    { key = "WHOIS2",     name = "Second Whois",   cpu_tier = 8,  ram_tier = 4, hdd_tier = 6, net_tier = 5, hasher_v = 50,  firewall_v = 36 },
    { key = "WHOIS3",     name = "Third Whois",    cpu_tier = 8,  ram_tier = 4, hdd_tier = 6, net_tier = 6, hasher_v = 75,  firewall_v = 50 },
    { key = "WHOIS4",     name = "Fourth Whois",   cpu_tier = 9,  ram_tier = 4, hdd_tier = 6, net_tier = 6, hasher_v = 100, firewall_v = 70 },
    { key = "EMPLOYERS",  name = "Employers",      cpu_tier = 5,  ram_tier = 3, hdd_tier = 6, net_tier = 4, hasher_v = 20, firewall_v = 17 },
    { key = "MSA",        name = "MSA",            cpu_tier = 12, ram_tier = 5, hdd_tier = 7, net_tier = 10, hasher_v = 200 },
    { key = "DC",         name = "Download Center",cpu_tier = 8,  ram_tier = 4, hdd_tier = 7, net_tier = 7, hasher_v = 10,  firewall_v = 10 },
    { key = "ISP",        name = "ISP",            cpu_tier = 4,  ram_tier = 3, hdd_tier = 6, net_tier = 8, hasher_v = 20,  firewall_v = 20 },
    { key = "BITCOIN",    name = "Bitcoin Market", cpu_tier = 12, ram_tier = 5, hdd_tier = 7, net_tier = 10,hasher_v = 50,  firewall_v = 50 },
    { key = "SOURCENET",    name = "Sourcenet",        cpu_tier = 8,  ram_tier = 3, hdd_tier = 7, net_tier = 4, hasher_v = 50,  firewall_v = 35 },
    { key = "BANK1",      name = "First International Bank", cpu_tier = 4,  ram_tier = 4, hdd_tier = 6, net_tier = 4, hasher_v = 15,  firewall_v = 15 },
    { key = "BANK2",      name = "HEBC Bank",                cpu_tier = 5,  ram_tier = 3, hdd_tier = 6, net_tier = 5, hasher_v = 25,  firewall_v = 25 },
    { key = "BANK3",      name = "American Express Bank",    cpu_tier = 6,  ram_tier = 4, hdd_tier = 7, net_tier = 5, hasher_v = 40,  firewall_v = 40 },
    { key = "BANK4",      name = "Swiss International Bank", cpu_tier = 8,  ram_tier = 4, hdd_tier = 6, net_tier = 5, hasher_v = 60,  firewall_v = 60 },
    { key = "BANK5",      name = "Ultimate Bank",            cpu_tier = 10, ram_tier = 4, hdd_tier = 6, net_tier = 7, hasher_v = 80,  firewall_v = 80 },
    { key = "FBI",        name = "FBI",                      cpu_tier = 8,  ram_tier = 4, hdd_tier = 7, net_tier = 7, hasher_v = 100, firewall_v = 75  },
    { key = "MD",         name = "MD",                       cpu_tier = 8,  ram_tier = 4, hdd_tier = 7, net_tier = 7, hasher_v = 100, firewall_v = 100 },
    { key = "GOOSECORP",  name = "GooseCorp",                cpu_tier = 8,  ram_tier = 4, hdd_tier = 7, net_tier = 6, hasher_v = 100, firewall_v = 100 },
    { key = "TORRENT",    name = "Torrent",                  cpu_tier = 8,  ram_tier = 4, hdd_tier = 7, net_tier = 7, hasher_v = 25,  firewall_v = 25  },
}
local PUZZLE_SOFT_COLS = {
    { 2,  "hasher",     1 },
    { 4,  "firewall",   1 },
    { 1,  "cracker",    1 },
    { 13, "ftp_exp",    0 },
    { 14, "ssh_exp",    0 },
    { 5,  "hider",      0 },
    { 6,  "seeker",     0 },
    { 8,  "spam",       0 },
    { 11, "collector",  0 },
    { 9,  "warez",      0 },
    { 20, "miner",      0 },
    { 10, "ddos",       0 },
    { 12, "breaker",    0 },
    { 7,  "antivirus",  0 },
    { 17, "torrent",    0 },
    { 15, "nmap",       0 },
    { 3,  "portscan",   0 },
}
local PUZZLE_SOFTWARES = {
    { 10, 10, 11, 10,  0, 10,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0 },
    { 11, 10, 12,  0, 10,  0, 12,  0,  0, 10,  0,  0,  0,  0, 10,  0,  0 },
    { 12, 12, 13, 11, 10, 11, 10,  0,  0,  0,  0, 10, 10,  0,  0,  0,  0 },
    { 13, 12, 14,  0, 11, 14, 11,  0,  0,  0, 13,  0,  0,  0,  0,  0,  0 },
    { 14, 14, 15, 18,  0, 13, 10, 15, 15,  0,  0,  0,  0, 15,  0,  0,  0 },
    { 15, 14, 16, 10, 14, 15, 15,  0,  0,  0,  0,  0,  0, 12,  0,  0,  0 },
    { 16, 16, 17, 13, 12,  0,  0,  0,  0, 15, 16,  0,  0, 15,  0,  0,  0 },
    { 17, 16, 18, 10, 13, 17, 13, 14,  0,  0,  0, 15,  0,  0,  0,  0,  0 },
    { 18, 18, 19, 17, 13,  0, 20, 17, 20,  0,  0,  0,  0, 14,  0,  0,  0 },
    { 19, 18, 20, 20, 12, 15, 16, 14,  0,  0,  0,  0,  0,  0,  0,  0,  0 },
    { 21, 20, 22, 26, 19, 18,  0,  0,  0,  0,  0, 20,  0,  0,  0,  0,  0 },
    { 22, 20, 23,  0, 24, 25,  0,  0,  0,  0,  0,  0,  0, 25,  0,  0,  0 },
    { 23, 22, 24, 24, 22,  0, 30, 26,  0,  0,  0,  0,  0,  0,  0,  0,  0 },
    { 24, 22, 25, 22, 17, 19, 26,  0,  0, 25,  0,  0,  0,  0,  0,  0,  0 },
    { 25, 24, 27, 23,  0, 10, 15,  0, 25,  0, 30,  0,  0,  0,  0,  0,  0 },
    { 27, 24, 29, 18, 24, 33, 28, 30,  0,  0,  0,  0,  0, 30,  0,  0,  0 },
    { 29, 26, 30, 16, 20, 29, 36,  0,  0, 33,  0,  0,  0,  0,  0,  0,  0 },
    { 30, 26, 32, 30, 30, 37,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0 },
    { 32, 28, 34, 28, 24, 30, 28, 35,  0,  0,  0,  0,  0, 34,  0,  0,  0 },
    { 34, 28, 36, 23, 19, 33, 27,  0,  0,  0,  0, 30, 30,  0,  0,  0,  0 },
    { 36, 30, 38, 22, 21, 40, 40,  0,  0,  0,  0,  0,  0, 40,  0,  0,  0 },
    { 38, 30, 40, 30, 30, 37, 35, 40, 40,  0,  0,  0,  0,  0,  0,  0,  0 },
    { 40, 32, 42, 29, 22, 28, 33,  0,  0, 40,  0,  0,  0,  0,  0,  0,  0 },
    { 42, 32, 44, 36, 24, 37, 34,  0,  0,  0, 40,  0,  0,  0,  0,  0,  0 },
    { 44, 34, 46, 34, 30, 40, 37, 45,  0,  0,  0,  0,  0,  0,  0,  0,  0 },
    { 46, 34, 48, 36, 20, 46, 40,  0,  0,  0,  0,  0,  0, 50,  0,  0,  0 },
    { 48, 36, 50, 30, 30, 44, 40,  0, 50,  0,  0,  0,  0,  0,  0,  0,  0 },
    { 53, 39, 56, 36, 42,  0,  0,  0,  0,  0,  0, 50, 50,  0,  0,  0,  0 },
    { 56, 39, 59, 42, 33, 60,  0,  0,  0,  0, 60,  0,  0, 70,  0,  0,  0 },
    { 59, 42, 62, 42, 45,  0, 60, 70, 70,  0,  0,  0,  0,  0,  0,  0,  0 },
    { 62, 42, 64, 50, 45, 59, 56,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0 },
    { 64, 45, 68, 47, 45, 70,  0,  0,  0,  0,  0, 75, 75,  0,  0,  0,  0 },
    { 68, 45, 71, 42, 50,  0, 70,  0,  0,  0,  0,  0,  0, 80,  0,  0,  0 },
    { 71, 48, 75, 39, 42, 68, 70,  0,  0,  0, 90,  0,  0,  0,  0,  0,  0 },
    { 80, 55, 85, 46, 50, 74, 72,100,100,  0,  0,  0,  0,  0,  0,  0,  0 },
    { 85, 55, 90, 47, 70,100, 75,  0,  0,  0,  0,  0,  0,100,  0,  0,  0 },
    { 90, 60, 95, 49, 66, 92,100,  0,  0,  0,  0,100,  0,  0,  0,  0,  0 },
    { 95, 60,100, 80, 59, 68, 96,  0,  0,  0,  0, 73,100,  0,  0,  0,  0 },
    {110, 80,120, 76, 69,110, 97,  0,  0,  0,  0,  0,  0,120,  0,  0,  0 },
    {120, 90,130,  0,  0,104,110,120,120,  0,  0,  0,  0,  0,  0,  0,  0 },
    {130, 90,140, 90, 90, 98,102,  0,  0,140,  0,  0,  0,  0,  0,  0,  0 },
    {140,100,150, 87, 62,150,104,  0,  0,  0,  0,  0,  0,140,  0,  0,  0 },
    {150,110,160, 88, 82,134,150,  0,  0,  0,150,  0,  0,  0,  0,  0,  0 },
    {160,120,170,130,130,149,132,  0,  0,  0,  0,  0,150,  0,  0,  0,  0 },
    {170,130,180,127,114,149,142,150,150,  0,  0,  0,  0,  0,  0,  0,  0 },
    {180,140,190,107,124,142,134,  0,  0,150,  0,  0,  0,150,  0,  0,  0 },
    {190,150,200,127, 95,143,128,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0 },
}
local function puzzle_row(idx) return PUZZLE_SOFTWARES[tonumber(idx or 0) or 0] end
local function puzzle_hasher_v(idx)
    local r = puzzle_row(idx)
    return r and r[1] or 10
end
local function puzzle_firewall_v(idx)
    local r = puzzle_row(idx)
    return r and r[2] or 10
end
local function puzzle_npc_name(idx) return "Puzzle " .. tostring(idx) end

MH.State.IP_RESET_COOLDOWN = 600

function MH.State.IPResetPrice(sid)
    local p = MH.State.GetPlayer(sid)
    if not p then return 0 end
    local resets = tonumber(p.ip_resets or 0) or 0
    if resets <= 0 then return 0 end
    return math.min(100000, resets * 15000)
end

function MH.State.IPResetReady(sid)
    local p = MH.State.GetPlayer(sid)
    if not p then return false, 0 end
    local last = tonumber(p.last_ip_reset or 0) or 0
    if last <= 0 then return true, 0 end
    local wait = (last + MH.State.IP_RESET_COOLDOWN) - now()
    if wait <= 0 then return true, 0 end
    return false, wait
end

MH.State.PWD_RESET_COOLDOWN = 300
function MH.State.PwdResetPrice(sid)
    local p = MH.State.GetPlayer(sid)
    if not p then return 0 end
    local resets = tonumber(p.pwd_resets or 0) or 0
    if resets <= 0 then return 0 end
    return math.min(25000, resets * 5000)
end
function MH.State.PwdResetReady(sid)
    local p = MH.State.GetPlayer(sid)
    if not p then return false, 0 end
    local last = tonumber(p.last_pwd_reset or 0) or 0
    if last <= 0 then return true, 0 end
    local wait = (last + MH.State.PWD_RESET_COOLDOWN) - now()
    if wait <= 0 then return true, 0 end
    return false, wait
end

function MH.State.MissionTargetExcludeSQL()
    local names = {}
    for _, s in ipairs(SPECIAL_NPCS) do names[#names + 1] = s.name end
    for i = 1, #(MH.Data.Puzzles or {}) do names[#names + 1] = puzzle_npc_name(i) end
    local escaped = {}
    for _, n in ipairs(names) do escaped[#escaped + 1] = MH.DB.Esc(n) end
    return "name NOT IN (" .. table.concat(escaped, ",") .. ")"
end

local NPC_EXTRA_STOCK = {
    ["Bitcoin Market"] = {
        { 20, 100, "miner",       70, 20, 0 },
    },
    ["Torrent"] = {
        { 17,  10, "torrent_v1",  40, 15, 0 },
        { 17,  20, "torrent_v2",  70, 20, 0 },
        { 17,  30, "torrent_v3", 100, 25, 0 },
    },
    ["First Whois"] = {
        { 26,  10, "riddle",      20, 64, 0 },
        {  1,  21, "cracker",     28,  9, 1 },
        {  5,  20, "hider",       18,  7, 0 },
        {  6,  19, "seeker",      18,  7, 0 },
        {  7,  20, "antivirus",   20,  8, 0 },
        {  8,  20, "spam",        14,  6, 0 },
        {  9,  20, "warez",       14,  6, 0 },
        { 20,  20, "miner",       20,  8, 0 },
        { 13,  18, "ftp_exp",     22, 10, 0 },
        { 14,  20, "ssh_exp",     24, 11, 0 },
        { 16,  10, "analyzer",    10,  6, 0 },
        { 17,  20, "torrent",     20, 10, 0 },
    },
    ["Second Whois"] = {
        { 26,  10, "riddle",      20, 64, 0 },
        {  1,  53, "cracker",     70, 15, 1 },
        {  5,  50, "hider",       50, 12, 0 },
        {  6,  50, "seeker",      50, 12, 0 },
        { 15,  10, "nmap",        10,  7, 0 },
        {  8,  50, "spam",        50, 10, 0 },
        {  9,  50, "warez",       50, 10, 0 },
        { 20,  50, "miner",       50, 12, 0 },
        { 13,  20, "ftp_exp",     22, 10, 0 },
        { 14,  45, "ssh_exp",     60, 15, 0 },
        { 16,  20, "analyzer",    20,  8, 0 },
        { 17,  30, "torrent",     30, 12, 0 },
    },
    ["Third Whois"] = {
        { 26,  10, "riddle",      20, 64, 0 },
        {  1,  80, "cracker",    110, 20, 1 },
        {  5,  75, "hider",      100, 16, 0 },
        {  6,  75, "seeker",     100, 16, 0 },
        { 13,  50, "ftp_exp",     70, 18, 0 },
        { 14,  50, "ssh_exp",     70, 18, 0 },
        { 16,  30, "analyzer",    30, 10, 0 },
    },
    ["Fourth Whois"] = {
        { 26,  10, "riddle",      20, 64, 0 },
        {  1, 110, "cracker",    150, 25, 1 },
        {  5, 100, "hider",      130, 20, 0 },
        {  6, 100, "seeker",     130, 20, 0 },
        {  9, 100, "warez",      130, 20, 0 },
        { 20, 100, "miner",      130, 20, 0 },
        { 13,  70, "ftp_exp",     95, 22, 0 },
        { 14,  75, "ssh_exp",    100, 23, 0 },
    },
    ["Download Center"] = {
        {  1, 10, "cracker",     28,  9, 1 },
        {  4, 10, "firewall",    24, 10, 1 },
        {  3, 10, "portscan",    22,  8, 0 },
        {  5, 10, "hider",       18,  7, 0 },
        {  6, 10, "seeker",      18,  7, 0 },
        {  8, 10, "spam",        14,  6, 0 },
        { 11, 10, "collector",   20,  9, 0 },
        { 13, 10, "ftp_exploit", 26, 12, 0 },
        { 14, 10, "ssh_exploit", 26, 12, 0 },
    },
}

local HIRER_LOADOUTS = {
    { { 2, 14 }, { 1, 17 }, { 13, 15 }, { 4, 13 }, { 14, 11 }, { 20, 15 } },
    { { 2, 11 }, { 1, 13 }, { 4, 12 }, { 5, 14 }, { 6, 12 }, { 8, 12 }, { 13, 11 } },
    { { 2, 12 }, { 1, 11 }, { 4, 10 }, { 8, 20 }, { 13, 12 }, { 14, 13 }, { 3, 10 }, { 9, 10 } },
    { { 2, 13 }, { 1, 14 }, { 4, 17 }, { 8, 12 }, { 13, 12 }, { 3, 10 }, { 9, 13 }, { 6, 12 }, { 5, 11 } },
    { { 2, 17 }, { 1, 13 }, { 4, 14 }, { 20, 20 }, { 5, 16 }, { 8, 15 } },
    { { 2, 16 }, { 1, 22 }, { 4, 19 }, { 8, 14 }, { 14, 14 }, { 3, 10 }, { 5, 18 } },
    { { 2, 22 }, { 1, 20 }, { 4, 10 }, { 14, 17 }, { 13, 16 }, { 3, 10 } },
    { { 2, 25 }, { 1, 23 }, { 4, 20 }, { 9, 15 }, { 13, 16 }, { 7, 13 } },
    { { 2, 28 }, { 1, 27 }, { 4, 24 } },
    { { 2, 20 }, { 1, 27 }, { 4, 17 } },
    { { 2, 17 }, { 1, 19 }, { 4, 17 }, { 8, 11 } },
    { { 2, 17 }, { 1, 18 }, { 4, 25 }, { 8, 15 }, { 5, 22 }, { 7, 23 } },
    { { 2, 27 }, { 1, 25 }, { 4, 22 }, { 9, 20 }, { 13, 25 } },
    { { 2, 19 }, { 1, 26 }, { 4, 20 } },
    { { 2, 19 }, { 1, 17 }, { 4, 17 }, { 8, 20 }, { 13, 25 }, { 3, 10 } },
    { { 2, 33 }, { 1, 35 }, { 4, 28 }, { 8, 22 }, { 5, 12 } },
    { { 2, 30 }, { 1, 40 }, { 4, 37 }, { 8, 24 }, { 13, 28 }, { 14, 33 }, { 6, 27 } },
    { { 2, 42 }, { 1, 59 }, { 4, 34 }, { 8, 39 }, { 13, 50 }, { 6, 36 } },
    { { 2, 54 }, { 1, 38 }, { 4, 40 }, { 8, 20 } },
    { { 2, 38 }, { 1, 44 }, { 4, 28 }, { 8, 19 }, { 13, 40 }, { 14, 33 } },
    { { 2, 52 }, { 1, 56 }, { 4, 36 }, { 8, 39 }, { 13, 30 }, { 3, 10 }, { 14, 46 }, { 6, 29 }, { 5, 36 } },
    { { 2, 56 }, { 1, 52 }, { 4, 30 } },
    { { 2, 36 }, { 1, 40 }, { 4, 59 }, { 9, 42 }, { 13, 63 } },
    { { 2, 13 }, { 1, 14 }, { 4, 17 }, { 8, 12 }, { 13, 12 }, { 3, 10 }, { 9, 13 }, { 6, 12 }, { 5, 11 } },
}
local SOFT_SHORT_NAMES = {
    [1] = "cracker", [2] = "hasher", [3] = "portscan", [4] = "firewall",
    [5] = "hider",   [6] = "seeker", [7] = "antivirus", [8] = "spam",
    [9] = "warez",  [13] = "ftp_exp", [14] = "ssh_exp", [20] = "miner",
}

local function expected_softwares_for(nm, hasher_v, firewall_v)
    local list = {}
    hasher_v = tonumber(hasher_v) or 10
    firewall_v = tonumber(firewall_v) or 0
    list[#list + 1] = { 2, hasher_v, "Hasher", 10, 32, 1 }
    if firewall_v > 0 then
        list[#list + 1] = { 4, firewall_v, "Firewall", 10, 32, 1 }
    end
    local puzzleIdx = string.match(nm, "^Puzzle (%d+)$")
    if puzzleIdx then
        list = {}
        list[#list + 1] = { 26, 10, "Riddle", 20, 64, 0 }
        local row = puzzle_row(tonumber(puzzleIdx))
        if row then
            for col, meta in ipairs(PUZZLE_SOFT_COLS) do
                local v = tonumber(row[col] or 0) or 0
                if v > 0 then
                    local size = math.max(10, math.floor(v * 1.5))
                    local ram = math.max(6, math.floor(v / 2))
                    list[#list + 1] = { meta[1], v, meta[2], size, ram, meta[3] }
                end
            end
        end
    end
    local extras = NPC_EXTRA_STOCK[nm]
    if extras then
        for _, s in ipairs(extras) do
            list[#list + 1] = { s[1], s[2], s[3], s[4], s[5], s[6] }
        end
    end
    for idx, hname in ipairs(NPC_NAMES) do
        if hname == nm then
            local loadout = HIRER_LOADOUTS[idx]
            if loadout then
                list = {}
                for _, s in ipairs(loadout) do
                    local t, v = s[1], s[2]
                    local inst = (t == 1 or t == 2 or t == 4) and 1 or 0
                    list[#list + 1] = {
                        t, v, SOFT_SHORT_NAMES[t] or "soft",
                        math.max(10, math.floor(v * 1.5)),
                        math.max(6, math.floor(v / 2)),
                        inst,
                    }
                end
            end
            break
        end
    end
    return list
end

local function apply_expected_softwares(srvId, nm, hasher_v, firewall_v, replaceAll)
    local expected = expected_softwares_for(nm, hasher_v, firewall_v)
    if replaceAll then
        MH.DB.Query("DELETE FROM mh_software WHERE server_id = " .. tonumber(srvId))
    end
    for _, s in ipairs(expected) do
        local t, v, name, size, ram, inst = s[1], s[2], s[3], s[4], s[5], s[6]
        local existing = tonumber(MH.DB.QueryValue(
            "SELECT id FROM mh_software WHERE server_id = " .. tonumber(srvId) ..
            " AND soft_type = " .. t ..
            (t == 17 and (" AND soft_name = " .. MH.DB.Esc(name)) or "") ..
            " LIMIT 1"))
        if not existing then
            MH.DB.Query("INSERT INTO mh_software (server_id, soft_type, soft_version, soft_name, soft_size, soft_ram, installed) VALUES (" ..
                tonumber(srvId) .. ", " .. t .. ", " .. v .. ", " .. MH.DB.Esc(name) ..
                ", " .. size .. ", " .. ram .. ", " .. inst .. ")")
        else
            MH.DB.Query("UPDATE mh_software SET soft_version = " .. v ..
                " WHERE id = " .. existing .. " AND soft_version < " .. v)
        end
    end
end

local function versions_for(name)
    for _, s in ipairs(SPECIAL_NPCS) do
        if s.name == name then return (s.hasher_v or 10), (s.firewall_v or 0) end
    end
    local pidx = string.match(tostring(name or ""), "^Puzzle (%d+)$")
    if pidx then
        local idx = tonumber(pidx)
        return puzzle_hasher_v(idx), puzzle_firewall_v(idx)
    end
    return 10, 0
end

local VIRUS_SOFT_TYPES = { [8] = true, [9] = true, [10] = true, [11] = true, [20] = true }
local VIRUS_SOFT_TYPES_SQL = "(8, 9, 10, 11, 20)"
local AV_SCAN_INTERVAL = 86400

function MH.State.RestoreNPCSoftware(onlyServerId)
    local filter = ""
    if onlyServerId then
        onlyServerId = tonumber(onlyServerId or 0) or 0
        if onlyServerId <= 0 then return 0 end
        filter = " AND id = " .. onlyServerId
    end
    local servers = MH.DB.Query("SELECT id, name FROM mh_servers WHERE is_npc = 1" .. filter) or {}
    local wiped = 0
    for _, srv in ipairs(servers) do
        local sid = tonumber(srv.id)
        local foreignCount = tonumber(MH.DB.QueryValue(
            "SELECT COUNT(*) FROM mh_software WHERE server_id = " .. sid ..
            " AND owner_sid IS NOT NULL AND owner_sid != ''" ..
            " AND soft_type NOT IN " .. VIRUS_SOFT_TYPES_SQL)) or 0
        if foreignCount > 0 then
            MH.DB.Query("DELETE FROM mh_software WHERE server_id = " .. sid ..
                " AND owner_sid IS NOT NULL AND owner_sid != ''" ..
                " AND soft_type NOT IN " .. VIRUS_SOFT_TYPES_SQL)
            wiped = wiped + foreignCount
        end
        local hv, fv = versions_for(srv.name)
        apply_expected_softwares(sid, srv.name, hv, fv, false)
    end
    return wiped
end

function MH.State.AntivirusNPCSweep()
    local nowT = os.time()
    local due = MH.DB.Query("SELECT id, name FROM mh_servers WHERE is_npc = 1 AND next_av_scan <= " .. nowT) or {}
    local totalWiped = 0
    for _, srv in ipairs(due) do
        local sid = tonumber(srv.id)
        local viruses = MH.DB.Query("SELECT id, owner_sid, soft_type, soft_name, soft_version FROM mh_software " ..
            "WHERE server_id = " .. sid ..
            " AND owner_sid IS NOT NULL AND owner_sid != ''" ..
            " AND soft_type IN " .. VIRUS_SOFT_TYPES_SQL) or {}
        if #viruses > 0 then
            local notified = {}
            for _, v in ipairs(viruses) do
                local owner = tostring(v.owner_sid or "")
                if owner ~= "" and not notified[owner] then
                    notified[owner] = true
                    local meta = MH.Data.Soft[tonumber(v.soft_type or 0)] or {}
                    local vname = tostring(v.soft_name or meta.name or "virus") ..
                        (tostring(meta.ext or ""))
                    MH.DB.Query("INSERT INTO mh_notifications (owner_sid, kind, text, stamp, seen) VALUES (" ..
                        MH.DB.Esc(owner) .. ", 'warn', " ..
                        MH.DB.Esc(tostring(srv.name) .. " cleaned your " .. vname .. " on their antivirus run") ..
                        ", " .. nowT .. ", 0)")
                end
            end
            MH.DB.Query("DELETE FROM mh_software WHERE server_id = " .. sid ..
                " AND owner_sid IS NOT NULL AND owner_sid != ''" ..
                " AND soft_type IN " .. VIRUS_SOFT_TYPES_SQL)
            totalWiped = totalWiped + #viruses
        end
        MH.DB.Query("UPDATE mh_servers SET next_av_scan = " .. (nowT + AV_SCAN_INTERVAL) ..
            " WHERE id = " .. sid)
    end
    return totalWiped, #due
end

timer.Create("mh_restore_npc_software", 900, 0, function()
    local n = MH.State.RestoreNPCSoftware()
    if (n or 0) > 0 then
        MH.Log.info("state", "restore_npc_soft", "Wiped " .. n .. " non-virus player files from NPC servers")
    end
end)

timer.Create("mh_antivirus_npc_sweep", 10800, 0, function()
    local wiped, scanned = MH.State.AntivirusNPCSweep()
    if (wiped or 0) > 0 then
        MH.Log.info("state", "av_sweep", "Antivirus swept " .. scanned ..
            " NPC(s), wiped " .. wiped .. " player viruses")
    end
end)

function MH.State.GetPuzzleNPC(idx)
    idx = tonumber(idx or 0) or 0
    if idx <= 0 then return nil end
    return MH.DB.QueryRow("SELECT * FROM mh_servers WHERE name = " .. MH.DB.Esc(puzzle_npc_name(idx)) ..
        " AND is_npc = 1 LIMIT 1")
end

function MH.State.IsPuzzleSolved(sid, pid)
    local row = MH.DB.QueryValue(
        "SELECT 1 FROM mh_puzzle_solves WHERE owner_sid = " .. MH.DB.Esc(sid) ..
        " AND puzzle_id = " .. tonumber(pid))
    return row ~= nil
end

function MH.State.RecordPuzzleSolve(sid, pid)
    MH.DB.Query("INSERT OR REPLACE INTO mh_puzzle_solves (owner_sid, puzzle_id, stamp) VALUES (" ..
        MH.DB.Esc(sid) .. ", " .. tonumber(pid) .. ", " .. now() .. ")")
end

MH.State.PUZZLE_COOLDOWN = 1800
function MH.State.PuzzleReady(sid)
    local p = MH.State.GetPlayer(sid)
    if not p then return false, 0 end
    local last = tonumber(p.last_puzzle or 0) or 0
    if last <= 0 then return true, 0 end
    local wait = (last + MH.State.PUZZLE_COOLDOWN) - now()
    if wait <= 0 then return true, 0 end
    return false, wait
end

local LOG_DISABLED_NAMES = {
    ["Download Center"] = true,
}

function MH.State.IsLogDisabled(serverId)
    local srv = MH.State.GetServerById(tonumber(serverId or 0))
    if not srv then return false end
    return LOG_DISABLED_NAMES[tostring(srv.name)] == true
end

function MH.State.IsBanned(sid)
    if not sid then return false end
    local row = MH.DB.QueryRow("SELECT reason FROM mh_bans WHERE sid64 = " .. MH.DB.Esc(tostring(sid)))
    if not row then return false end
    return true, tostring(row.reason or "")
end

function MH.State.BanSid(sid, reason, adminSid)
    if not sid or tostring(sid) == "" then return false end
    MH.DB.Query("INSERT OR REPLACE INTO mh_bans (sid64, reason, banned_by, stamp) VALUES (" ..
        MH.DB.Esc(tostring(sid)) .. ", " .. MH.DB.Esc(tostring(reason or "")) ..
        ", " .. MH.DB.Esc(tostring(adminSid or "")) .. ", " .. os.time() .. ")")
    return true
end

function MH.State.UnbanSid(sid)
    if not sid then return end
    MH.DB.Query("DELETE FROM mh_bans WHERE sid64 = " .. MH.DB.Esc(tostring(sid)))
end

function MH.State.ListBans()
    local rows = MH.DB.Query(
        "SELECT b.sid64, b.reason, b.banned_by, b.stamp, p.nick " ..
        "FROM mh_bans b LEFT JOIN mh_players p ON p.sid64 = b.sid64 " ..
        "ORDER BY b.stamp DESC") or {}
    return rows
end

function MH.State.IsMailBanned(sid)
    if not sid then return false end
    local row = MH.DB.QueryRow("SELECT reason FROM mh_mail_bans WHERE sid64 = " .. MH.DB.Esc(tostring(sid)))
    if not row then return false end
    return true, tostring(row.reason or "")
end

function MH.State.MailBanSid(sid, reason, adminSid)
    if not sid or tostring(sid) == "" then return false end
    MH.DB.Query("INSERT OR REPLACE INTO mh_mail_bans (sid64, reason, banned_by, stamp) VALUES (" ..
        MH.DB.Esc(tostring(sid)) .. ", " .. MH.DB.Esc(tostring(reason or "")) ..
        ", " .. MH.DB.Esc(tostring(adminSid or "")) .. ", " .. os.time() .. ")")
    return true
end

function MH.State.MailUnbanSid(sid)
    if not sid then return end
    MH.DB.Query("DELETE FROM mh_mail_bans WHERE sid64 = " .. MH.DB.Esc(tostring(sid)))
end

function MH.State.ListMailBans()
    local rows = MH.DB.Query(
        "SELECT b.sid64, b.reason, b.banned_by, b.stamp, p.nick " ..
        "FROM mh_mail_bans b LEFT JOIN mh_players p ON p.sid64 = b.sid64 " ..
        "ORDER BY b.stamp DESC") or {}
    return rows
end

local function seed_single_npc(nm, cpu_tier, ram_tier, hdd_tier, net_tier, fixed_ip, hasher_v, firewall_v)
    local ip = fixed_ip or gen_ip()
    local pass = gen_pass(10)
    MH.DB.Query("INSERT INTO mh_servers (owner_sid, name, ip, cpu_tier, ram_tier, hdd_tier, net_tier, is_npc, root_pass, ent_class) VALUES (" ..
        MH.DB.Esc("npc:" .. nm) .. ", " .. MH.DB.Esc(nm) .. ", " .. MH.DB.Esc(ip) ..
        ", " .. cpu_tier .. ", " .. ram_tier .. ", " .. hdd_tier .. ", " .. net_tier ..
        ", 1, " .. MH.DB.Esc(pass) .. ", '')")
    local srvId = tonumber(MH.DB.QueryValue("SELECT last_insert_rowid()"))
    apply_expected_softwares(srvId, nm, hasher_v, firewall_v, true)
    return srvId, ip
end

function MH.State.GetSpecialNPC(key)
    for _, s in ipairs(SPECIAL_NPCS) do
        if s.key == key then
            return MH.DB.QueryRow("SELECT * FROM mh_servers WHERE name = " .. MH.DB.Esc(s.name) ..
                " AND is_npc = 1 LIMIT 1")
        end
    end
    return nil
end

function MH.State.SeedNPCs()
    local existing = tonumber(MH.DB.QueryValue("SELECT COUNT(*) FROM mh_servers WHERE is_npc = 1")) or 0
    local puzzles = MH.Data.Puzzles or {}
    if existing > 0 then return end
    local HIRER_LOADOUTS = {
        { { 2, 14 }, { 1, 17 }, { 13, 15 }, { 4, 13 }, { 14, 11 }, { 20, 15 } },
        { { 2, 11 }, { 1, 13 }, { 4, 12 }, { 5, 14 }, { 6, 12 }, { 8, 12 }, { 13, 11 } },
        { { 2, 12 }, { 1, 11 }, { 4, 10 }, { 8, 20 }, { 13, 12 }, { 14, 13 }, { 3, 10 }, { 9, 10 } },
        { { 2, 13 }, { 1, 14 }, { 4, 17 }, { 8, 12 }, { 13, 12 }, { 3, 10 }, { 9, 13 }, { 6, 12 }, { 5, 11 } },
        { { 2, 17 }, { 1, 13 }, { 4, 14 }, { 20, 20 }, { 5, 16 }, { 8, 15 } },
        { { 2, 16 }, { 1, 22 }, { 4, 19 }, { 8, 14 }, { 14, 14 }, { 3, 10 }, { 5, 18 } },
        { { 2, 22 }, { 1, 20 }, { 4, 10 }, { 14, 17 }, { 13, 16 }, { 3, 10 } },
        { { 2, 25 }, { 1, 23 }, { 4, 20 }, { 9, 15 }, { 13, 16 }, { 7, 13 } },
        { { 2, 28 }, { 1, 27 }, { 4, 24 } },
        { { 2, 20 }, { 1, 27 }, { 4, 17 } },
        { { 2, 17 }, { 1, 19 }, { 4, 17 }, { 8, 11 } },
    }
    local SOFT_NAMES = {
        [1] = "cracker", [2] = "hasher", [3] = "portscan", [4] = "firewall",
        [5] = "hider",   [6] = "seeker", [7] = "antivirus", [8] = "spam",
        [9] = "warez",  [13] = "ftp_exp", [14] = "ssh_exp", [20] = "miner",
    }
    for idx, nm in ipairs(NPC_NAMES) do
        local loadout = HIRER_LOADOUTS[idx] or { { 2, 10 } }
        local hv = 10
        for _, s in ipairs(loadout) do if s[1] == 2 then hv = s[2] break end end
        local srvId = seed_single_npc(nm, 4, 4, 4, 4, nil, hv)
        MH.DB.Query("DELETE FROM mh_software WHERE server_id = " .. srvId)
        for _, s in ipairs(loadout) do
            local t, v = s[1], s[2]
            local inst = (t == 1 or t == 2 or t == 4) and 1 or 0
            local sz = math.max(10, math.floor(v * 1.5))
            local ram = math.max(6, math.floor(v / 2))
            MH.DB.Query("INSERT INTO mh_software (server_id, soft_type, soft_version, soft_name, soft_size, soft_ram, installed) VALUES (" ..
                srvId .. ", " .. t .. ", " .. v .. ", " .. MH.DB.Esc(SOFT_NAMES[t] or "soft") ..
                ", " .. sz .. ", " .. ram .. ", " .. inst .. ")")
        end
        if string.find(string.lower(nm), "bank") then
            local acc = tostring(math.random(111111111, 999999999))
            MH.DB.Query("INSERT INTO mh_banks (bank_npc, acc_num, acc_pass, owner_sid, cash, created) VALUES (" ..
                srvId .. ", " .. MH.DB.Esc(acc) .. ", " .. MH.DB.Esc(gen_pass(6)) ..
                ", " .. MH.DB.Esc("npc:" .. nm) .. ", " .. math.random(5000, 50000) ..
                ", " .. now() .. ")")
        end
    end
    for _, s in ipairs(SPECIAL_NPCS) do
        local srvId = seed_single_npc(s.name, s.cpu_tier, s.ram_tier, s.hdd_tier, s.net_tier, s.fixed_ip, s.hasher_v, s.firewall_v)
        if string.find(string.lower(s.name), "bank") then
            local acc = tostring(math.random(111111111, 999999999))
            MH.DB.Query("INSERT INTO mh_banks (bank_npc, acc_num, acc_pass, owner_sid, cash, created) VALUES (" ..
                srvId .. ", " .. MH.DB.Esc(acc) .. ", " .. MH.DB.Esc(gen_pass(6)) ..
                ", " .. MH.DB.Esc("npc:" .. s.name) .. ", " .. math.random(5000, 50000) ..
                ", " .. now() .. ")")
        end
    end
    for i = 1, #puzzles do
        seed_single_npc(puzzle_npc_name(i), 4, 3, 3, 4, nil, puzzle_hasher_v(i), puzzle_firewall_v(i))
    end
    MH.Log.info("state", "seed", "Seeded " .. (#NPC_NAMES + #SPECIAL_NPCS) .. " NPC servers")
end

hook.Add("Initialize", "mh_seed_npcs", function()
    timer.Simple(1, function() MH.State.SeedNPCs() end)
end)

function MH.State.GetServersFor(sid)
    return MH.DB.Query("SELECT * FROM mh_servers WHERE owner_sid = " .. MH.DB.Esc(sid) ..
        " ORDER BY id ASC") or {}
end

function MH.State.GetServerById(id)
    return MH.DB.QueryRow("SELECT * FROM mh_servers WHERE id = " .. tonumber(id or 0))
end

function MH.State.GetSoftwareFor(serverId)
    return MH.DB.Query("SELECT * FROM mh_software WHERE server_id = " .. tonumber(serverId)) or {}
end

function MH.State.GetProcessesFor(serverId)
    return MH.DB.Query("SELECT * FROM mh_processes WHERE local_server = " .. tonumber(serverId) ..
        " OR victim_server = " .. tonumber(serverId)) or {}
end

function MH.State.CountServers(sid)
    local v = MH.DB.QueryValue("SELECT COUNT(*) FROM mh_servers WHERE owner_sid = " .. MH.DB.Esc(sid))
    return tonumber(v) or 0
end

function MH.State.SnapshotFor(ply)
    local sid = ply:SteamID64()
    local pdata = MH.State.GetPlayer(sid) or {}
    local servers = MH.State.GetServersFor(sid)
    for _, srv in ipairs(servers) do
        srv.software = MH.State.GetSoftwareFor(srv.id)
        srv.processes = MH.State.GetProcessesFor(srv.id)
        srv.log_text = MH.State.ReadLog(srv.id)
        srv.log_locked = MH.DB.QueryValue(
            "SELECT 1 FROM mh_processes WHERE action IN ('E_LOG','D_LOG') AND local_server = " ..
            tonumber(srv.id) .. " LIMIT 1") and true or false
        srv.xhds = MH.DB.Query("SELECT * FROM mh_xhds WHERE server_id = " .. tonumber(srv.id)) or {}
    end
    local hacked_banks = MH.DB.Query(
        "SELECT b.*, s.ip AS bank_ip, s.name AS bank_name " ..
        "FROM mh_hacked_banks b LEFT JOIN mh_servers s ON s.id = b.bank_server_id " ..
        "WHERE b.owner_sid = " .. MH.DB.Esc(sid)) or {}

    local notifications = MH.DB.Query("SELECT * FROM mh_notifications WHERE owner_sid = " .. MH.DB.Esc(sid) ..
        " AND seen = 0 ORDER BY stamp DESC LIMIT 20") or {}
    local all_processes = MH.DB.Query("SELECT * FROM mh_processes WHERE creator_sid = " .. MH.DB.Esc(sid)) or {}
    local installed_viruses = MH.DB.Query(
        "SELECT sw.id, sw.soft_type, sw.soft_version, sw.soft_name, sw.last_collect, sw.hidden, " ..
        "sw.server_id, s.name AS host_name, s.ip AS host_ip " ..
        "FROM mh_software sw INNER JOIN mh_servers s ON s.id = sw.server_id " ..
        "WHERE sw.owner_sid = " .. MH.DB.Esc(sid) ..
        " AND sw.installed = 1 AND sw.soft_type IN (8, 9, 10, 20) " ..
        "ORDER BY sw.last_collect ASC") or {}
    local news = MH.DB.Query("SELECT * FROM mh_news ORDER BY stamp DESC LIMIT 5") or {}
    local discovered = MH.DB.Query(
        "SELECT s.id, s.name, s.ip, s.is_npc, d.stamp " ..
        "FROM mh_discovered d INNER JOIN mh_servers s ON s.id = d.server_id " ..
        "WHERE d.owner_sid = " .. MH.DB.Esc(sid) ..
        " ORDER BY d.stamp DESC") or {}
    local known_players = MH.DB.Query(
        "SELECT nick, sid64 FROM mh_players WHERE sid64 != " .. MH.DB.Esc(sid) ..
        " ORDER BY last_login DESC LIMIT 50") or {}
    local ranking = {
        reputation = MH.DB.Query("SELECT nick, exp AS val, sid64 FROM mh_players ORDER BY exp DESC LIMIT 10") or {},
        hacks = MH.DB.Query("SELECT nick, hack_count AS val, sid64 FROM mh_players WHERE hack_count > 0 ORDER BY hack_count DESC LIMIT 10") or {},
        missions = MH.DB.Query("SELECT nick, mission_count AS val, sid64 FROM mh_players WHERE mission_count > 0 ORDER BY mission_count DESC LIMIT 10") or {},
        money = MH.DB.Query("SELECT nick, money_earned AS val, sid64 FROM mh_players WHERE money_earned > 0 ORDER BY money_earned DESC LIMIT 10") or {},
        transfers = MH.DB.Query("SELECT nick, money_transferred AS val, sid64 FROM mh_players WHERE money_transferred > 0 ORDER BY money_transferred DESC LIMIT 10") or {},
        viruses = MH.DB.Query("SELECT nick, virus_installs AS val, sid64 FROM mh_players WHERE virus_installs > 0 ORDER BY virus_installs DESC LIMIT 10") or {},
        ddos = MH.DB.Query("SELECT nick, ddos_count AS val, sid64 FROM mh_players WHERE ddos_count > 0 ORDER BY ddos_count DESC LIMIT 10") or {},
        doom = MH.DB.Query("SELECT nick, doom_count AS val, sid64 FROM mh_players WHERE doom_count > 0 ORDER BY doom_count DESC LIMIT 10") or {},
        wealth = MH.DB.Query(
            "SELECT p.nick AS nick, COALESCE(SUM(b.cash),0) AS val, p.sid64 AS sid64 " ..
            "FROM mh_players p LEFT JOIN mh_banks b ON b.owner_sid = p.sid64 " ..
            "GROUP BY p.sid64 ORDER BY val DESC LIMIT 10") or {},
        bitcoin = MH.DB.Query("SELECT nick, bitcoin AS val, sid64 FROM mh_players WHERE bitcoin > 0 ORDER BY bitcoin DESC LIMIT 10") or {},
        certs = MH.DB.Query("SELECT nick, cert_level AS val, sid64 FROM mh_players WHERE cert_level > 0 ORDER BY cert_level DESC, exp DESC LIMIT 10") or {},
        software = MH.DB.Query(
            "SELECT p.nick AS nick, p.sid64 AS sid64, sw.soft_type, sw.soft_name, sw.soft_version " ..
            "FROM mh_software sw " ..
            "INNER JOIN mh_players p ON p.sid64 = sw.licensed_to " ..
            "WHERE sw.licensed_to IS NOT NULL AND sw.licensed_to != '' AND sw.licensed_to != 'NULL' " ..
            "ORDER BY sw.soft_version DESC LIMIT 10") or {},
    }
    local bank_sess = MH.DB.QueryRow("SELECT * FROM mh_bank_session WHERE owner_sid = " .. MH.DB.Esc(sid))
    local bank_sess_info = nil
    if bank_sess then
        local acc = MH.DB.QueryRow("SELECT * FROM mh_banks WHERE acc_num = " .. MH.DB.Esc(bank_sess.acc_num))
        local bank = MH.DB.QueryRow("SELECT id, ip, name FROM mh_servers WHERE id = " .. tonumber(bank_sess.bank_server_id or 0))
        if acc and bank then
            bank_sess_info = {
                bank_id = tonumber(bank.id), bank_ip = bank.ip, bank_name = bank.name,
                acc_num = acc.acc_num, acc_pass = acc.acc_pass, cash = tonumber(acc.cash) or 0,
                is_owner = acc.owner_sid == sid,
            }
        end
    end
    local net_row = MH.DB.QueryRow("SELECT * FROM mh_internet WHERE owner_sid = " .. MH.DB.Esc(sid))
    local internet = nil
    if net_row and tonumber(net_row.target_server) and tonumber(net_row.target_server) > 0 then
        local target = MH.State.GetServerById(tonumber(net_row.target_server))
        if target then
            local info = {
                id = tonumber(target.id),
                ip = target.ip,
                name = target.name,
                is_npc = tonumber(target.is_npc) == 1,
                is_bank = (tonumber(target.is_npc) == 1) and (string.find(string.lower(target.name or ""), "bank") ~= nil),
                is_isp = (tonumber(target.is_npc) == 1) and target.name == "ISP",
                hp = tonumber(target.hp) or 100,
                authed = tonumber(net_row.authed or 0) == 1,
                auth_user = tostring(net_row.auth_user or "root"),
                cpu_tier = tonumber(target.cpu_tier) or 1,
                ram_tier = tonumber(target.ram_tier) or 1,
                hdd_tier = tonumber(target.hdd_tier) or 1,
                net_tier = tonumber(target.net_tier) or 1,
            }
            info.target_hasher = tonumber(MH.DB.QueryValue(
                "SELECT MAX(soft_version) FROM mh_software WHERE server_id = " .. tonumber(target.id) ..
                " AND soft_type = 2")) or 0
            info.target_firewall = tonumber(MH.DB.QueryValue(
                "SELECT MAX(soft_version) FROM mh_software WHERE server_id = " .. tonumber(target.id) ..
                " AND soft_type = 4")) or 0
            info.saved_pass = MH.DB.QueryValue(
                "SELECT discovered_pass FROM mh_hacked WHERE owner_sid = " .. MH.DB.Esc(sid) ..
                " AND target_server = " .. tonumber(target.id) .. " LIMIT 1")
            info.log_disabled = MH.State.IsLogDisabled(tonumber(target.id))
            info.is_bitcoin = (tonumber(target.is_npc) == 1) and target.name == "Bitcoin Market"
            local NPC_PAGE_IMAGES = {
                ["MSA"] = "materials/metastruct/metahacker/msa.png",
            }
            info.web_image = NPC_PAGE_IMAGES[tostring(target.name)]
            if info.is_isp then
                info.ip_reset_price = MH.State.IPResetPrice(sid)
                local ready, wait = MH.State.IPResetReady(sid)
                info.ip_reset_ready = ready
                info.ip_reset_wait = wait
                info.ip_resets_done = tonumber((MH.State.GetPlayer(sid) or {}).ip_resets or 0) or 0
                info.pwd_reset_price = MH.State.PwdResetPrice(sid)
                local pr, pw = MH.State.PwdResetReady(sid)
                info.pwd_reset_ready = pr
                info.pwd_reset_wait = pw
                info.pwd_resets_done = tonumber((MH.State.GetPlayer(sid) or {}).pwd_resets or 0) or 0
            end
            local puzzleIdx = string.match(tostring(target.name or ""), "^Puzzle (%d+)$")
            if puzzleIdx then
                puzzleIdx = tonumber(puzzleIdx)
                info.is_puzzle = true
                info.puzzle_index = puzzleIdx
                info.puzzle_total = #(MH.Data.Puzzles or {})
                info.puzzles_solved_count = tonumber(MH.DB.QueryValue(
                    "SELECT COUNT(*) FROM mh_puzzle_solves WHERE owner_sid = " .. MH.DB.Esc(sid))) or 0
                local pr, pw = MH.State.PuzzleReady(sid)
                info.puzzle_ready = pr
                info.puzzle_wait = pw
                local puzzleData
                for _, p in ipairs(MH.Data.Puzzles or {}) do
                    if tonumber(p.id) == puzzleIdx then puzzleData = p break end
                end
                info.puzzle_solved = MH.State.IsPuzzleSolved(sid, puzzleIdx)
                local prevIdx = puzzleIdx - 1
                info.puzzle_prev_cleared = prevIdx == 0 or MH.State.IsPuzzleSolved(sid, prevIdx)
                if puzzleData and info.puzzle_prev_cleared then
                    info.puzzle = {
                        id = puzzleData.id,
                        kind = puzzleData.kind or "qa",
                        name = puzzleData.name,
                        question = puzzleData.question,
                        hint = puzzleData.hint,
                    }
                end
                if info.puzzle_solved then
                    local nextRow = MH.State.GetPuzzleNPC(puzzleIdx + 1)
                    if nextRow then info.puzzle_next_ip = nextRow.ip end
                end
            end
            if info.authed then
                local allSoft = MH.State.GetSoftwareFor(target.id)
                local viewerSeekerV = tonumber(MH.DB.QueryValue(
                    "SELECT MAX(sw.soft_version) FROM mh_software sw " ..
                    "INNER JOIN mh_servers sv ON sv.id = sw.server_id " ..
                    "WHERE sv.owner_sid = " .. MH.DB.Esc(sid) ..
                    " AND sw.soft_type = 6 AND sw.installed = 1")) or 0
                local visible, hiddenHddMb, hiddenRamMb = {}, 0, 0
                for _, s in ipairs(allSoft or {}) do
                    local hv = tonumber(s.hidden_version or 0) or 0
                    local isHidden = tonumber(s.hidden or 0) == 1
                    if isHidden and hv > viewerSeekerV then
                        hiddenHddMb = hiddenHddMb + (tonumber(s.soft_size or 0) or 0)
                        if tonumber(s.installed or 0) == 1 then
                            hiddenRamMb = hiddenRamMb + (tonumber(s.soft_ram or 0) or 0)
                        end
                    else
                        visible[#visible + 1] = s
                    end
                end
                info.software = visible
                info.hidden_hdd_mb = hiddenHddMb
                info.hidden_ram_mb = hiddenRamMb
                info.viewer_seeker_v = viewerSeekerV
                info.log_text = MH.State.ReadLog(target.id)
                info.log_locked = MH.DB.QueryValue(
                    "SELECT 1 FROM mh_processes WHERE action IN ('E_LOG','D_LOG') AND local_server = " ..
                    tonumber(target.id) .. " LIMIT 1") and true or false
                if info.is_bank and tostring(info.auth_user or "root") == "root" then
                    info.bank_accounts = MH.DB.Query(
                        "SELECT b.acc_num, b.cash, b.owner_sid, p.nick AS owner_nick " ..
                        "FROM mh_banks b LEFT JOIN mh_players p ON p.sid64 = b.owner_sid " ..
                        "WHERE b.bank_npc = " .. tonumber(target.id) ..
                        " ORDER BY b.cash DESC LIMIT 200") or {}
                end
            end
            internet = info
        end
    end
    local hacked = MH.DB.Query(
        "SELECT h.id, h.target_server, h.discovered_pass, h.stamp, s.ip, s.name AS target_name " ..
        "FROM mh_hacked h LEFT JOIN mh_servers s ON s.id = h.target_server " ..
        "WHERE h.owner_sid = " .. MH.DB.Esc(sid)) or {}
    local banks = MH.DB.Query(
        "SELECT b.*, s.name AS bank_name, s.ip AS bank_ip " ..
        "FROM mh_banks b LEFT JOIN mh_servers s ON s.id = b.bank_npc " ..
        "WHERE b.owner_sid = " .. MH.DB.Esc(sid)) or {}
    local available_banks = MH.DB.Query(
        "SELECT s.id, s.name, s.ip, " ..
        "(SELECT COUNT(*) FROM mh_banks b WHERE b.bank_npc = s.id AND b.owner_sid = " .. MH.DB.Esc(sid) .. ") AS owned " ..
        "FROM mh_servers s " ..
        "INNER JOIN mh_discovered d ON d.server_id = s.id AND d.owner_sid = " .. MH.DB.Esc(sid) .. " " ..
        "WHERE s.is_npc = 1 AND LOWER(s.name) LIKE '%bank%' ORDER BY s.name") or {}
    local mail_inbox = MH.DB.Query("SELECT * FROM mh_mail WHERE to_sid = " .. MH.DB.Esc(sid) ..
        " AND (is_deleted IS NULL OR is_deleted = 0) ORDER BY stamp DESC LIMIT 100") or {}
    local mail_unread = tonumber(MH.DB.QueryValue(
        "SELECT COUNT(*) FROM mh_mail WHERE to_sid = " .. MH.DB.Esc(sid) ..
        " AND (is_deleted IS NULL OR is_deleted = 0) AND (seen IS NULL OR seen = 0)")) or 0
    local mail_outbox = MH.DB.Query("SELECT * FROM mh_mail WHERE from_sid = " .. MH.DB.Esc(sid) ..
        " ORDER BY stamp DESC LIMIT 100") or {}
    local completedCount = tonumber(MH.DB.QueryValue(
        "SELECT COUNT(*) FROM mh_missions WHERE assigned_sid = " .. MH.DB.Esc(sid) ..
        " AND status = 3")) or 0
    local crackerV = tonumber(MH.DB.QueryValue(
        "SELECT MAX(sw.soft_version) FROM mh_software sw " ..
        "INNER JOIN mh_servers sv ON sv.id = sw.server_id " ..
        "WHERE sv.owner_sid = " .. MH.DB.Esc(sid) .. " AND sw.soft_type = 1")) or 0
    local playerTier = 1
    if crackerV >= 60 then playerTier = 3
    elseif crackerV >= 30 then playerTier = 2 end
    local boardClause = completedCount >= 1 and
        "   OR (m.status = 0 AND (m.assigned_sid IS NULL OR m.assigned_sid = '') AND m.level = " .. playerTier .. ")" or ""
    local missions = MH.DB.Query(
        "SELECT m.*, s.name AS target_name, s.ip AS target_ip, h.name AS hirer_name, h.ip AS hirer_ip, " ..
        "(SELECT 1 FROM mh_discovered d WHERE d.owner_sid = " .. MH.DB.Esc(sid) ..
        " AND d.server_id = m.hirer_server LIMIT 1) AS hirer_discovered " ..
        "FROM mh_missions m LEFT JOIN mh_servers s ON s.id = m.target_server " ..
        "LEFT JOIN mh_servers h ON h.id = m.hirer_server " ..
        "WHERE m.assigned_sid = " .. MH.DB.Esc(sid) .. boardClause ..
        " ORDER BY (CASE m.status WHEN 2 THEN 0 WHEN 1 THEN 1 WHEN 0 THEN 2 WHEN 3 THEN 3 ELSE 4 END) ASC," ..
        " m.level ASC, m.created DESC LIMIT 200") or {}
    local playerDiscovered = {}
    for _, d in ipairs(discovered) do playerDiscovered[tonumber(d.id)] = true end
    for _, m in ipairs(missions) do
        local ownRow = (m.assigned_sid == sid)
        local hirerKnown = tonumber(m.hirer_discovered or 0) == 1
        if not ownRow and not hirerKnown then
            m.mtype = 0
            m.target_server = 0
            m.target_name = "????"
            m.target_ip = "????"
            m.hirer_name = "????"
            m.hirer_ip = "????"
            m.prize = 0
            m.level = 0
            m.briefing = ""
            m.locked = 1
        elseif not ownRow and not playerDiscovered[tonumber(m.target_server or 0)] then
            m.target_name = "????"
            m.target_ip = "????"
            m.briefing = (tostring(m.briefing or "")) ~= "" and
                "Target details withheld. Accept the contract to reveal the IP." or ""
            m.target_hidden = 1
        end
    end
    for _, m in ipairs(missions) do
        if tonumber(m.status) == 1 then
            local acceptedAt = tonumber(m.accepted_at or 0) or 0
            local hit = MH.DB.QueryValue(
                "SELECT 1 FROM mh_hacked WHERE owner_sid = " .. MH.DB.Esc(sid) ..
                " AND target_server = " .. tonumber(m.target_server) ..
                " AND stamp > " .. acceptedAt .. " LIMIT 1")
            if hit then
                MH.DB.Query("UPDATE mh_missions SET status = 2 WHERE id = " .. tonumber(m.id))
                m.status = 2
            end
        end
    end
    local btc = MH.DB.QueryRow("SELECT * FROM mh_btc_wallets WHERE owner_sid = " .. MH.DB.Esc(sid))

    local public_services = {}
    local serviceKeys = {
        "DIRECTORY", "WHOIS2", "WHOIS3", "WHOIS4",
        "DC", "ISP", "BITCOIN", "EMPLOYERS", "MSA", "SOURCENET",
        "BANK1", "BANK2", "BANK3", "BANK4", "BANK5",
    }
    for _, k in ipairs(serviceKeys) do
        local row = MH.State.GetSpecialNPC(k)
        if row then
            public_services[k] = { id = tonumber(row.id), ip = row.ip, name = row.name }
        end
    end
    for i = 1, #(MH.Data.Puzzles or {}) do
        local prow = MH.State.GetPuzzleNPC(i)
        if prow then
            public_services["PUZZLE_" .. i] = { id = tonumber(prow.id), ip = prow.ip, name = "Puzzle " .. i }
        end
    end
    local puzzle1 = public_services.PUZZLE_1
    if puzzle1 then public_services.PUZZLE = puzzle1 end

    local software_count = tonumber(MH.DB.QueryValue(
        "SELECT COUNT(*) FROM mh_software sw INNER JOIN mh_servers s ON s.id = sw.server_id " ..
        "WHERE s.owner_sid = " .. MH.DB.Esc(sid))) or 0
    local has_cracker = tonumber(MH.DB.QueryValue(
        "SELECT 1 FROM mh_software sw INNER JOIN mh_servers s ON s.id = sw.server_id " ..
        "WHERE s.owner_sid = " .. MH.DB.Esc(sid) .. " AND sw.soft_type = 1 LIMIT 1")) and 1 or 0

    local is_admin = IsValid(ply) and ply:IsSuperAdmin() or false
    local admin_bans, admin_mail_bans, admin_online, admin_stats, admin_abuse_log, admin_mail_counts =
        nil, nil, nil, nil, nil, nil
    if is_admin then
        admin_bans = MH.State.ListBans()
        admin_mail_bans = MH.State.ListMailBans()
        admin_online = {}
        for _, p in ipairs(player.GetHumans()) do
            admin_online[#admin_online + 1] = { sid64 = p:SteamID64(), nick = p:Nick() }
        end
        admin_stats = MH.DB.Query(
            "SELECT sid64, nick, abuse_cmd_hits, abuse_mail_hits, last_abuse_stamp, " ..
            "total_cmds, total_mails_sent " ..
            "FROM mh_players " ..
            "WHERE abuse_cmd_hits > 0 OR abuse_mail_hits > 0 OR total_mails_sent > 20 OR total_cmds > 500 " ..
            "ORDER BY (COALESCE(abuse_cmd_hits,0) + COALESCE(abuse_mail_hits,0)) DESC, " ..
            "COALESCE(total_mails_sent,0) DESC, COALESCE(total_cmds,0) DESC " ..
            "LIMIT 30") or {}
        admin_abuse_log = MH.DB.Query(
            "SELECT a.sid64, a.kind, a.info, a.stamp, p.nick " ..
            "FROM mh_abuse_log a LEFT JOIN mh_players p ON p.sid64 = a.sid64 " ..
            "ORDER BY a.stamp DESC LIMIT 50") or {}
        admin_mail_counts = MH.DB.Query(
            "SELECT m.from_sid AS sid64, p.nick, COUNT(*) AS cnt, MAX(m.stamp) AS last_stamp " ..
            "FROM mh_mail m LEFT JOIN mh_players p ON p.sid64 = m.from_sid " ..
            "WHERE m.from_sid GLOB '[0-9]*' AND LENGTH(m.from_sid) >= 15 " ..
            "GROUP BY m.from_sid HAVING cnt >= 5 ORDER BY cnt DESC LIMIT 30") or {}
    end

    return {
        player = pdata,
        public_services = public_services,
        software_count = software_count,
        has_cracker = has_cracker,
        servers = servers,
        hacked = hacked,
        hacked_banks = hacked_banks,
        banks = banks,
        available_banks = available_banks,
        mail_inbox = mail_inbox,
        mail_outbox = mail_outbox,
        mail_unread = mail_unread,
        missions = missions,
        btc = btc,
        internet = internet,
        bank_session = bank_sess_info,
        notifications = notifications,
        all_processes = all_processes,
        installed_viruses = installed_viruses,
        news = news,
        discovered = discovered,
        known_players = known_players,
        ranking = ranking,
        server_now = now(),
        is_admin = is_admin,
        admin_bans = admin_bans,
        admin_mail_bans = admin_mail_bans,
        admin_online = admin_online,
        admin_stats = admin_stats,
        admin_abuse_log = admin_abuse_log,
        admin_mail_counts = admin_mail_counts,
    }
end

hook.Add("PlayerInitialSpawn", "mh_ensure_player", function(ply)
    MH.State.EnsurePlayer(ply)
end)
