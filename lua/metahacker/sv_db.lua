MH = MH or {}
MH.DB = {}

local SCHEMA = {
[[CREATE TABLE IF NOT EXISTS mh_players (
    sid64 TEXT PRIMARY KEY,
    nick TEXT,
    exp INTEGER DEFAULT 0,
    cash INTEGER DEFAULT 100,
    bitcoin REAL DEFAULT 0,
    joined INTEGER,
    last_login INTEGER
);]],
[[CREATE TABLE IF NOT EXISTS mh_servers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    owner_sid TEXT,
    name TEXT,
    ip TEXT,
    cpu_tier INTEGER DEFAULT 1,
    ram_tier INTEGER DEFAULT 1,
    hdd_tier INTEGER DEFAULT 1,
    net_tier INTEGER DEFAULT 1,
    is_npc INTEGER DEFAULT 0,
    root_pass TEXT,
    ent_class TEXT,
    pos_x REAL, pos_y REAL, pos_z REAL
);]],
[[CREATE TABLE IF NOT EXISTS mh_software (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    server_id INTEGER,
    owner_sid TEXT,
    soft_type INTEGER,
    soft_version INTEGER,
    soft_name TEXT,
    soft_size INTEGER,
    soft_ram INTEGER,
    hidden INTEGER DEFAULT 0,
    installed INTEGER DEFAULT 0,
    last_collect INTEGER DEFAULT 0
);]],
[[CREATE TABLE IF NOT EXISTS mh_processes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    creator_sid TEXT,
    victim_server INTEGER,
    local_server INTEGER,
    action TEXT,
    soft_id INTEGER,
    info TEXT,
    time_start INTEGER,
    time_end INTEGER,
    cpu_usage INTEGER,
    net_usage INTEGER
);]],
[[CREATE TABLE IF NOT EXISTS mh_banks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    bank_npc INTEGER,
    acc_num TEXT,
    acc_pass TEXT,
    owner_sid TEXT,
    owner_server INTEGER,
    cash INTEGER DEFAULT 0,
    created INTEGER
);]],
[[CREATE TABLE IF NOT EXISTS mh_btc_wallets (
    address TEXT PRIMARY KEY,
    owner_sid TEXT,
    owner_server INTEGER,
    priv_key TEXT,
    amount REAL DEFAULT 0,
    created INTEGER
);]],
[[CREATE TABLE IF NOT EXISTS mh_server_log (
    server_id INTEGER PRIMARY KEY,
    content TEXT,
    last_mod INTEGER
);]],
[[CREATE TABLE IF NOT EXISTS mh_mail (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    to_sid TEXT,
    from_sid TEXT,
    subject TEXT,
    body TEXT,
    stamp INTEGER,
    seen INTEGER DEFAULT 0
);]],
[[CREATE TABLE IF NOT EXISTS mh_missions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    assigned_sid TEXT,
    mtype INTEGER,
    target_server INTEGER,
    prize INTEGER,
    status INTEGER DEFAULT 0,
    created INTEGER,
    finished INTEGER
);]],
[[CREATE TABLE IF NOT EXISTS mh_clans (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE,
    owner_sid TEXT,
    created INTEGER
);]],
[[CREATE TABLE IF NOT EXISTS mh_clan_users (
    clan_id INTEGER,
    sid64 TEXT,
    role INTEGER DEFAULT 0,
    joined INTEGER,
    PRIMARY KEY (clan_id, sid64)
);]],
[[CREATE TABLE IF NOT EXISTS mh_hacked (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    owner_sid TEXT,
    target_server INTEGER,
    discovered_pass TEXT,
    stamp INTEGER
);]],
[[CREATE TABLE IF NOT EXISTS mh_tmp_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    server_id INTEGER,
    content TEXT,
    author_sid TEXT,
    stamp INTEGER
);]],
[[CREATE TABLE IF NOT EXISTS mh_hacked_banks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    owner_sid TEXT,
    bank_server_id INTEGER,
    acc_num TEXT,
    acc_pass TEXT,
    stamp INTEGER
);]],
[[CREATE TABLE IF NOT EXISTS mh_xhds (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    server_id INTEGER,
    name TEXT,
    cap_tier INTEGER DEFAULT 1
);]],
[[CREATE TABLE IF NOT EXISTS mh_internet (
    owner_sid TEXT PRIMARY KEY,
    target_server INTEGER,
    authed INTEGER DEFAULT 0,
    stamp INTEGER
);]],
[[CREATE TABLE IF NOT EXISTS mh_bank_session (
    owner_sid TEXT PRIMARY KEY,
    bank_server_id INTEGER,
    acc_num TEXT,
    stamp INTEGER
);]],
[[CREATE TABLE IF NOT EXISTS mh_notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    owner_sid TEXT,
    kind TEXT,
    text TEXT,
    stamp INTEGER,
    seen INTEGER DEFAULT 0
);]],
[[CREATE TABLE IF NOT EXISTS mh_discovered (
    owner_sid TEXT,
    server_id INTEGER,
    stamp INTEGER,
    PRIMARY KEY (owner_sid, server_id)
);]],
[[CREATE TABLE IF NOT EXISTS mh_news (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    text TEXT,
    stamp INTEGER
);]],
[[CREATE TABLE IF NOT EXISTS mh_puzzle_solves (
    owner_sid TEXT,
    puzzle_id INTEGER,
    stamp INTEGER,
    PRIMARY KEY (owner_sid, puzzle_id)
);]],
[[CREATE TABLE IF NOT EXISTS mh_bans (
    sid64 TEXT PRIMARY KEY,
    reason TEXT,
    banned_by TEXT,
    stamp INTEGER
);]],
[[CREATE TABLE IF NOT EXISTS mh_abuse_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sid64 TEXT,
    kind TEXT,
    info TEXT,
    stamp INTEGER
);]],
[[CREATE TABLE IF NOT EXISTS mh_mail_bans (
    sid64 TEXT PRIMARY KEY,
    reason TEXT,
    banned_by TEXT,
    stamp INTEGER
);]],
}

