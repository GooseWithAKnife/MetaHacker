MH = MH or {}
MH.OS = MH.OS or {}

local N = MH.Net.Names

MH.OS.State = { player = {}, servers = {} }
MH.OS.FocusServer = 0

surface.CreateFont("MH_MailBody", {
    font = "Tahoma",
    size = 17,
    weight = 400,
    antialias = true,
})

local NOTIFY_COL = {
    ok    = Color(90, 200, 120),
    warn  = Color(230, 170, 50),
    error = Color(220, 80, 90),
    info  = Color(220, 226, 236),
}

MH.OS = MH.OS or {}
MH.OS.NotifyToasts = MH.OS.NotifyToasts or {}

local TOAST_LIFETIME = 5
local TOAST_FADE = 0.6
local TOAST_WIDE = 340
local TOAST_TALL = 56
local TOAST_GAP = 6
local TOAST_RIGHT_PAD = 24
local TOAST_TOP_PAD = 80

local function layout_toasts()
    local list = MH.OS.NotifyToasts
    local y = TOAST_TOP_PAD
    for i = #list, 1, -1 do
        local t = list[i]
        if IsValid(t) then
            t:SetPos(ScrW() - TOAST_WIDE - TOAST_RIGHT_PAD, y)
            y = y + TOAST_TALL + TOAST_GAP
        end
    end
end

function MH.OS.ShowNotify(kind, msg)
    local col = NOTIFY_COL[kind] or NOTIFY_COL.info
    local panel = vgui.Create("DPanel")
    panel:SetSize(TOAST_WIDE, TOAST_TALL)
    panel.Born = CurTime()
    panel.Lifetime = TOAST_LIFETIME
    panel.Paint = function(self, w, h)
        local age = CurTime() - self.Born
        local a = 255
        if age > self.Lifetime - TOAST_FADE then
            a = math.Clamp(255 * (self.Lifetime - age) / TOAST_FADE, 0, 255)
        end
        surface.SetDrawColor(23, 23, 23, a * 0.95)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(col.r, col.g, col.b, a)
        surface.DrawRect(0, 0, 4, h)
        surface.SetDrawColor(60, 60, 70, a)
        surface.DrawOutlinedRect(0, 0, w, h)
    end
    panel.Think = function(self)
        if (CurTime() - self.Born) >= self.Lifetime then
            self:Remove()
            for i, t in ipairs(MH.OS.NotifyToasts) do
                if t == self then table.remove(MH.OS.NotifyToasts, i) break end
            end
            layout_toasts()
        end
    end
    local tag = vgui.Create("DLabel", panel)
    tag:Dock(TOP)
    tag:DockMargin(14, 6, 10, 0)
    tag:SetFont("DermaDefaultBold")
    tag:SetTextColor(col)
    tag:SetText(string.upper(kind or "info"))
    tag:SizeToContents()
    local body = vgui.Create("DLabel", panel)
    body:Dock(FILL)
    body:DockMargin(14, 2, 10, 6)
    body:SetFont("DermaDefault")
    body:SetTextColor(Color(230, 236, 246))
    body:SetWrap(true)
    body:SetText(tostring(msg or ""))
    panel:MakePopup()
    panel:SetKeyboardInputEnabled(false)
    panel:SetMouseInputEnabled(false)
    table.insert(MH.OS.NotifyToasts, panel)
    layout_toasts()
end

local Tabs = {}
MH.OS.Tabs = Tabs

local function clear(container)
    container:Clear()
    if IsValid(MH.OS and MH.OS._FloatSidebar) then
        MH.OS._FloatSidebar:Remove()
        MH.OS._FloatSidebar = nil
    end
end

local function label(parent, text, font)
    local l = vgui.Create("DLabel", parent)
    l:SetText(text)
    l:SetDark(true)
    if font then l:SetFont(font) end
    l:SizeToContents()
    return l
end

local function button(parent, text, cb)
    local b = vgui.Create("DButton", parent)
    b:SetText(text)
    b.DoClick = cb
    return b
end

local PROCESS_SPAWNING_CMDS = {
    research              = "research",
    crack_ip              = "crack",
    scan_ip               = "scan",
    log_edit_submit       = "E_LOG",
    log_delete_all        = "D_LOG",
    internet_log_edit_submit = "E_LOG",
    internet_log_delete_all  = "D_LOG",
    av_scan                  = "AV_SCAN",
    ddos_launch              = "DDOS",
    remote_soft_download     = "SOFT_DOWNLOAD",
    remote_soft_upload       = "SOFT_UPLOAD",
    ip_reset                 = "RESET_IP",
    pwd_reset                = "RESET_PWD",
    bank_internet_hack_acc   = "BANK_ACC_CRACK",
    doom_launch              = "DOOM_SPREAD",
}

local function arm_watch(cmd, args)
    local actionMatch = PROCESS_SPAWNING_CMDS[cmd]
    if cmd == "soft_action" and args and args.action then
        actionMatch = "SOFT_" .. string.upper(tostring(args.action))
    end
    if not actionMatch then return end
    MH.OS.PendingWatch = {
        sourceTab = MH.OS.ActiveTab or "Home",
        actionMatch = actionMatch,
        startedAfter = os.time() - 2,
    }
end

local function send_cmd(cmd, args)
    arm_watch(cmd, args)
    net.Start(N.Command)
    net.WriteString(cmd)
    net.WriteString(util.TableToJSON(args or {}))
    net.SendToServer()
end
MH.OS.SendCmd = send_cmd

local function current_server()
    for _, s in ipairs(MH.OS.State.servers or {}) do
        if tonumber(s.id) == tonumber(MH.OS.FocusServer) then return s end
    end
    return (MH.OS.State.servers or {})[1]
end
MH.OS.CurrentServer = current_server

local proc_row
local SYSTEM_SENDERS, DEFAULT_SENDER_MODEL
local resolve_sender_model, resolve_sender_name, setup_avatar

local function format_bytes_mb(mb)
    mb = tonumber(mb) or 0
    if mb >= 1024 * 1024 then
        return string.format("%.2f TB", mb / (1024 * 1024))
    elseif mb >= 1024 then
        return string.format("%.2f GB", mb / 1024)
    else
        return string.format("%d MB", math.floor(mb))
    end
end
MH.OS.FormatBytesMB = format_bytes_mb