local MIGRATIONS = {
    "ALTER TABLE mh_software ADD COLUMN owner_sid TEXT",
    "ALTER TABLE mh_software ADD COLUMN last_collect INTEGER DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN cert_level INTEGER DEFAULT 0",
    "ALTER TABLE mh_mail ADD COLUMN is_deleted INTEGER DEFAULT 0",
    "ALTER TABLE mh_missions ADD COLUMN info TEXT",
    "ALTER TABLE mh_missions ADD COLUMN info_str TEXT",
    "ALTER TABLE mh_processes ADD COLUMN paused_remaining INTEGER DEFAULT 0",
    "ALTER TABLE mh_processes ADD COLUMN info_str TEXT",
    "ALTER TABLE mh_servers ADD COLUMN active INTEGER DEFAULT 0",
    "ALTER TABLE mh_internet ADD COLUMN authed INTEGER DEFAULT 0",
    "ALTER TABLE mh_missions ADD COLUMN accepted_at INTEGER DEFAULT 0",
    "ALTER TABLE mh_missions ADD COLUMN briefing TEXT",
    "ALTER TABLE mh_software ADD COLUMN content TEXT",
    "ALTER TABLE mh_servers ADD COLUMN hp INTEGER DEFAULT 100",
    "ALTER TABLE mh_players ADD COLUMN ip_resets INTEGER DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN last_ip_reset INTEGER DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN pwd_resets INTEGER DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN last_pwd_reset INTEGER DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN last_puzzle INTEGER DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN premium INTEGER DEFAULT 0",
    "ALTER TABLE mh_servers ADD COLUMN doom_status INTEGER DEFAULT 0",
    "ALTER TABLE mh_servers ADD COLUMN doom_owner_sid TEXT",
    "ALTER TABLE mh_players ADD COLUMN btc_address TEXT",
    "ALTER TABLE mh_players ADD COLUMN badges INTEGER DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN hack_count INTEGER DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN mission_count INTEGER DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN money_earned INTEGER DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN money_transferred INTEGER DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN virus_installs INTEGER DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN ddos_count INTEGER DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN doom_count INTEGER DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN time_playing INTEGER DEFAULT 0",
    "ALTER TABLE mh_missions ADD COLUMN level INTEGER DEFAULT 1",
    "ALTER TABLE mh_missions ADD COLUMN hirer_server INTEGER DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN puzzles_solved INTEGER DEFAULT 0",
    "UPDATE mh_mail SET from_sid = 'RakTheGoose' WHERE from_sid = 'Goose'",
    "UPDATE mh_mail SET from_sid = 'Employers' WHERE from_sid = 'RakTheGoose' AND subject != 'Welcome to MetaHacker!'",
    "ALTER TABLE mh_banks ADD COLUMN last_pass_change INTEGER DEFAULT 0",
    "ALTER TABLE mh_internet ADD COLUMN auth_user TEXT DEFAULT 'root'",
    "UPDATE mh_servers SET name = 'Sourcenet' WHERE name = 'Safenet'",
    "UPDATE mh_mail SET from_sid = 'Sourcenet' WHERE from_sid = 'Safenet'",
    "UPDATE mh_servers SET name = 'Employers' WHERE name = 'Employers HQ'",
    "UPDATE mh_servers SET name = 'First Whois' WHERE name = 'Public Directory'",
    "UPDATE mh_missions SET hirer_server = (SELECT id FROM mh_servers WHERE name = 'Employers' LIMIT 1) WHERE (hirer_server IS NULL OR hirer_server = 0) AND status IN (0, 1, 2)",
    "ALTER TABLE mh_players ADD COLUMN abuse_cmd_hits INTEGER DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN abuse_mail_hits INTEGER DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN last_abuse_stamp INTEGER DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN total_cmds INTEGER DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN total_mails_sent INTEGER DEFAULT 0",
    "ALTER TABLE mh_servers ADD COLUMN next_av_scan INTEGER DEFAULT 0",
    "ALTER TABLE mh_software ADD COLUMN hidden_version INTEGER DEFAULT 0",
    "UPDATE mh_software SET soft_name = 'hider' WHERE soft_name = 'hidder'",
    "ALTER TABLE mh_software ADD COLUMN licensed_to TEXT",
    "UPDATE mh_servers SET name = 'Black Mesa' WHERE name = 'MD'",
    "UPDATE mh_software SET soft_version = 10 WHERE server_id IN " ..
        "(SELECT id FROM mh_servers WHERE name IN ('Treas', 'DarkMail', 'CryptoEx')) " ..
        "AND soft_version > 10",
    "ALTER TABLE mh_players ADD COLUMN last_collect_stamp INTEGER DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN last_collect_cash INTEGER DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN last_collect_btc REAL DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN last_collect_visited INTEGER DEFAULT 0",
    "ALTER TABLE mh_players ADD COLUMN last_collect_acc TEXT",
    "ALTER TABLE mh_players ADD COLUMN last_collect_json TEXT",
}