local function usage_pie(parent, size, title, used, total)
    local wrap = vgui.Create("DPanel", parent)
    wrap:SetWide(size + 20)
    wrap:SetTall(size + 36)
    wrap.Paint = function(self, w, h)
        if w <= 0 or h <= 0 then return end
        local radius = math.max(4, math.min(size, w, h - 20) / 2 - 6)
        local cx = w / 2
        local cy = radius + 8
        draw.NoTexture()
        local bg = {}
        for i = 0, 32 do
            local a = (i / 32) * math.pi * 2
            table.insert(bg, { x = cx + math.sin(a) * radius, y = cy - math.cos(a) * radius })
        end
        surface.SetDrawColor(60, 60, 60, 220)
        surface.DrawPoly(bg)
        local frac = total > 0 and math.min(1, used / total) or 0
        if frac > 0 then
            local col
            if frac < 0.8 then col = Color(90, 200, 120)
            elseif frac < 0.95 then col = Color(230, 170, 50)
            else col = Color(220, 80, 90) end
            surface.SetDrawColor(col)
            local arc = {{ x = cx, y = cy }}
            local segs = math.max(2, math.ceil(64 * frac))
            for i = 0, segs do
                local t = math.min(i / 64, frac)
                local theta = t * math.pi * 2
                table.insert(arc, { x = cx + math.sin(theta) * radius, y = cy - math.cos(theta) * radius })
            end
            surface.DrawPoly(arc)
        end
        surface.SetDrawColor(30, 30, 30, 255)
        for i = 0, 32 do
            local a1 = (i / 32) * math.pi * 2
            local a2 = ((i + 1) / 32) * math.pi * 2
            surface.DrawLine(
                cx + math.sin(a1) * radius, cy - math.cos(a1) * radius,
                cx + math.sin(a2) * radius, cy - math.cos(a2) * radius)
        end
        draw.SimpleText(title, "DermaDefaultBold", cx, cy, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(format_bytes_mb(used) .. " / " .. format_bytes_mb(total),
            "DermaDefault", cx, cy + radius + 10, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
    return wrap
end

local function open_text_editor(s, readOnly)
    local f = vgui.Create("DFrame")
    f:SetSize(640, 480)
    f:Center()
    f:SetTitle(tostring(s.soft_name or "text") .. (readOnly and "   (read only)" or "   (edit)"))
    f:SetDeleteOnClose(true)
    f:MakePopup()
    local body = vgui.Create("DTextEntry", f)
    body:Dock(FILL)
    body:DockMargin(8, 4, 8, 4)
    body:SetMultiline(true)
    body:SetVerticalScrollbarEnabled(true)
    body:SetValue(tostring(s.content or ""))
    if readOnly then body:SetEditable(false) end
    local actionBar = vgui.Create("DPanel", f)
    actionBar:Dock(BOTTOM)
    actionBar:SetTall(32)
    actionBar:DockMargin(8, 0, 8, 8)
    if not readOnly then
        local saveB = vgui.Create("DButton", actionBar)
        saveB:SetText("Save")
        saveB:Dock(RIGHT)
        saveB:SetWide(100)
        saveB.DoClick = function()
            MH.OS.SendCmd("soft_text_edit", { soft_id = s.id, content = body:GetValue() })
            f:Remove()
        end
    end
end

Tabs["Home"] = function(container)
    clear(container)
    local p = MH.OS.State.player or {}
    local nick = tostring(p.nick or LocalPlayer():Nick())
    label(container, "Welcome back, " .. nick, "DermaLarge"):Dock(TOP)

    local function card(title)
        local w = vgui.Create("DPanel", container)
        w:Dock(TOP)
        w:DockMargin(0, 8, 0, 0)
        local h = vgui.Create("DLabel", w)
        h:Dock(TOP)
        h:DockMargin(10, 6, 10, 0)
        h:SetDark(true)
        h:SetFont("DermaDefaultBold")
        h:SetText(title)
        h:SizeToContents()
        return w
    end

    local status = card("Status")
    status:SetTall(130)
    local function row(parent, txt)
        local l = vgui.Create("DLabel", parent)
        l:Dock(TOP)
        l:DockMargin(14, 2, 10, 0)
        l:SetDark(true)
        l:SetText(txt)
        l:SizeToContents()
    end
    row(status, "Bitcoin: " .. string.format("%.7f", tonumber(p.bitcoin or 0)))
    row(status, "Reputation: " .. tostring(tonumber(p.exp or 0)))
    row(status, "Certification level: " .. tostring(tonumber(p.cert_level or 0)) .. " / 5")
    row(status, "Servers owned: " .. tostring(#(MH.OS.State.servers or {})))

    local activeMission = nil
    for _, m in ipairs(MH.OS.State.missions or {}) do
        if tonumber(m.status or 0) == 1 or tonumber(m.status or 0) == 2 then
            activeMission = m
            break
        end
    end
    if activeMission then
        local mc = card("Current mission")
        mc:SetTall(72)
        local MISSION_TITLES_LOCAL = {
            [1] = "Delete a software", [2] = "Steal a software",
            [3] = "Check bank status", [4] = "Transfer money",
            [5] = "Destroy a server",
        }
        local title = MISSION_TITLES_LOCAL[tonumber(activeMission.mtype)] or ("Mission #" .. tostring(activeMission.mtype))
        row(mc, title .. "  prize $" .. tostring(activeMission.prize))
        row(mc, "Target: " .. tostring(activeMission.target_name or "?") .. "   " .. tostring(activeMission.target_ip or ""))
    end

    local unread = tonumber(MH.OS.State.mail_unread or 0) or 0
    if unread > 0 then
        local mc = card("Mail")
        mc:SetTall(44)
        row(mc, "You have " .. unread .. " unread message" .. (unread == 1 and "" or "s") .. ".")
    end

    local ddosProc = nil
    for _, pr in ipairs(MH.OS.State.all_processes or {}) do
        if pr.action == "DDOS" then ddosProc = pr break end
    end
    if ddosProc then
        local mc = card("DDoS in progress")
        mc:SetTall(44)
        row(mc, "Attack running against target " .. tostring(ddosProc.info or ddosProc.victim_server))
    end

    local newsRows = MH.OS.State.news or {}
    if #newsRows > 0 then
        local mc = card("News")
        mc:SetTall(22 + 18 * #newsRows + 10)
        for _, n in ipairs(newsRows) do
            row(mc, os.date("[%Y-%m-%d %H:%M] ", tonumber(n.stamp or 0)) .. tostring(n.text or ""))
        end
    end
end

MH.OS.HardwareView = MH.OS.HardwareView or "My hardware"

local function hardware_slot_row(parent, srv, kind, label_name, unit)
    local idx = tonumber(srv[kind .. "_tier"] or 1) or 1
    local cur = MH.Data.Hardware[kind][idx]
    local nxt = MH.Data.Hardware[kind][idx + 1]
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:SetTall(44)
    row:DockMargin(0, 6, 0, 0)
    local l = vgui.Create("DLabel", row)
    l:SetDark(true)
    l:SetFont("DermaDefaultBold")
    l:SetText(label_name .. "   " .. cur.name .. "   " .. (cur.mhz or cur.mb or cur.mbps) .. " " .. unit)
    l:Dock(LEFT)
    l:DockMargin(10, 0, 0, 0)
    l:SizeToContents()
    if nxt then
        local b = vgui.Create("DButton", row)
        b:SetText("Upgrade to " .. nxt.name .. "   $" .. nxt.price)
        b:Dock(RIGHT)
        b:DockMargin(0, 6, 10, 6)
        b:SetWide(300)
        b.DoClick = function() send_cmd("buy_hardware", { server_id = srv.id, kind = kind }) end
    else
        label(row, "Max tier"):Dock(RIGHT)
    end
end

Tabs["Hardware"] = function(container)
    clear(container)
    label(container, "Hardware", "DermaLarge"):Dock(TOP)

    local subbar = vgui.Create("DPanel", container)
    subbar:Dock(TOP)
    subbar:SetTall(28)
    subbar:DockMargin(0, 2, 0, 6)
    for _, name in ipairs({ "My hardware", "Upgrade server", "Buy new server", "Internet", "External HD" }) do
        local b = vgui.Create("DButton", subbar)
        b:SetText(name)
        b:Dock(LEFT)
        b:SetWide(140)
        b:DockMargin(0, 0, 4, 0)
        b.DoClick = function()
            MH.OS.HardwareView = name
            if MH.OS.Rebuild then MH.OS.Rebuild() end
        end
    end

    local srv = current_server()
    if not srv then
        label(container, "No servers owned"):Dock(TOP)
        return
    end

    if MH.OS.HardwareView == "My hardware" then
        local strip = vgui.Create("DPanel", container)
        strip:Dock(TOP)
        strip:SetTall(60)
        strip:DockMargin(0, 4, 0, 4)
        local function tile(parent, kind, titleTxt, valueFmt)
            local idx = tonumber(srv[kind .. "_tier"] or 1) or 1
            local cur = MH.Data.Hardware[kind][idx]
            local t = vgui.Create("DPanel", parent)
            t:Dock(LEFT)
            t:SetWide(200)
            t:DockMargin(0, 0, 6, 0)
            local heading = vgui.Create("DLabel", t)
            heading:Dock(TOP)
            heading:DockMargin(8, 4, 0, 0)
            heading:SetDark(true)
            heading:SetFont("DermaDefaultBold")
            heading:SetText(titleTxt)
            heading:SizeToContents()
            local value = vgui.Create("DLabel", t)
            value:Dock(TOP)
            value:DockMargin(8, 2, 0, 0)
            value:SetDark(true)
            value:SetFont("DermaLarge")
            value:SetText(valueFmt(cur))
            value:SizeToContents()
        end
        tile(strip, "cpu", "CPU", function(c) return c.mhz .. " MHz" end)
        tile(strip, "ram", "RAM", function(c) return c.mb .. " MB" end)
        tile(strip, "hdd", "HDD", function(c) return c.mb .. " MB" end)
        tile(strip, "net", "NET", function(c) return c.mbps .. " Mbps" end)

        label(container, "Owned servers", "DermaDefaultBold"):Dock(TOP)
        for _, s in ipairs(MH.OS.State.servers or {}) do
            local row = vgui.Create("DPanel", container)
            row:Dock(TOP)
            row:SetTall(32)
            row:DockMargin(0, 4, 0, 0)
            local sl = vgui.Create("DLabel", row)
            sl:SetDark(true)
            sl:SetFont("DermaDefaultBold")
            sl:SetText("   " .. tostring(s.name) .. "   " .. tostring(s.ip or "?"))
            sl:Dock(LEFT)
            sl:SizeToContents()
            local renameB = vgui.Create("DButton", row)
            renameB:SetText("Rename")
            renameB:Dock(RIGHT)
            renameB:SetWide(100)
            renameB:DockMargin(0, 4, 10, 4)
            renameB.DoClick = function()
                Derma_StringRequest("Rename server", "New name:", tostring(s.name or ""), function(nm)
                    send_cmd("server_rename", { server_id = s.id, name = nm })
                end)
            end
            local focusB = vgui.Create("DButton", row)
            focusB:SetText(tonumber(MH.OS.FocusServer) == tonumber(s.id) and "Active" or "Set active")
            focusB:Dock(RIGHT)
            focusB:SetWide(100)
            focusB:DockMargin(0, 4, 4, 4)
            focusB:SetEnabled(tonumber(MH.OS.FocusServer) ~= tonumber(s.id))
            focusB.DoClick = function()
                MH.OS.FocusServer = tonumber(s.id)
                if MH.OS.Rebuild then MH.OS.Rebuild() end
            end
        end
    elseif MH.OS.HardwareView == "Upgrade server" then
        label(container, "Upgrading " .. tostring(srv.name) .. "   " .. tostring(srv.ip or ""), "DermaDefaultBold"):Dock(TOP)
        hardware_slot_row(container, srv, "cpu", "CPU", "MHz")
        hardware_slot_row(container, srv, "ram", "RAM", "MB")
        hardware_slot_row(container, srv, "hdd", "HDD", "MB")
    elseif MH.OS.HardwareView == "Buy new server" then
        local countServers = #(MH.OS.State.servers or {})
        local nextPrice = MH.Data.PCPrice(countServers)
        label(container, "Server slot " .. (countServers + 1), "DermaDefaultBold"):Dock(TOP)
        label(container, "Price: $" .. nextPrice):Dock(TOP)
        local bServer = vgui.Create("DButton", container)
        bServer:SetText("Buy server")
        bServer:Dock(TOP)
        bServer:DockMargin(0, 8, 0, 0)
        bServer:SetTall(32)
        bServer.DoClick = function() send_cmd("buy_server", {}) end
    elseif MH.OS.HardwareView == "Internet" then
        label(container, "Network connection on " .. tostring(srv.name), "DermaDefaultBold"):Dock(TOP)
        hardware_slot_row(container, srv, "net", "NET", "Mbps")
    elseif MH.OS.HardwareView == "External HD" then
        local xhds = srv.xhds or {}
        local xhdCount = #xhds
        label(container, "External HDs on " .. tostring(srv.name) .. "   (" .. xhdCount .. " mounted)", "DermaDefaultBold"):Dock(TOP)
        for _, x in ipairs(xhds) do
            local row = vgui.Create("DPanel", container)
            row:Dock(TOP)
            row:DockMargin(0, 4, 0, 0)
            row:SetTall(28)
            local xl = vgui.Create("DLabel", row)
            xl:SetDark(true)
            xl:SetFont("DermaDefaultBold")
            xl:SetText("   " .. tostring(x.name) .. "   cap tier " .. tostring(x.cap_tier))
            xl:Dock(LEFT)
            xl:SizeToContents()
            local xrn = vgui.Create("DButton", row)
            xrn:SetText("Rename")
            xrn:Dock(RIGHT)
            xrn:SetWide(100)
            xrn:DockMargin(0, 4, 10, 4)
            xrn.DoClick = function()
                Derma_StringRequest("Rename external HD", "New name:", tostring(x.name or ""), function(nm)
                    send_cmd("xhd_rename", { xhd_id = x.id, name = nm })
                end)
            end
        end
        local XHD_PRICES = { 100, 1000, 10000, 50000, 150000, 300000, 500000 }
        local nextXhdPrice = XHD_PRICES[math.min(xhdCount + 1, #XHD_PRICES)]
        local buyXhd = vgui.Create("DButton", container)
        buyXhd:SetText("Buy external HD   $" .. nextXhdPrice)
        buyXhd:Dock(TOP)
        buyXhd:DockMargin(0, 12, 0, 0)
        buyXhd:SetTall(32)
        buyXhd.DoClick = function() send_cmd("xhd_buy", { server_id = srv.id }) end
    end
end

MH.OS.SoftwareView = MH.OS.SoftwareView or "Softwares"

local function hdd_usage_for(srv)
    local tierIdx = tonumber(srv.hdd_tier or 1) or 1
    local tier = MH.Data.Hardware.hdd[tierIdx] or MH.Data.Hardware.hdd[1]
    local total = tier.mb
    local used = 0
    for _, s in ipairs(srv.software or {}) do
        if tonumber(s.on_xhd or 0) ~= 1 then
            used = used + (tonumber(s.soft_size or 0) or 0)
        end
    end
    used = used + (tonumber(srv.hidden_hdd_mb or 0) or 0)
    return used, total
end

local function xhd_usage_for(srv)
    local xhds = srv.xhds or {}
    local total = 0
    for _, x in ipairs(xhds) do
        local tier = MH.Data.Hardware.hdd[tonumber(x.cap_tier) or 1] or MH.Data.Hardware.hdd[1]
        total = total + tier.mb
    end
    local used = 0
    for _, s in ipairs(srv.software or {}) do
        if tonumber(s.on_xhd or 0) == 1 then
            used = used + (tonumber(s.soft_size or 0) or 0)
        end
    end
    return used, total
end

local function ram_usage_for(srv)
    local tierIdx = tonumber(srv.ram_tier or 1) or 1
    local tier = MH.Data.Hardware.ram[tierIdx] or MH.Data.Hardware.ram[1]
    local total = tier.mb
    local used = 0
    for _, s in ipairs(srv.software or {}) do
        if tonumber(s.installed or 0) == 1 then
            used = used + (tonumber(s.soft_ram or 0) or 0)
        end
    end
    used = used + (tonumber(srv.hidden_ram_mb or 0) or 0)
    return used, total
end

local function soft_row(parent, s, srv, isXHD)
    local meta = MH.Data.Soft[tonumber(s.soft_type or 0)] or {}
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:SetTall(28)
    row:DockMargin(0, 2, 0, 0)
    local function rcol(txt, wide, dock)
        local l = vgui.Create("DLabel", row)
        l:Dock(dock or LEFT)
        if wide then l:SetWide(wide) end
        l:SetDark(true)
        l:SetText("  " .. tostring(txt or ""))
    end
    local statusTxt
    if tonumber(s.installed or 0) == 1 then statusTxt = "Running"
    elseif tonumber(s.hidden or 0) == 1 then statusTxt = "Hidden"
    else statusTxt = "" end
    rcol((s.soft_name or "unknown") .. (meta.ext or ""), 180)
    rcol(meta.name or ("#" .. tostring(s.soft_type)), 110)
    rcol("v" .. MH.Data.DotVersion(s.soft_version), 60)
    rcol(tostring(s.soft_size or 0) .. " MB", 60)
    rcol(statusTxt, 70)
    local actions = vgui.Create("DPanel", row)
    actions:Dock(RIGHT)
    actions:SetWide(isXHD and 220 or 360)
    local function add_btn(text, cb, w)
        local b = vgui.Create("DButton", actions)
        b:SetText(text)
        b:Dock(LEFT)
        b:SetWide(w or 70)
        b:DockMargin(0, 2, 2, 2)
        b.DoClick = cb
        return b
    end
    if isXHD then
        add_btn("Rename", function()
            Derma_StringRequest("Rename file", "New name:", tostring(s.soft_name or ""), function(nm)
                send_cmd("soft_rename", { soft_id = s.id, name = nm })
            end)
        end)
        add_btn("Download", function()
            send_cmd("soft_action", { soft_id = s.id, action = "install" })
        end, 90)
        add_btn("Delete", function()
            Derma_Query("Delete " .. tostring(s.soft_name or "file") .. "?",
                "Delete file", "Delete",
                function() send_cmd("soft_action", { soft_id = s.id, action = "delete" }) end,
                "Cancel", function() end)
        end)
    else
        local toolOwned = { [5] = 0, [6] = 0, [7] = 0 }
        for _, inv in ipairs(srv.software or {}) do
            local st = tonumber(inv.soft_type)
            if toolOwned[st] ~= nil and tonumber(inv.installed) == 1 then
                toolOwned[st] = math.max(toolOwned[st], tonumber(inv.soft_version) or 0)
            end
        end
        add_btn("Info", function()
            local meta = MH.Data.Soft[tonumber(s.soft_type or 0)] or {}
            Derma_Message(
                "Name: " .. tostring(s.soft_name or "?") .. (meta.ext or "") ..
                "\nType: " .. (meta.name or ("#" .. tostring(s.soft_type))) ..
                "\nVersion: " .. MH.Data.DotVersion(s.soft_version) ..
                "\nSize: " .. tostring(s.soft_size or 0) .. " MB" ..
                "\nRAM: " .. tostring(s.soft_ram or 0) .. " MB" ..
                "\nStatus: " .. (tonumber(s.installed) == 1 and "Running" or
                                 (tonumber(s.hidden) == 1 and "Hidden" or "Idle")),
                "File info", "OK")
        end)
        if tonumber(s.soft_type) == 30 then
            add_btn("Edit", function() open_text_editor(s, false) end)
        end
        add_btn(tonumber(s.installed) == 1 and "Stop" or "Run", function()
            send_cmd("soft_action", { soft_id = s.id,
                action = tonumber(s.installed) == 1 and "uninstall" or "install" })
        end)
        local isHidden = tonumber(s.hidden) == 1
        local toolType = isHidden and 6 or 5
        local toolName = isHidden and "Seeker" or "Hider"
        local hsBtn = add_btn(isHidden and "Seek" or "Hide", function()
            send_cmd("soft_action", { soft_id = s.id, action = isHidden and "seek" or "hide" })
        end)
        if toolOwned[toolType] <= 0 then
            hsBtn:SetEnabled(false)
            hsBtn:SetTooltip("Install a " .. toolName .. " first")
        end
        add_btn("Rename", function()
            Derma_StringRequest("Rename file", "New name:", tostring(s.soft_name or ""), function(nm)
                send_cmd("soft_rename", { soft_id = s.id, name = nm })
            end)
        end)
        add_btn("Delete", function()
            Derma_Query("Delete " .. tostring(s.soft_name or "file") .. "?",
                "Delete file", "Delete",
                function() send_cmd("soft_action", { soft_id = s.id, action = "delete" }) end,
                "Cancel", function() end)
        end)
    end
end

Tabs["Software"] = function(container)
    clear(container)
    local srv = current_server()
    if not srv then
        label(container, "No servers owned"):Dock(TOP)
        return
    end

    local subbar = vgui.Create("DPanel", container)
    subbar:Dock(TOP)
    subbar:SetTall(28)
    for _, name in ipairs({ "Softwares", "External HD" }) do
        local b = vgui.Create("DButton", subbar)
        b:SetText(name)
        b:Dock(LEFT)
        b:SetWide(140)
        b:DockMargin(0, 0, 4, 0)
        b.DoClick = function()
            MH.OS.SoftwareView = name
            if MH.OS.Rebuild then MH.OS.Rebuild() end
        end
    end
    local newTxt = vgui.Create("DButton", subbar)
    newTxt:SetText("New text file")
    newTxt:Dock(RIGHT)
    newTxt:SetWide(120)
    newTxt:DockMargin(0, 2, 6, 2)
    newTxt.DoClick = function()
        Derma_StringRequest("New text file", "File name:", "note", function(nm)
            send_cmd("soft_text_create", { server_id = srv.id, name = nm, content = "" })
        end)
    end

    local avOwned = 0
    for _, inv in ipairs(srv.software or {}) do
        if tonumber(inv.soft_type) == 7 and tonumber(inv.installed) == 1 then
            avOwned = math.max(avOwned, tonumber(inv.soft_version) or 0)
        end
    end
    local avScan = vgui.Create("DButton", subbar)
    avScan:SetText("AV scan")
    avScan:Dock(RIGHT)
    avScan:SetWide(90)
    avScan:DockMargin(0, 2, 6, 2)
    avScan.DoClick = function()
        send_cmd("av_scan", { scope = "local", server_id = srv.id })
    end
    if avOwned <= 0 then
        avScan:SetEnabled(false)
        avScan:SetTooltip("Install an Antivirus first")
    end

    local hUsed, hTotal = hdd_usage_for(srv)
    local rUsed, rTotal = ram_usage_for(srv)
    local xUsed, xTotal = xhd_usage_for(srv)
    local sidebar = vgui.Create("DPanel", container)
    sidebar:Dock(RIGHT)
    sidebar:SetWide(220)
    sidebar:SetTall(500)
    sidebar:DockMargin(10, 6, 0, 0)
    local pies = {}
    local hdd = usage_pie(sidebar, 110, "HDD", hUsed, hTotal)
    hdd:Dock(TOP)
    hdd:DockMargin(0, 4, 0, 8)
    table.insert(pies, hdd)
    local ram = usage_pie(sidebar, 110, "RAM", rUsed, rTotal)
    ram:Dock(TOP)
    ram:DockMargin(0, 0, 0, 8)
    table.insert(pies, ram)
    if xTotal > 0 then
        local xhd = usage_pie(sidebar, 110, "XHD", xUsed, xTotal)
        xhd:Dock(TOP)
        xhd:DockMargin(0, 0, 0, 8)
        table.insert(pies, xhd)
    end
    sidebar:InvalidateLayout(true)
    container:InvalidateLayout(true)
    local canvas = container.GetCanvas and container:GetCanvas() or nil
    if canvas then canvas:InvalidateLayout(true) end
    for _, p in ipairs(pies) do p:InvalidateLayout(true) end

    local heading = vgui.Create("DPanel", container)
    heading:Dock(TOP)
    heading:SetTall(22)
    heading:DockMargin(0, 8, 0, 0)
    local function hcol(txt, wide, dock)
        local l = vgui.Create("DLabel", heading)
        l:Dock(dock or LEFT)
        if wide then l:SetWide(wide) end
        l:SetDark(true)
        l:SetFont("DermaDefaultBold")
        l:SetText("  " .. txt)
    end
    hcol("File",    180)
    hcol("Type",    110)
    hcol("Version", 60)
    hcol("Size",    60)
    hcol("Status",  70)
    hcol("Actions", nil, FILL)

    local softScroll = vgui.Create("DScrollPanel", container)
    softScroll:Dock(TOP)
    softScroll:SetTall(560)
    softScroll:DockMargin(0, 4, 0, 0)

    if MH.OS.SoftwareView == "External HD" then
        local xhds = srv.xhds or {}
        if #xhds == 0 then
            label(container, "No external drives mounted."):Dock(TOP)
            return
        end
        for _, s in ipairs(srv.software or {}) do
            if tonumber(s.on_xhd or 0) == 1 then soft_row(softScroll, s, srv, true) end
        end
        return
    end

    for _, s in ipairs(srv.software or {}) do
        if tonumber(s.on_xhd or 0) == 0 or s.on_xhd == nil then
            soft_row(softScroll, s, srv, false)
        end
    end
end

MH.OS.InternetView = MH.OS.InternetView or "Index"

local function set_cell_paint(btn, text, color)
    btn:SetText(text or "")
    btn.MH_Color = color
    btn.Paint = function(self, w, h)
        surface.SetDrawColor(self.MH_Color or Color(60, 60, 60))
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(20, 20, 20)
        surface.DrawOutlinedRect(0, 0, w, h)
    end
end

function MH.OS.RenderTicTacToe(parent, on_done)
    local status = vgui.Create("DLabel", parent)
    status:Dock(TOP)
    status:DockMargin(0, 8, 0, 0)
    status:SetDark(true)
    status:SetText("You are O. Click to place.")

    local grid = vgui.Create("DPanel", parent)
    grid:Dock(TOP)
    grid:SetTall(320)
    grid:DockMargin(0, 8, 0, 0)
    grid.Paint = function() end

    local board = { 0, 0, 0, 0, 0, 0, 0, 0, 0 }
    local cells = {}
    local gameOver = false
    local function winner()
        local lines = { {1,2,3},{4,5,6},{7,8,9},{1,4,7},{2,5,8},{3,6,9},{1,5,9},{3,5,7} }
        for _, L in ipairs(lines) do
            local a, b, c = board[L[1]], board[L[2]], board[L[3]]
            if a ~= 0 and a == b and b == c then return a end
        end
        local full = true
        for i = 1, 9 do if board[i] == 0 then full = false break end end
        if full then return 0 end
        return nil
    end
    local function redraw()
        for i = 1, 9 do
            local v = board[i]
            local txt = v == 1 and "X" or (v == 2 and "O" or "")
            local col = v == 1 and Color(120, 60, 60) or (v == 2 and Color(60, 80, 120) or Color(60, 60, 60))
            set_cell_paint(cells[i], txt, col)
        end
    end
    local function ai_move()
        local empties = {}
        for i = 1, 9 do if board[i] == 0 then empties[#empties + 1] = i end end
        if #empties == 0 then return end
        local pick = empties[math.random(1, #empties)]
        board[pick] = 1
    end
    local function check_end()
        local w = winner()
        if w == 2 then
            gameOver = true
            status:SetText("You win. Submitting...")
            timer.Simple(0.3, function() if on_done then on_done() end end)
            return true
        elseif w == 1 then
            gameOver = true
            status:SetText("Lost. Click Restart to try again.")
            return true
        elseif w == 0 then
            gameOver = true
            status:SetText("Draw. Click Restart to try again.")
            return true
        end
    end

    local gridW = 300
    local cellW = (gridW - 20) / 3
    for i = 1, 9 do
        local r = math.floor((i - 1) / 3)
        local c = (i - 1) % 3
        local b = vgui.Create("DButton", grid)
        b:SetSize(cellW, cellW)
        b:SetPos(c * (cellW + 4), r * (cellW + 4))
        b:SetFont("DermaLarge")
        b.DoClick = function()
            if gameOver or board[i] ~= 0 then return end
            board[i] = 2
            redraw()
            if check_end() then return end
            ai_move()
            redraw()
            check_end()
        end
        cells[i] = b
    end
    redraw()

    local restartB = vgui.Create("DButton", parent)
    restartB:Dock(TOP)
    restartB:SetTall(28)
    restartB:DockMargin(0, 8, 0, 0)
    restartB:SetText("Restart")
    restartB.DoClick = function()
        for i = 1, 9 do board[i] = 0 end
        gameOver = false
        status:SetText("You are O. Click to place.")
        redraw()
    end
end

function MH.OS.RenderLightsOut(parent, on_done)
    local status = vgui.Create("DLabel", parent)
    status:Dock(TOP)
    status:DockMargin(0, 8, 0, 0)
    status:SetDark(true)
    status:SetText("Turn off every light.")

    local grid = vgui.Create("DPanel", parent)
    grid:Dock(TOP)
    grid:SetTall(320)
    grid:DockMargin(0, 8, 0, 0)
    grid.Paint = function() end

    local SIZE = 5
    local board = {}
    local cells = {}
    local function idx(r, c) return (r - 1) * SIZE + c end

    local function redraw()
        for r = 1, SIZE do
            for c = 1, SIZE do
                local v = board[idx(r, c)]
                set_cell_paint(cells[idx(r, c)], "", v == 1 and Color(220, 190, 80) or Color(50, 50, 60))
            end
        end
    end
    local function toggle(r, c)
        if r < 1 or r > SIZE or c < 1 or c > SIZE then return end
        board[idx(r, c)] = 1 - board[idx(r, c)]
    end
    local function all_off()
        for i = 1, SIZE * SIZE do if board[i] == 1 then return false end end
        return true
    end
    local function scramble()
        for i = 1, SIZE * SIZE do board[i] = 0 end
        for _ = 1, 7 do
            local r = math.random(1, SIZE)
            local c = math.random(1, SIZE)
            toggle(r, c) toggle(r - 1, c) toggle(r + 1, c) toggle(r, c - 1) toggle(r, c + 1)
        end
        if all_off() then toggle(1, 1); toggle(2, 1); toggle(1, 2) end
    end

    local cellW = 56
    local pad = 4
    for r = 1, SIZE do
        for c = 1, SIZE do
            local b = vgui.Create("DButton", grid)
            b:SetSize(cellW, cellW)
            b:SetPos((c - 1) * (cellW + pad), (r - 1) * (cellW + pad))
            b.DoClick = function()
                toggle(r, c) toggle(r - 1, c) toggle(r + 1, c) toggle(r, c - 1) toggle(r, c + 1)
                redraw()
                if all_off() then
                    status:SetText("Cleared. Submitting...")
                    timer.Simple(0.3, function() if on_done then on_done() end end)
                end
            end
            cells[idx(r, c)] = b
        end
    end
    scramble()
    redraw()

    local resetB = vgui.Create("DButton", parent)
    resetB:Dock(TOP)
    resetB:SetTall(28)
    resetB:DockMargin(0, 8, 0, 0)
    resetB:SetText("New board")
    resetB.DoClick = function()
        scramble()
        redraw()
        status:SetText("Turn off every light.")
    end
end

function MH.OS.RenderMemSequence(parent, on_done)
    local status = vgui.Create("DLabel", parent)
    status:Dock(TOP)
    status:DockMargin(0, 8, 0, 0)
    status:SetDark(true)
    status:SetText("Press Start to begin.")

    local grid = vgui.Create("DPanel", parent)
    grid:Dock(TOP)
    grid:SetTall(320)
    grid:DockMargin(0, 8, 0, 0)
    grid.Paint = function() end

    local SIZE = 3
    local cells = {}
    local sequence = {}
    local inputIndex = 1
    local acceptInput = false
    local flashColor = Color(240, 220, 80)
    local idleColor = Color(60, 60, 60)
    local target = 6

    local function idx(r, c) return (r - 1) * SIZE + c end
    local function paint_cell(i, color) set_cell_paint(cells[i], "", color or idleColor) end
    local function paint_all_idle()
        for i = 1, SIZE * SIZE do paint_cell(i, idleColor) end
    end

    local function play_sequence(after)
        acceptInput = false
        paint_all_idle()
        local step = 1
        local function tick()
            if step > #sequence then
                paint_all_idle()
                acceptInput = true
                inputIndex = 1
                status:SetText("Repeat the sequence (" .. #sequence .. "/" .. target .. ")")
                if after then after() end
                return
            end
            paint_cell(sequence[step], flashColor)
            timer.Simple(0.4, function()
                paint_cell(sequence[step], idleColor)
                step = step + 1
                timer.Simple(0.2, tick)
            end)
        end
        tick()
    end

    local function start()
        sequence = { math.random(1, SIZE * SIZE) }
        status:SetText("Watch...")
        play_sequence()
    end

    local function next_round()
        sequence[#sequence + 1] = math.random(1, SIZE * SIZE)
        status:SetText("Watch (" .. #sequence .. ")...")
        play_sequence()
    end

    local cellW = 90
    local pad = 6
    for r = 1, SIZE do
        for c = 1, SIZE do
            local b = vgui.Create("DButton", grid)
            b:SetSize(cellW, cellW)
            b:SetPos((c - 1) * (cellW + pad), (r - 1) * (cellW + pad))
            local id = idx(r, c)
            b.DoClick = function()
                if not acceptInput then return end
                paint_cell(id, flashColor)
                timer.Simple(0.15, function() paint_cell(id, idleColor) end)
                if sequence[inputIndex] == id then
                    inputIndex = inputIndex + 1
                    if inputIndex > #sequence then
                        acceptInput = false
                        if #sequence >= target then
                            status:SetText("Cleared length " .. target .. ". Submitting...")
                            timer.Simple(0.4, function() if on_done then on_done() end end)
                        else
                            timer.Simple(0.5, next_round)
                        end
                    end
                else
                    acceptInput = false
                    status:SetText("Wrong. Press Start to try again.")
                end
            end
            cells[id] = b
        end
    end
    paint_all_idle()

    local startB = vgui.Create("DButton", parent)
    startB:Dock(TOP)
    startB:SetTall(28)
    startB:DockMargin(0, 8, 0, 0)
    startB:SetText("Start")
    startB.DoClick = function() start() end
end

function MH.OS.OpenRiddlePopup(inet)
    local p = inet and inet.puzzle
    if not p then return end
    local f = vgui.Create("DFrame")
    f:SetTitle("Riddle.rdl - Puzzle " .. tostring(inet.puzzle_index or 0))
    f:SetSize(560, 540)
    f:Center()
    f:SetDeleteOnClose(true)
    f:MakePopup()

    if p.name and p.name ~= "" then
        label(f, tostring(p.name), "DermaDefaultBold"):Dock(TOP)
    end
    local qBox = vgui.Create("DTextEntry", f)
    qBox:Dock(TOP)
    qBox:SetTall(80)
    qBox:DockMargin(8, 8, 8, 0)
    qBox:SetMultiline(true)
    qBox:SetEditable(false)
    qBox:SetVerticalScrollbarEnabled(true)
    qBox:SetValue(tostring(p.question or ""))

    local function send_minigame_done()
        send_cmd("puzzle_solve", { puzzle_id = p.id, kind = p.kind, done = true })
        timer.Simple(0.1, function() if IsValid(f) then f:Close() end end)
    end

    local body = vgui.Create("DPanel", f)
    body:Dock(FILL)
    body:DockMargin(8, 8, 8, 8)
    body.Paint = function() end

    local kind = tostring(p.kind or "qa")
    if kind == "qa" then
        local answerRow = vgui.Create("DPanel", body)
        answerRow:Dock(TOP)
        answerRow:SetTall(32)
        answerRow:DockMargin(0, 4, 0, 0)
        local answerEntry = vgui.Create("DTextEntry", answerRow)
        answerEntry:Dock(FILL)
        answerEntry:SetPlaceholderText("Your answer")
        local submitB = vgui.Create("DButton", answerRow)
        submitB:Dock(RIGHT)
        submitB:SetWide(130)
        submitB:DockMargin(6, 0, 0, 0)
        submitB:SetText("Submit")
        local function submit()
            send_cmd("puzzle_solve", { puzzle_id = p.id, answer = answerEntry:GetValue() })
            timer.Simple(0.1, function() if IsValid(f) then f:Close() end end)
        end
        submitB.DoClick = submit
        answerEntry.OnEnter = submit
        if p.hint and p.hint ~= "" then
            local hintB = vgui.Create("DButton", body)
            hintB:Dock(TOP)
            hintB:SetTall(26)
            hintB:DockMargin(0, 8, 0, 0)
            hintB:SetText("Show hint")
            local shown = false
            hintB.DoClick = function()
                if shown then return end
                shown = true
                hintB:SetText("Hint shown")
                hintB:SetEnabled(false)
                local hintLabel = vgui.Create("DLabel", body)
                hintLabel:Dock(TOP)
                hintLabel:DockMargin(0, 4, 0, 0)
                hintLabel:SetWrap(true)
                hintLabel:SetAutoStretchVertical(true)
                hintLabel:SetDark(true)
                hintLabel:SetText("Hint: " .. tostring(p.hint))
            end
        end
    elseif kind == "tictactoe" then
        MH.OS.RenderTicTacToe(body, send_minigame_done)
    elseif kind == "lightsout" then
        MH.OS.RenderLightsOut(body, send_minigame_done)
    elseif kind == "memsequence" then
        MH.OS.RenderMemSequence(body, send_minigame_done)
    else
        label(body, "Unknown puzzle kind: " .. kind):Dock(TOP)
    end
end

Tabs["Internet"] = function(container)
    clear(container)
    label(container, "Internet", "DermaLarge"):Dock(TOP)

    local inet = MH.OS.State.internet

    local bar = vgui.Create("DPanel", container)
    bar:Dock(TOP)
    bar:SetTall(32)
    bar:DockMargin(0, 4, 0, 6)
    local urlLbl = vgui.Create("DLabel", bar)
    urlLbl:SetDark(true)
    urlLbl:SetFont("DermaDefaultBold")
    urlLbl:SetText("Address:")
    urlLbl:Dock(LEFT)
    urlLbl:DockMargin(0, 6, 6, 0)
    urlLbl:SizeToContents()
    local urlEntry = vgui.Create("DTextEntry", bar)
    urlEntry:Dock(FILL)
    urlEntry:SetText(inet and inet.ip or "")
    urlEntry:SetPlaceholderText("Target IP")
    local goB = button(bar, "Go", function()
        send_cmd("internet_goto", { ip = urlEntry:GetValue() })
    end)
    goB:Dock(RIGHT)
    goB:SetWide(60)
    goB:DockMargin(4, 0, 0, 0)
    local scanB = button(bar, "Scan", function()
        send_cmd("scan_ip", { ip = urlEntry:GetValue() })
    end)
    scanB:Dock(RIGHT)
    scanB:SetWide(60)
    scanB:DockMargin(4, 0, 0, 0)
    do
        local primary = (MH.OS.State.servers or {})[1]
        local hasPortScan = false
        for _, s in ipairs(primary and primary.software or {}) do
            if tonumber(s.soft_type) == 3 and tonumber(s.soft_version or 0) > 0 and tonumber(s.installed or 0) == 1 then
                hasPortScan = true
                break
            end
        end
        if not hasPortScan then
            scanB:SetEnabled(false)
            scanB:SetTooltip("Install a Port Scan to use this.")
        end
    end
    local refreshB = button(bar, "Refresh", function()
        if MH.OS.Rebuild then MH.OS.Rebuild() end
    end)
    refreshB:Dock(RIGHT)
    refreshB:SetWide(70)
    refreshB:DockMargin(4, 0, 0, 0)
    local homeB = button(bar, "Home", function()
        local svcs = MH.OS.State.public_services or {}
        local disc = {}
        for _, d in ipairs(MH.OS.State.discovered or {}) do disc[tonumber(d.id)] = true end
        local pick
        for _, key in ipairs({ "WHOIS3", "WHOIS2", "DIRECTORY" }) do
            local svc = svcs[key]
            if svc and disc[tonumber(svc.id)] then pick = svc break end
        end
        if pick then
            send_cmd("internet_goto", { ip = tostring(pick.ip) })
        end
    end)
    homeB:Dock(RIGHT)
    homeB:SetWide(60)
    homeB:DockMargin(4, 0, 0, 0)

    local sidebar = vgui.Create("DPanel", container)
    sidebar:Dock(RIGHT)
    sidebar:SetWide(220)
    sidebar:SetTall(680)
    sidebar:DockMargin(10, 0, 0, 0)
    local function side_header(text)
        local l = vgui.Create("DLabel", sidebar)
        l:Dock(TOP)
        l:DockMargin(6, 8, 6, 2)
        l:SetDark(true)
        l:SetFont("DermaDefaultBold")
        l:SetText(text)
        l:SizeToContents()
    end
    local function side_link(name, ip)
        local b = vgui.Create("DButton", sidebar)
        b:SetText(name .. "   " .. ip)
        b:Dock(TOP)
        b:DockMargin(6, 2, 6, 0)
        b:SetTall(24)
        b.DoClick = function()
            send_cmd("internet_goto", { ip = ip })
        end
    end

    local disc = MH.OS.State.discovered or {}
    local important, generic = {}, {}
    local importantNames = {
        ["First Whois"] = true, ["Second Whois"] = true, ["Third Whois"] = true,
        ["Fourth Whois"] = true,
        ["Download Center"] = true, ["ISP"] = true,
        ["Bitcoin Market"] = true, ["Sourcenet"] = true,
        ["Employers"] = true, ["MSA"] = true,
    }
    for _, s in ipairs(disc) do
        local nm = tostring(s.name or "")
        local isBank = string.find(string.lower(nm), "bank") ~= nil
        if importantNames[nm] or isBank then
            table.insert(important, s)
        else
            table.insert(generic, s)
        end
    end
    local function by_name(a, b)
        return tostring(a.name or ""):lower() < tostring(b.name or ""):lower()
    end
    table.sort(important, by_name)
    side_header("Important IPs")
    if #important == 0 then
        local l = vgui.Create("DLabel", sidebar)
        l:Dock(TOP) l:DockMargin(10, 2, 6, 0) l:SetDark(true)
        l:SetText("None discovered yet.") l:SizeToContents()
    else
        for _, s in ipairs(important) do side_link(s.name, s.ip) end
    end
    if #generic > 0 then
        side_header("History")
        local shown = 0
        for _, s in ipairs(generic) do
            if shown >= 5 then break end
            side_link(s.name, s.ip)
            shown = shown + 1
        end
    end

    local body = vgui.Create("DPanel", container)
    body:Dock(TOP)
    body:SetTall(680)

    if not inet then
        return
    end

    local topInfo = vgui.Create("DLabel", body)
    topInfo:Dock(TOP)
    topInfo:SetDark(true)
    topInfo:SetFont("DermaDefaultBold")
    topInfo:SetText("Target: " .. tostring(inet.ip) .. "  (" .. tostring(inet.name) .. ")" ..
        (inet.authed and "  [Logged in]" or "  [Not authenticated]"))

    local whoisTier = ({ ["First Whois"] = 1, ["Second Whois"] = 2, ["Third Whois"] = 3, ["Fourth Whois"] = 4 })[tostring(inet.name)]
    if whoisTier then
        label(body, tostring(inet.name) .. " directory", "DermaDefaultBold"):Dock(TOP)
        local svcs = MH.OS.State.public_services or {}
        local discoveredIds = {}
        for _, d in ipairs(MH.OS.State.discovered or {}) do
            discoveredIds[tonumber(d.id)] = true
        end
        local WHOIS_CONTENTS = {
            [1] = {
                { key = "DC",        blurb = "Public Downloads Server" },
                { key = "TORRENT",   blurb = "Torrent hub." },
                { key = "PUZZLE_1",  blurb = "First puzzle." },
                { key = "BANK1",     blurb = "Your everyday provider for your financial needs." },
                { key = "EMPLOYERS", blurb = "Some believe the fate of our worlds is inflexible." },
                { key = "SOURCENET",   blurb = "Keeping you safe since 1984." },
                { key = "ISP",       blurb = "Your Internet Service Provider" },
                { key = "MSA",       blurb = "Metastruct Security Agency." },
                { key = "PUZZLE_5",  blurb = "Fifth puzzle." },
                { key = "WHOIS2",    blurb = "Second Whois" },
            },
            [2] = {
                { key = "BANK2",     blurb = "Banking refined." },
                { key = "PUZZLE_15", blurb = "Puzzle 15" },
                { key = "BANK3",     blurb = "Our rates are unbeatable!" },
                { key = "PUZZLE_22", blurb = "Puzzle 22" },
                { key = "PUZZLE_11", blurb = "Puzzle 11" },
                { key = "EMPLOYERS", blurb = "Some believe the fate of our worlds is inflexible." },
                { key = "WHOIS3",    blurb = "Third Whois" },
            },
            [3] = {
                { key = "BANK4",     blurb = "Swiss Excellence." },
                { key = "PUZZLE_35", blurb = "Puzzle 35" },
                { key = "PUZZLE_28", blurb = "Puzzle 28" },
                { key = "FBI",       blurb = "Federal Bureau of Investigation." },
                { key = "BITCOIN",   blurb = "Your Crypto Marketplace" },
                { key = "BANK5",     blurb = "Only for the most distinguished clients." },
                { key = "PUZZLE_47", blurb = "Final puzzle of the chain." },
                { key = "MD",        blurb = "MD - corporate target with secrets." },
                { key = "GOOSECORP", blurb = "GooseCorp - endgame corporate hit." },
                { key = "WHOIS4",    blurb = "Fourth Whois" },
            },
            [4] = {
                { key = "PUZZLE_36", blurb = "Puzzle 36" },
                { key = "PUZZLE_40", blurb = "Puzzle 40" },
                { key = "PUZZLE_42", blurb = "Puzzle 42" },
                { key = "PUZZLE_45", blurb = "Puzzle 45" },
            },
        }
        local entries = WHOIS_CONTENTS[whoisTier] or {}
        local visible = {}
        for _, e in ipairs(entries) do
            local svc = svcs[e.key]
            local gated = (e.key == "WHOIS2") or (e.key == "WHOIS3") or (e.key == "WHOIS4")
                or (string.sub(e.key, 1, 7) == "PUZZLE_" and e.key ~= "PUZZLE_1")
            if svc and (not gated or discoveredIds[tonumber(svc.id)]) then
                visible[#visible + 1] = { svc = svc, blurb = e.blurb }
            end
        end
        if #visible == 0 then
            label(body, "No services on file for this directory."):Dock(TOP)
            return
        end
        local actionBar = vgui.Create("DPanel", body)
        actionBar:Dock(BOTTOM)
        actionBar:SetTall(32)
        actionBar:DockMargin(0, 8, 0, 0)
        local visitB = vgui.Create("DButton", actionBar)
        visitB:Dock(RIGHT)
        visitB:SetWide(160)
        visitB:SetText("Visit")
        visitB:SetEnabled(true)

        local svcList = vgui.Create("DListView", body)
        svcList:Dock(TOP)
        svcList:SetTall(200)
        svcList:DockMargin(0, 8, 0, 0)
        svcList:AddColumn("Service"):SetFixedWidth(220)
        svcList:AddColumn("IP"):SetFixedWidth(160)
        svcList:AddColumn("What it does")
        local selectedIP
        for _, v in ipairs(visible) do
            local line = svcList:AddLine(v.svc.name, v.svc.ip, v.blurb)
            line.MH_IP = v.svc.ip
            line.DoDoubleClick = function()
                send_cmd("internet_goto", { ip = line.MH_IP })
            end
        end
        svcList.OnRowSelected = function(_, _, lineRef)
            selectedIP = lineRef and lineRef.MH_IP or nil
            visitB:SetText(selectedIP and ("Visit " .. selectedIP) or "Visit")
        end
        visitB.DoClick = function()
            if selectedIP then
                send_cmd("internet_goto", { ip = selectedIP })
                return
            end
            local lineID = svcList:GetSelectedLine()
            local lineRef = lineID and svcList:GetLine(lineID)
            if lineRef and lineRef.MH_IP then
                send_cmd("internet_goto", { ip = lineRef.MH_IP })
            end
        end
        svcList.OnRowRightClick = function(_, _, lineRef)
            if not lineRef or not lineRef.MH_IP then return end
            local m = DermaMenu()
            m:AddOption("Visit " .. lineRef.MH_IP, function()
                send_cmd("internet_goto", { ip = lineRef.MH_IP })
            end)
            m:Open()
        end
    end

    if inet.is_bitcoin then
        local p = MH.OS.State.player or {}
        label(body, "Bitcoin Market", "DermaLarge"):Dock(TOP)

        label(body, "Your wallet", "DermaDefaultBold"):Dock(TOP)
        label(body, "Address: " .. tostring(p.btc_address or "unassigned")):Dock(TOP)
        label(body, "Balance: " .. string.format("%.7f", tonumber(p.bitcoin or 0)) .. " BTC"):Dock(TOP)

        label(body, "Buy BTC   Rate: $81,629 / BTC", "DermaDefaultBold"):Dock(TOP)
        local xrow = vgui.Create("DPanel", body)
        xrow:Dock(TOP) xrow:SetTall(32) xrow:DockMargin(0, 6, 0, 0)
        local xamt = vgui.Create("DTextEntry", xrow)
        xamt:Dock(LEFT) xamt:SetWide(140) xamt:SetPlaceholderText("cash amount")
        local buyB = button(xrow, "Buy BTC", function()
            send_cmd("btc_buy", { cash = tonumber(xamt:GetValue()) })
        end)
        buyB:Dock(LEFT) buyB:SetWide(130) buyB:DockMargin(4, 0, 0, 0)

        label(body, "Transfer BTC to another player", "DermaDefaultBold"):Dock(TOP)
        local btrow = vgui.Create("DPanel", body)
        btrow:Dock(TOP) btrow:SetTall(32) btrow:DockMargin(0, 6, 0, 0)
        local btTo = vgui.Create("DTextEntry", btrow)
        btTo:Dock(LEFT) btTo:SetWide(200) btTo:SetPlaceholderText("recipient (SteamID64 or nick)")
        local btAmt = vgui.Create("DTextEntry", btrow)
        btAmt:Dock(LEFT) btAmt:SetWide(120) btAmt:SetPlaceholderText("BTC amount") btAmt:DockMargin(4, 0, 0, 0)
        local btSend = button(btrow, "Send", function()
            send_cmd("btc_transfer", { to = btTo:GetValue(), amount = tonumber(btAmt:GetValue()) })
        end)
        btSend:Dock(LEFT) btSend:SetWide(80) btSend:DockMargin(4, 0, 0, 0)
        return
    end

    local function render_target_processes(parent, headerText)
        local targetId = tonumber(inet.id or 0)
        local matches = {}
        for _, p in ipairs(MH.OS.State.all_processes or {}) do
            if tonumber(p.victim_server or 0) == targetId or tonumber(p.local_server or 0) == targetId then
                table.insert(matches, p)
            end
        end
        if #matches == 0 then return end
        label(parent, headerText or "Active processes against this target", "DermaDefaultBold"):Dock(TOP)
        for _, p in ipairs(matches) do proc_row(parent, p) end
    end

    if not inet.authed then
        label(body, "Login or attempt to Bruteforce / Exploit to gain access.", "DermaDefault"):Dock(TOP)
        local loginRow = vgui.Create("DPanel", body)
        loginRow:Dock(TOP)
        loginRow:SetTall(32)
        loginRow:DockMargin(0, 8, 0, 0)
        local userEntry = vgui.Create("DTextEntry", loginRow)
        userEntry:Dock(LEFT)
        userEntry:SetWide(140)
        userEntry:SetPlaceholderText("username (root)")
        local passEntry = vgui.Create("DTextEntry", loginRow)
        passEntry:Dock(FILL)
        passEntry:DockMargin(4, 0, 0, 0)
        passEntry:SetPlaceholderText("password")
        local isDC = tostring(inet.name) == "Download Center"
        local hasSaved = inet.saved_pass and tostring(inet.saved_pass) ~= ""
        if hasSaved then
            userEntry:SetText("root")
            passEntry:SetText(tostring(inet.saved_pass))
        elseif isDC then
            userEntry:SetText("download")
            passEntry:SetText("download")
        else
            userEntry:SetText("root")
        end
        local loginB = button(loginRow, "Login", function()
            send_cmd("internet_login", { user = userEntry:GetValue(), pass = passEntry:GetValue() })
        end)
        loginB:Dock(RIGHT)
        loginB:SetWide(80)
        loginB:DockMargin(4, 0, 0, 0)

        if inet.web_image and inet.web_image ~= "" then
            local webBox = vgui.Create("DPanel", body)
            webBox:Dock(TOP)
            webBox:SetTall(300)
            webBox:DockMargin(0, 10, 0, 0)
            local src = tostring(inet.web_image)
            local bind = surface.LazyURLImage and surface.LazyURLImage(src)
            webBox.Paint = function(self, w, h)
                if not bind then return end
                bind()
                local size = math.min(w, h)
                local x = math.floor((w - size) / 2)
                local y = math.floor((h - size) / 2)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.DrawTexturedRect(x, y, size, size)
            end
        end

        local attackerSoft = {}
        local primary = (MH.OS.State.servers or {})[1]
        for _, s in ipairs(primary and primary.software or {}) do
            local t = tonumber(s.soft_type)
            local v = tonumber(s.soft_version) or 0
            if (attackerSoft[t] or 0) < v then attackerSoft[t] = v end
        end
        local certLvl = tonumber((MH.OS.State.player or {}).cert_level or 0) or 0

        local tiles = vgui.Create("DPanel", body)
        tiles:Dock(TOP)
        tiles:SetTall(140)
        tiles:DockMargin(0, 8, 0, 0)

        local function build_tile(parent, title, headline, ok, disabledReason, onClick)
            local tile = vgui.Create("DPanel", parent)
            tile:Dock(LEFT)
            tile:SetWide(260)
            tile:DockMargin(0, 0, 10, 0)
            local t = vgui.Create("DLabel", tile)
            t:Dock(TOP)
            t:DockMargin(10, 10, 10, 0)
            t:SetDark(true)
            t:SetFont("DermaLarge")
            t:SetText(title)
            t:SizeToContents()
            local h = vgui.Create("DLabel", tile)
            h:Dock(TOP)
            h:DockMargin(10, 6, 10, 0)
            h:SetDark(true)
            h:SetText(headline)
            h:SizeToContents()
            if not ok then
                local d = vgui.Create("DLabel", tile)
                d:Dock(TOP)
                d:DockMargin(10, 2, 10, 0)
                d:SetDark(true)
                d:SetText(disabledReason or "Unavailable")
                d:SizeToContents()
            end
            local b = vgui.Create("DButton", tile)
            b:Dock(BOTTOM)
            b:DockMargin(10, 0, 10, 10)
            b:SetTall(28)
            b:SetText(ok and "Launch" or "Unavailable")
            b:SetEnabled(ok)
            b.DoClick = onClick
            return tile
        end

        local crackerV = attackerSoft[1] or 0
        local tgtHasher = tonumber(inet.target_hasher or 0) or 0
        local tgtFirewall = tonumber(inet.target_firewall or 0) or 0
        local crackOk = crackerV > 0 and crackerV >= tgtHasher
        local crackReason
        if crackerV <= 0 then crackReason = "No Cracker."
        elseif crackerV < tgtHasher then crackReason = "Cracker not high enough level" end
        build_tile(tiles,
            "Bruteforce attack",
            "Cracker version " .. MH.Data.DotVersion(crackerV),
            crackOk,
            crackReason,
            function() send_cmd("crack_ip", { ip = inet.ip, method = "bruteforce" }) end
        )

        local ftpV = attackerSoft[13] or 0
        local sshV = attackerSoft[14] or 0
        local portV = attackerSoft[3] or 0
        local bestExploit = math.max(ftpV, sshV)
        local haveExploit = ftpV > 0 or sshV > 0
        local exploitOk = certLvl >= 3 and portV > 0 and haveExploit and bestExploit >= tgtFirewall
        local reason
        if certLvl < 3 then reason = "No certification."
        elseif portV <= 0 then reason = "No Port Scan."
        elseif not haveExploit then reason = "No Exploits."
        elseif bestExploit < tgtFirewall then reason = "Exploit not high enough level" end
        local method = ftpV >= sshV and ftpV > 0 and "ftp_exploit" or "ssh_exploit"
        build_tile(tiles,
            "Exploit attack",
            "FTP Exploit " .. MH.Data.DotVersion(ftpV) .. "    SSH Exploit " .. MH.Data.DotVersion(sshV),
            exploitOk,
            reason,
            function() send_cmd("crack_ip", { ip = inet.ip, method = method }) end
        )

        render_target_processes(body, "Active attacks on this target")

        if inet.is_isp then
            label(body, "Internet Service Provider", "DermaLarge"):Dock(TOP)
            label(body, "Reset your home IP or your root password.", "DermaDefault"):Dock(TOP)

            local ipPrice = tonumber(inet.ip_reset_price or 0) or 0
            local ipB = vgui.Create("DButton", body)
            ipB:Dock(TOP)
            ipB:DockMargin(0, 4, 0, 0)
            ipB:SetTall(30)
            if not inet.ip_reset_ready then
                ipB:SetText("IP reset cooldown: " .. math.ceil(tonumber(inet.ip_reset_wait or 0)) .. "s")
                ipB:SetEnabled(false)
            else
                ipB:SetText("Reset My IP - " .. (ipPrice == 0 and "Free" or ("$" .. ipPrice)))
                ipB.DoClick = function()
                    Derma_Query("Reset your home IP?" .. (ipPrice > 0 and ("\nCost: $" .. ipPrice) or ""),
                        "Reset IP", "Reset",
                        function() send_cmd("ip_reset", {}) end,
                        "Cancel", function() end)
                end
            end

            local pPrice = tonumber(inet.pwd_reset_price or 0) or 0
            local pwdB = vgui.Create("DButton", body)
            pwdB:Dock(TOP)
            pwdB:DockMargin(0, 4, 0, 0)
            pwdB:SetTall(30)
            if not inet.pwd_reset_ready then
                pwdB:SetText("Password reset cooldown: " .. math.ceil(tonumber(inet.pwd_reset_wait or 0)) .. "s")
                pwdB:SetEnabled(false)
            else
                pwdB:SetText("Reset Root Password - " .. (pPrice == 0 and "Free" or ("$" .. pPrice)))
                pwdB.DoClick = function()
                    Derma_Query("Rotate your root password?\nAll existing hacked-list entries pointing at your server will be invalidated.",
                        "Reset password", "Reset",
                        function() send_cmd("pwd_reset", {}) end,
                        "Cancel", function() end)
                end
            end
            return
        end

        if inet.is_puzzle and inet.puzzle_solved then
            local banner = vgui.Create("DPanel", body)
            banner:Dock(TOP)
            banner:SetTall(48)
            banner:DockMargin(0, 6, 0, 6)
            local msg = vgui.Create("DLabel", banner)
            msg:Dock(FILL)
            msg:DockMargin(10, 0, 10, 0)
            msg:SetDark(true)
            msg:SetFont("DermaDefaultBold")
            if inet.puzzle_next_ip then
                msg:SetText("Puzzle cleared. Next puzzle in the chain: " .. tostring(inet.puzzle_next_ip))
                local goB = vgui.Create("DButton", banner)
                goB:Dock(RIGHT)
                goB:SetWide(190)
                goB:DockMargin(6, 6, 6, 6)
                goB:SetText("Visit " .. tostring(inet.puzzle_next_ip))
                goB.DoClick = function()
                    send_cmd("internet_goto", { ip = tostring(inet.puzzle_next_ip) })
                end
            else
                msg:SetText("You have cleared the entire puzzle chain. Nothing after this one.")
            end
        end

        if inet.is_bank then
            local bankRow = vgui.Create("DPanel", body)
            bankRow:Dock(TOP)
            bankRow:SetTall(32)
            bankRow:DockMargin(0, 6, 0, 0)
            local accEntry = vgui.Create("DTextEntry", bankRow)
            accEntry:Dock(LEFT) accEntry:SetWide(140) accEntry:SetPlaceholderText("account #")
            local bPassEntry = vgui.Create("DTextEntry", bankRow)
            bPassEntry:Dock(LEFT) bPassEntry:SetWide(140) bPassEntry:SetPlaceholderText("password") bPassEntry:DockMargin(4, 0, 0, 0)
            local blogin = vgui.Create("DButton", bankRow)
            blogin:SetText("Account login") blogin:Dock(LEFT) blogin:SetWide(130) blogin:DockMargin(4, 0, 0, 0)
            blogin.DoClick = function()
                send_cmd("bank_internet_login", { ip = inet.ip, acc = accEntry:GetValue(), pass = bPassEntry:GetValue() })
            end
            local register = vgui.Create("DButton", bankRow)
            register:SetText("Register account") register:Dock(LEFT) register:SetWide(150) register:DockMargin(4, 0, 0, 0)
            register.DoClick = function() send_cmd("bank_internet_register", { ip = inet.ip }) end

            if inet.authed and tostring(inet.auth_user or "root") == "root" then
                label(body, "Or crack a specific bank account by number:", "DermaDefaultBold"):Dock(TOP)
                local hackRow = vgui.Create("DPanel", body)
                hackRow:Dock(TOP)
                hackRow:SetTall(32)
                hackRow:DockMargin(0, 6, 0, 0)
                local hAcc = vgui.Create("DTextEntry", hackRow)
                hAcc:Dock(LEFT) hAcc:SetWide(200) hAcc:SetPlaceholderText("account # to crack")
                local hBtn = vgui.Create("DButton", hackRow)
                hBtn:SetText("Hack account")
                hBtn:Dock(LEFT) hBtn:SetWide(140) hBtn:DockMargin(4, 0, 0, 0)
                hBtn.DoClick = function()
                    send_cmd("bank_internet_hack_acc", { ip = inet.ip, acc = hAcc:GetValue() })
                end
            end
        end

        local sess = MH.OS.State.bank_session
        if sess and tonumber(sess.bank_id) == tonumber(inet.id) then
            local balanceBox = vgui.Create("DPanel", body)
            balanceBox:Dock(TOP)
            balanceBox:SetTall(70)
            balanceBox:DockMargin(0, 8, 0, 6)
            local balLbl = vgui.Create("DLabel", balanceBox)
            balLbl:Dock(FILL)
            balLbl:SetDark(true)
            balLbl:SetFont("DermaLarge")
            balLbl:SetContentAlignment(5)
            balLbl:SetText("$" .. tostring(sess.cash))
            local meta = vgui.Create("DLabel", balanceBox)
            meta:Dock(BOTTOM)
            meta:SetDark(true)
            meta:SetContentAlignment(5)
            meta:SetTall(16)
            meta:SetText("Account " .. sess.acc_num .. "   on bank " .. tostring(sess.bank_name or "?") .. "   " .. tostring(sess.bank_ip or ""))

            label(body, "Transfer money", "DermaDefaultBold"):Dock(TOP)
            local tRow = vgui.Create("DPanel", body)
            tRow:Dock(TOP) tRow:SetTall(32) tRow:DockMargin(0, 6, 0, 0)
            local tFrom = vgui.Create("DTextEntry", tRow)
            tFrom:Dock(LEFT) tFrom:SetWide(140) tFrom:SetText(sess.acc_num) tFrom:SetEditable(false)
            local tTo = vgui.Create("DTextEntry", tRow)
            tTo:Dock(LEFT) tTo:SetWide(140) tTo:SetPlaceholderText("to account #") tTo:DockMargin(4, 0, 0, 0)
            local tBankIp = vgui.Create("DTextEntry", tRow)
            tBankIp:Dock(LEFT) tBankIp:SetWide(130) tBankIp:SetPlaceholderText("recipient bank IP") tBankIp:DockMargin(4, 0, 0, 0)
            local tAmt = vgui.Create("DTextEntry", tRow)
            tAmt:Dock(LEFT) tAmt:SetWide(100) tAmt:SetPlaceholderText("amount") tAmt:DockMargin(4, 0, 0, 0) tAmt:SetNumeric(true)
            local tSend = vgui.Create("DButton", tRow)
            tSend:SetText("Transfer")
            tSend:Dock(LEFT) tSend:SetWide(100) tSend:DockMargin(4, 0, 0, 0)
            tSend.DoClick = function()
                send_cmd("bank_internet_transfer", { to = tTo:GetValue(), amount = tonumber(tAmt:GetValue()), bank_ip = tBankIp:GetValue() })
            end

            local actionRow = vgui.Create("DPanel", body)
            actionRow:Dock(TOP) actionRow:SetTall(32) actionRow:DockMargin(0, 8, 0, 0)
            local chpass = vgui.Create("DButton", actionRow)
            chpass:SetText("Change password") chpass:Dock(LEFT) chpass:SetWide(160)
            chpass.DoClick = function()
                Derma_Query("Rotate password on account " .. sess.acc_num .. "?",
                    "Change password", "Change",
                    function() send_cmd("bank_internet_change_pass", {}) end,
                    "Cancel", function() end)
            end
            local closeB = vgui.Create("DButton", actionRow)
            closeB:SetText("Close account") closeB:Dock(LEFT) closeB:SetWide(140) closeB:DockMargin(4, 0, 0, 0)
            closeB.DoClick = function()
                Derma_Query("Close " .. sess.acc_num .. "?", "Close account",
                    "Close", function() send_cmd("bank_internet_close", {}) end,
                    "Cancel", function() end)
            end
            local logoutB = vgui.Create("DButton", actionRow)
            logoutB:SetText("Logout account") logoutB:Dock(LEFT) logoutB:SetWide(140) logoutB:DockMargin(4, 0, 0, 0)
            logoutB.DoClick = function() send_cmd("bank_internet_logout", {}) end
        end
        return
    end

    render_target_processes(body, "Processes running on this target")

    local subbar = vgui.Create("DPanel", body)
    subbar:Dock(TOP)
    subbar:SetTall(28)
    subbar:DockMargin(0, 4, 0, 6)
    local rightCol = vgui.Create("DPanel", body)
    rightCol:Dock(RIGHT)
    rightCol:SetWide(180)
    rightCol:DockMargin(10, 0, 0, 0)
    rightCol.Paint = function() end
    local sub = vgui.Create("DScrollPanel", body)
    sub:Dock(FILL)

    local function paintRemote()
        sub:Clear()
        rightCol:Clear()
        if MH.OS.InternetView == "Banking" then
            label(sub, "Check account balance", "DermaDefaultBold"):Dock(TOP)
            local lookupRow = vgui.Create("DPanel", sub)
            lookupRow:Dock(TOP)
            lookupRow:SetTall(28)
            lookupRow:DockMargin(0, 4, 0, 0)
            local lookupResult = vgui.Create("DLabel", sub)
            lookupResult:Dock(TOP)
            lookupResult:SetTall(22)
            lookupResult:DockMargin(0, 4, 0, 8)
            lookupResult:SetDark(true)
            lookupResult:SetText("")
            local lookupEntry = vgui.Create("DTextEntry", lookupRow)
            lookupEntry:Dock(FILL)
            lookupEntry:SetPlaceholderText("Account number")
            local lookupBtn = vgui.Create("DButton", lookupRow)
            lookupBtn:Dock(RIGHT)
            lookupBtn:SetWide(120)
            lookupBtn:DockMargin(4, 0, 0, 0)
            lookupBtn:SetText("Check balance")
            local function doLookup()
                local q = string.Trim(tostring(lookupEntry:GetValue() or ""))
                if q == "" then
                    lookupResult:SetText("Enter an account number.")
                    return
                end
                for _, a in ipairs(inet.bank_accounts or {}) do
                    if tostring(a.acc_num or "") == q then
                        lookupResult:SetText("Account " .. q .. "  balance $" ..
                            tostring(tonumber(a.cash) or 0))
                        return
                    end
                end
                lookupResult:SetText("Account " .. q .. " not found on this bank.")
            end
            lookupBtn.DoClick = doLookup
            lookupEntry.OnEnter = doLookup

            label(sub, "Transfer money", "DermaDefaultBold"):Dock(TOP)
            local tRow = vgui.Create("DPanel", sub)
            tRow:Dock(TOP)
            tRow:SetTall(28)
            tRow:DockMargin(0, 4, 0, 0)
            local tFrom = vgui.Create("DTextEntry", tRow)
            tFrom:Dock(LEFT) tFrom:SetWide(140) tFrom:SetPlaceholderText("from account")
            local tPass = vgui.Create("DTextEntry", tRow)
            tPass:Dock(LEFT) tPass:SetWide(140) tPass:DockMargin(4, 0, 0, 0)
            tPass:SetPlaceholderText("from password")
            local tTo = vgui.Create("DTextEntry", tRow)
            tTo:Dock(LEFT) tTo:SetWide(140) tTo:DockMargin(4, 0, 0, 0)
            tTo:SetPlaceholderText("to account")
            local tAmt = vgui.Create("DTextEntry", tRow)
            tAmt:Dock(LEFT) tAmt:SetWide(100) tAmt:DockMargin(4, 0, 0, 0)
            tAmt:SetPlaceholderText("amount") tAmt:SetNumeric(true)
            local tSend = vgui.Create("DButton", tRow)
            tSend:Dock(LEFT) tSend:SetWide(100) tSend:DockMargin(4, 0, 0, 0)
            tSend:SetText("Transfer")
            tSend.DoClick = function()
                send_cmd("bank_transfer", {
                    from = tFrom:GetValue(),
                    pass = tPass:GetValue(),
                    to = tTo:GetValue(),
                    amount = tonumber(tAmt:GetValue()),
                })
            end
        elseif MH.OS.InternetView == "Logs" then
            local toolbar = vgui.Create("DPanel", sub)
            toolbar:Dock(TOP)
            toolbar:SetTall(30)
            toolbar:DockMargin(0, 0, 0, 4)
            local editBtn = vgui.Create("DButton", toolbar)
            editBtn:SetText("Edit")
            editBtn:Dock(LEFT)
            editBtn:SetWide(80)
            local saveBtn = vgui.Create("DButton", toolbar)
            saveBtn:SetText("Save edits")
            saveBtn:Dock(LEFT)
            saveBtn:DockMargin(4, 0, 0, 0)
            saveBtn:SetWide(100)
            saveBtn:SetVisible(false)
            local cancelBtn = vgui.Create("DButton", toolbar)
            cancelBtn:SetText("Cancel")
            cancelBtn:Dock(LEFT)
            cancelBtn:DockMargin(4, 0, 0, 0)
            cancelBtn:SetWide(80)
            cancelBtn:SetVisible(false)
            local delBtn = vgui.Create("DButton", toolbar)
            delBtn:SetText("Delete all")
            delBtn:Dock(RIGHT)
            delBtn:SetWide(100)
            if inet.log_disabled then
                editBtn:SetEnabled(false)
                delBtn:SetEnabled(false)
                editBtn:SetTooltip("This server does not keep logs.")
                delBtn:SetTooltip("This server does not keep logs.")
            end
            local status = vgui.Create("DLabel", sub)
            status:Dock(TOP)
            status:SetDark(true)
            status:SetText(inet.log_locked and "A log process is already running on target." or "")
            local text = vgui.Create("DTextEntry", sub)
            text:Dock(TOP)
            text:SetTall(560)
            text:DockMargin(0, 4, 0, 4)
            text:SetMultiline(true)
            text:SetEditable(false)
            text:SetVerticalScrollbarEnabled(true)
            text:SetValue(tostring(inet.log_text or ""))
            editBtn.DoClick = function()
                text:SetEditable(true)
                editBtn:SetVisible(false)
                saveBtn:SetVisible(true)
                cancelBtn:SetVisible(true)
            end
            cancelBtn.DoClick = function()
                text:SetEditable(false)
                text:SetValue(tostring(inet.log_text or ""))
                editBtn:SetVisible(true)
                saveBtn:SetVisible(false)
                cancelBtn:SetVisible(false)
            end
            saveBtn.DoClick = function()
                send_cmd("internet_log_edit_submit", { content = text:GetValue() })
                text:SetEditable(false)
                editBtn:SetVisible(true)
                saveBtn:SetVisible(false)
                cancelBtn:SetVisible(false)
            end
            delBtn.DoClick = function()
                Derma_Query("Wipe remote log on " .. tostring(inet.ip) .. "?",
                    "Delete remote log", "Delete",
                    function() send_cmd("internet_log_delete_all", {}) end,
                    "Cancel", function() end)
            end
        elseif MH.OS.InternetView == "Softwares" then
            local primaryNet = (MH.OS.State.servers or {})[1]
            local myNetTier = tonumber(primaryNet and primaryNet.net_tier or 1) or 1
            local myNet = (MH.Data.Hardware.net[myNetTier] or MH.Data.Hardware.net[1]).mbps or 1

            local hUsed, hTotal = hdd_usage_for(inet)
            local rUsed, rTotal = ram_usage_for(inet)
            local hdd = usage_pie(rightCol, 110, "HDD", hUsed, hTotal)
            hdd:Dock(TOP) hdd:DockMargin(0, 4, 0, 8)
            local ram = usage_pie(rightCol, 110, "RAM", rUsed, rTotal)
            ram:Dock(TOP) ram:DockMargin(0, 0, 0, 8)

            label(sub, "Files on remote target  (your NET: " .. myNet .. " Mbps)", "DermaDefaultBold"):Dock(TOP)
            local header = vgui.Create("DPanel", sub)
            header:Dock(TOP)
            header:SetTall(20)
            header:DockMargin(0, 4, 0, 0)
            local function hcol(txt, wide, dock)
                local l = vgui.Create("DLabel", header)
                l:Dock(dock or LEFT)
                if wide then l:SetWide(wide) end
                l:SetDark(true)
                l:SetFont("DermaDefaultBold")
                l:SetText("  " .. txt)
            end
            hcol("File",     180)
            hcol("Type",     110)
            hcol("Version",  60)
            hcol("Size",     60)
            hcol("Actions", nil, FILL)

            local missionTargetSoft, missionTargetKind = nil, nil
            for _, m in ipairs(MH.OS.State.missions or {}) do
                local st = tonumber(m.status or 0)
                if (st == 1 or st == 2) and tonumber(m.target_server) == tonumber(inet.id or 0) then
                    local mt = tonumber(m.mtype)
                    if (mt == 1 or mt == 2) and tostring(m.info_str or "") ~= "" then
                        missionTargetSoft = tostring(m.info_str)
                        missionTargetKind = mt == 1 and "delete" or "download"
                        break
                    end
                end
            end
            local HIGHLIGHT_COLOR = {
                delete   = Color(220, 60, 60),
                download = Color(90, 200, 90),
            }
            for _, s in ipairs(inet.software or {}) do
                local meta = MH.Data.Soft[tonumber(s.soft_type or 0)] or {}
                local row = vgui.Create("DPanel", sub)
                row:Dock(TOP)
                row:SetTall(28)
                row:DockMargin(0, 2, 0, 0)
                local highlight = missionTargetSoft and tostring(s.soft_name or "") == missionTargetSoft
                    and HIGHLIGHT_COLOR[missionTargetKind] or nil
                local function rcol(txt, wide, dock)
                    local l = vgui.Create("DLabel", row)
                    l:Dock(dock or LEFT)
                    if wide then l:SetWide(wide) end
                    if highlight then
                        l:SetDark(false)
                        l:SetTextColor(highlight)
                    else
                        l:SetDark(true)
                    end
                    l:SetText("  " .. tostring(txt or ""))
                end
                rcol((s.soft_name or "?") .. (meta.ext or ""), 180)
                rcol(meta.name or ("#" .. tostring(s.soft_type)), 110)
                rcol("v" .. MH.Data.DotVersion(s.soft_version), 60)
                rcol(tostring(s.soft_size or 0) .. " MB", 60)
                local actions = vgui.Create("DPanel", row)
                actions:Dock(RIGHT)
                actions:SetWide(430)
                local primary = (MH.OS.State.servers or {})[1]
                local myTools = { [5] = 0, [6] = 0, [7] = 0 }
                for _, inv in ipairs(primary and primary.software or {}) do
                    local st = tonumber(inv.soft_type)
                    if myTools[st] ~= nil and tonumber(inv.installed) == 1 then
                        myTools[st] = math.max(myTools[st], tonumber(inv.soft_version) or 0)
                    end
                end
                local function remote_btn(text, action, needTool, needName)
                    local b = vgui.Create("DButton", actions)
                    b:SetText(text)
                    b:Dock(LEFT)
                    b:SetWide(70)
                    b:DockMargin(0, 2, 2, 2)
                    b.DoClick = function()
                        send_cmd("remote_soft_action", { soft_id = s.id, action = action })
                    end
                    if needTool and myTools[needTool] <= 0 then
                        b:SetEnabled(false)
                        b:SetTooltip("Install a " .. needName .. " on your rig first")
                    end
                    return b
                end
                local isRiddle = tonumber(s.soft_type) == 26
                if isRiddle and inet.is_puzzle then
                    local solveB = vgui.Create("DButton", actions)
                    solveB:Dock(LEFT)
                    solveB:SetWide(90)
                    solveB:DockMargin(0, 2, 2, 2)
                    if inet.puzzle_solved then
                        solveB:SetText("Solved")
                        solveB:SetEnabled(false)
                    elseif not inet.puzzle_prev_cleared then
                        solveB:SetText("Locked")
                        solveB:SetEnabled(false)
                    else
                        solveB:SetText("Solve")
                        solveB.DoClick = function()
                            MH.OS.OpenRiddlePopup(inet)
                        end
                    end
                else
                    local dl = vgui.Create("DButton", actions)
                    dl:SetText("Download")
                    dl:Dock(LEFT)
                    dl:SetWide(80)
                    dl:DockMargin(0, 2, 2, 2)
                    dl.DoClick = function()
                        send_cmd("remote_soft_download", { soft_id = s.id })
                    end
                    local isRoot = tostring(inet.auth_user or "root") == "root"
                    if isRoot then
                        remote_btn(tonumber(s.installed) == 1 and "Stop" or "Run",
                            tonumber(s.installed) == 1 and "uninstall" or "install")
                        local isHidden = tonumber(s.hidden) == 1
                        remote_btn(isHidden and "Seek" or "Hide",
                            isHidden and "seek" or "hide",
                            isHidden and 6 or 5,
                            isHidden and "Seeker" or "Hider")
                        remote_btn("Delete", "delete")
                    end
                end
                if tonumber(s.soft_type) == 30 then
                    local edit = vgui.Create("DButton", actions)
                    edit:SetText("Read")
                    edit:Dock(LEFT)
                    edit:SetWide(60)
                    edit:DockMargin(0, 2, 2, 2)
                    edit.DoClick = function()
                        open_text_editor(s, true)
                    end
                end
            end
            local primary2 = (MH.OS.State.servers or {})[1]
            local myAv = 0
            for _, inv in ipairs(primary2 and primary2.software or {}) do
                if tonumber(inv.soft_type) == 7 and tonumber(inv.installed) == 1 then
                    myAv = math.max(myAv, tonumber(inv.soft_version) or 0)
                end
            end
            if tostring(inet.auth_user or "root") == "root" then
                local avRow = vgui.Create("DPanel", sub)
                avRow:Dock(TOP)
                avRow:SetTall(32)
                avRow:DockMargin(0, 6, 0, 6)
                local avB = vgui.Create("DButton", avRow)
                avB:SetText("Run Antivirus scan on target (200s)")
                avB:Dock(LEFT)
                avB:SetWide(300)
                avB.DoClick = function() send_cmd("av_scan", { scope = "remote" }) end
                if myAv <= 0 then
                    avB:SetEnabled(false)
                    avB:SetTooltip("Install an Antivirus on your rig first")
                end
            end

            if tostring(inet.auth_user or "root") == "root" then
                label(sub, "Upload a local file to this target:", "DermaDefaultBold"):Dock(TOP)
                local primary = (MH.OS.State.servers or {})[1]
                local uploadables = {}
                for _, inv in ipairs(primary and primary.software or {}) do
                    if tonumber(inv.hidden or 0) == 0 then table.insert(uploadables, inv) end
                end
                local uploadCombo = vgui.Create("DComboBox", sub)
                uploadCombo:Dock(TOP)
                uploadCombo:DockMargin(0, 4, 0, 0)
                uploadCombo:SetValue("Pick a local file to upload...")
                for i, inv in ipairs(uploadables) do
                    local meta = MH.Data.Soft[tonumber(inv.soft_type or 0)] or {}
                    uploadCombo:AddChoice((inv.soft_name or "?") .. (meta.ext or "") ..
                        "  v" .. MH.Data.DotVersion(inv.soft_version), i)
                end
                local uploadB = vgui.Create("DButton", sub)
                uploadB:SetText("Upload selected")
                uploadB:Dock(TOP)
                uploadB:DockMargin(0, 4, 0, 0)
                uploadB:SetTall(28)
                uploadB.DoClick = function()
                    local _, idx = uploadCombo:GetSelected()
                    local pick = idx and uploadables[tonumber(idx)]
                    if not pick then return end
                    send_cmd("remote_soft_upload", { soft_id = pick.id })
                end
            end
        end
    end

    local logoutB = button(subbar, "Logout", function()
        send_cmd("internet_logout", {})
    end)
    logoutB:Dock(RIGHT)
    logoutB:SetWide(100)

    local tabs = { "Logs", "Softwares" }
    local showBanking = inet.is_bank and inet.authed and tostring(inet.auth_user or "root") == "root"
    if showBanking then tabs[#tabs + 1] = "Banking" end
    for _, name in ipairs(tabs) do
        local b = vgui.Create("DButton", subbar)
        b:SetText(name)
        b:Dock(LEFT)
        b:SetWide(120)
        b:DockMargin(0, 0, 4, 0)
        b.DoClick = function() MH.OS.InternetView = name paintRemote() end
    end
    local validView = { Logs = true, Softwares = true, Banking = showBanking }
    if not validView[MH.OS.InternetView] then
        MH.OS.InternetView = "Logs"
    end
    if inet.is_puzzle and MH.OS.PuzzleAutoSwitch ~= tostring(inet.ip) then
        MH.OS.PuzzleAutoSwitch = tostring(inet.ip)
        MH.OS.InternetView = "Softwares"
    end
    paintRemote()
end

MH.OS.TaskView = MH.OS.TaskView or "All"

proc_row = function(parent, p)
    local total = math.max(1, (tonumber(p.time_end) or 0) - (tonumber(p.time_start) or 0))
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:SetTall(76)
    row:DockMargin(0, 4, 0, 0)

    local topLine = vgui.Create("DPanel", row)
    topLine:Dock(TOP)
    topLine:SetTall(22)
    topLine:DockMargin(6, 2, 6, 0)

    local actionLbl = vgui.Create("DLabel", topLine)
    actionLbl:SetDark(true)
    actionLbl:SetFont("DermaDefaultBold")
    actionLbl:SetText((p.action or "?") .. "   -> " ..
        tostring(p.info ~= "" and p.info or (p.victim_server or p.local_server)))
    actionLbl:Dock(LEFT)
    actionLbl:SizeToContents()

    local pauseB = vgui.Create("DButton", topLine)
    pauseB:Dock(RIGHT)
    pauseB:SetWide(70)
    pauseB:DockMargin(2, 0, 0, 0)
    pauseB:SetText((tonumber(p.paused_remaining) or 0) > 0 and "Resume" or "Pause")
    pauseB.DoClick = function()
        send_cmd((tonumber(p.paused_remaining) or 0) > 0 and "proc_resume" or "proc_pause", { pid = p.id })
    end
    local completeB = vgui.Create("DButton", topLine)
    completeB:Dock(RIGHT)
    completeB:SetWide(140)
    completeB:DockMargin(2, 0, 0, 0)
    completeB:SetText("Complete")
    completeB.DoClick = function() send_cmd("proc_complete", { pid = p.id }) end
    completeB.Think = function(self)
        local serverNow = tonumber((MH.OS.State or {}).server_now or 0) or 0
        local timeEnd = tonumber(p.time_end or 0) or 0
        local paused = (tonumber(p.paused_remaining or 0) or 0) > 0
        local ready = (not paused) and timeEnd > 0 and serverNow >= timeEnd
        if ready then
            if self:GetText() ~= "Complete" then self:SetText("Complete") end
        else
            if self:GetText() ~= "Fast-finish (0.5 BTC)" then self:SetText("Fast-finish (0.5 BTC)") end
        end
    end
    local cancelB = vgui.Create("DButton", topLine)
    cancelB:Dock(RIGHT)
    cancelB:SetWide(70)
    cancelB:DockMargin(2, 0, 0, 0)
    cancelB:SetText("Cancel")
    cancelB.DoClick = function() send_cmd("proc_delete", { pid = p.id }) end

    local statusLbl = vgui.Create("DLabel", topLine)
    statusLbl:SetDark(true)
    statusLbl:Dock(RIGHT)
    statusLbl:SetWide(190)
    statusLbl:SetContentAlignment(6)

    local metaLine = vgui.Create("DPanel", row)
    metaLine:Dock(TOP)
    metaLine:SetTall(16)
    metaLine:DockMargin(6, 0, 6, 0)
    local metaLbl = vgui.Create("DLabel", metaLine)
    metaLbl:Dock(FILL)
    metaLbl:SetDark(true)
    local startedTxt = os.date("%H:%M:%S", tonumber(p.time_start or 0))
    local endsTxt = os.date("%H:%M:%S", tonumber(p.time_end or 0))
    local cpu = tonumber(p.cpu_usage or 0) or 0
    local net = tonumber(p.net_usage or 0) or 0
    metaLbl:SetText("Started " .. startedTxt .. "   Ends " .. endsTxt ..
        "   CPU " .. cpu .. "%   NET " .. net .. "%")

    local bar = vgui.Create("DProgress", row)
    bar:Dock(FILL)
    bar:DockMargin(6, 2, 6, 6)
    bar.Think = function(self)
        local paused = (tonumber(p.paused_remaining) or 0) > 0
        local remaining
        if paused then
            remaining = tonumber(p.paused_remaining) or 0
        else
            local delta = CurTime() - (MH.OS.State.client_baseline or CurTime())
            local effNow = (tonumber(MH.OS.State.server_now) or 0) + delta
            remaining = (tonumber(p.time_end) or 0) - effNow
            if remaining < 0 then remaining = 0 end
        end
        local frac = 1 - (remaining / total)
        if frac < 0 then frac = 0 end
        if frac > 1 then frac = 1 end
        self:SetFraction(frac)
        statusLbl:SetText((paused and "Paused   " or "Running   ") ..
            math.ceil(remaining) .. "s   " .. math.floor(frac * 100) .. "%")
    end
end

Tabs["Task Manager"] = function(container)
    clear(container)
    local srv = current_server()
    label(container, "Task Manager", "DermaLarge"):Dock(TOP)

    local body = IsValid(container) and container:GetParent() or nil
    local tmSidebar = IsValid(body) and vgui.Create("DPanel", body) or nil
    if IsValid(tmSidebar) then
        MH.OS._FloatSidebar = tmSidebar
        tmSidebar:Dock(RIGHT)
        tmSidebar:SetWide(210)
        tmSidebar:DockMargin(6, 6, 6, 6)
        local function side_btn(txt, cb)
            local b = vgui.Create("DButton", tmSidebar)
            b:SetText(txt)
            b:Dock(TOP)
            b:SetTall(32)
            b:DockMargin(0, 4, 0, 0)
            b.DoClick = cb
            return b
        end
        side_btn("My files", function()
            MH.OS.ActiveTab = "Software"
            if MH.OS.Rebuild then MH.OS.Rebuild() end
        end)
        side_btn("My tasks", function()
            if MH.OS.Rebuild then MH.OS.Rebuild() end
        end)
        local inet = MH.OS.State.internet
        if inet and inet.authed then
            side_btn(tostring(inet.ip) .. "'s files", function()
                MH.OS.InternetView = "Softwares"
                MH.OS.ActiveTab = "Internet"
                if MH.OS.Rebuild then MH.OS.Rebuild() end
            end)
            side_btn(tostring(inet.ip) .. "'s log", function()
                MH.OS.InternetView = "Logs"
                MH.OS.ActiveTab = "Internet"
                if MH.OS.Rebuild then MH.OS.Rebuild() end
            end)
        end
    end

    if MH.OS.WatchProcess then
        local watch = MH.OS.WatchProcess
        local match
        for _, p in ipairs(MH.OS.State.all_processes or {}) do
            if (watch.actionMatch == true or p.action == watch.actionMatch)
                and (tonumber(p.time_start) or 0) >= watch.startedAfter
            then
                match = p
                break
            end
        end
        if match then
            watch.seen = true
            label(container, "Running " .. (match.action or "?") .. "   target " ..
                tostring(match.info ~= "" and match.info or (match.victim_server or match.local_server)),
                "DermaDefaultBold"):Dock(TOP)
            proc_row(container, match)
            local backB = vgui.Create("DButton", container)
            backB:SetText("Back to " .. tostring(watch.sourceTab or "Home"))
            backB:Dock(TOP)
            backB:DockMargin(0, 10, 0, 0)
            backB:SetTall(28)
            backB.DoClick = function()
                local st = watch.sourceTab or "Home"
                MH.OS.WatchProcess = nil
                MH.OS.ActiveTab = st
                if MH.OS.Rebuild then MH.OS.Rebuild() end
            end
            return
        elseif watch.seen then
            local st = watch.sourceTab or "Home"
            MH.OS.WatchProcess = nil
            MH.OS.ActiveTab = st
            if MH.OS.Rebuild then MH.OS.Rebuild() end
            return
        else
            label(container, "Spawning process...", "DermaDefaultBold"):Dock(TOP)
            return
        end
    end

    local subbar = vgui.Create("DPanel", container)
    subbar:Dock(TOP)
    subbar:SetTall(28)
    subbar:DockMargin(0, 2, 0, 6)
    for _, name in ipairs({ "All", "CPU", "Network", "Running" }) do
        local b = vgui.Create("DButton", subbar)
        b:SetText(name)
        b:Dock(LEFT)
        b:SetWide(110)
        b:DockMargin(0, 0, 4, 0)
        b.DoClick = function()
            MH.OS.TaskView = name
            if MH.OS.Rebuild then MH.OS.Rebuild() end
        end
    end

    if MH.OS.TaskView == "Running" then
        label(container, "Software installed and running on " .. tostring(srv and srv.name or "?"), "DermaDefaultBold"):Dock(TOP)
        for _, s in ipairs(srv and srv.software or {}) do
            if tonumber(s.installed or 0) == 1 then
                local meta = MH.Data.Soft[tonumber(s.soft_type or 0)] or {}
                local srow = vgui.Create("DPanel", container)
                srow:Dock(TOP)
                srow:SetTall(28)
                srow:DockMargin(0, 2, 0, 0)
                local info = vgui.Create("DLabel", srow)
                info:Dock(FILL)
                info:SetDark(true)
                info:SetFont("DermaDefaultBold")
                local sinceTxt = s.last_collect and tonumber(s.last_collect) > 0 and
                    ("since " .. os.date("%H:%M:%S", tonumber(s.last_collect))) or "running"
                info:SetText("  " .. (s.soft_name or "?") .. (meta.ext or "") ..
                    "   v" .. MH.Data.DotVersion(s.soft_version) ..
                    "   " .. tostring(s.soft_size or 0) .. " MB" ..
                    "   RAM " .. tostring(s.soft_ram or 0) .. " MB" ..
                    "   " .. sinceTxt)
                local stopB = vgui.Create("DButton", srow)
                stopB:Dock(RIGHT)
                stopB:SetWide(80)
                stopB:DockMargin(0, 2, 6, 2)
                stopB:SetText("Stop")
                stopB.DoClick = function()
                    send_cmd("soft_action", { soft_id = s.id, action = "uninstall" })
                end
            end
        end
        return
    end

    local procs = MH.OS.State.all_processes or {}
    if #procs == 0 then
        label(container, "No processes running."):Dock(TOP)
        return
    end

    local matches = 0
    for _, p in ipairs(procs) do
        local isNet = (tonumber(p.net_usage or 0) or 0) > (tonumber(p.cpu_usage or 0) or 0)
        if MH.OS.TaskView == "All"
            or (MH.OS.TaskView == "CPU" and not isNet)
            or (MH.OS.TaskView == "Network" and isNet)
        then
            proc_row(container, p)
            matches = matches + 1
        end
    end
    if matches == 0 then
        label(container, "No processes in this category."):Dock(TOP)
    end
end

Tabs["Log File"] = function(container)
    clear(container)
    local srv = current_server()
    label(container, "Log File", "DermaLarge"):Dock(TOP)
    if not srv then label(container, "No server"):Dock(TOP) return end

    local toolbar = vgui.Create("DPanel", container)
    toolbar:Dock(TOP)
    toolbar:SetTall(30)
    toolbar:DockMargin(0, 4, 0, 4)

    local editBtn = vgui.Create("DButton", toolbar)
    editBtn:SetText("Edit")
    editBtn:Dock(LEFT)
    editBtn:SetWide(80)

    local saveBtn = vgui.Create("DButton", toolbar)
    saveBtn:SetText("Save edits")
    saveBtn:Dock(LEFT)
    saveBtn:DockMargin(4, 0, 0, 0)
    saveBtn:SetWide(100)
    saveBtn:SetVisible(false)

    local cancelBtn = vgui.Create("DButton", toolbar)
    cancelBtn:SetText("Cancel")
    cancelBtn:Dock(LEFT)
    cancelBtn:DockMargin(4, 0, 0, 0)
    cancelBtn:SetWide(80)
    cancelBtn:SetVisible(false)

    local delBtn = vgui.Create("DButton", toolbar)
    delBtn:SetText("Delete all")
    delBtn:Dock(RIGHT)
    delBtn:SetWide(100)

    local status = vgui.Create("DLabel", container)
    status:Dock(TOP)
    status:SetDark(true)
    status:SetText(srv.log_locked and "A log process is already running." or "")

    local text = vgui.Create("DTextEntry", container)
    text:Dock(TOP)
    text:SetTall(640)
    text:DockMargin(0, 4, 0, 4)
    text:SetMultiline(true)
    text:SetEditable(false)
    text:SetVerticalScrollbarEnabled(true)
    text:SetValue(tostring(srv.log_text or ""))

    editBtn.DoClick = function()
        text:SetEditable(true)
        editBtn:SetVisible(false)
        saveBtn:SetVisible(true)
        cancelBtn:SetVisible(true)
    end
    cancelBtn.DoClick = function()
        text:SetEditable(false)
        text:SetValue(tostring(srv.log_text or ""))
        editBtn:SetVisible(true)
        saveBtn:SetVisible(false)
        cancelBtn:SetVisible(false)
    end
    saveBtn.DoClick = function()
        send_cmd("log_edit_submit", { server_id = srv.id, content = text:GetValue() })
        text:SetEditable(false)
        editBtn:SetVisible(true)
        saveBtn:SetVisible(false)
        cancelBtn:SetVisible(false)
    end
    delBtn.DoClick = function()
        Derma_Query("Spawn a process to wipe this server's log?", "Delete log",
            "Delete", function() send_cmd("log_delete_all", { server_id = srv.id }) end,
            "Cancel", function() end)
    end
end

MH.OS.UniversityView = MH.OS.UniversityView or "Certifications"

local function open_cert_briefing(c, state)
    local f = vgui.Create("DFrame")
    f:SetSize(640, 520)
    f:Center()
    f:SetTitle("Level " .. c.level .. ": " .. c.name .. (c.price > 0 and ("   $" .. c.price) or "   free"))
    f:SetDeleteOnClose(true)
    f:MakePopup()
    local body = vgui.Create("DTextEntry", f)
    body:Dock(FILL)
    body:DockMargin(8, 4, 8, 4)
    body:SetMultiline(true)
    body:SetEditable(false)
    body:SetVerticalScrollbarEnabled(true)
    body:SetValue(tostring(c.briefing or "No briefing on file."))
    local actionBar = vgui.Create("DPanel", f)
    actionBar:Dock(BOTTOM)
    actionBar:DockMargin(8, 0, 8, 8)
    actionBar:SetTall(32)
    if state == "Available" then
        local b = vgui.Create("DButton", actionBar)
        b:Dock(RIGHT)
        b:SetWide(220)
        b:SetText(c.price > 0 and ("Complete and pay $" .. c.price) or "Complete")
        b.DoClick = function()
            MH.OS.SendCmd("cert_buy", { level = c.level })
            f:Remove()
        end
    else
        local lbl = vgui.Create("DLabel", actionBar)
        lbl:Dock(FILL)
        lbl:SetContentAlignment(6)
        lbl:SetDark(true)
        lbl:SetText(state == "Owned" and "Already completed." or "Complete the previous certification first.")
    end
end

Tabs["University"] = function(container)
    clear(container)
    label(container, "University", "DermaLarge"):Dock(TOP)

    local subbar = vgui.Create("DPanel", container)
    subbar:Dock(TOP)
    subbar:SetTall(28)
    subbar:DockMargin(0, 2, 0, 6)
    for _, name in ipairs({ "Certifications", "Research softwares" }) do
        local b = vgui.Create("DButton", subbar)
        b:SetText(name)
        b:Dock(LEFT)
        b:SetWide(170)
        b:DockMargin(0, 0, 4, 0)
        b.DoClick = function()
            MH.OS.UniversityView = name == "Certifications" and "Certifications" or "Research"
            if MH.OS.Rebuild then MH.OS.Rebuild() end
        end
    end

    if MH.OS.UniversityView == "Research" then
        local srv = current_server()
        if not srv then
            label(container, "No servers owned"):Dock(TOP)
            return
        end
        label(container, "License files or research upgrades on " .. tostring(srv.name), "DermaDefaultBold"):Dock(TOP)
        local list = vgui.Create("DListView", container)
        list:Dock(TOP)
        list:SetTall(500)
        list:DockMargin(0, 6, 0, 0)
        list:AddColumn("File"):SetFixedWidth(180)
        list:AddColumn("Type"):SetFixedWidth(140)
        list:AddColumn("Version"):SetFixedWidth(80)
        list:AddColumn("Licensed"):SetFixedWidth(80)
        list:AddColumn("Cost"):SetFixedWidth(100)
        list:AddColumn("Action"):SetFixedWidth(90)
        local mySid = (LocalPlayer and IsValid(LocalPlayer()) and LocalPlayer():SteamID64()) or ""
        for _, s in ipairs(srv.software or {}) do
            local meta = MH.Data.Soft[tonumber(s.soft_type or 0)] or {}
            if meta.research and meta.research > 0 then
                local curV = tonumber(s.soft_version) or 0
                local lic = tostring(s.licensed_to or "")
                if lic == "NULL" then lic = "" end
                local line
                if lic == mySid then
                    local cost = MH.Data.ResearchCost(tonumber(s.soft_type), curV)
                    line = list:AddLine(
                        tostring(s.soft_name or "?") .. (meta.ext or ""),
                        meta.name or "?",
                        MH.Data.DotVersion(curV),
                        "yours",
                        "$" .. cost,
                        "Research")
                    line.MH_Mode = "research"
                    line.MH_Cost = cost
                elseif lic ~= "" then
                    line = list:AddLine(
                        tostring(s.soft_name or "?") .. (meta.ext or ""),
                        meta.name or "?",
                        MH.Data.DotVersion(curV),
                        "other",
                        "-",
                        "Locked")
                    line.MH_Mode = "locked"
                else
                    local cost = MH.Data.LicenseFee(tonumber(s.soft_type), curV)
                    line = list:AddLine(
                        tostring(s.soft_name or "?") .. (meta.ext or ""),
                        meta.name or "?",
                        MH.Data.DotVersion(curV),
                        "no",
                        "$" .. cost,
                        "License")
                    line.MH_Mode = "license"
                    line.MH_Cost = cost
                end
                line.MH_SoftId = tonumber(s.id)
                line.MH_SoftTypeName = meta.name
            end
        end
        local function fireLine(lineRef)
            if not lineRef or not lineRef.MH_SoftId then return end
            if lineRef.MH_Mode == "license" then
                Derma_StringRequest(
                    "License " .. tostring(lineRef.MH_SoftTypeName or "software"),
                    "Pick a file name (letters, digits, spaces, _, -). Do not include the extension.",
                    "",
                    function(nm)
                        send_cmd("license", { soft_id = lineRef.MH_SoftId, name = nm })
                    end)
            elseif lineRef.MH_Mode == "research" then
                send_cmd("research", { soft_id = lineRef.MH_SoftId })
            end
        end
        list.DoDoubleClick = function(_, _, lineRef) fireLine(lineRef) end
        list.OnRowRightClick = function(_, _, lineRef)
            if not lineRef or not lineRef.MH_SoftId then return end
            if lineRef.MH_Mode == "locked" then return end
            local m = DermaMenu()
            local lbl = lineRef.MH_Mode == "license"
                and ("License ($" .. lineRef.MH_Cost .. ")")
                or ("Research upgrade ($" .. lineRef.MH_Cost .. ")")
            m:AddOption(lbl, function() fireLine(lineRef) end)
            m:Open()
        end
        return
    end

    local p = MH.OS.State.player or {}
    local owned = tonumber(p.cert_level or 0) or 0
    label(container, "Current level: " .. owned .. " / 5", "DermaDefault"):Dock(TOP)
    for _, c in ipairs(MH.Data.Certs) do
        local state
        if owned >= c.level then state = "Owned"
        elseif owned == c.level - 1 then state = "Available"
        else state = "Locked" end
        local row = vgui.Create("DPanel", container)
        row:Dock(TOP)
        row:DockMargin(0, 6, 0, 0)
        row:SetTall(36)
        local l = vgui.Create("DLabel", row)
        l:SetFont("DermaDefaultBold")
        l:SetDark(true)
        l:SetText("Level " .. c.level .. ": " .. c.name .. "   $" .. c.price)
        l:Dock(LEFT)
        l:DockMargin(10, 0, 0, 0)
        l:SizeToContents()
        local b = button(row, state == "Owned" and "Review" or state, function()
            open_cert_briefing(c, state)
        end)
        b:Dock(RIGHT)
        b:SetWide(160)
        b:DockMargin(0, 4, 10, 4)
        b:SetEnabled(state ~= "Locked")
    end
end

Tabs["Finances"] = function(container)
    clear(container)
    local p = MH.OS.State.player or {}
    label(container, "Finances", "DermaLarge"):Dock(TOP)
    label(container, "Default account balance: $" .. tostring(tonumber(p.cash or 0))):Dock(TOP)
    label(container, "Bitcoin:      " .. string.format("%.7f", tonumber(p.bitcoin or 0))):Dock(TOP)
    label(container, "Reputation:   " .. tostring(tonumber(p.exp or 0))):Dock(TOP)

    label(container, "Bank accounts", "DermaDefaultBold"):Dock(TOP)
    local openRow = vgui.Create("DPanel", container)
    openRow:Dock(TOP)
    openRow:SetTall(28)
    openRow:DockMargin(0, 4, 0, 4)
    local combo = vgui.Create("DComboBox", openRow)
    combo:Dock(FILL)
    combo:SetValue("Pick a bank to open an account at...")
    local comboBanks = {}
    for _, b in ipairs(MH.OS.State.available_banks or {}) do
        if tonumber(b.owned or 0) == 0 then
            table.insert(comboBanks, b)
            combo:AddChoice(tostring(b.name) .. "   " .. tostring(b.ip), #comboBanks)
        end
    end
    if #comboBanks == 0 then
        local anyKnown = #(MH.OS.State.available_banks or {})
        if anyKnown == 0 then
            combo:SetValue("No banks discovered yet. Scan or visit a bank IP first.")
        else
            combo:SetValue("You already have an account at every discovered bank.")
        end
        combo:SetEnabled(false)
    end
    local openB = vgui.Create("DButton", openRow)
    openB:SetText("Open account")
    openB:Dock(RIGHT)
    openB:SetWide(140)
    openB:DockMargin(4, 0, 0, 0)
    openB.DoClick = function()
        local _, idx = combo:GetSelected()
        local pick = idx and comboBanks[tonumber(idx)]
        if not pick then
            MH.Api = MH.Api or {}
            MH.OS.ShowNotify("warn", "Select a bank first")
            return
        end
        send_cmd("bank_create", { bank_id = pick.id })
    end

    local banks = MH.OS.State.banks or {}
    for _, b in ipairs(banks) do
        local brow = vgui.Create("DPanel", container)
        brow:Dock(TOP)
        brow:SetTall(28)
        brow:DockMargin(0, 2, 0, 0)
        local binfo = vgui.Create("DLabel", brow)
        binfo:Dock(FILL)
        binfo:SetDark(true)
        binfo:SetFont("DermaDefaultBold")
        binfo:SetText("  " .. tostring(b.bank_name or "?") .. "   " .. tostring(b.bank_ip or "") ..
            "   acc " .. tostring(b.acc_num) .. "   pass " .. tostring(b.acc_pass) .. "   $" .. tostring(b.cash))
        local closeB = vgui.Create("DButton", brow)
        closeB:SetText("Close")
        closeB:Dock(RIGHT) closeB:SetWide(70) closeB:DockMargin(0, 2, 6, 2)
        closeB.DoClick = function()
            Derma_Query("Close account " .. tostring(b.acc_num) .. "?",
                "Close account", "Close",
                function() send_cmd("bank_close", { acc = b.acc_num }) end,
                "Cancel", function() end)
        end
        local chpassB = vgui.Create("DButton", brow)
        chpassB:SetText("Change pass")
        chpassB:Dock(RIGHT) chpassB:SetWide(110) chpassB:DockMargin(0, 2, 2, 2)
        chpassB.DoClick = function() send_cmd("bank_change_pass", { acc = b.acc_num }) end
        local withdrawB = vgui.Create("DButton", brow)
        withdrawB:SetText("Withdraw")
        withdrawB:Dock(RIGHT) withdrawB:SetWide(90) withdrawB:DockMargin(0, 2, 2, 2)
        withdrawB.DoClick = function() send_cmd("bank_collect", { acc = b.acc_num }) end
        local loginB = vgui.Create("DButton", brow)
        loginB:SetText("Login via Internet")
        loginB:Dock(RIGHT) loginB:SetWide(140) loginB:DockMargin(0, 2, 2, 2)
        loginB.DoClick = function()
            send_cmd("internet_goto", { ip = tostring(b.bank_ip or "") })
            send_cmd("bank_internet_login", { ip = tostring(b.bank_ip or ""), acc = b.acc_num, pass = b.acc_pass })
            MH.OS.ActiveTab = "Internet"
            if MH.OS.Rebuild then MH.OS.Rebuild() end
        end
    end

end

MH.OS.HackedView = MH.OS.HackedView or "IP List"

Tabs["Hacked Database"] = function(container)
    clear(container)
    label(container, "Hacked Database", "DermaLarge"):Dock(TOP)

    local subbar = vgui.Create("DPanel", container)
    subbar:Dock(TOP)
    subbar:SetTall(28)
    subbar:DockMargin(0, 2, 0, 6)

    local body = vgui.Create("DPanel", container)
    body:Dock(TOP)
    body:SetTall(680)

    local function paint()
        body:Clear()
        if MH.OS.HackedView == "IP List" then
            local notes = MH.OS.State.notifications or {}
            if #notes > 0 then
                local noteBox = vgui.Create("DPanel", body)
                noteBox:Dock(TOP)
                noteBox:SetTall(math.min(140, 24 + 20 * #notes))
                noteBox:DockMargin(0, 0, 0, 6)
                local header = vgui.Create("DPanel", noteBox)
                header:Dock(TOP)
                header:SetTall(22)
                local hLbl = vgui.Create("DLabel", header)
                hLbl:SetDark(true)
                hLbl:SetFont("DermaDefaultBold")
                hLbl:SetText("   Alerts (" .. #notes .. ")")
                hLbl:Dock(LEFT)
                hLbl:SizeToContents()
                local dismissB = vgui.Create("DButton", header)
                dismissB:SetText("Dismiss all")
                dismissB:Dock(RIGHT)
                dismissB:SetWide(100)
                dismissB.DoClick = function() send_cmd("notification_dismiss", {}) end
                for _, n in ipairs(notes) do
                    local l = vgui.Create("DLabel", noteBox)
                    l:SetDark(true)
                    l:SetText("   " .. os.date("[%H:%M]", tonumber(n.stamp or 0)) .. " " .. tostring(n.text))
                    l:Dock(TOP)
                    l:DockMargin(0, 1, 0, 0)
                    l:SizeToContents()
                end
            end
            local sortRow = vgui.Create("DPanel", body)
            sortRow:Dock(TOP)
            sortRow:SetTall(28)
            sortRow:DockMargin(0, 0, 0, 4)
            local sortLbl = vgui.Create("DLabel", sortRow)
            sortLbl:Dock(LEFT)
            sortLbl:DockMargin(4, 6, 6, 0)
            sortLbl:SetDark(true)
            sortLbl:SetText("Sort:")
            sortLbl:SizeToContents()
            MH.OS.HackedSort = MH.OS.HackedSort or "newest"
            local combo = vgui.Create("DComboBox", sortRow)
            combo:Dock(LEFT)
            combo:SetWide(200)
            combo:DockMargin(0, 2, 0, 2)
            local sortOptions = {
                { k = "newest",   t = "Hacked time (newest first)" },
                { k = "name",     t = "Target name (a-z)" },
                { k = "ip",       t = "Target IP" },
            }
            local selIdx = 1
            for i, o in ipairs(sortOptions) do
                combo:AddChoice(o.t, o.k)
                if MH.OS.HackedSort == o.k then selIdx = i end
            end
            combo:ChooseOptionID(selIdx)
            combo.OnSelect = function(_, _, _, data)
                MH.OS.HackedSort = data
                if MH.OS.Rebuild then MH.OS.Rebuild() end
            end

            local sortedHacked = {}
            for _, h in ipairs(MH.OS.State.hacked or {}) do table.insert(sortedHacked, h) end
            table.sort(sortedHacked, function(a, b)
                if MH.OS.HackedSort == "name" then return tostring(a.target_name or "") < tostring(b.target_name or "") end
                if MH.OS.HackedSort == "ip" then return tostring(a.ip or "") < tostring(b.ip or "") end
                return (tonumber(a.stamp) or 0) > (tonumber(b.stamp) or 0)
            end)

            label(body, "Compromised machines", "DermaDefault"):Dock(TOP)
            local headerRow = vgui.Create("DPanel", body)
            headerRow:Dock(TOP)
            headerRow:SetTall(20)
            headerRow:DockMargin(0, 4, 0, 0)
            local function hcol(txt, wide, dock)
                local l = vgui.Create("DLabel", headerRow)
                l:Dock(dock or LEFT)
                if wide then l:SetWide(wide) end
                l:SetDark(true)
                l:SetFont("DermaDefaultBold")
                l:SetText("  " .. txt)
            end
            hcol("IP",       130)
            hcol("Target",   220)
            hcol("Password", 110)
            hcol("Actions",  nil, FILL)
            for _, h in ipairs(sortedHacked) do
                local hrow = vgui.Create("DPanel", body)
                hrow:Dock(TOP)
                hrow:SetTall(28)
                hrow:DockMargin(0, 2, 0, 0)
                local function rcol(txt, wide, dock)
                    local l = vgui.Create("DLabel", hrow)
                    l:Dock(dock or LEFT)
                    if wide then l:SetWide(wide) end
                    l:SetDark(true)
                    l:SetText("  " .. tostring(txt or ""))
                end
                rcol(h.ip or "?",             130)
                rcol(h.target_name or "?",    220)
                rcol(h.discovered_pass or "?",110)
                local removeB = vgui.Create("DButton", hrow)
                removeB:SetText("Remove")
                removeB:Dock(RIGHT) removeB:SetWide(90) removeB:DockMargin(0, 2, 6, 2)
                removeB.DoClick = function() send_cmd("hacked_remove", { hacked_id = h.id }) end
                local virusB = vgui.Create("DButton", hrow)
                virusB:SetText("Install virus")
                virusB:Dock(RIGHT) virusB:SetWide(110) virusB:DockMargin(0, 2, 2, 2)
                virusB.DoClick = function()
                    local m = DermaMenu()
                    for _, st in ipairs({ 8, 9, 10, 11, 12, 20, 29 }) do
                        m:AddOption(MH.Data.SoftName(st), function()
                            send_cmd("virus_install", { target_server = h.target_server, soft_type = st })
                        end)
                    end
                    m:Open()
                end
                local doomB = vgui.Create("DButton", hrow)
                doomB:SetText("Launch DOOM")
                doomB:Dock(RIGHT) doomB:SetWide(120) doomB:DockMargin(0, 2, 2, 2)
                doomB.DoClick = function()
                    local myDoom
                    for _, s in ipairs(MH.OS.State.servers or {}) do
                        for _, inv in ipairs(s.software or {}) do
                            if tonumber(inv.server_id) == tonumber(h.target_server)
                                and (tonumber(inv.soft_type) == 29 or tonumber(inv.soft_type) == 96)
                                and inv.owner_sid == (MH.OS.State.player or {}).sid64
                            then myDoom = inv break end
                        end
                        if myDoom then break end
                    end
                    if not myDoom then
                        Derma_Message("Install a Doom virus on this target first (right-click, Install virus, Doom).",
                            "No Doom planted", "OK")
                        return
                    end
                    Derma_Query("Release DOOM against " .. tostring(h.ip) .. "?\nThis is irreversible and will escalate everything.",
                        "Launch DOOM", "Release",
                        function() send_cmd("doom_launch", { target_server = h.target_server, soft_id = myDoom.id }) end,
                        "Cancel", function() end)
                end
                local gotoB = vgui.Create("DButton", hrow)
                gotoB:SetText("Open in Internet")
                gotoB:Dock(RIGHT) gotoB:SetWide(130) gotoB:DockMargin(0, 2, 2, 2)
                gotoB.DoClick = function()
                    send_cmd("internet_goto", { ip = tostring(h.ip or "") })
                    MH.OS.ActiveTab = "Internet"
                    if MH.OS.Rebuild then MH.OS.Rebuild() end
                end
            end
        elseif MH.OS.HackedView == "Bank Accounts" then
            local banks = MH.OS.State.hacked_banks or {}
            if #banks == 0 then
                label(body, "No captured bank accounts."):Dock(TOP)
                return
            end
            local list = vgui.Create("DListView", body)
            list:Dock(FILL)
            list:AddColumn("Bank"):SetFixedWidth(140)
            list:AddColumn("Bank IP"):SetFixedWidth(140)
            list:AddColumn("Account"):SetFixedWidth(130)
            list:AddColumn("Password"):SetFixedWidth(100)
            for _, b in ipairs(banks) do
                local brow = vgui.Create("DPanel", body)
                brow:Dock(TOP)
                brow:SetTall(28)
                brow:DockMargin(0, 2, 0, 0)
                local binfo = vgui.Create("DLabel", brow)
                binfo:Dock(FILL)
                binfo:SetDark(true)
                binfo:SetFont("DermaDefaultBold")
                binfo:SetText("  " .. tostring(b.bank_name or "?") .. "   " .. tostring(b.bank_ip or "?") ..
                    "   acc " .. tostring(b.acc_num) .. "   pass " .. tostring(b.acc_pass))
                local forgetB = vgui.Create("DButton", brow)
                forgetB:SetText("Forget")
                forgetB:Dock(RIGHT) forgetB:SetWide(80) forgetB:DockMargin(0, 2, 6, 2)
                forgetB.DoClick = function() send_cmd("hacked_bank_forget", { hacked_bank_id = b.id }) end
                local siphonB = vgui.Create("DButton", brow)
                siphonB:SetText("Siphon")
                siphonB:Dock(RIGHT) siphonB:SetWide(80) siphonB:DockMargin(0, 2, 2, 2)
                siphonB.DoClick = function() send_cmd("hacked_bank_withdraw", { hacked_bank_id = b.id }) end
                local loginB = vgui.Create("DButton", brow)
                loginB:SetText("Login via Internet")
                loginB:Dock(RIGHT) loginB:SetWide(140) loginB:DockMargin(0, 2, 2, 2)
                loginB.DoClick = function()
                    send_cmd("internet_goto", { ip = tostring(b.bank_ip or "") })
                    send_cmd("bank_internet_login", { ip = tostring(b.bank_ip or ""), acc = b.acc_num, pass = b.acc_pass })
                    MH.OS.ActiveTab = "Internet"
                    if MH.OS.Rebuild then MH.OS.Rebuild() end
                end
            end
        elseif MH.OS.HackedView == "Collect" then
            local viruses = MH.OS.State.installed_viruses or {}
            label(body, "Installed viruses (" .. #viruses .. ")", "DermaDefaultBold"):Dock(TOP)
            local collectB = vgui.Create("DButton", body)
            collectB:Dock(TOP)
            collectB:DockMargin(0, 6, 0, 6)
            collectB:SetTall(32)
            collectB:SetText("Collect from all installed viruses")
            collectB.DoClick = function() send_cmd("virus_collect", {}) end
            if #viruses == 0 then
                label(body, "No viruses installed on any host. Hack a target and install a Spam, Warez, DDoS, or Miner virus on it."):Dock(TOP)
            else
                local list = vgui.Create("DListView", body)
                list:Dock(TOP)
                list:SetTall(400)
                list:AddColumn("Host"):SetFixedWidth(160)
                list:AddColumn("IP"):SetFixedWidth(140)
                list:AddColumn("Virus"):SetFixedWidth(130)
                list:AddColumn("Version"):SetFixedWidth(70)
                list:AddColumn("Last collect"):SetFixedWidth(160)
                list:AddColumn("Status")
                local nowT = os.time()
                for _, v in ipairs(viruses) do
                    local meta = MH.Data.Soft[tonumber(v.soft_type or 0)] or {}
                    local last = tonumber(v.last_collect or 0) or 0
                    local lastStr = last > 0 and os.date("%Y-%m-%d %H:%M", last) or "never"
                    local waited = last == 0 and 600 or (nowT - last)
                    local status = waited >= 600 and "Ready" or ("Cooling (" .. (600 - waited) .. "s)")
                    if tonumber(v.hidden or 0) == 1 then status = status .. "  [hidden]" end
                    list:AddLine(
                        tostring(v.host_name or "?"),
                        tostring(v.host_ip or "?"),
                        tostring(meta.name or ("#" .. tostring(v.soft_type))),
                        "v" .. MH.Data.DotVersion(v.soft_version),
                        lastStr,
                        status)
                end
            end
        elseif MH.OS.HackedView == "DDoS" then
            label(body, "Launch DDoS attack", "DermaLarge"):Dock(TOP)
            local warn = vgui.Create("DLabel", body)
            warn:Dock(TOP)
            warn:DockMargin(0, 4, 0, 4)
            warn:SetDark(false)
            warn:SetTextColor(Color(220, 80, 90))
            warn:SetFont("DermaDefaultBold")
            warn:SetText("WARNING: your attacker IP is logged on every victim machine during a DDoS run.")
            warn:SizeToContents()
            local p = MH.OS.State.player or {}
            local certLvl = tonumber(p.cert_level or 0) or 0
            if certLvl < 4 then
                label(body, "Requires DDoS Security (cert 4). Current level: " .. certLvl .. " / 5."):Dock(TOP)
                return
            end
            local virusCount = 0
            for _, h in ipairs(MH.OS.State.hacked or {}) do
                for _, s in ipairs(MH.OS.State.servers or {}) do
                    for _, inv in ipairs(s.software or {}) do
                        if tonumber(inv.soft_type) == 10 and tonumber(inv.installed) == 1
                            and tonumber(inv.server_id) == tonumber(h.target_server)
                        then virusCount = virusCount + 1 end
                    end
                end
            end
            label(body, "Active DDoS viruses: " .. virusCount .. " / 3 required"):Dock(TOP)
            if virusCount < 3 then
                return
            end
            local row = vgui.Create("DPanel", body)
            row:Dock(TOP)
            row:SetTall(32)
            row:DockMargin(0, 8, 0, 0)
            local entry = vgui.Create("DTextEntry", row)
            entry:Dock(FILL)
            entry:SetPlaceholderText("Target IP")
            local launchB = vgui.Create("DButton", row)
            launchB:SetText("Launch")
            launchB:Dock(RIGHT)
            launchB:SetWide(100)
            launchB:DockMargin(4, 0, 0, 0)
            launchB.DoClick = function()
                send_cmd("ddos_launch", { ip = entry:GetValue() })
            end
        end
    end

    for _, name in ipairs({ "IP List", "Bank Accounts", "Collect", "DDoS" }) do
        local b = vgui.Create("DButton", subbar)
        b:SetText(name)
        b:Dock(LEFT)
        b:SetWide(130)
        b:DockMargin(0, 0, 4, 0)
        b.DoClick = function() MH.OS.HackedView = name paint() end
    end

    paint()
end

MH.OS.MissionView = MH.OS.MissionView or "Active"

local MISSION_STATUS_TXT = {
    [0] = "Available",
    [1] = "Active",
    [2] = "Ready",
    [3] = "Done",
    [-1] = "Aborted",
}

local MISSION_TITLES = {
    [1] = "Delete a software",
    [2] = "Steal a software",
    [3] = "Check bank status",
    [4] = "Transfer money",
    [5] = "Destroy a server",
}

Tabs["Missions"] = function(container)
    clear(container)
    label(container, "Missions", "DermaLarge"):Dock(TOP)

    local subbar = vgui.Create("DPanel", container)
    subbar:Dock(TOP)
    subbar:SetTall(28)
    subbar:DockMargin(0, 2, 0, 6)

    local body = vgui.Create("DPanel", container)
    body:Dock(TOP)
    body:SetTall(640)

    local function paint()
        body:Clear()
        local ms = MH.OS.State.missions or {}
        local filter
        if MH.OS.MissionView == "Active" then
            filter = function(m) local s = tonumber(m.status) return s == 0 or s == 1 or s == 2 end
        else
            filter = function(m) local s = tonumber(m.status) return s == 3 or s == -1 end
        end

        local filtered = {}
        for _, m in ipairs(ms) do if filter(m) then table.insert(filtered, m) end end

        if #filtered == 0 then
            label(body, MH.OS.MissionView == "Active" and "No active missions." or "No history yet."):Dock(TOP)
            return
        end

        local list = vgui.Create("DListView", body)
        list:Dock(TOP)
        list:SetTall(200)
        list:DockMargin(0, 0, 0, 6)
        list:AddColumn("Mission"):SetFixedWidth(200)
        list:AddColumn("Giver"):SetFixedWidth(110)
        list:AddColumn("Target"):SetFixedWidth(260)
        list:AddColumn("Prize"):SetFixedWidth(90)
        list:AddColumn("Difficulty"):SetFixedWidth(90)
        list:AddColumn("Status"):SetFixedWidth(90)

        local giverBox = vgui.Create("DPanel", body)
        giverBox:Dock(TOP)
        giverBox:SetTall(80)
        giverBox:DockMargin(0, 4, 0, 4)
        local giverAvatar = vgui.Create("DModelPanel", giverBox)
        giverAvatar:Dock(LEFT)
        giverAvatar:SetWide(80)
        giverAvatar:SetVisible(false)
        local headerLbl = vgui.Create("DLabel", giverBox)
        headerLbl:Dock(FILL)
        headerLbl:DockMargin(10, 0, 0, 0)
        headerLbl:SetDark(true)
        headerLbl:SetFont("DermaDefaultBold")
        headerLbl:SetWrap(true)
        headerLbl:SetText("Select a mission to read the briefing.")

        local reader = vgui.Create("DTextEntry", body)
        reader:Dock(TOP)
        reader:SetTall(300)
        reader:DockMargin(0, 4, 0, 4)

        local actionBar = vgui.Create("DPanel", body)
        actionBar:Dock(TOP)
        actionBar:SetTall(32)
        actionBar:DockMargin(0, 0, 0, 0)
        reader:SetMultiline(true)
        reader:SetEditable(false)
        reader:SetVerticalScrollbarEnabled(true)

        local acceptB = vgui.Create("DButton", actionBar)
        acceptB:SetText("Accept")
        acceptB:Dock(LEFT)
        acceptB:SetWide(140)
        acceptB:SetEnabled(false)

        local abortB = vgui.Create("DButton", actionBar)
        abortB:SetText("Abort (10% rep decay)")
        abortB:Dock(LEFT)
        abortB:DockMargin(4, 0, 0, 0)
        abortB:SetWide(180)
        abortB:SetEnabled(false)

        local completeB = vgui.Create("DButton", actionBar)
        completeB:SetText("Complete and claim prize")
        completeB:Dock(LEFT)
        completeB:DockMargin(4, 0, 0, 0)
        completeB:SetWide(200)
        completeB:SetEnabled(false)

        local selectedMission
        local function difficulty_for(prize)
            prize = tonumber(prize) or 0
            if prize < 2000 then return "Low"
            elseif prize < 5000 then return "Medium"
            elseif prize < 10000 then return "High"
            else return "Extreme" end
        end
        for _, m in ipairs(filtered) do
            local locked = tonumber(m.locked or 0) == 1
            local title, giver, targetTxt, prizeTxt, diffTxt, statusTxt
            if locked then
                title = "????"
                giver = "????"
                targetTxt = "????"
                prizeTxt = "????"
                diffTxt = "????"
                statusTxt = "Unavailable"
            else
                title = MISSION_TITLES[tonumber(m.mtype)] or ("#" .. tostring(m.mtype))
                giver = tostring(m.hirer_name or "Employers")
                targetTxt = tostring(m.target_name or "?") .. "  " .. tostring(m.target_ip or "")
                prizeTxt = "$" .. tostring(m.prize)
                diffTxt = difficulty_for(m.prize)
                statusTxt = MISSION_STATUS_TXT[tonumber(m.status)] or tostring(m.status)
            end
            local line = list:AddLine(title, giver, targetTxt, prizeTxt, diffTxt, statusTxt)
            line.MH_Mission = m
        end

        list.OnRowSelected = function(_, _, lineRef)
            local m = lineRef and lineRef.MH_Mission
            if not m then return end
            selectedMission = m
            local locked = tonumber(m.locked or 0) == 1
            if locked then
                headerLbl:SetText("????\nGiver: ????\nTarget: ????   Prize ????   Status Unavailable")
                giverAvatar:SetVisible(false)
                reader:SetValue("Hirer unknown. Discover the giver's IP first.")
                acceptB:SetEnabled(false)
                abortB:SetEnabled(false)
                completeB:SetEnabled(false)
                return
            end
            local giverName = tostring(m.hirer_name or "Employers")
            local title = MISSION_TITLES[tonumber(m.mtype)] or ("Mission #" .. tostring(m.mtype))
            headerLbl:SetText(title ..
                "\nGiver: " .. giverName ..
                "\nTarget: " .. tostring(m.target_name or "?") .. " " .. tostring(m.target_ip or "") ..
                "   Prize $" .. tostring(m.prize) ..
                "   Status " .. (MISSION_STATUS_TXT[tonumber(m.status)] or ""))
            giverAvatar:SetVisible(true)
            setup_avatar(giverAvatar, resolve_sender_model(giverName))
            local brief = tostring(m.briefing or "")
            if brief == "" then brief = "No briefing on file." end
            reader:SetValue(brief)
            local s = tonumber(m.status)
            acceptB:SetEnabled(s == 0)
            abortB:SetEnabled(s == 1 and tonumber(m.mtype) < 49)
            completeB:SetEnabled(s == 2)
        end

        acceptB.DoClick = function()
            if not selectedMission then return end
            send_cmd("mission_accept", { mission_id = selectedMission.id })
        end
        abortB.DoClick = function()
            if not selectedMission then return end
            local mid = selectedMission.id
            Derma_Query("Abort mission? You will lose 10 percent of your reputation.",
                "Abort", "Abort",
                function() send_cmd("mission_abort", { mission_id = mid }) end,
                "Cancel", function() end)
        end
        completeB.DoClick = function()
            if not selectedMission then return end
            local mid = selectedMission.id
            if tonumber(selectedMission.mtype) == 3 then
                Derma_StringRequest(
                    "Report balance",
                    "Report the balance you observed on the target account:",
                    "", function(txt)
                        send_cmd("mission_complete", { mission_id = mid, amount = tonumber(txt) })
                    end)
            else
                send_cmd("mission_complete", { mission_id = mid })
            end
        end
    end

    for _, name in ipairs({ "Active", "Completed" }) do
        local b = vgui.Create("DButton", subbar)
        b:SetText(name)
        b:Dock(LEFT)
        b:SetWide(110)
        b:DockMargin(0, 0, 4, 0)
        b.DoClick = function() MH.OS.MissionView = name paint() end
    end

    paint()
end

MH.OS.MailView = MH.OS.MailView or "Inbox"
MH.OS.MailReply = MH.OS.MailReply or nil

SYSTEM_SENDERS = {
    RakTheGoose  = { model = "models/player/skeleton.mdl",              name = "RakTheGoose" },
    Employers    = { model = "models/player/gman_high.mdl",             name = "G-Man" },
    FBI          = { model = "models/player/police.mdl",                name = "FBI" },
    MSA          = { model = "models/player/soldier_stripped.mdl",      name = "MSA" },
    Sourcenet      = { model = "models/player/combine_super_soldier.mdl", name = "Sourcenet" },
    Social       = { model = "models/player/alyx.mdl",                  name = "Social" },
    BadgeAdvisor = { model = "models/player/kleiner.mdl",               name = "Badge Advisor" },
}
DEFAULT_SENDER_MODEL = "models/player/kleiner.mdl"

resolve_sender_model = function(sid)
    sid = tostring(sid or "")
    local sys = SYSTEM_SENDERS[sid]
    if sys then return sys.model end
    local ply = player.GetBySteamID64(sid)
    if IsValid(ply) then return ply:GetModel() end
    return DEFAULT_SENDER_MODEL
end

resolve_sender_name = function(sid)
    sid = tostring(sid or "")
    local sys = SYSTEM_SENDERS[sid]
    if sys then return sys.name end
    local ply = player.GetBySteamID64(sid)
    if IsValid(ply) then return ply:Nick() end
    return sid
end

setup_avatar = function(mdlPanel, model)
    mdlPanel:SetModel(model)
    mdlPanel.CamSet = false
    function mdlPanel:LayoutEntity(ent)
        self:RunAnimation()
        if not self.CamSet then
            local boneIdx = ent:LookupBone("ValveBiped.Bip01_Head1")
            if boneIdx then
                local pos = ent:GetBonePosition(boneIdx)
                if pos and pos:LengthSqr() > 0 then
                    local lookPos = pos + Vector(0, 0, 2)
                    self:SetLookAt(lookPos)
                    self:SetCamPos(lookPos + Vector(28, 0, 4))
                    self:SetFOV(32)
                    self.CamSet = true
                end
            end
        end
    end
end

Tabs["Mail"] = function(container)
    clear(container)
    label(container, "Mail", "DermaLarge"):Dock(TOP)

    local subbar = vgui.Create("DPanel", container)
    subbar:Dock(TOP)
    subbar:SetTall(28)
    subbar:DockMargin(0, 2, 0, 6)

    for _, name in ipairs({ "Inbox", "Outbox", "Compose" }) do
        local b = vgui.Create("DButton", subbar)
        b:SetText(name)
        b:Dock(LEFT)
        b:SetWide(100)
        b:DockMargin(0, 0, 4, 0)
        b.DoClick = function()
            MH.OS.MailView = name
            if MH.OS.Rebuild then MH.OS.Rebuild() end
        end
    end

    if MH.OS.MailView == "Inbox" or MH.OS.MailView == "Outbox" then
        local src = MH.OS.MailView == "Inbox" and (MH.OS.State.mail_inbox or {}) or (MH.OS.State.mail_outbox or {})
        local isInbox = MH.OS.MailView == "Inbox"
        if #src == 0 then
            label(container, isInbox and "Inbox is empty." or "No sent messages."):Dock(TOP)
            return
        end

        local list = vgui.Create("DListView", container)
        list:Dock(TOP)
        list:SetTall(200)
        list:DockMargin(0, 0, 0, 6)
        list:AddColumn(""):SetFixedWidth(24)
        list:AddColumn(isInbox and "From" or "To"):SetFixedWidth(160)
        list:AddColumn("Subject"):SetFixedWidth(260)
        list:AddColumn("Received")

        local senderBox = vgui.Create("DPanel", container)
        senderBox:Dock(TOP)
        senderBox:SetTall(80)
        senderBox:DockMargin(0, 4, 0, 4)

        local avatar = vgui.Create("DModelPanel", senderBox)
        avatar:Dock(LEFT)
        avatar:SetWide(80)
        avatar:SetVisible(false)

        local senderInfo = vgui.Create("DLabel", senderBox)
        senderInfo:Dock(FILL)
        senderInfo:DockMargin(10, 0, 0, 0)
        senderInfo:SetDark(true)
        senderInfo:SetFont("DermaDefaultBold")
        senderInfo:SetWrap(true)
        senderInfo:SetText("Select a message to read its contents here.")

        local reader = vgui.Create("RichText", container)
        if not IsValid(reader) then
            reader = vgui.Create("DTextEntry", container)
            reader:SetMultiline(true)
            reader:SetEditable(false)
            reader:SetVerticalScrollbarEnabled(true)
            reader.InsertColorChange = function() end
            reader.AppendText = function(self, s) self:SetValue((self:GetValue() or "") .. tostring(s)) end
        end
        reader:Dock(TOP)
        reader:SetTall(280)
        reader:DockMargin(0, 4, 0, 4)
        if reader.SetFontInternal then reader:SetFontInternal("MH_MailBody") end
        if reader.SetFont then reader:SetFont("MH_MailBody") end

        local ipStrip = vgui.Create("DPanel", container)
        ipStrip:Dock(TOP)
        ipStrip:SetTall(32)
        ipStrip:DockMargin(0, 2, 0, 4)
        ipStrip:SetVisible(false)

        local actionRow = vgui.Create("DPanel", container)
        actionRow:Dock(TOP)
        actionRow:SetTall(32)
        actionRow:DockMargin(0, 2, 0, 0)
        local replyB = vgui.Create("DButton", actionRow)
        replyB:SetText("Reply")
        replyB:Dock(LEFT)
        replyB:SetWide(80)
        replyB:SetEnabled(false)
        local delB = vgui.Create("DButton", actionRow)
        delB:SetText("Delete")
        delB:Dock(LEFT)
        delB:DockMargin(4, 0, 0, 0)
        delB:SetWide(80)
        delB:SetEnabled(false)
        delB:SetVisible(isInbox)

        for _, m in ipairs(src) do
            local party = isInbox and m.from_sid or m.to_sid
            local unread = isInbox and tonumber(m.seen or 0) == 0
            local lineRef = list:AddLine(
                unread and "*" or "",
                resolve_sender_name(party),
                tostring(m.subject or "(no subject)"),
                os.date("%Y-%m-%d %H:%M", tonumber(m.stamp or 0))
            )
            lineRef.MH_Mail = m
        end

        local selected = nil
        list.OnRowSelected = function(_, _, lineRef)
            local m = lineRef and lineRef.MH_Mail
            if not m then return end
            selected = m
            local party = isInbox and m.from_sid or m.to_sid
            local partyName = resolve_sender_name(party)
            senderInfo:SetText(tostring(m.subject or "(no subject)") ..
                "\n" .. (isInbox and ("From " .. partyName) or ("To " .. partyName)) ..
                "\n" .. os.date("%Y-%m-%d %H:%M", tonumber(m.stamp or 0)))
            reader:SetText("")
            if reader.SetFontInternal then reader:SetFontInternal("MH_MailBody") end
            if reader.SetFont then reader:SetFont("MH_MailBody") end
            reader:InsertColorChange(230, 236, 246, 255)
            reader:AppendText(tostring(m.body or ""))

            ipStrip:Clear()
            local ips, seen = {}, {}
            for ip in tostring(m.body or ""):gmatch("%d+%.%d+%.%d+%.%d+") do
                if not seen[ip] then seen[ip] = true table.insert(ips, ip) end
            end
            if #ips > 0 then
                ipStrip:SetVisible(true)
                local lbl = vgui.Create("DLabel", ipStrip)
                lbl:SetText("Open in Internet:")
                lbl:SetDark(true)
                lbl:SetFont("DermaDefaultBold")
                lbl:Dock(LEFT)
                lbl:DockMargin(4, 0, 6, 0)
                lbl:SizeToContents()
                for _, ip in ipairs(ips) do
                    local btn = vgui.Create("DButton", ipStrip)
                    btn:SetText(ip)
                    btn:Dock(LEFT)
                    btn:DockMargin(0, 4, 4, 4)
                    btn:SetWide(130)
                    btn.DoClick = function()
                        send_cmd("internet_goto", { ip = ip })
                        MH.OS.ActiveTab = "Internet"
                        if MH.OS.Rebuild then MH.OS.Rebuild() end
                    end
                end
            else
                ipStrip:SetVisible(false)
            end

            avatar:SetVisible(true)
            setup_avatar(avatar, resolve_sender_model(party))
            local isSystem = SYSTEM_SENDERS[tostring(party)] ~= nil
            replyB:SetEnabled(not isSystem)
            delB:SetEnabled(isInbox)
            if isInbox and tonumber(m.seen or 0) == 0 then
                send_cmd("mail_mark_read", { mail_id = m.id })
                m.seen = 1
                if lineRef.SetColumnText then lineRef:SetColumnText(1, "") end
                local unreadCount = tonumber(MH.OS.State.mail_unread or 0) or 0
                MH.OS.State.mail_unread = math.max(0, unreadCount - 1)
            end
        end
        replyB.DoClick = function()
            if not selected then return end
            MH.OS.MailReply = {
                to = tostring(isInbox and selected.from_sid or selected.to_sid),
                subject = "Re: " .. tostring(selected.subject or ""),
                body = "\n\n--- Original ---\n" .. tostring(selected.body or ""),
            }
            MH.OS.MailView = "Compose"
            if MH.OS.Rebuild then MH.OS.Rebuild() end
        end
        delB.DoClick = function()
            if not selected or not isInbox then return end
            send_cmd("mail_delete", { mail_id = selected.id })
        end
    elseif MH.OS.MailView == "Compose" then
        local initial = MH.OS.MailReply or {}
        MH.OS.MailReply = nil
        label(container, "New message", "DermaDefaultBold"):Dock(TOP)
        local toLbl = label(container, "To (SteamID64 or nick):") toLbl:Dock(TOP) toLbl:DockMargin(0, 6, 0, 2)
        local toRow = vgui.Create("DPanel", container)
        toRow:Dock(TOP) toRow:SetTall(26)
        local toEntry = vgui.Create("DTextEntry", toRow)
        toEntry:Dock(FILL) toEntry:SetText(initial.to or "")
        local toCombo = vgui.Create("DComboBox", toRow)
        toCombo:Dock(RIGHT) toCombo:SetWide(160)
        toCombo:SetValue("Pick known player")
        for _, kp in ipairs(MH.OS.State.known_players or {}) do
            toCombo:AddChoice(tostring(kp.nick), tostring(kp.sid64))
        end
        toCombo.OnSelect = function(_, _, _, data) toEntry:SetValue(tostring(data)) end
        local subLbl = label(container, "Subject:")              subLbl:Dock(TOP) subLbl:DockMargin(0, 6, 0, 2)
        local subEntry = vgui.Create("DTextEntry", container)    subEntry:Dock(TOP) subEntry:SetText(initial.subject or "")
        local bodyLbl = label(container, "Message:")             bodyLbl:Dock(TOP) bodyLbl:DockMargin(0, 6, 0, 2)
        local bodyEntry = vgui.Create("DTextEntry", container)
        bodyEntry:Dock(TOP)
        bodyEntry:SetTall(280)
        bodyEntry:SetMultiline(true)
        bodyEntry:SetValue(initial.body or "")
        local sendB = vgui.Create("DButton", container)
        sendB:Dock(TOP)
        sendB:SetTall(32)
        sendB:DockMargin(0, 8, 0, 0)
        sendB:SetText("Send")
        sendB.DoClick = function()
            send_cmd("mail_send", {
                to = toEntry:GetValue(),
                subject = subEntry:GetValue(),
                body = bodyEntry:GetValue(),
            })
            MH.OS.MailView = "Outbox"
            if MH.OS.Rebuild then MH.OS.Rebuild() end
        end
        end
end

local TAB_ORDER = { "Home", "Task Manager", "Software", "Internet", "Log File", "Hardware", "University", "Finances", "Hacked Database", "Missions", "Mail", "Ranking", "Settings", "Admin" }
local ADMIN_ONLY_TABS = { Admin = true }

Tabs["Ranking"] = function(container)
    clear(container)
    label(container, "Hall of Fame", "DermaLarge"):Dock(TOP)

    local CATEGORIES = {
        { key = "reputation", title = "Reputation",     valueFmt = function(v) return tostring(math.floor(v)) end },
        { key = "hacks",      title = "Hacks",          valueFmt = function(v) return tostring(math.floor(v)) end },
        { key = "software",   title = "Software",       software = true },
        { key = "money",      title = "Money earned",   valueFmt = function(v) return "$" .. math.floor(v) end },
        { key = "transfers",  title = "Money moved",    valueFmt = function(v) return "$" .. math.floor(v) end },
        { key = "wealth",     title = "Current wealth", valueFmt = function(v) return "$" .. math.floor(v) end },
        { key = "bitcoin",    title = "Bitcoin",        valueFmt = function(v) return string.format("%.4f BTC", v) end },
        { key = "viruses",    title = "Viruses planted",valueFmt = function(v) return tostring(math.floor(v)) end },
        { key = "ddos",       title = "DDoS runs",      valueFmt = function(v) return tostring(math.floor(v)) end },
        { key = "doom",       title = "DOOM releases",  valueFmt = function(v) return tostring(math.floor(v)) end },
        { key = "certs",      title = "Certifications", valueFmt = function(v) return tostring(math.floor(v)) .. " / 5" end },
        { key = "missions",   title = "Missions done",  valueFmt = function(v) return tostring(math.floor(v)) end },
    }

    local TABLES_PER_ROW = 2
    local TABLE_WIDE = 490
    local TABLE_TALL = 300
    local HEADER_TALL = 22

    local rowPanel
    for i, c in ipairs(CATEGORIES) do
        if (i - 1) % TABLES_PER_ROW == 0 then
            rowPanel = vgui.Create("DPanel", container)
            rowPanel:Dock(TOP)
            rowPanel:SetTall(TABLE_TALL + HEADER_TALL + 8)
            rowPanel:DockMargin(0, 6, 0, 8)
            rowPanel.Paint = function() end
        end

        local cell = vgui.Create("DPanel", rowPanel)
        cell:Dock(LEFT)
        cell:SetWide(TABLE_WIDE)
        cell:DockMargin(0, 0, 10, 0)
        cell.Paint = function() end

        local hdr = vgui.Create("DLabel", cell)
        hdr:Dock(TOP)
        hdr:SetTall(HEADER_TALL)
        hdr:SetFont("DermaDefaultBold")
        hdr:SetDark(true)
        hdr:SetText(c.title)

        local list = vgui.Create("DListView", cell)
        list:Dock(FILL)
        list:AddColumn("Rank"):SetFixedWidth(50)
        list:AddColumn("Nick"):SetFixedWidth(200)
        list:AddColumn(c.title)
        local rows = (MH.OS.State.ranking or {})[c.key] or {}
        if #rows == 0 then
            list:AddLine("-", "No entries yet", "")
        else
            for rank, r in ipairs(rows) do
                local valStr
                if c.software then
                    local meta = MH.Data.Soft[tonumber(r.soft_type or 0)] or {}
                    valStr = tostring(r.soft_name or "?") .. (meta.ext or "") ..
                        " v" .. MH.Data.DotVersion(r.soft_version)
                else
                    valStr = c.valueFmt(tonumber(r.val) or 0)
                end
                list:AddLine(tostring(rank), tostring(r.nick or "?"), valStr)
            end
        end
    end
end

Tabs["Settings"] = function(container)
    clear(container)
    label(container, "Settings", "DermaLarge"):Dock(TOP)
    local reconnectB = vgui.Create("DButton", container)
    reconnectB:SetText("Refresh")
    reconnectB:Dock(TOP)
    reconnectB:SetTall(30)
    reconnectB:DockMargin(0, 10, 0, 0)
    reconnectB.DoClick = function() send_cmd("refresh", {}) end
    local closeB = vgui.Create("DButton", container)
    closeB:SetText("Close")
    closeB:Dock(TOP)
    closeB:SetTall(30)
    closeB:DockMargin(0, 6, 0, 0)
    closeB.DoClick = function()
        if IsValid(MH.OS.Frame) then MH.OS.Frame:Remove() end
    end
end

Tabs["Admin"] = function(container)
    clear(container)
    if not MH.OS.State.is_admin then
        label(container, "Admin", "DermaLarge"):Dock(TOP)
        label(container, "You are not an administrator."):Dock(TOP)
        return
    end
    label(container, "Admin", "DermaLarge"):Dock(TOP)
    label(container, "Ban a player (SteamID64 or online player). Banned users cannot interact with Metahacker."):Dock(TOP)

    local pickerRow = vgui.Create("DPanel", container)
    pickerRow:Dock(TOP) pickerRow:SetTall(28) pickerRow:DockMargin(0, 8, 0, 0)
    local onlineCombo = vgui.Create("DComboBox", pickerRow)
    onlineCombo:Dock(LEFT) onlineCombo:SetWide(220)
    onlineCombo:SetValue("Pick online player...")
    for _, op in ipairs(MH.OS.State.admin_online or {}) do
        onlineCombo:AddChoice(op.nick .. " (" .. op.sid64 .. ")", op.sid64)
    end
    local sidEntry = vgui.Create("DTextEntry", pickerRow)
    sidEntry:Dock(LEFT) sidEntry:SetWide(220) sidEntry:DockMargin(6, 0, 0, 0)
    sidEntry:SetPlaceholderText("or paste SteamID64")
    onlineCombo.OnSelect = function(_, _, _, data)
        if data then sidEntry:SetValue(tostring(data)) end
    end

    local reasonRow = vgui.Create("DPanel", container)
    reasonRow:Dock(TOP) reasonRow:SetTall(28) reasonRow:DockMargin(0, 6, 0, 0)
    local reasonEntry = vgui.Create("DTextEntry", reasonRow)
    reasonEntry:Dock(FILL) reasonEntry:SetPlaceholderText("ban reason")

    local btnRow = vgui.Create("DPanel", container)
    btnRow:Dock(TOP) btnRow:SetTall(30) btnRow:DockMargin(0, 6, 0, 0)
    local banB = button(btnRow, "Ban", function()
        local target = string.Trim(tostring(sidEntry:GetValue() or ""))
        if target == "" then return end
        send_cmd("admin_ban", { sid64 = target, reason = reasonEntry:GetValue() })
    end)
    banB:Dock(LEFT) banB:SetWide(100)

    label(container, "Currently banned", "DermaDefaultBold"):Dock(TOP)
    local banList = vgui.Create("DListView", container)
    banList:Dock(TOP) banList:SetTall(220) banList:DockMargin(0, 4, 0, 0)
    banList:AddColumn("Nick"):SetFixedWidth(160)
    banList:AddColumn("SteamID64"):SetFixedWidth(180)
    banList:AddColumn("Reason")
    for _, b in ipairs(MH.OS.State.admin_bans or {}) do
        local line = banList:AddLine(tostring(b.nick or "?"), tostring(b.sid64 or ""), tostring(b.reason or ""))
        line.MH_SID = tostring(b.sid64 or "")
    end
    banList.OnRowRightClick = function(_, _, lineRef)
        if not lineRef or not lineRef.MH_SID then return end
        local m = DermaMenu()
        m:AddOption("Unban " .. lineRef.MH_SID, function()
            send_cmd("admin_unban", { sid64 = lineRef.MH_SID })
        end)
        m:Open()
    end
    local unbanB = vgui.Create("DButton", container)
    unbanB:SetText("Unban selected")
    unbanB:Dock(TOP) unbanB:SetTall(28) unbanB:DockMargin(0, 6, 0, 0)
    unbanB.DoClick = function()
        local id = banList:GetSelectedLine()
        local lineRef = id and banList:GetLine(id)
        if lineRef and lineRef.MH_SID then
            send_cmd("admin_unban", { sid64 = lineRef.MH_SID })
        end
    end

    label(container, "Mail-banned (cannot send mail)", "DermaDefaultBold"):Dock(TOP)
    local mailBanList = vgui.Create("DListView", container)
    mailBanList:Dock(TOP) mailBanList:SetTall(160) mailBanList:DockMargin(0, 4, 0, 0)
    mailBanList:AddColumn("Nick"):SetFixedWidth(160)
    mailBanList:AddColumn("SteamID64"):SetFixedWidth(180)
    mailBanList:AddColumn("Reason")
    for _, b in ipairs(MH.OS.State.admin_mail_bans or {}) do
        local line = mailBanList:AddLine(tostring(b.nick or "?"), tostring(b.sid64 or ""), tostring(b.reason or ""))
        line.MH_SID = tostring(b.sid64 or "")
    end
    mailBanList.OnRowRightClick = function(_, _, lineRef)
        if not lineRef or not lineRef.MH_SID then return end
        local m = DermaMenu()
        m:AddOption("Mail-unban " .. lineRef.MH_SID, function()
            send_cmd("admin_mail_unban", { sid64 = lineRef.MH_SID })
        end)
        m:Open()
    end
    local mailBanRow = vgui.Create("DPanel", container)
    mailBanRow:Dock(TOP) mailBanRow:SetTall(28) mailBanRow:DockMargin(0, 6, 0, 0)
    local mailBanAdd = button(mailBanRow, "Mail-ban SID from Ban form above", function()
        local target = string.Trim(tostring(sidEntry:GetValue() or ""))
        if target == "" then return end
        send_cmd("admin_mail_ban", { sid64 = target, reason = reasonEntry:GetValue() })
    end)
    mailBanAdd:Dock(LEFT) mailBanAdd:SetWide(260)
    local mailUnbanB = button(mailBanRow, "Mail-unban selected", function()
        local id = mailBanList:GetSelectedLine()
        local lineRef = id and mailBanList:GetLine(id)
        if lineRef and lineRef.MH_SID then
            send_cmd("admin_mail_unban", { sid64 = lineRef.MH_SID })
        end
    end)
    mailUnbanB:Dock(LEFT) mailUnbanB:SetWide(180) mailUnbanB:DockMargin(6, 0, 0, 0)

    label(container, "Abuse stats", "DermaDefaultBold"):Dock(TOP)
    label(container, "Players with rate-limit strikes, high command counts, or high mail volume."):Dock(TOP)
    local statsList = vgui.Create("DListView", container)
    statsList:Dock(TOP) statsList:SetTall(220) statsList:DockMargin(0, 4, 0, 0)
    statsList:AddColumn("Nick"):SetFixedWidth(140)
    statsList:AddColumn("SteamID64"):SetFixedWidth(170)
    statsList:AddColumn("CmdHits"):SetFixedWidth(70)
    statsList:AddColumn("MailHits"):SetFixedWidth(70)
    statsList:AddColumn("Cmds"):SetFixedWidth(70)
    statsList:AddColumn("Mails"):SetFixedWidth(70)
    statsList:AddColumn("Last abuse")
    for _, s in ipairs(MH.OS.State.admin_stats or {}) do
        local last = tonumber(s.last_abuse_stamp or 0) or 0
        local lastStr = last > 0 and os.date("%Y-%m-%d %H:%M", last) or ""
        local line = statsList:AddLine(
            tostring(s.nick or "?"), tostring(s.sid64 or ""),
            tostring(s.abuse_cmd_hits or 0), tostring(s.abuse_mail_hits or 0),
            tostring(s.total_cmds or 0), tostring(s.total_mails_sent or 0),
            lastStr)
        line.MH_SID = tostring(s.sid64 or "")
    end
    statsList.OnRowRightClick = function(_, _, lineRef)
        if not lineRef or not lineRef.MH_SID then return end
        local m = DermaMenu()
        m:AddOption("Ban " .. lineRef.MH_SID, function()
            Derma_StringRequest("Ban reason", "Why ban " .. lineRef.MH_SID .. "?", "spam/abuse", function(txt)
                send_cmd("admin_ban", { sid64 = lineRef.MH_SID, reason = txt })
            end)
        end)
        m:AddOption("Mail-ban " .. lineRef.MH_SID, function()
            Derma_StringRequest("Mail-ban reason", "Why mail-ban " .. lineRef.MH_SID .. "?", "mail spam", function(txt)
                send_cmd("admin_mail_ban", { sid64 = lineRef.MH_SID, reason = txt })
            end)
        end)
        m:AddOption("Wipe all mail from " .. lineRef.MH_SID, function()
            send_cmd("admin_wipe_mail_from", { sid64 = lineRef.MH_SID })
        end)
        m:AddOption("Reset abuse counters", function()
            send_cmd("admin_reset_abuse", { sid64 = lineRef.MH_SID })
        end)
        m:Open()
    end

    label(container, "Top mail senders", "DermaDefaultBold"):Dock(TOP)
    local mailStats = vgui.Create("DListView", container)
    mailStats:Dock(TOP) mailStats:SetTall(180) mailStats:DockMargin(0, 4, 0, 0)
    mailStats:AddColumn("Nick"):SetFixedWidth(140)
    mailStats:AddColumn("SteamID64"):SetFixedWidth(170)
    mailStats:AddColumn("Mails in DB"):SetFixedWidth(100)
    mailStats:AddColumn("Last sent")
    for _, m in ipairs(MH.OS.State.admin_mail_counts or {}) do
        local last = tonumber(m.last_stamp or 0) or 0
        local lastStr = last > 0 and os.date("%Y-%m-%d %H:%M", last) or ""
        local line = mailStats:AddLine(
            tostring(m.nick or "?"), tostring(m.sid64 or ""),
            tostring(m.cnt or 0), lastStr)
        line.MH_SID = tostring(m.sid64 or "")
    end
    mailStats.OnRowRightClick = function(_, _, lineRef)
        if not lineRef or not lineRef.MH_SID then return end
        local m = DermaMenu()
        m:AddOption("Wipe mail from " .. lineRef.MH_SID, function()
            send_cmd("admin_wipe_mail_from", { sid64 = lineRef.MH_SID })
        end)
        m:AddOption("Mail-ban " .. lineRef.MH_SID, function()
            Derma_StringRequest("Mail-ban reason", "Why mail-ban " .. lineRef.MH_SID .. "?", "mail spam", function(txt)
                send_cmd("admin_mail_ban", { sid64 = lineRef.MH_SID, reason = txt })
            end)
        end)
        m:AddOption("Ban " .. lineRef.MH_SID, function()
            Derma_StringRequest("Ban reason", "Why ban " .. lineRef.MH_SID .. "?", "mail spam", function(txt)
                send_cmd("admin_ban", { sid64 = lineRef.MH_SID, reason = txt })
            end)
        end)
        m:Open()
    end

    label(container, "Recent abuse events", "DermaDefaultBold"):Dock(TOP)
    local logList = vgui.Create("DListView", container)
    logList:Dock(TOP) logList:SetTall(200) logList:DockMargin(0, 4, 0, 0)
    logList:AddColumn("When"):SetFixedWidth(140)
    logList:AddColumn("Nick"):SetFixedWidth(140)
    logList:AddColumn("SteamID64"):SetFixedWidth(170)
    logList:AddColumn("Kind"):SetFixedWidth(90)
    logList:AddColumn("Info")
    for _, a in ipairs(MH.OS.State.admin_abuse_log or {}) do
        local stamp = tonumber(a.stamp or 0) or 0
        logList:AddLine(
            stamp > 0 and os.date("%Y-%m-%d %H:%M:%S", stamp) or "",
            tostring(a.nick or "?"), tostring(a.sid64 or ""),
            tostring(a.kind or ""), tostring(a.info or ""))
    end

    local wipeRow = vgui.Create("DPanel", container)
    wipeRow:Dock(TOP) wipeRow:SetTall(30) wipeRow:DockMargin(0, 8, 0, 0)
    local wipeAllB = button(wipeRow, "Wipe ALL user-to-user mail", function()
        Derma_Query("Delete every mail sent between players? System mail is kept.",
            "Wipe user mail",
            "Yes, wipe", function() send_cmd("admin_wipe_user_mail", {}) end,
            "Cancel", function() end)
    end)
    wipeAllB:Dock(LEFT) wipeAllB:SetWide(240)
    local resetAllB = button(wipeRow, "Reset ALL abuse counters", function()
        Derma_Query("Zero every player's abuse counters and clear the event log?",
            "Reset abuse",
            "Yes, reset", function() send_cmd("admin_reset_abuse", { sid64 = "" }) end,
            "Cancel", function() end)
    end)
    resetAllB:Dock(LEFT) resetAllB:SetWide(240) resetAllB:DockMargin(6, 0, 0, 0)
    local refreshMissionsB = button(wipeRow, "Refresh Missions", function()
        send_cmd("admin_refresh_missions", {})
    end)
    refreshMissionsB:Dock(LEFT) refreshMissionsB:SetWide(180) refreshMissionsB:DockMargin(6, 0, 0, 0)
end

local function build_frame()
    if IsValid(MH.OS.Frame) then MH.OS.Frame:Remove() end
    local f = vgui.Create("DFrame")
    f:SetSize(ScrW() * 0.8, ScrH() * 0.82)
    f:Center()
    f:SetTitle("MetaHacker")
    f:SetDeleteOnClose(true)
    f:MakePopup()
    MH.OS.Frame = f

    local statusBar = vgui.Create("DPanel", f)
    statusBar:Dock(TOP)
    statusBar:DockMargin(4, 4, 4, 0)
    statusBar:SetTall(22)
    local statusLbl = vgui.Create("DLabel", statusBar)
    statusLbl:Dock(FILL)
    statusLbl:DockMargin(0, 0, 10, 0)
    statusLbl:SetContentAlignment(6)
    statusLbl:SetDark(true)
    statusLbl.Think = function(self)
        local p = MH.OS.State.player or {}
        local baseline = tonumber(MH.OS.State.client_baseline or CurTime()) or CurTime()
        local serverNow = (tonumber(MH.OS.State.server_now) or os.time()) + (CurTime() - baseline)
        local clock = os.date("%H:%M:%S", math.floor(serverNow))
        self:SetText(clock ..
            "   BTC " .. string.format("%.4f", tonumber(p.bitcoin or 0)) ..
            "   Rep " .. tostring(tonumber(p.exp or 0)))
    end

    local body = vgui.Create("DPanel", f)
    body:Dock(FILL)
    body:DockMargin(4, 4, 4, 4)

    local sidebar = vgui.Create("DPanel", body)
    sidebar:Dock(LEFT)
    sidebar:SetWide(170)

    local serverBar = vgui.Create("DPanel", body)
    serverBar:Dock(TOP)
    serverBar:DockMargin(6, 0, 0, 0)
    serverBar:SetTall(32)

    local content = vgui.Create("DScrollPanel", body)
    content:Dock(FILL)
    content:DockMargin(6, 6, 0, 0)

    MH.OS.TabScroll = MH.OS.TabScroll or {}

    local function save_scroll()
        local prev = MH.OS.ActiveTab
        if not prev then return end
        local vbar = IsValid(content) and content:GetVBar() or nil
        if IsValid(vbar) then
            MH.OS.TabScroll[prev] = tonumber(vbar:GetScroll()) or 0
        end
    end

    local function restore_scroll(name)
        local target = tonumber(MH.OS.TabScroll[name] or 0) or 0
        timer.Simple(0, function()
            if not IsValid(content) then return end
            local vbar = content:GetVBar()
            if IsValid(vbar) then vbar:SetScroll(target) end
        end)
    end

    local function switch_tab(name)
        save_scroll()
        MH.OS.ActiveTab = name
        local fn = Tabs[name]
        if fn then fn(content) end
        restore_scroll(name)
    end

    for _, name in ipairs(TAB_ORDER) do
        if ADMIN_ONLY_TABS[name] and not MH.OS.State.is_admin then continue end
        local b = vgui.Create("DButton", sidebar)
        b:SetText(name)
        b:Dock(TOP)
        b:DockMargin(4, 4, 4, 0)
        b:SetTall(26)
        b.DoClick = function()
            MH.OS.WatchProcess = nil
            switch_tab(name)
        end
        if name == "Mail" then
            b.Think = function(self)
                local unread = tonumber(MH.OS.State.mail_unread or 0) or 0
                if unread > 0 then
                    self:SetText("Mail (" .. unread .. ")")
                else
                    self:SetText("Mail")
                end
            end
        end
    end

    local function rebuild_serverbar()
        serverBar:Clear()
        for _, s in ipairs(MH.OS.State.servers or {}) do
            local sb = vgui.Create("DButton", serverBar)
            sb:SetText(s.name .. " (" .. (s.ip or "?") .. ")")
            sb:Dock(LEFT)
            sb:DockMargin(4, 4, 0, 4)
            sb:SetWide(200)
            sb.DoClick = function()
                MH.OS.FocusServer = tonumber(s.id)
                switch_tab(MH.OS.ActiveTab or "Home")
            end
        end
    end

    MH.OS.Rebuild = function()
        rebuild_serverbar()
        local tab = MH.OS.ActiveTab or "Home"
        local fn = Tabs[tab]
        if fn then fn(content) end
        restore_scroll(tab)
    end

    rebuild_serverbar()
    switch_tab("Home")
end
MH.OS.Build = build_frame

local snapshot_buf = {}
net.Receive(N.StateSync, function()
    local seq = net.ReadUInt(32)
    local chunks = net.ReadUInt(16)
    local idx = net.ReadUInt(16)
    local focus = net.ReadUInt(32)
    local len = net.ReadUInt(32)
    local raw = net.ReadData(len)
    local buf = snapshot_buf[seq]
    if not buf then
        buf = { parts = {}, count = 0, chunks = chunks, focus = focus }
        snapshot_buf[seq] = buf
    end
    if not buf.parts[idx] then
        buf.parts[idx] = raw
        buf.count = buf.count + 1
    end
    if buf.count < buf.chunks then return end
    snapshot_buf[seq] = nil
    local assembled = table.concat(buf.parts)
    local json = util.Decompress(assembled) or assembled
    local snap = util.JSONToTable(json or "") or {}
    MH.OS.State = snap
    MH.OS.State.client_baseline = CurTime()
    if focus and focus > 0 then MH.OS.FocusServer = focus end
    if (not MH.OS.FocusServer or MH.OS.FocusServer == 0) and snap.servers and snap.servers[1] then
        MH.OS.FocusServer = tonumber(snap.servers[1].id)
    end
    local pw = MH.OS.PendingWatch
    if pw then
        local match
        for _, p in ipairs(snap.all_processes or {}) do
            if (pw.actionMatch == true or p.action == pw.actionMatch)
                and (tonumber(p.time_start) or 0) >= pw.startedAfter
            then match = p break end
        end
        if match then
            MH.OS.WatchProcess = {
                sourceTab = pw.sourceTab,
                actionMatch = pw.actionMatch,
                startedAfter = pw.startedAfter,
                seen = false,
            }
            MH.OS.PendingWatch = nil
            MH.OS.ActiveTab = "Task Manager"
        end
    end
    if IsValid(MH.OS.Frame) and MH.OS.Rebuild then MH.OS.Rebuild() end
end)

net.Receive(N.Notify, function()
    local kind = net.ReadString()
    local msg = net.ReadString()
    if kind == "ok" then return end
    if kind == "error" then
        MH.OS.PendingWatch = nil
    end
    MH.OS.ShowNotify(kind, msg)
end)

net.Receive(N.OpenOS, function()
    build_frame()
end)