function MH.DB.Init()
    for _, stmt in ipairs(SCHEMA) do
        local ok = sql.Query(stmt)
        if ok == false then
            MH.Log.error("db", "init", "Schema failed: " .. sql.LastError() .. " on " .. stmt:sub(1, 80))
        end
    end
    for _, stmt in ipairs(MIGRATIONS) do
        sql.Query(stmt)
    end
    MH.Log.info("db", "init", "Schema OK (" .. #SCHEMA .. " tables, " .. #MIGRATIONS .. " migrations attempted)")
end

function MH.DB.Esc(s)
    if s == nil then return "NULL" end
    if type(s) == "number" then return tostring(s) end
    return "'" .. sql.SQLStr(tostring(s), true) .. "'"
end

function MH.DB.Query(q)
    local r = sql.Query(q)
    if r == false then
        MH.Log.error("db", "query", sql.LastError() .. " :: " .. q)
        return nil
    end
    return r
end

function MH.DB.QueryRow(q)
    local r = MH.DB.Query(q)
    if r and r[1] then return r[1] end
    return nil
end

function MH.DB.QueryValue(q)
    local v = sql.QueryValue(q)
    if v == false then
        MH.Log.error("db", "queryvalue", sql.LastError() .. " :: " .. q)
        return nil
    end
    return v
end

hook.Add("Initialize", "mh_db_init", function()
    MH.DB.Init()
end)

MH.DB.Init()
