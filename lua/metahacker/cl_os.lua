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

surface.CreateFont("MH_BankWelcome", {
    font = "Tahoma",
    size = 16,
    weight = 400,
    antialias = true,
})

surface.CreateFont("MH_BankWelcomeBold", {
    font = "Tahoma",
    size = 16,
    weight = 700,
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

function MH.OS.FmtCash(n)
    n = math.floor(tonumber(n) or 0)
    local neg = n < 0
    local str = tostring(math.abs(n))
    local out = ""
    local count = 0
    for i = #str, 1, -1 do
        out = string.sub(str, i, i) .. out
        count = count + 1
        if count % 3 == 0 and i > 1 then out = "," .. out end
    end
    return (neg and "-" or "") .. out
end

local fmt_cash = MH.OS.FmtCash

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

local function install_password_mask(entry, initial)
    local realValue = tostring(initial or "")
    local updating = false
    if realValue ~= "" then
        updating = true
        entry:SetText(string.rep("*", #realValue))
        updating = false
    end
    entry.GetRealValue = function() return realValue end
    entry.OnChange = function(self)
        if updating then return end
        local shown = self:GetValue() or ""
        local prevLen = #realValue
        if #shown > prevLen then
            realValue = realValue .. string.sub(shown, prevLen + 1)
        elseif #shown < prevLen then
            realValue = string.sub(realValue, 1, #shown)
        else
            return
        end
        updating = true
        self:SetText(string.rep("*", #realValue))
        self:SetCaretPos(#realValue)
        updating = false
    end
end

local SERVER_TAG_VARIANTS = {
    default   = { bg = Color(153, 153, 153), fg = Color(255, 255, 255) },
    inverse   = { bg = Color( 55,  55,  55), fg = Color(255, 255, 255) },
    success   = { bg = Color( 70, 136,  71), fg = Color(255, 255, 255) },
    warning   = { bg = Color(248, 148,   6), fg = Color(255, 255, 255) },
    important = { bg = Color(185,  74,  72), fg = Color(255, 255, 255) },
    info      = { bg = Color( 58, 135, 173), fg = Color(255, 255, 255) },
}

local function get_server_tag(inet)
    local n = tostring(inet and inet.name or "")
    if string.find(string.lower(n), "whois") then return "Whois", "warning" end
    if string.find(string.lower(n), "bank") then return "Bank", "inverse" end
    if n == "Bitcoin Market" then return "Bitcoin Market", "inverse" end
    if n == "ISP" then return "ISP", "important" end
    if n == "FBI" or n == "Sourcenet" or n == "MSA" then return "Important", "important" end
    if n == "Employers" or n == "GooseCorp" or n == "MD" or n == "Black Mesa" then return "Employers", "inverse" end
    return "NPC", "info"
end

local function server_tag(parent, text, variant)
    local palette = SERVER_TAG_VARIANTS[variant] or SERVER_TAG_VARIANTS.info
    local tagRow = vgui.Create("DPanel", parent)
    tagRow:Dock(TOP)
    tagRow:SetTall(22)
    tagRow:DockMargin(0, 6, 0, 0)
    tagRow.Paint = function() end
    local tagBtn = vgui.Create("DPanel", tagRow)
    tagBtn:Dock(RIGHT)
    tagBtn:DockMargin(0, 0, 10, 0)
    surface.SetFont("DermaDefaultBold")
    local tw = surface.GetTextSize(text)
    tagBtn:SetWide(math.max(80, tw + 24))
    tagBtn.Paint = function(self, w, h)
        surface.SetDrawColor(palette.bg.r, palette.bg.g, palette.bg.b, 255)
        surface.DrawRect(0, 0, w, h)
        draw.SimpleText(text, "DermaDefaultBold", w / 2, h / 2, palette.fg,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    return tagRow
end

local function tab_header(container, titleText, srv)
    local header = vgui.Create("DPanel", container)
    header:Dock(TOP)
    header:SetTall(70)
    header.Paint = function() end

    local title = vgui.Create("DLabel", header)
    title:Dock(LEFT)
    title:SetWide(400)
    title:DockMargin(10, 0, 0, 0)
    title:SetFont("DermaLarge")
    title:SetDark(true)
    title:SetText(tostring(titleText or ""))

    local info = vgui.Create("DPanel", header)
    info:Dock(RIGHT)
    info:SetWide(320)
    info.Paint = function() end

    local ipTxt = tostring((srv and srv.ip) or "0.0.0.0")
    local ipLbl = vgui.Create("DLabel", info)
    ipLbl:Dock(TOP)
    ipLbl:DockMargin(0, 0, 10, 0)
    ipLbl:SetFont("DermaLarge")
    ipLbl:SetDark(true)
    ipLbl:SetContentAlignment(6)
    ipLbl:SetTall(26)
    ipLbl:SetText(ipTxt)

    surface.SetFont("DermaLarge")
    local ipTextW = select(1, surface.GetTextSize(ipTxt))
    local clockRow = vgui.Create("DPanel", info)
    clockRow:Dock(TOP)
    clockRow:SetTall(16)
    clockRow:DockMargin(0, 2, 0, 0)
    clockRow.Paint = function() end
    local clockLbl = vgui.Create("DLabel", clockRow)
    clockLbl:Dock(RIGHT)
    clockLbl:SetWide(ipTextW + 20)
    clockLbl:DockMargin(0, 0, -25, 0)
    clockLbl:SetDark(true)
    clockLbl:SetContentAlignment(4)
    clockLbl:SetTextInset(20, 0)
    local timeIconMat = Material("icon16/time.png")
    clockLbl.PaintOver = function(self, w, h)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(timeIconMat)
        surface.DrawTexturedRect(0, math.floor((h - 16) / 2), 16, 16)
    end
    clockLbl.Think = function(self)
        local baseline = tonumber(MH.OS.State.client_baseline or CurTime()) or CurTime()
        local serverNow = (tonumber(MH.OS.State.server_now) or os.time()) + (CurTime() - baseline)
        self:SetText(os.date("!%Y-%m-%d %H:%M:%S", math.floor(serverNow)))
    end

    local p = MH.OS.State.player or {}
    local rep = math.floor(tonumber(p.exp or 0) or 0)
    local myRank
    for i, r in ipairs((MH.OS.State.ranking or {}).reputation or {}) do
        if tostring(r.sid64 or "") == (LocalPlayer and IsValid(LocalPlayer()) and LocalPlayer():SteamID64() or "") then
            myRank = i
            break
        end
    end
    local statsWrap = vgui.Create("DPanel", info)
    statsWrap:Dock(TOP)
    statsWrap:SetTall(16)
    statsWrap:DockMargin(0, 4, 10, 0)
    statsWrap.Paint = function() end
    local statsRow = vgui.Create("DPanel", statsWrap)
    statsRow:Dock(RIGHT)
    statsRow:SetWide(math.max(ipTextW, 160))
    statsRow.Paint = function() end
    local repLbl = vgui.Create("DLabel", statsRow)
    repLbl:Dock(LEFT)
    repLbl:SetDark(true)
    repLbl:SetText(tostring(rep) .. (myRank and ("   (#" .. myRank .. ")") or ""))
    repLbl:SizeToContents()
    local cashLbl = vgui.Create("DLabel", statsRow)
    cashLbl:Dock(RIGHT)
    cashLbl:SetDark(false)
    cashLbl:SetTextColor(Color(60, 160, 70))
    cashLbl:SetContentAlignment(6)
    cashLbl:SetText("$" .. fmt_cash(p.cash))
    cashLbl:SizeToContents()

    return header, info
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

function MH.OS.OpenNewTextPopup(ipAtText, onCreate)
    local f = vgui.Create("DFrame")
    f:SetSize(560, 380)
    f:Center()
    f:SetTitle("Create text file at " .. tostring(ipAtText or ""))
    f:SetDeleteOnClose(true)
    f:MakePopup()

    local nameRow = vgui.Create("DPanel", f)
    nameRow:Dock(TOP)
    nameRow:SetTall(28)
    nameRow:DockMargin(10, 32, 10, 0)
    nameRow.Paint = function() end
    local nameEntry = vgui.Create("DTextEntry", nameRow)
    nameEntry:Dock(FILL)
    nameEntry:SetPlaceholderText("File name")
    local extLbl = vgui.Create("DLabel", nameRow)
    extLbl:Dock(RIGHT)
    extLbl:SetWide(44)
    extLbl:DockMargin(6, 0, 0, 0)
    extLbl:SetDark(true)
    extLbl:SetContentAlignment(5)
    extLbl:SetText(".txt")

    local body = vgui.Create("DTextEntry", f)
    body:Dock(FILL)
    body:DockMargin(10, 10, 10, 10)
    body:SetMultiline(true)
    body:SetVerticalScrollbarEnabled(true)
    body:SetPlaceholderText("Content")

    local btnRow = vgui.Create("DPanel", f)
    btnRow:Dock(BOTTOM)
    btnRow:SetTall(40)
    btnRow:DockMargin(10, 0, 10, 10)
    btnRow.Paint = function() end
    local cancelB = vgui.Create("DButton", btnRow)
    cancelB:Dock(RIGHT)
    cancelB:SetWide(90)
    cancelB:SetText("Cancel")
    cancelB.DoClick = function() f:Remove() end
    local createB = vgui.Create("DButton", btnRow)
    createB:Dock(RIGHT)
    createB:SetWide(140)
    createB:DockMargin(0, 0, 6, 0)
    createB:SetText("Create text file")
    createB.DoClick = function()
        local nm = string.Trim(tostring(nameEntry:GetValue() or ""))
        if nm == "" then return end
        if onCreate then onCreate(nm, tostring(body:GetValue() or "")) end
        f:Remove()
    end
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
    local srv = current_server() or (MH.OS.State.servers or {})[1]

    local header = vgui.Create("DPanel", container)
    header:Dock(TOP)
    header:SetTall(70)
    header.Paint = function() end

    local title = vgui.Create("DLabel", header)
    title:Dock(LEFT)
    title:SetWide(400)
    title:DockMargin(10, 0, 0, 0)
    title:SetFont("DermaLarge")
    title:SetDark(true)
    title:SetText("Control Panel")

    local info = vgui.Create("DPanel", header)
    info:Dock(RIGHT)
    info:SetWide(320)
    info.Paint = function() end

    local ipLbl = vgui.Create("DLabel", info)
    ipLbl:Dock(TOP)
    ipLbl:DockMargin(0, 0, 10, 0)
    ipLbl:SetFont("DermaLarge")
    ipLbl:SetDark(true)
    ipLbl:SetContentAlignment(6)
    ipLbl:SetTall(26)
    ipLbl:SetText(tostring((srv and srv.ip) or "0.0.0.0"))

    surface.SetFont("DermaLarge")
    local ipTextW = select(1, surface.GetTextSize(tostring((srv and srv.ip) or "0.0.0.0")))
    local clockRow = vgui.Create("DPanel", info)
    clockRow:Dock(TOP)
    clockRow:SetTall(16)
    clockRow:DockMargin(0, 2, 5, 0)
    clockRow.Paint = function() end
    local clockLbl = vgui.Create("DLabel", clockRow)
    clockLbl:Dock(RIGHT)
    clockLbl:SetWide(ipTextW + 20)
    clockLbl:DockMargin(0, 0, -30, 0)
    clockLbl:SetDark(true)
    clockLbl:SetContentAlignment(4)
    clockLbl:SetTextInset(20, 0)
    local timeIconMat = Material("icon16/time.png")
    clockLbl.PaintOver = function(self, w, h)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(timeIconMat)
        surface.DrawTexturedRect(0, math.floor((h - 16) / 2), 16, 16)
    end
    clockLbl.Think = function(self)
        local baseline = tonumber(MH.OS.State.client_baseline or CurTime()) or CurTime()
        local serverNow = (tonumber(MH.OS.State.server_now) or os.time()) + (CurTime() - baseline)
        self:SetText(os.date("!%Y-%m-%d %H:%M:%S", math.floor(serverNow)))
    end

    local passRow = vgui.Create("DPanel", info)
    passRow:Dock(TOP)
    passRow:SetTall(22)
    passRow:DockMargin(0, 4, 6, 0)
    passRow.Paint = function() end
    local changeB = vgui.Create("DButton", passRow)
    changeB:Dock(RIGHT)
    changeB:SetWide(80)
    changeB:SetText("Change")
    changeB.DoClick = function()
        Derma_Query("Reset root password on " .. tostring(srv and srv.name or "server") .. "?",
            "Reset password", "Reset", function() send_cmd("pwd_reset", {}) end,
            "Cancel", function() end)
    end
    local passLbl = vgui.Create("DLabel", passRow)
    passLbl:Dock(FILL)
    passLbl:DockMargin(0, 0, 10, 0)
    passLbl:SetDark(true)
    passLbl:SetContentAlignment(6)
    passLbl:SetText(tostring((srv and srv.root_pass) or "????????"))

    local function card(parent, title)
        local w = vgui.Create("DPanel", parent)
        local h = vgui.Create("DLabel", w)
        h:Dock(TOP)
        h:DockMargin(10, 6, 10, 2)
        h:SetDark(true)
        h:SetFont("DermaDefaultBold")
        h:SetText(title)
        h:SizeToContents()
        return w, h
    end

    local function kv_row(parent, key, value)
        local r = vgui.Create("DPanel", parent)
        r:Dock(TOP)
        r:SetTall(24)
        r:DockMargin(10, 2, 10, 0)
        local lk = vgui.Create("DLabel", r)
        lk:Dock(LEFT)
        lk:SetWide(130)
        lk:SetDark(true)
        lk:SetText(tostring(key))
        local lv = vgui.Create("DLabel", r)
        lv:Dock(FILL)
        lv:SetDark(true)
        lv:SetText(tostring(value))
        return r
    end

    local topRow = vgui.Create("DPanel", container)
    topRow:Dock(TOP)
    topRow:SetTall(170)
    topRow:DockMargin(0, 8, 0, 0)
    topRow.Paint = function() end

    local hw, hwTitle = card(topRow, "Hardware Information")
    hw:Dock(LEFT)
    hw:DockMargin(0, 0, 10, 0)
    hwTitle:DockMargin(8, 5, 10, 2)
    topRow.PerformLayout = function(self)
        hw:SetWide(math.floor((self:GetWide() - 10) / 2))
    end
    local cpuTier = MH.Data.Hardware.cpu[tonumber(srv and srv.cpu_tier or 1) or 1]
    local hddTier = MH.Data.Hardware.hdd[tonumber(srv and srv.hdd_tier or 1) or 1]
    local ramTier = MH.Data.Hardware.ram[tonumber(srv and srv.ram_tier or 1) or 1]
    local netTier = MH.Data.Hardware.net[tonumber(srv and srv.net_tier or 1) or 1]
    local xhdCount = srv and srv.xhds and #srv.xhds or 0
    local xhdTxt = "None"
    if xhdCount > 0 then
        local total = 0
        for _, x in ipairs(srv.xhds or {}) do
            local t = MH.Data.Hardware.hdd[tonumber(x.cap_tier) or 1] or MH.Data.Hardware.hdd[1]
            total = total + (t.mb or 0)
        end
        xhdTxt = xhdCount .. " drive" .. (xhdCount == 1 and "" or "s") .. "   " .. total .. " MB"
    end
    local function hw_row(key, value)
        local row = kv_row(hw, key, value)
        row:DockMargin(5.5, 0, 0, 0)
        for _, child in ipairs(row:GetChildren()) do
            if child.SetTextInset then child:SetTextInset(5, 0) end
        end
    end
    hw_row("Processor",   (cpuTier.mhz or 0) .. " MHz   " .. (cpuTier.name or ""))
    hw_row("Hard Drive",  (hddTier.mb or 0) .. " MB   " .. (hddTier.name or ""))
    hw_row("Memory",      (ramTier.mb or 0) .. " MB   " .. (ramTier.name or ""))
    hw_row("Internet",    (netTier.mbps or 0) .. " Mbit/s   " .. (netTier.name or ""))
    hw_row("External HD", xhdTxt)

    local gi, giTitle = card(topRow, "General Info")
    gi:Dock(FILL)
    giTitle:DockMargin(14, 5, 10, 2)
    local rep = tonumber(p.exp or 0) or 0
    local myRank
    for i, r in ipairs((MH.OS.State.ranking or {}).reputation or {}) do
        if tostring(r.sid64 or "") == (LocalPlayer and IsValid(LocalPlayer()) and LocalPlayer():SteamID64() or "") then
            myRank = i
            break
        end
    end
    local runningTasks = 0
    for _, pr in ipairs(MH.OS.State.all_processes or {}) do
        if (tonumber(pr.paused_remaining or 0) or 0) == 0 then
            runningTasks = runningTasks + 1
        end
    end
    local connectedTo = "No one"
    local inet = MH.OS.State.internet
    if inet and inet.id and tonumber(inet.id or 0) > 0 then
        connectedTo = tostring(inet.ip or "?") .. " (" .. tostring(inet.name or "?") .. ")"
    end
    local missionTxt = "None"
    for _, m in ipairs(MH.OS.State.missions or {}) do
        local st = tonumber(m.status or 0)
        if st == 1 or st == 2 then
            local MISSION_TITLES_LOCAL = {
                [1] = "Delete a software", [2] = "Steal a software",
                [3] = "Check bank status", [4] = "Transfer money",
                [5] = "Destroy a server",
            }
            missionTxt = (MISSION_TITLES_LOCAL[tonumber(m.mtype)] or ("Mission #" .. tostring(m.mtype))) ..
                " ($" .. tostring(m.prize or 0) .. ")"
            break
        end
    end
    local function gi_row(key, value)
        local row = kv_row(gi, key, value)
        for _, child in ipairs(row:GetChildren()) do
            if child.SetTextInset then child:SetTextInset(5, 0) end
        end
    end
    gi_row("Reputation",   rep .. (myRank and ("   Ranked #" .. myRank) or ""))
    gi_row("Running tasks", runningTasks)
    gi_row("Connected to", connectedTo)
    gi_row("Mission",      missionTxt)

    local midRow = vgui.Create("DPanel", container)
    midRow:Dock(TOP)
    midRow:SetTall(300)
    midRow:DockMargin(0, 8, 0, 0)
    midRow.Paint = function() end

    local leftCol = vgui.Create("DPanel", midRow)
    leftCol:Dock(LEFT)
    leftCol:DockMargin(0, 0, 10, 0)
    leftCol.Paint = function() end
    midRow.PerformLayout = function(self)
        leftCol:SetWide(math.floor((self:GetWide() - 10) / 2))
    end

    local newsCard = card(leftCol, "News")
    newsCard:Dock(TOP)
    newsCard:SetTall(170)
    local newsRows = MH.OS.State.news or {}
    if #newsRows == 0 then
        kv_row(newsCard, "", "No news yet.")
    else
        local inner = vgui.Create("DScrollPanel", newsCard)
        inner:Dock(FILL)
        inner:DockMargin(10, 4, 10, 6)
        for _, n in ipairs(newsRows) do
            local l = vgui.Create("DLabel", inner)
            l:Dock(TOP)
            l:DockMargin(0, 2, 0, 0)
            l:SetDark(true)
            l:SetText(os.date("[%Y-%m-%d %H:%M] ", tonumber(n.stamp or 0)) .. tostring(n.text or ""))
            l:SizeToContents()
        end
    end

    local bottomRow = vgui.Create("DPanel", leftCol)
    bottomRow:Dock(FILL)
    bottomRow:DockMargin(0, 8, 0, 0)
    bottomRow.Paint = function() end
    local fbi = card(bottomRow, "FBI Wanted List")
    fbi:Dock(FILL)
    local fbiWanted = MH.OS.State.fbi_wanted or {}
    if #fbiWanted == 0 then
        kv_row(fbi, "", "No wanted IPs ATM")
    else
        local scroll = vgui.Create("DScrollPanel", fbi)
        scroll:Dock(FILL)
        scroll:DockMargin(10, 4, 10, 6)
        for _, w in ipairs(fbiWanted) do
            local row = vgui.Create("DPanel", scroll)
            row:Dock(TOP)
            row:SetTall(18)
            row.Paint = function() end
            local ipLbl = vgui.Create("DLabel", row)
            ipLbl:Dock(LEFT)
            ipLbl:SetWide(140)
            ipLbl:SetDark(true)
            ipLbl:SetFont("DermaDefaultBold")
            ipLbl:SetText(tostring(w.ip or "?"))
            local bountyLbl = vgui.Create("DLabel", row)
            bountyLbl:Dock(LEFT)
            bountyLbl:SetWide(100)
            bountyLbl:SetDark(false)
            bountyLbl:SetTextColor(Color(60, 160, 70))
            bountyLbl:SetFont("DermaDefaultBold")
            bountyLbl:SetText("$" .. fmt_cash(w.bounty or 0))
            local reasonLbl = vgui.Create("DLabel", row)
            reasonLbl:Dock(FILL)
            reasonLbl:SetDark(true)
            reasonLbl:SetText(tostring(w.reason or ""))
        end
    end

    local topUsers, topTitle = card(midRow, "Top 7 users")
    topUsers:Dock(FILL)
    topTitle:DockMargin(10, 6, 10, 2)
    local topList = vgui.Create("DListView", topUsers)
    topList:Dock(FILL)
    topList:DockMargin(10, 4, 10, 10)
    topList:AddColumn("#"):SetFixedWidth(40)
    topList:AddColumn("User"):SetFixedWidth(200)
    topList:AddColumn("Reputation")
    local repRows = (MH.OS.State.ranking or {}).reputation or {}
    for i = 1, math.min(7, #repRows) do
        local r = repRows[i]
        topList:AddLine(tostring(i), tostring(r.nick or "?"), tostring(math.floor(tonumber(r.val) or 0)))
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
    tab_header(container, "Hardware", current_server())

    local subbar = vgui.Create("DPanel", container)
    subbar:Dock(TOP)
    subbar:SetTall(28)
    subbar:DockMargin(0, 2, 0, 6)
    local HW_ICONS = {
        ["My hardware"]    = "icon16/server.png",
        ["Upgrade server"] = "icon16/wrench.png",
        ["Buy new server"] = "icon16/server_add.png",
        ["Internet"]       = "icon16/connect.png",
        ["External HD"]    = "icon16/drive.png",
    }
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
        if HW_ICONS[name] then
            local iconMat = Material(HW_ICONS[name])
            surface.SetFont("DermaDefault")
            local textW = select(1, surface.GetTextSize(name))
            local iconW, gap = 16, 8
            b:SetContentAlignment(6)
            b:SetTextInset(math.floor((140 - (iconW + gap + textW)) / 2), 0)
            b.PaintOver = function(self, w, h)
                local x = math.floor((w - (iconW + gap + textW)) / 2)
                local y = math.floor((h - iconW) / 2)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(iconMat)
                surface.DrawTexturedRect(x, y, iconW, iconW)
            end
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
        local buyXhd = vgui.Create("DButton", container)
        buyXhd:SetText("Buy external HD   (coming soon)")
        buyXhd:Dock(TOP)
        buyXhd:DockMargin(0, 12, 0, 0)
        buyXhd:SetTall(32)
        buyXhd:SetEnabled(false)
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

local LOCAL_SOFT_COL_LINES_X = { 290, 370, 450 }
local function soft_row(parent, s, srv, isXHD)
    local meta = MH.Data.Soft[tonumber(s.soft_type or 0)] or {}
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:SetTall(28)
    row:DockMargin(0, 2, 0, 0)
    row.PaintOver = function(self, w, h)
        surface.SetDrawColor(80, 80, 80, 180)
        for _, x in ipairs(LOCAL_SOFT_COL_LINES_X) do
            surface.DrawLine(x, 0, x, h)
        end
    end
    local function rcol(txt, wide, dock, bold)
        local l = vgui.Create("DLabel", row)
        l:Dock(dock or LEFT)
        if wide then l:SetWide(wide) end
        l:SetDark(true)
        if bold then l:SetFont("DermaDefaultBold") end
        l:SetText("  " .. tostring(txt or ""))
    end
    local isRunning = tonumber(s.installed or 0) == 1
    rcol((s.soft_name or "unknown") .. (meta.ext or ""), 290, nil, isRunning)
    rcol("v" .. MH.Data.DotVersion(s.soft_version), 80)
    rcol(tostring(s.soft_size or 0) .. " MB", 80)
    local actions = vgui.Create("DPanel", row)
    actions:Dock(RIGHT)
    actions:SetWide(isXHD and 160 or 220)
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
        local infoBtn = add_btn("", function()
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
        end, 28)
        infoBtn:SetTooltip("Info")
        local infoMat = Material("icon16/information.png")
        infoBtn.PaintOver = function(self, w, h)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(infoMat)
            surface.DrawTexturedRect(math.floor((w - 16) / 2), math.floor((h - 16) / 2), 16, 16)
        end
        local st = tonumber(s.soft_type)
        if st == 30 then
            add_btn("Edit", function() open_text_editor(s, false) end)
        end
        if st ~= 30 and st ~= 31 then
            local isRunning = tonumber(s.installed) == 1
            if isRunning then
                local stopBtn = add_btn("", function()
                    send_cmd("soft_action", { soft_id = s.id, action = "uninstall" })
                end, 28)
                stopBtn:SetTooltip("Stop")
                local stopMat = Material("icon16/stop.png")
                stopBtn.PaintOver = function(self, w, h)
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.SetMaterial(stopMat)
                    surface.DrawTexturedRect(math.floor((w - 16) / 2), math.floor((h - 16) / 2), 16, 16)
                end
            else
                local runBtn = add_btn("", function()
                    send_cmd("soft_action", { soft_id = s.id, action = "install" })
                end, 28)
                runBtn:SetTooltip("Run")
                local runMat = Material("icon16/control_play.png")
                runBtn.PaintOver = function(self, w, h)
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.SetMaterial(runMat)
                    surface.DrawTexturedRect(math.floor((w - 16) / 2), math.floor((h - 16) / 2), 16, 16)
                end
            end
            local isHidden = tonumber(s.hidden) == 1
            local toolType = isHidden and 6 or 5
            local toolName = isHidden and "Seeker" or "Hider"
            local hsBtn = add_btn("", function()
                send_cmd("soft_action", { soft_id = s.id, action = isHidden and "seek" or "hide" })
            end, 28)
            hsBtn:SetTooltip(isHidden and "Show" or "Hide")
            local hsMat = Material(isHidden and "icon16/magnifier.png" or "icon16/wand.png")
            hsBtn.PaintOver = function(self, w, h)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(hsMat)
                surface.DrawTexturedRect(math.floor((w - 16) / 2), math.floor((h - 16) / 2), 16, 16)
            end
            if toolOwned[toolType] <= 0 then
                hsBtn:SetEnabled(false)
                hsBtn:SetTooltip("Install a " .. toolName .. " first")
            end
        end
        local renameBtn = add_btn("", function()
            Derma_StringRequest("Rename file", "New name:", tostring(s.soft_name or ""), function(nm)
                send_cmd("soft_rename", { soft_id = s.id, name = nm })
            end)
        end, 28)
        renameBtn:SetTooltip("Rename")
        local pencilMat = Material("icon16/pencil.png")
        renameBtn.PaintOver = function(self, w, h)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(pencilMat)
            surface.DrawTexturedRect(math.floor((w - 16) / 2), math.floor((h - 16) / 2), 16, 16)
        end
        local deleteBtn = add_btn("", function()
            Derma_Query("Delete " .. tostring(s.soft_name or "file") .. "?",
                "Delete file", "Delete",
                function() send_cmd("soft_action", { soft_id = s.id, action = "delete" }) end,
                "Cancel", function() end)
        end, 28)
        deleteBtn:SetTooltip("Delete")
        local binMat = Material("icon16/bin.png")
        deleteBtn.PaintOver = function(self, w, h)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(binMat)
            surface.DrawTexturedRect(math.floor((w - 16) / 2), math.floor((h - 16) / 2), 16, 16)
        end
    end
end

Tabs["Software"] = function(container)
    clear(container)
    local srv = current_server()
    if not srv then
        label(container, "No servers owned"):Dock(TOP)
        return
    end

    tab_header(container, "Software", srv)

    local body = vgui.Create("DPanel", container)
    body:Dock(TOP)
    body:SetTall(620)
    body.Paint = function() end

    local sidebar = vgui.Create("DPanel", body)
    sidebar:Dock(RIGHT)
    sidebar:SetWide(220)
    sidebar:DockMargin(10, 6, 0, 0)

    local hUsed, hTotal = hdd_usage_for(srv)
    local hdd = usage_pie(sidebar, 180, "HDD", hUsed, hTotal)
    hdd:Dock(TOP)
    hdd:DockMargin(0, 4, 0, 8)

    local btnRow = vgui.Create("DPanel", sidebar)
    btnRow:Dock(TOP)
    btnRow:SetTall(32)
    btnRow:DockMargin(0, 10, 0, 0)
    btnRow.Paint = function() end
    local newTxt = vgui.Create("DButton", btnRow)
    newTxt:Dock(LEFT)
    newTxt:SetWide(100)
    newTxt:SetText("New text file")
    newTxt.DoClick = function()
        MH.OS.OpenNewTextPopup(tostring(srv.ip or ""), function(name, content)
            send_cmd("soft_text_create", { server_id = srv.id, name = name, content = content })
        end)
    end
    local avOwned = 0
    for _, inv in ipairs(srv.software or {}) do
        if tonumber(inv.soft_type) == 7 and tonumber(inv.installed) == 1 then
            avOwned = math.max(avOwned, tonumber(inv.soft_version) or 0)
        end
    end
    local avScan = vgui.Create("DButton", btnRow)
    avScan:Dock(RIGHT)
    avScan:SetWide(100)
    avScan:SetText("AV scan")
    avScan:DockMargin(10, 0, 0, 0)
    avScan.DoClick = function()
        send_cmd("av_scan", { scope = "local", server_id = srv.id })
    end
    if avOwned <= 0 then
        avScan:SetEnabled(false)
        avScan:SetTooltip("Install an Antivirus first")
    end

    local main = vgui.Create("DPanel", body)
    main:Dock(FILL)
    main:DockMargin(0, 6, 10, 0)
    main:DockPadding(6, 6, 6, 6)

    local subbar = vgui.Create("DPanel", main)
    subbar:Dock(TOP)
    subbar:SetTall(28)
    local SW_ICONS = {
        ["Softwares"]   = "icon16/folder.png",
        ["External HD"] = "icon16/drive.png",
    }
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
        if SW_ICONS[name] then
            local iconMat = Material(SW_ICONS[name])
            surface.SetFont("DermaDefault")
            local textW = select(1, surface.GetTextSize(name))
            local iconW, gap = 16, 8
            b:SetContentAlignment(6)
            b:SetTextInset(math.floor((140 - (iconW + gap + textW)) / 2), 0)
            b.PaintOver = function(self, w, h)
                local x = math.floor((w - (iconW + gap + textW)) / 2)
                local y = math.floor((h - iconW) / 2)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(iconMat)
                surface.DrawTexturedRect(x, y, iconW, iconW)
            end
        end
    end

    local LOCAL_COL_LINES_X = { 290, 370, 450 }
    local heading = vgui.Create("DPanel", main)
    heading:Dock(TOP)
    heading:SetTall(22)
    heading:DockMargin(0, 8, 0, 0)
    heading.PaintOver = function(self, w, h)
        surface.SetDrawColor(80, 80, 80, 180)
        for _, x in ipairs(LOCAL_COL_LINES_X) do
            surface.DrawLine(x, 0, x, h)
        end
    end
    local function hcol(txt, wide, dock)
        local l = vgui.Create("DLabel", heading)
        l:Dock(dock or LEFT)
        if wide then l:SetWide(wide) end
        l:SetDark(true)
        l:SetFont("DermaDefaultBold")
        l:SetText("  " .. txt)
    end
    hcol("Software name", 290)
    hcol("Version", 80)
    hcol("Size", 80)
    local actionsL = vgui.Create("DLabel", heading)
    actionsL:Dock(FILL)
    actionsL:SetDark(true)
    actionsL:SetFont("DermaDefaultBold")
    actionsL:SetText("  Actions")
    actionsL:SetTextInset(466, 0)

    local softScroll = vgui.Create("DScrollPanel", main)
    softScroll:Dock(FILL)
    softScroll:DockMargin(0, 4, 0, 0)

    if MH.OS.SoftwareView == "External HD" then
        local xhds = srv.xhds or {}
        if #xhds == 0 then
            label(main, "No external drives mounted."):Dock(TOP)
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

    MH.OS.PuzzleTokens = MH.OS.PuzzleTokens or {}
    MH.OS.PuzzleTokens[tonumber(p.id)] = nil
    send_cmd("puzzle_start", { puzzle_id = p.id })

    local function puzzle_token()
        return (MH.OS.PuzzleTokens or {})[tonumber(p.id)]
    end

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
        local tk = puzzle_token()
        if not tk then
            MH.OS.ShowNotify("warn", "Puzzle session not ready. Try again.")
            return
        end
        send_cmd("puzzle_solve", { puzzle_id = p.id, kind = p.kind, done = true, token = tk })
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
            local tk = puzzle_token()
            if not tk then
                MH.OS.ShowNotify("warn", "Puzzle session not ready. Try again.")
                return
            end
            send_cmd("puzzle_solve", { puzzle_id = p.id, answer = answerEntry:GetValue(), token = tk })
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
    tab_header(container, "Internet", current_server())

    local inet = MH.OS.State.internet

    local bar = vgui.Create("DPanel", container)
    bar:Dock(TOP)
    bar:SetTall(32)
    bar:DockMargin(0, 4, 0, 6)
    local urlLbl = vgui.Create("DLabel", bar)
    urlLbl:SetDark(true)
    urlLbl:SetFont("DermaDefaultBold")
    urlLbl:SetText("IP Address:")
    urlLbl:Dock(LEFT)
    urlLbl:DockMargin(5.5, 4, 6, 0)
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

    local currentMainTab = inet and inet.authed and "Index" or (MH.OS.InternetMainTab or "Index")
    local showSideCol = not (inet and inet.authed) and currentMainTab == "Index"
    if showSideCol then
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
        side_header("Recently visited")
        if #generic == 0 then
            local l = vgui.Create("DLabel", sidebar)
            l:Dock(TOP)
            l:DockMargin(10, 2, 6, 0)
            l:SetDark(true)
            l:SetText("Nothing yet.")
            l:SizeToContents()
        else
            local shown = 0
            for _, s in ipairs(generic) do
                if shown >= 5 then break end
                side_link(s.name, s.ip)
                shown = shown + 1
            end
        end
        side_header("Important IPs")
        if #important == 0 then
            local l = vgui.Create("DLabel", sidebar)
            l:Dock(TOP)
            l:DockMargin(10, 2, 6, 0)
            l:SetDark(true)
            l:SetText("None discovered yet.")
            l:SizeToContents()
        else
            for _, s in ipairs(important) do side_link(s.name, s.ip) end
        end
    end

    local body = vgui.Create("DPanel", container)
    body:Dock(TOP)
    body:SetTall(680)

    if not inet then
        return
    end

    local tabList = { "Index", "Login", "Hack" }
    local bankSessActive = false
    if inet.is_bank then
        local sess = MH.OS.State.bank_session
        if sess and tonumber(sess.bank_id or 0) == tonumber(inet.id or 0) then
            bankSessActive = true
            tabList = { "Index", "Login", "Hack", "Account overview" }
        else
            tabList = { "Index", "Login", "Hack", "Account login" }
        end
    end
    local tabSet = {}
    for _, n in ipairs(tabList) do tabSet[n] = true end
    if not inet.authed then
        MH.OS.LastAuthedIP = nil
        local defaultTab = bankSessActive and "Account overview" or "Index"
        MH.OS.InternetMainTab = MH.OS.InternetMainTab or defaultTab
        if not tabSet[MH.OS.InternetMainTab] then MH.OS.InternetMainTab = defaultTab end
        local mainTabBar = vgui.Create("DPanel", body)
        mainTabBar:Dock(TOP)
        mainTabBar:SetTall(28)
        mainTabBar:DockMargin(0, 0, 0, 0)
        local TAB_ICONS = {
            ["Index"]            = "icon16/application_side_boxes.png",
            ["Login"]            = "icon16/application_side_expand.png",
            ["Hack"]             = "icon16/application_xp_terminal.png",
            ["Account login"]    = "icon16/user_suit.png",
            ["Hack account"]     = "icon16/user_gray.png",
            ["Account overview"] = "icon16/creditcards.png",
        }
        for _, name in ipairs(tabList) do
            local b = vgui.Create("DButton", mainTabBar)
            b:SetText(name)
            if TAB_ICONS[name] then
                local iconMat = Material(TAB_ICONS[name])
                surface.SetFont("DermaDefault")
                local textW = select(1, surface.GetTextSize(name))
                local iconW, gap = 16, 8
                b:SetContentAlignment(6)
                b:SetTextInset(math.floor((120 - (iconW + gap + textW)) / 2), 0)
                b.PaintOver = function(self, w, h)
                    local x = math.floor((w - (iconW + gap + textW)) / 2)
                    local y = math.floor((h - iconW) / 2)
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.SetMaterial(iconMat)
                    surface.DrawTexturedRect(x, y, iconW, iconW)
                end
            end
            b:Dock(LEFT)
            b:SetWide(120)
            b:DockMargin(0, 0, 4, 0)
            b.DoClick = function()
                MH.OS.InternetMainTab = name
                if MH.OS.Rebuild then MH.OS.Rebuild() end
            end
        end
    end

    local mainTab = inet.authed and "Index" or (MH.OS.InternetMainTab or "Index")
    local whoisTier = ({ ["First Whois"] = 1, ["Second Whois"] = 2, ["Third Whois"] = 3, ["Fourth Whois"] = 4 })[tostring(inet.name)]
    if mainTab == "Index" then
        local tagText, tagVariant = get_server_tag(inet)
        server_tag(body, tagText, tagVariant)
    end
    if mainTab == "Index" and whoisTier and not inet.authed then
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
                { key = "SOURCENET", blurb = "Keeping you safe since 1984." },
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
                { key = "MD",        blurb = "Black Mesa - corporate target with secrets." },
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
            local gated = not e.ungated and ((e.key == "WHOIS2") or (e.key == "WHOIS3") or (e.key == "WHOIS4")
                or (string.sub(e.key, 1, 7) == "PUZZLE_" and e.key ~= "PUZZLE_1"))
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

    if inet.is_bitcoin and mainTab == "Index" then
        local btcWallet = MH.OS.State.btc or {}
        local walletAddr = tostring(btcWallet.address or "")
        local walletKey  = tostring(btcWallet.priv_key or "")
        local btcBuyRate = MH.Data.BtcBuyRate or 81650
        local btcSellRate = MH.Data.BtcSellRate or 81624

        local cols = vgui.Create("DPanel", body)
        cols:Dock(TOP)
        cols:SetTall(220)
        cols:DockMargin(10, 8, 10, 0)
        cols.Paint = function() end

        local function green_banner(parent, text)
            local banner = vgui.Create("DPanel", parent)
            banner:Dock(TOP)
            banner:SetTall(28)
            banner:DockMargin(10, 8, 10, 0)
            banner.Paint = function(self, w, h)
                surface.SetDrawColor(220, 240, 220, 255)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(190, 220, 190, 255)
                surface.DrawOutlinedRect(0, 0, w, h)
                draw.SimpleText(text, "DermaDefault", w / 2, h / 2, Color(60, 120, 60),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            return banner
        end

        local function card_box(parent, iconPath, title)
            local box = vgui.Create("DPanel", parent)
            local head = vgui.Create("DPanel", box)
            head:Dock(TOP)
            head:SetTall(28)
            local hIcon = vgui.Create("DImage", head)
            hIcon:SetPos(8, 6)
            hIcon:SetSize(16, 16)
            hIcon:SetImage(iconPath)
            local hLbl = vgui.Create("DLabel", head)
            hLbl:SetPos(30, 6)
            hLbl:SetFont("DermaDefaultBold")
            hLbl:SetDark(true)
            hLbl:SetText(title)
            hLbl:SizeToContents()
            return box
        end

        local actBox = card_box(cols, "icon16/coins.png", "Bitcoin Actions")
        actBox:Dock(LEFT)
        actBox:DockMargin(0, 0, 8, 0)
        local btcLoggedIn = MH.OS.State.btc_logged_in and true or false
        local loginBox = card_box(cols, "icon16/application_osx_terminal.png",
            btcLoggedIn and "Wallet Overview" or "Wallet Login")
        loginBox:Dock(FILL)

        cols.PerformLayout = function(self, w, h)
            local lw = math.floor(w * 0.58)
            actBox:SetWide(lw)
        end

        green_banner(actBox, "Only public information is logged!")

        local btnRow = vgui.Create("DPanel", actBox)
        btnRow:Dock(FILL)
        btnRow:DockMargin(10, 10, 10, 10)
        btnRow.Paint = function() end

        local function action_tile(parent, iconPath, title, subText, subColor, onClick)
            local tile = vgui.Create("DButton", parent)
            tile:SetText("")
            local tileMat = Material(iconPath)
            tile.Paint = function(self, w, h)
                derma.SkinHook("Paint", "Button", self, w, h)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(tileMat)
                surface.DrawTexturedRect(math.floor(w / 2 - 16), 20, 32, 32)
                local sk = self:GetSkin()
                local tc = (sk and sk.Colours and sk.Colours.Label and sk.Colours.Label.Default) or color_black
                draw.SimpleText(title, "DermaDefaultBold", w / 2, 68, tc,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText(subText, "DermaDefault", w / 2, 86, subColor or tc,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            tile.DoClick = onClick
            return tile
        end

        local function ensure_btc_login()
            if not MH.OS.State.btc_logged_in then
                MH.OS.ShowNotify("warn", "Please login first")
                return false
            end
            return true
        end

        local buyTile = action_tile(btnRow, "icon16/money_dollar.png",
            "Buy Bitcoins", "for $" .. fmt_cash(btcBuyRate), Color(80, 140, 80), function()
                if not ensure_btc_login() then return end
                Derma_StringRequest("Buy Bitcoins", "Cash to spend (USD):", "",
                    function(txt) send_cmd("btc_buy", { cash = tonumber(txt) }) end)
            end)

        local sellTile = action_tile(btnRow, "icon16/money.png",
            "Sell Bitcoins", "for $" .. fmt_cash(btcSellRate), Color(80, 140, 80), function()
                if not ensure_btc_login() then return end
                Derma_StringRequest("Sell Bitcoins", "BTC to sell:", "",
                    function(txt) send_cmd("btc_sell", { amount = tonumber(txt) }) end)
            end)

        local xferTile = action_tile(btnRow, "icon16/user_go.png",
            "Transfer Bitcoins", "No fees!", Color(120, 120, 120), function()
                if not ensure_btc_login() then return end
                Derma_StringRequest("Transfer Bitcoins", "Recipient wallet address:", "",
                    function(to)
                        Derma_StringRequest("Transfer Bitcoins", "BTC amount:", "",
                            function(amt) send_cmd("btc_transfer", { to = to, amount = tonumber(amt) }) end)
                    end)
            end)

        local tileWide = 140
        local tileTall = 100
        local tileGap = 10
        btnRow.PerformLayout = function(self, w, h)
            local total = tileWide * 3 + tileGap * 2
            local x = math.floor((w - total) / 2)
            local y = math.floor((h - tileTall) / 2)
            buyTile:SetSize(tileWide, tileTall)
            buyTile:SetPos(x, y)
            sellTile:SetSize(tileWide, tileTall)
            sellTile:SetPos(x + tileWide + tileGap, y)
            xferTile:SetSize(tileWide, tileTall)
            xferTile:SetPos(x + (tileWide + tileGap) * 2, y)
        end

        if btcLoggedIn then
            local overviewBody = vgui.Create("DPanel", loginBox)
            overviewBody:Dock(FILL)
            overviewBody:DockPadding(10, 14, 10, 10)
            local addrHdr = vgui.Create("DLabel", overviewBody)
            addrHdr:Dock(TOP)
            addrHdr:SetTall(20)
            addrHdr:SetFont("DermaDefaultBold")
            addrHdr:SetDark(true)
            addrHdr:SetContentAlignment(5)
            addrHdr:SetText("Address:")
            local addrVal = vgui.Create("DLabel", overviewBody)
            addrVal:Dock(TOP)
            addrVal:SetTall(20)
            addrVal:SetDark(true)
            addrVal:SetContentAlignment(5)
            addrVal:SetText(walletAddr)
            local btcHdr = vgui.Create("DLabel", overviewBody)
            btcHdr:Dock(TOP)
            btcHdr:SetTall(20)
            btcHdr:DockMargin(0, 12, 0, 0)
            btcHdr:SetFont("DermaDefaultBold")
            btcHdr:SetDark(true)
            btcHdr:SetContentAlignment(5)
            btcHdr:SetText("Bitcoins:")
            local btcVal = vgui.Create("DLabel", overviewBody)
            btcVal:Dock(TOP)
            btcVal:SetTall(20)
            btcVal:SetDark(true)
            btcVal:SetContentAlignment(5)
            local playerBtc = tonumber((MH.OS.State.player or {}).bitcoin or 0) or 0
            btcVal:SetText(string.format("%.7f", playerBtc) .. " BTC")
            local btnWrap = vgui.Create("DPanel", overviewBody)
            btnWrap:Dock(TOP)
            btnWrap:SetTall(34)
            btnWrap:DockMargin(0, 10, 0, 0)
            btnWrap.Paint = function() end
            local logoutBtn = vgui.Create("DButton", btnWrap)
            logoutBtn:SetSize(100, 28)
            btnWrap.PerformLayout = function(self, w, h)
                logoutBtn:SetPos(math.floor((w - 100) / 2), 0)
            end
            logoutBtn:SetText("Log out")
            logoutBtn:SetTextColor(color_white)
            logoutBtn.Paint = function(self, w, h)
                local col = self:IsHovered() and Color(60, 150, 185) or Color(70, 160, 195)
                surface.SetDrawColor(col.r, col.g, col.b, 255)
                surface.DrawRect(0, 0, w, h)
            end
            logoutBtn.DoClick = function()
                send_cmd("btc_internet_logout", { ip = tostring(inet.ip or "") })
            end
            return
        end

        green_banner(loginBox, "Anonymous login!")

        local loginBody = vgui.Create("DPanel", loginBox)
        loginBody:Dock(FILL)
        loginBody:DockMargin(10, 10, 10, 10)
        loginBody.Paint = function() end

        local function field_row(parent, iconPath, value, mask)
            local row = vgui.Create("DPanel", parent)
            row:Dock(TOP)
            row:SetTall(28)
            row:DockMargin(0, 0, 0, 6)
            row.Paint = function() end
            local iconPanel = vgui.Create("DPanel", row)
            iconPanel:Dock(LEFT)
            iconPanel:SetWide(28)
            local iconMat = Material(iconPath)
            iconPanel.Paint = function(self, w, h)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(iconMat)
                surface.DrawTexturedRect(math.floor((w - 16) / 2), math.floor((h - 16) / 2), 16, 16)
            end
            local entry = vgui.Create("DTextEntry", row)
            entry:Dock(FILL)
            entry:DockMargin(0, 0, 0, 0)
            if mask then
                install_password_mask(entry, value)
            else
                entry:SetText(value or "")
            end
            return entry
        end

        local addrEntry = field_row(loginBody, "icon16/user.png", walletAddr, false)
        local keyEntry  = field_row(loginBody, "icon16/key.png",  walletKey,  true)

        local loginBtn = vgui.Create("DButton", loginBody)
        loginBtn:Dock(TOP)
        loginBtn:SetTall(28)
        loginBtn:DockMargin(0, 4, 0, 0)
        loginBtn:SetText("Login")
        loginBtn.DoClick = function()
            send_cmd("btc_internet_login", {
                ip = tostring(inet.ip or ""),
                addr = addrEntry:GetValue(),
                key = keyEntry.GetRealValue and keyEntry:GetRealValue() or keyEntry:GetValue(),
            })
        end
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

    if mainTab == "Login" and not inet.authed then
        local centerWrap = vgui.Create("DPanel", body)
        centerWrap:Dock(TOP)
        centerWrap:SetTall(200)
        centerWrap:DockMargin(0, 40, 0, 0)
        centerWrap.Paint = function() end

        local boxWide = 440
        local loginBox = vgui.Create("DPanel", centerWrap)
        loginBox:SetSize(boxWide, 180)
        centerWrap.PerformLayout = function(self)
            loginBox:SetPos(math.floor((self:GetWide() - boxWide) / 2), 0)
        end

        local prompt = vgui.Create("DLabel", loginBox)
        prompt:Dock(TOP)
        prompt:SetTall(28)
        prompt:DockMargin(10, 14, 10, 4)
        prompt:SetDark(true)
        prompt:SetContentAlignment(5)
        prompt:SetText("Enter username and password to continue.")

        local isDC = tostring(inet.name) == "Download Center"
        local hasSaved = inet.saved_pass and tostring(inet.saved_pass) ~= ""

        local function iconRow(parent, iconMat, placeholder, initial)
            local row = vgui.Create("DPanel", parent)
            row:Dock(TOP)
            row:SetTall(28)
            row:DockMargin(80, 6, 80, 0)
            local ic = vgui.Create("DPanel", row)
            ic:Dock(LEFT)
            ic:SetWide(28)
            local mat = Material(iconMat)
            ic.Paint = function(self, w, h)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(mat)
                surface.DrawTexturedRect(math.floor((w - 16) / 2), math.floor((h - 16) / 2), 16, 16)
            end
            local entry = vgui.Create("DTextEntry", row)
            entry:Dock(FILL)
            entry:SetPlaceholderText(placeholder)
            if initial then entry:SetText(initial) end
            return entry
        end

        local userDefault = hasSaved and "root" or (isDC and "download" or "root")
        local passDefault = hasSaved and tostring(inet.saved_pass) or (isDC and "download" or "")
        local userEntry = iconRow(loginBox, "icon16/user.png", "Username", userDefault)
        local passEntry = iconRow(loginBox, "icon16/key.png", "Password", "")
        install_password_mask(passEntry, passDefault)

        local btnRow = vgui.Create("DPanel", loginBox)
        btnRow:Dock(BOTTOM)
        btnRow:SetTall(44)
        btnRow:DockMargin(10, 0, 10, 10)
        btnRow.Paint = function() end
        local loginB = vgui.Create("DButton", btnRow)
        loginB:Dock(RIGHT)
        loginB:SetWide(100)
        loginB:SetText("Login")
        loginB.DoClick = function()
            send_cmd("internet_login", { user = userEntry:GetValue(), pass = passEntry:GetRealValue() })
        end
        return
    end

    if mainTab == "Hack" and not inet.authed then
        local attackerSoft = {}
        local primary = (MH.OS.State.servers or {})[1]
        for _, s in ipairs(primary and primary.software or {}) do
            local t = tonumber(s.soft_type)
            local v = tonumber(s.soft_version) or 0
            if (attackerSoft[t] or 0) < v then attackerSoft[t] = v end
        end
        local certLvl = tonumber((MH.OS.State.player or {}).cert_level or 0) or 0

        local prompt = vgui.Create("DLabel", body)
        prompt:Dock(TOP)
        prompt:SetTall(24)
        prompt:DockMargin(0, 40, 0, 10)
        prompt:SetDark(true)
        prompt:SetContentAlignment(5)
        prompt:SetText("Choose your attack method:")

        local tileWide = 180
        local tileTall = 120
        local gap = 30
        local tiles = vgui.Create("DPanel", body)
        tiles:Dock(TOP)
        tiles:SetTall(tileTall)
        tiles.Paint = function() end

        local function build_tile(parent, title, iconText, headline, ok, disabledReason, onClick, iconMat, headlineIcon)
            local tile = vgui.Create(ok and "DButton" or "DPanel", parent)
            tile:SetSize(tileWide, tileTall)
            if ok then
                tile:SetText("")
                tile.Paint = function(self, w, h)
                    derma.SkinHook("Paint", "Panel", self, w, h)
                end
                tile.DoClick = onClick
            end
            if iconMat then
                local iconHolder = vgui.Create("DPanel", tile)
                iconHolder:Dock(TOP)
                iconHolder:SetTall(42)
                iconHolder:DockMargin(10, 12, 10, 0)
                iconHolder.Paint = function() end
                local img = vgui.Create("DImage", iconHolder)
                img:SetMaterial(Material(iconMat))
                img:SetSize(32, 32)
                iconHolder.PerformLayout = function(self)
                    img:SetPos(math.floor((self:GetWide() - 32) / 2), math.floor((self:GetTall() - 32) / 2))
                end
            else
                local ic = vgui.Create("DLabel", tile)
                ic:Dock(TOP)
                ic:SetTall(42)
                ic:DockMargin(10, 12, 10, 0)
                ic:SetDark(true)
                ic:SetFont("DermaLarge")
                ic:SetContentAlignment(5)
                ic:SetText(iconText)
            end
            local t = vgui.Create("DLabel", tile)
            t:Dock(TOP)
            t:SetTall(20)
            t:DockMargin(10, 4, 10, 0)
            t:SetDark(true)
            t:SetFont("DermaDefaultBold")
            t:SetContentAlignment(5)
            t:SetText(title)
            if headlineIcon then
                local segments
                if type(headlineIcon) == "table" then
                    segments = headlineIcon
                else
                    segments = { { icon = headlineIcon, text = tostring(headline or "") } }
                end
                local iconSize = 16
                local gap = 4
                local segGap = 10
                surface.SetFont("DermaDefault")
                local parts = {}
                local totalW = 0
                for i, seg in ipairs(segments) do
                    local tw = select(1, surface.GetTextSize(tostring(seg.text or "")))
                    local w = iconSize + gap + tw
                    parts[i] = { seg = seg, tw = tw, w = w }
                    totalW = totalW + w
                    if i > 1 then totalW = totalW + segGap end
                end
                local hRow = vgui.Create("DPanel", tile)
                hRow:Dock(TOP)
                hRow:SetTall(16)
                hRow:DockMargin(10, 2, 10, 0)
                hRow.Paint = function() end
                for _, p in ipairs(parts) do
                    p.img = vgui.Create("DImage", hRow)
                    p.img:SetMaterial(Material(p.seg.icon))
                    p.img:SetSize(iconSize, iconSize)
                    p.lbl = vgui.Create("DLabel", hRow)
                    if p.seg.color then
                        p.lbl:SetDark(false)
                        p.lbl:SetTextColor(p.seg.color)
                    else
                        p.lbl:SetDark(true)
                    end
                    p.lbl:SetText(tostring(p.seg.text or ""))
                    p.lbl:SizeToContents()
                end
                hRow.PerformLayout = function(self)
                    local x = math.floor((self:GetWide() - totalW) / 2)
                    for i, p in ipairs(parts) do
                        if i > 1 then x = x + segGap end
                        p.img:SetPos(x, 0)
                        p.lbl:SetPos(x + iconSize + gap, math.floor((16 - p.lbl:GetTall()) / 2))
                        x = x + p.w
                    end
                end
            else
                local h = vgui.Create("DLabel", tile)
                h:Dock(TOP)
                h:SetTall(16)
                h:DockMargin(10, 2, 10, 0)
                h:SetDark(true)
                h:SetContentAlignment(5)
                h:SetText(headline)
            end
            if not ok then
                local d = vgui.Create("DLabel", tile)
                d:Dock(TOP)
                d:SetTall(16)
                d:DockMargin(10, 2, 10, 0)
                d:SetDark(false)
                d:SetTextColor(Color(200, 80, 80))
                d:SetContentAlignment(5)
                d:SetText(disabledReason or "Unavailable")
            end
            if ok then
                tile:SetCursor("hand")
                local function propagate(p)
                    if not IsValid(p) then return end
                    p:SetMouseInputEnabled(false)
                    for _, child in ipairs(p:GetChildren() or {}) do propagate(child) end
                end
                for _, child in ipairs(tile:GetChildren() or {}) do propagate(child) end
            end
            return tile
        end

        local crackerV = attackerSoft[1] or 0
        local tgtHasher = tonumber(inet.target_hasher or 0) or 0
        local tgtFirewall = tonumber(inet.target_firewall or 0) or 0
        local crackOk = crackerV > 0 and crackerV >= tgtHasher
        local crackReason
        if crackerV <= 0 then crackReason = "No Cracker."
        elseif crackerV < tgtHasher then crackReason = "Cracker not high enough level" end
        local crackerText = crackerV > 0 and MH.Data.DotVersion(crackerV) or "-"
        local crackerColor
        if crackerV <= 0 then
            crackerColor = Color(200, 60, 60)
        elseif crackOk then
            crackerColor = color_white
        end
        local bruteTile = build_tile(tiles,
            "Bruteforce attack",
            nil,
            nil,
            crackOk,
            crackReason,
            function() send_cmd("crack_ip", { ip = inet.ip, method = "bruteforce" }) end,
            "icon16/lock_open.png",
            { { icon = "icon16/application_key.png", text = crackerText, color = crackerColor } }
        )

        local ftpV = attackerSoft[13] or 0
        local sshV = attackerSoft[14] or 0
        local portV = attackerSoft[3] or 0
        local bestExploit = math.max(ftpV, sshV)
        local haveExploit = ftpV > 0 or sshV > 0
        local exploitOk = certLvl >= 3 and portV > 0 and haveExploit and bestExploit >= tgtFirewall
        local reason
        if portV <= 0 then reason = "No Port Scan."
        elseif not haveExploit then reason = "No Exploits."
        elseif bestExploit < tgtFirewall then reason = "Exploit not high enough level" end
        local method = ftpV >= sshV and ftpV > 0 and "ftp_exploit" or "ssh_exploit"
        local ftpText = ftpV > 0 and MH.Data.DotVersion(ftpV) or "-"
        local sshText = sshV > 0 and MH.Data.DotVersion(sshV) or "-"
        local ftpColor
        if ftpV <= 0 then
            ftpColor = Color(200, 60, 60)
        elseif exploitOk and ftpV >= tgtFirewall then
            ftpColor = color_white
        end
        local sshColor
        if sshV <= 0 then
            sshColor = Color(200, 60, 60)
        elseif exploitOk and sshV >= tgtFirewall then
            sshColor = color_white
        end
        local exploitTile = build_tile(tiles,
            "Exploit attack",
            nil,
            nil,
            exploitOk,
            reason,
            function() send_cmd("crack_ip", { ip = inet.ip, method = method }) end,
            "icon16/bug.png",
            {
                { icon = "icon16/folder_bug.png",    text = ftpText, color = ftpColor },
                { icon = "icon16/monitor_error.png", text = sshText, color = sshColor },
            }
        )

        tiles.PerformLayout = function(self)
            local totalW = tileWide * 2 + gap
            local x = math.floor((self:GetWide() - totalW) / 2)
            bruteTile:SetPos(x, 0)
            exploitTile:SetPos(x + tileWide + gap, 0)
        end

        return
    end

    if mainTab == "Account login" and inet.is_bank then
        local wrap = vgui.Create("DPanel", body)
        wrap:Dock(TOP)
        wrap:SetTall(220)
        wrap:DockMargin(0, 40, 0, 0)
        wrap.Paint = function() end

        local boxWide = 440
        local box = vgui.Create("DPanel", wrap)
        box:SetSize(boxWide, 180)
        wrap.PerformLayout = function(self)
            box:SetPos(math.floor((self:GetWide() - boxWide) / 2), 0)
        end

        local prompt = vgui.Create("DLabel", box)
        prompt:Dock(TOP)
        prompt:SetTall(28)
        prompt:DockMargin(10, 14, 10, 4)
        prompt:SetDark(true)
        prompt:SetContentAlignment(5)
        prompt:SetText("Enter account number and password to continue.")

        local savedAcc, savedPass = "", ""
        for _, b in ipairs(MH.OS.State.banks or {}) do
            if tonumber(b.bank_npc or 0) == tonumber(inet.id or 0) then
                savedAcc = tostring(b.acc_num or "")
                savedPass = tostring(b.acc_pass or "")
                break
            end
        end
        if savedAcc == "" then
            for _, h in ipairs(MH.OS.State.hacked_banks or {}) do
                if tonumber(h.bank_server_id or 0) == tonumber(inet.id or 0) then
                    savedAcc = tostring(h.acc_num or "")
                    savedPass = tostring(h.acc_pass or "")
                    break
                end
            end
        end

        local function iconRow(parent, iconMat, placeholder, initial)
            local row = vgui.Create("DPanel", parent)
            row:Dock(TOP)
            row:SetTall(28)
            row:DockMargin(80, 6, 80, 0)
            local ic = vgui.Create("DPanel", row)
            ic:Dock(LEFT)
            ic:SetWide(28)
            local mat = Material(iconMat)
            ic.Paint = function(self, w, h)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(mat)
                surface.DrawTexturedRect(math.floor((w - 16) / 2), math.floor((h - 16) / 2), 16, 16)
            end
            local entry = vgui.Create("DTextEntry", row)
            entry:Dock(FILL)
            entry:SetPlaceholderText(placeholder)
            if initial and initial ~= "" then entry:SetText(initial) end
            return entry
        end

        local accEntry = iconRow(box, "icon16/user.png", "Account #", savedAcc)
        local passEntry = iconRow(box, "icon16/key.png", "Password", "")
        install_password_mask(passEntry, savedPass)

        local btnRow = vgui.Create("DPanel", box)
        btnRow:Dock(BOTTOM)
        btnRow:SetTall(44)
        btnRow:DockMargin(10, 0, 10, 10)
        btnRow.Paint = function() end
        local loginB = vgui.Create("DButton", btnRow)
        loginB:Dock(RIGHT)
        loginB:SetWide(100)
        loginB:SetText("Login")
        loginB.DoClick = function()
            send_cmd("bank_internet_login", { ip = inet.ip, acc = accEntry:GetValue(), pass = passEntry:GetRealValue() })
        end
        if savedAcc ~= "" then
            local savedBox = vgui.Create("DPanel", btnRow)
            savedBox:Dock(LEFT)
            savedBox:SetWide(220)
            savedBox.Paint = function() end
            local accLine = vgui.Create("DLabel", savedBox)
            accLine:Dock(TOP)
            accLine:SetTall(18)
            accLine:SetDark(true)
            accLine:SetFont("DermaDefaultBold")
            accLine:SetText("Account #: " .. savedAcc)
            local passLine = vgui.Create("DLabel", savedBox)
            passLine:Dock(TOP)
            passLine:SetTall(18)
            passLine:SetDark(true)
            passLine:SetFont("DermaDefaultBold")
            passLine:SetText("Password: " .. savedPass)
        end
        return
    end

    if mainTab == "Hack account" and inet.is_bank then
        local wrap = vgui.Create("DPanel", body)
        wrap:Dock(TOP)
        wrap:SetTall(180)
        wrap:DockMargin(0, 40, 0, 0)
        wrap.Paint = function() end

        local boxWide = 440
        local box = vgui.Create("DPanel", wrap)
        box:SetSize(boxWide, 150)
        wrap.PerformLayout = function(self)
            box:SetPos(math.floor((self:GetWide() - boxWide) / 2), 0)
        end

        local prompt = vgui.Create("DLabel", box)
        prompt:Dock(TOP)
        prompt:SetTall(28)
        prompt:DockMargin(10, 14, 10, 4)
        prompt:SetDark(true)
        prompt:SetContentAlignment(5)
        prompt:SetText("Hack bank account")

        local row = vgui.Create("DPanel", box)
        row:Dock(TOP)
        row:SetTall(28)
        row:DockMargin(80, 6, 80, 0)
        row.Paint = function() end
        local accLbl = vgui.Create("DLabel", row)
        accLbl:Dock(LEFT)
        accLbl:SetWide(80)
        accLbl:SetDark(true)
        accLbl:SetContentAlignment(5)
        accLbl:SetText("Account #")
        local accEntry = vgui.Create("DTextEntry", row)
        accEntry:Dock(FILL)
        accEntry:SetPlaceholderText("Account to hack")

        local btnRow = vgui.Create("DPanel", box)
        btnRow:Dock(BOTTOM)
        btnRow:SetTall(44)
        btnRow:DockMargin(10, 0, 10, 10)
        btnRow.Paint = function() end
        local hackB = vgui.Create("DButton", btnRow)
        hackB:Dock(RIGHT)
        hackB:SetWide(100)
        hackB:SetText("Hack")
        hackB.DoClick = function()
            send_cmd("bank_internet_hack_acc", { ip = inet.ip, acc = accEntry:GetValue() })
        end
        return
    end

    if mainTab == "Account overview" and inet.is_bank then
        local sess = MH.OS.State.bank_session
        if not sess or tonumber(sess.bank_id or 0) ~= tonumber(inet.id or 0) then
            label(body, "No active account session on this bank."):Dock(TOP)
            return
        end
        local balanceWrap = vgui.Create("DPanel", body)
        balanceWrap:Dock(TOP)
        balanceWrap:SetTall(60)
        balanceWrap:DockMargin(0, 20, 0, 0)
        balanceWrap.Paint = function() end
        local balBox = vgui.Create("DPanel", balanceWrap)
        balBox:SetSize(260, 50)
        balanceWrap.PerformLayout = function(self)
            balBox:SetPos(math.floor((self:GetWide() - 260) / 2), 0)
        end
        local balLbl = vgui.Create("DLabel", balBox)
        balLbl:Dock(FILL)
        balLbl:SetDark(false)
        balLbl:SetTextColor(Color(60, 160, 70))
        balLbl:SetFont("DermaLarge")
        balLbl:SetContentAlignment(5)
        balLbl:SetTextInset(20, 0)
        balLbl:SetText("$" .. fmt_cash(sess.cash))
        local moneyMat = Material("icon16/money.png")
        local iconSize = 28
        balLbl.PaintOver = function(self, w, h)
            surface.SetFont("DermaLarge")
            local tw = select(1, surface.GetTextSize(self:GetText() or ""))
            local textX = math.floor((w - tw) / 2) + 10
            local iconX = textX - iconSize - 56
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(moneyMat)
            surface.DrawTexturedRect(iconX, math.floor((h - iconSize) / 2), iconSize, iconSize)
        end

        local cols = vgui.Create("DPanel", body)
        cols:Dock(TOP)
        cols:SetTall(260)
        cols:DockMargin(20, 20, 20, 0)
        cols.Paint = function() end

        local rightCol = vgui.Create("DPanel", cols)
        rightCol:Dock(RIGHT)
        rightCol:SetWide(240)
        rightCol:DockMargin(10, 0, 0, 0)
        rightCol.Paint = function() end
        local actionsCard = vgui.Create("DPanel", rightCol)
        actionsCard:Dock(TOP)
        actionsCard:SetTall(160)
        actionsCard:DockPadding(10, 10, 10, 10)
        local aHdr = vgui.Create("DLabel", actionsCard)
        aHdr:Dock(TOP)
        aHdr:SetTall(22)
        aHdr:SetDark(true)
        aHdr:SetFont("DermaDefaultBold")
        aHdr:SetText("Other actions")
        local actRow = vgui.Create("DPanel", actionsCard)
        actRow:Dock(TOP)
        actRow:SetTall(32)
        actRow:DockMargin(0, 14, 0, 0)
        actRow.Paint = function() end
        local chpass = vgui.Create("DButton", actRow)
        chpass:Dock(LEFT)
        chpass:SetWide(104)
        chpass:SetText("Change password")
        chpass.DoClick = function()
            Derma_Query("Rotate password on account " .. sess.acc_num .. "?",
                "Change password", "Change",
                function() send_cmd("bank_internet_change_pass", {}) end,
                "Cancel", function() end)
        end
        local closeB = vgui.Create("DButton", actRow)
        closeB:Dock(LEFT)
        closeB:SetWide(104)
        closeB:DockMargin(6, 0, 0, 0)
        closeB:SetText("Close account")
        closeB.DoClick = function()
            Derma_Query("Close " .. sess.acc_num .. "?", "Close account",
                "Close", function() send_cmd("bank_internet_close", {}) end,
                "Cancel", function() end)
        end
        local logoutRow = vgui.Create("DPanel", actionsCard)
        logoutRow:Dock(TOP)
        logoutRow:SetTall(32)
        logoutRow:DockMargin(0, 40, 0, 0)
        logoutRow.Paint = function() end
        local logoutB = vgui.Create("DButton", logoutRow)
        logoutB:Dock(TOP)
        logoutB:SetTall(28)
        logoutB:DockMargin(60, 0, 60, 0)
        logoutB:SetText("Logout")
        logoutB.DoClick = function() send_cmd("bank_internet_logout", {}) end

        local transferCard = vgui.Create("DPanel", cols)
        transferCard:Dock(FILL)
        transferCard:DockPadding(10, 10, 10, 10)
        local tHdr = vgui.Create("DLabel", transferCard)
        tHdr:Dock(TOP)
        tHdr:SetTall(22)
        tHdr:SetDark(true)
        tHdr:SetFont("DermaDefaultBold")
        tHdr:SetText("Transfer money")

        local function tRow(parent, labelText, placeholder, initial, editable)
            local row = vgui.Create("DPanel", parent)
            row:Dock(TOP)
            row:SetTall(28)
            row:DockMargin(0, 6, 0, 0)
            row.Paint = function() end
            local lbl = vgui.Create("DLabel", row)
            lbl:Dock(LEFT)
            lbl:SetWide(90)
            lbl:SetDark(true)
            lbl:SetContentAlignment(6)
            lbl:SetText(labelText .. "  ")
            local entry = vgui.Create("DTextEntry", row)
            entry:Dock(FILL)
            entry:SetPlaceholderText(placeholder or "")
            if initial then entry:SetText(initial) end
            if editable == false then entry:SetEditable(false) end
            return entry
        end
        local tFrom = tRow(transferCard, "From", "", sess.acc_num, false)
        local tTo = tRow(transferCard, "To", "Transfer to...", "", true)
        local tAmt = tRow(transferCard, "Amount", "$0", "", true)
        tAmt:SetNumeric(true)
        local tBankIp = tRow(transferCard, "Bank IP", "IP of the receiver account", "", true)

        local sendRow = vgui.Create("DPanel", transferCard)
        sendRow:Dock(TOP)
        sendRow:SetTall(36)
        sendRow:DockMargin(90, 10, 0, 0)
        sendRow.Paint = function() end
        local tSend = vgui.Create("DButton", sendRow)
        tSend:Dock(LEFT)
        tSend:SetWide(140)
        tSend:SetText("Transfer Money")
        tSend.DoClick = function()
            send_cmd("bank_internet_transfer", { to = tTo:GetValue(), amount = tonumber(tAmt:GetValue()), bank_ip = tBankIp:GetValue() })
        end
        return
    end

    if mainTab == "Index" and not inet.authed then
        if inet.web_image and inet.web_image ~= "" then
            local webBox = vgui.Create("DPanel", body)
            webBox:Dock(TOP)
            webBox:SetTall(300)
            webBox:DockMargin(0, 10, 0, 10)
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
        if tostring(inet.name) == "Sourcenet" then
            local watched = MH.OS.State.sourcenet_watched or {}
            if #watched == 0 then
                label(body, "No IPs harming internet"):Dock(TOP)
            else
                for _, w in ipairs(watched) do
                    local row = vgui.Create("DPanel", body)
                    row:Dock(TOP)
                    row:SetTall(18)
                    row.Paint = function() end
                    local ipLbl = vgui.Create("DLabel", row)
                    ipLbl:Dock(LEFT)
                    ipLbl:SetWide(160)
                    ipLbl:SetDark(true)
                    ipLbl:SetFont("DermaDefaultBold")
                    ipLbl:SetText(tostring(w.ip or "?"))
                    local reasonLbl = vgui.Create("DLabel", row)
                    reasonLbl:Dock(FILL)
                    reasonLbl:SetDark(true)
                    reasonLbl:SetText("reason: " .. tostring(w.reason or ""))
                end
            end
            return
        end
        if tostring(inet.name) == "FBI" then
            label(body, "FBI Wanted List", "DermaDefaultBold"):Dock(TOP)
            local spacer = vgui.Create("DPanel", body)
            spacer:Dock(TOP) spacer:SetTall(8) spacer.Paint = function() end
            local wanted = MH.OS.State.fbi_wanted or {}
            if #wanted == 0 then
                label(body, "No wanted IPs atm"):Dock(TOP)
            else
                for _, w in ipairs(wanted) do
                    local row = vgui.Create("DPanel", body)
                    row:Dock(TOP)
                    row:SetTall(18)
                    row.Paint = function() end
                    local ipLbl = vgui.Create("DLabel", row)
                    ipLbl:Dock(LEFT)
                    ipLbl:SetWide(140)
                    ipLbl:SetDark(true)
                    ipLbl:SetFont("DermaDefaultBold")
                    ipLbl:SetText(tostring(w.ip or "?"))
                    local bountyLbl = vgui.Create("DLabel", row)
                    bountyLbl:Dock(LEFT)
                    bountyLbl:SetWide(120)
                    bountyLbl:SetDark(false)
                    bountyLbl:SetTextColor(Color(60, 160, 70))
                    bountyLbl:SetFont("DermaDefaultBold")
                    bountyLbl:SetText("$" .. fmt_cash(w.bounty))
                    local reasonLbl = vgui.Create("DLabel", row)
                    reasonLbl:Dock(FILL)
                    reasonLbl:SetDark(true)
                    reasonLbl:SetText(tostring(w.reason or ""))
                end
            end
            return
        end
        if tostring(inet.name) == "Download Center" then
            label(body, "Welcome to the download center!"):Dock(TOP)
            local spacer = vgui.Create("DPanel", body)
            spacer:Dock(TOP) spacer:SetTall(8) spacer.Paint = function() end
            label(body, "Download whatever you need. Unlimited bandwidth!"):Dock(TOP)
            local spacer2 = vgui.Create("DPanel", body)
            spacer2:Dock(TOP) spacer2:SetTall(10) spacer2.Paint = function() end
            local function labeled_line(bold, rest)
                local row = vgui.Create("DPanel", body)
                row:Dock(TOP)
                row:SetTall(18)
                row.Paint = function() end
                local b = vgui.Create("DLabel", row)
                b:Dock(LEFT)
                b:SetDark(true)
                b:SetFont("DermaDefaultBold")
                b:SetText(bold)
                b:SizeToContents()
                local v = vgui.Create("DLabel", row)
                v:Dock(LEFT)
                v:DockMargin(4, 0, 0, 0)
                v:SetDark(true)
                v:SetText(rest)
                v:SizeToContents()
            end
            labeled_line("Username:", "download")
            labeled_line("Password:", "download")
            return
        end
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
                ipB:SetText("Reset My IP - " .. (ipPrice == 0 and "Free" or ("$" .. fmt_cash(ipPrice))))
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
                pwdB:SetText("Reset Root Password - " .. (pPrice == 0 and "Free" or ("$" .. fmt_cash(pPrice))))
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
            local bankName = tostring(inet.name or "bank")
            local BANK_INFO = {
                ["First International Bank"] = {
                    blurb = "We have a very modest defense, but at least you didn't have to pay for an account.",
                    register_cost = 0,
                },
                ["HEBC Bank"] = {
                    blurb = "Fast, friendly service. Deposit today, protected tomorrow.",
                    register_cost = 500,
                },
                ["American Express Bank"] = {
                    blurb = "Where your money travels first class.",
                    register_cost = 5000,
                },
                ["Swiss International Bank"] = {
                    blurb = "Offshore. Off the record. Off limits.",
                    register_cost = 20000,
                },
                ["Ultimate Bank"] = {
                    blurb = "Safety matters. You won't find a safer bank.",
                    register_cost = 100000,
                },
            }
            local info = BANK_INFO[bankName] or { blurb = "Trusted banking for discerning hackers.", register_cost = 1000 }
            local hasAccount = false
            for _, b in ipairs(MH.OS.State.banks or {}) do
                if tonumber(b.bank_npc or 0) == tonumber(inet.id or 0) then hasAccount = true break end
            end

            local welcomeRow = vgui.Create("DPanel", body)
            welcomeRow:Dock(TOP)
            welcomeRow:SetTall(26)
            welcomeRow:DockMargin(12, 0, 0, 0)
            welcomeRow.Paint = function() end
            local prefix = vgui.Create("DLabel", welcomeRow)
            prefix:Dock(LEFT)
            prefix:SetDark(true)
            prefix:SetFont("MH_BankWelcome")
            prefix:SetText("Welcome to the ")
            prefix:SizeToContents()
            local bankLbl = vgui.Create("DLabel", welcomeRow)
            bankLbl:Dock(LEFT)
            bankLbl:SetDark(true)
            bankLbl:SetFont("MH_BankWelcomeBold")
            bankLbl:SetText(bankName)
            bankLbl:SizeToContents()
            local suffix = vgui.Create("DLabel", welcomeRow)
            suffix:Dock(LEFT)
            suffix:SetDark(true)
            suffix:SetFont("MH_BankWelcome")
            suffix:SetText(".")
            suffix:SizeToContents()

            local spacer = vgui.Create("DPanel", body)
            spacer:Dock(TOP) spacer:SetTall(10) spacer.Paint = function() end

            local blurbRow = vgui.Create("DPanel", body)
            blurbRow:Dock(TOP)
            blurbRow:SetTall(22)
            blurbRow:DockMargin(12, 0, 0, 0)
            blurbRow.Paint = function() end
            local blurbLbl = vgui.Create("DLabel", blurbRow)
            blurbLbl:Dock(LEFT)
            blurbLbl:SetDark(true)
            blurbLbl:SetFont("MH_BankWelcome")
            blurbLbl:SetText(info.blurb)
            blurbLbl:SizeToContents()

            local spacer2 = vgui.Create("DPanel", body)
            spacer2:Dock(TOP) spacer2:SetTall(10) spacer2.Paint = function() end

            local actionLink = vgui.Create("DButton", body)
            actionLink:Dock(TOP)
            actionLink:SetTall(20)
            actionLink:DockMargin(12, 0, 0, 0)
            actionLink:SetFont("MH_BankWelcome")
            if hasAccount then
                actionLink:SetText("Login to your account.")
            elseif info.register_cost > 0 then
                actionLink:SetText("Register an account for $" .. fmt_cash(info.register_cost) .. ".")
            else
                actionLink:SetText("Register a free account.")
            end
            actionLink:SetContentAlignment(4)
            actionLink:SetTextInset(0, 0)
            actionLink.Paint = function() end
            actionLink.PaintOver = function() end
            actionLink:SetTextColor(Color(60, 100, 190))
            actionLink:SizeToContents()
            actionLink.DoClick = function()
                if hasAccount then
                    MH.OS.InternetMainTab = "Account login"
                    if MH.OS.Rebuild then MH.OS.Rebuild() end
                else
                    send_cmd("bank_create", { bank_id = inet.id })
                end
            end
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
        local function centered_box(parent, title, boxTall)
            local wrap = vgui.Create("DPanel", parent)
            wrap:Dock(TOP)
            wrap:SetTall(boxTall + 40)
            wrap:DockMargin(0, 40, 0, 0)
            wrap.Paint = function() end
            local boxWide = 440
            local box = vgui.Create("DPanel", wrap)
            box:SetSize(boxWide, boxTall)
            wrap.PerformLayout = function(self)
                box:SetPos(math.floor((self:GetWide() - boxWide) / 2), 0)
            end
            local prompt = vgui.Create("DLabel", box)
            prompt:Dock(TOP)
            prompt:SetTall(28)
            prompt:DockMargin(10, 14, 10, 4)
            prompt:SetDark(true)
            prompt:SetContentAlignment(5)
            prompt:SetText(title)
            return box
        end

        if MH.OS.InternetView == "Banking" then
            local balBox = centered_box(sub, "Check account balance", 150)
            local lookupRow = vgui.Create("DPanel", balBox)
            lookupRow:Dock(TOP)
            lookupRow:SetTall(28)
            lookupRow:DockMargin(60, 6, 60, 0)
            lookupRow.Paint = function() end
            local lookupEntry = vgui.Create("DTextEntry", lookupRow)
            lookupEntry:Dock(FILL)
            lookupEntry:SetPlaceholderText("Account number")
            local lookupBtn = vgui.Create("DButton", lookupRow)
            lookupBtn:Dock(RIGHT)
            lookupBtn:SetWide(120)
            lookupBtn:DockMargin(6, 0, 0, 0)
            lookupBtn:SetText("Check balance")
            local lookupResult = vgui.Create("DLabel", balBox)
            lookupResult:Dock(TOP)
            lookupResult:SetTall(22)
            lookupResult:DockMargin(60, 8, 60, 0)
            lookupResult:SetDark(true)
            lookupResult:SetContentAlignment(5)
            lookupResult:SetText("")
            local function doLookup()
                local q = string.Trim(tostring(lookupEntry:GetValue() or ""))
                if q == "" then
                    lookupResult:SetText("Enter an account number.")
                    return
                end
                for _, a in ipairs(inet.bank_accounts or {}) do
                    if tostring(a.acc_num or "") == q then
                        lookupResult:SetText("Account " .. q .. "  balance $" .. fmt_cash(a.cash))
                        return
                    end
                end
                lookupResult:SetText("Account " .. q .. " not found on this bank.")
            end
            lookupBtn.DoClick = doLookup
            lookupEntry.OnEnter = doLookup

            local xBox = centered_box(sub, "Transfer money", 180)
            local rowA = vgui.Create("DPanel", xBox)
            rowA:Dock(TOP)
            rowA:SetTall(28)
            rowA:DockMargin(60, 6, 60, 0)
            rowA.Paint = function() end
            local tFrom = vgui.Create("DTextEntry", rowA)
            tFrom:Dock(LEFT)
            tFrom:SetWide(150)
            tFrom:SetPlaceholderText("from account")
            local tPass = vgui.Create("DTextEntry", rowA)
            tPass:Dock(FILL)
            tPass:DockMargin(6, 0, 0, 0)
            tPass:SetPlaceholderText("from password")
            local rowB = vgui.Create("DPanel", xBox)
            rowB:Dock(TOP)
            rowB:SetTall(28)
            rowB:DockMargin(60, 6, 60, 0)
            rowB.Paint = function() end
            local tTo = vgui.Create("DTextEntry", rowB)
            tTo:Dock(LEFT)
            tTo:SetWide(150)
            tTo:SetPlaceholderText("to account")
            local tAmt = vgui.Create("DTextEntry", rowB)
            tAmt:Dock(FILL)
            tAmt:DockMargin(6, 0, 0, 0)
            tAmt:SetPlaceholderText("amount")
            tAmt:SetNumeric(true)
            local btnRow = vgui.Create("DPanel", xBox)
            btnRow:Dock(TOP)
            btnRow:SetTall(32)
            btnRow:DockMargin(60, 10, 60, 0)
            btnRow.Paint = function() end
            local tSend = vgui.Create("DButton", btnRow)
            tSend:Dock(RIGHT)
            tSend:SetWide(100)
            tSend:SetText("Transfer")
            tSend.DoClick = function()
                send_cmd("bank_transfer", {
                    from = tFrom:GetValue(),
                    pass = tPass:GetValue(),
                    to = tTo:GetValue(),
                    amount = tonumber(tAmt:GetValue()),
                })
            end
        elseif MH.OS.InternetView == "Hack account" then
            local box = centered_box(sub, "Hack a bank account", 150)
            local row = vgui.Create("DPanel", box)
            row:Dock(TOP)
            row:SetTall(28)
            row:DockMargin(80, 6, 80, 0)
            row.Paint = function() end
            local hLbl = vgui.Create("DLabel", row)
            hLbl:Dock(LEFT)
            hLbl:SetWide(80)
            hLbl:SetDark(true)
            hLbl:SetContentAlignment(5)
            hLbl:SetText("Account #")
            local hEntry = vgui.Create("DTextEntry", row)
            hEntry:Dock(FILL)
            hEntry:SetPlaceholderText("Account to hack")
            local btnRow = vgui.Create("DPanel", box)
            btnRow:Dock(BOTTOM)
            btnRow:SetTall(44)
            btnRow:DockMargin(10, 0, 10, 10)
            btnRow.Paint = function() end
            local hBtn = vgui.Create("DButton", btnRow)
            hBtn:Dock(RIGHT)
            hBtn:SetWide(100)
            hBtn:SetText("Hack")
            hBtn.DoClick = function()
                send_cmd("bank_internet_hack_acc", { ip = tostring(inet.ip or ""), acc = hEntry:GetValue() })
            end
        elseif MH.OS.InternetView == "Logs" then
            local pad = vgui.Create("DPanel", sub)
            pad:Dock(TOP)
            pad:SetTall(560)
            pad:DockMargin(0, 6, 10, 0)
            pad:DockPadding(80, 20, 80, 20)

            if inet.log_locked then
                local status = vgui.Create("DLabel", pad)
                status:Dock(TOP)
                status:SetTall(18)
                status:SetDark(true)
                status:SetContentAlignment(5)
                status:SetText("A log process is already running on target.")
            end
            local text = vgui.Create("DTextEntry", pad)
            text:Dock(TOP)
            text:SetTall(420)
            text:DockMargin(0, 10, 0, 0)
            text:SetMultiline(true)
            text:SetEditable(not inet.log_disabled)
            text:SetVerticalScrollbarEnabled(true)
            text:SetValue(tostring(inet.log_text or ""))
            local btnRow = vgui.Create("DPanel", pad)
            btnRow:Dock(TOP)
            btnRow:SetTall(36)
            btnRow:DockMargin(0, 16, 0, 0)
            btnRow.Paint = function() end
            local editBtn = vgui.Create("DButton", btnRow)
            editBtn:SetSize(130, 32)
            editBtn:SetText("Edit log file")
            editBtn.DoClick = function()
                send_cmd("internet_log_edit_submit", { content = text:GetValue() })
            end
            local delBtn = vgui.Create("DButton", btnRow)
            delBtn:SetSize(130, 32)
            delBtn:SetText("Delete all")
            delBtn.DoClick = function()
                Derma_Query("Wipe remote log on " .. tostring(inet.ip) .. "?",
                    "Delete remote log", "Delete",
                    function() send_cmd("internet_log_delete_all", {}) end,
                    "Cancel", function() end)
            end
            if inet.log_disabled then
                editBtn:SetEnabled(false)
                delBtn:SetEnabled(false)
                editBtn:SetTooltip("This server does not keep logs.")
                delBtn:SetTooltip("This server does not keep logs.")
            end
            local gap = 10
            btnRow.PerformLayout = function(self)
                local totalW = 130 + gap + 130
                local x = math.floor((self:GetWide() - totalW) / 2)
                editBtn:SetPos(x, 0)
                delBtn:SetPos(x + 130 + gap, 0)
            end
        elseif MH.OS.InternetView == "Softwares" then
            local targetNetTier = tonumber(inet and inet.net_tier or 1) or 1
            local targetNet = (MH.Data.Hardware.net[targetNetTier] or MH.Data.Hardware.net[1]).mbps or 1
            local dlKBs = targetNet * 125
            local ulKBs = targetNet * 62.5
            local function fmt_rate(kBs)
                local n, unit
                if kBs >= 1000 then
                    n = kBs / 1000
                    unit = "MB/s"
                else
                    n = kBs
                    unit = "kB/s"
                end
                local s = string.format("%.2f", n)
                s = s:gsub("0+$", "")
                s = s:gsub("%.$", "")
                return s .. unit
            end

            local uploadB = vgui.Create("DButton", rightCol)
            uploadB:Dock(TOP)
            uploadB:SetTall(32)
            uploadB:DockMargin(0, 4, 0, 0)
            uploadB:SetText("Upload...")
            uploadB.DoClick = function()
                local primary = (MH.OS.State.servers or {})[1]
                local uploadables = {}
                for _, inv in ipairs(primary and primary.software or {}) do
                    if tonumber(inv.hidden or 0) == 0 then table.insert(uploadables, inv) end
                end
                if #uploadables == 0 then return end
                local m = DermaMenu()
                for _, inv in ipairs(uploadables) do
                    local meta = MH.Data.Soft[tonumber(inv.soft_type or 0)] or {}
                    local label = (inv.soft_name or "?") .. (meta.ext or "") ..
                        "  v" .. MH.Data.DotVersion(inv.soft_version)
                    m:AddOption(label, function()
                        send_cmd("remote_soft_upload", { soft_id = inv.id })
                    end)
                end
                m:Open()
            end

            local netLbl = vgui.Create("DLabel", rightCol)
            netLbl:Dock(TOP)
            netLbl:SetTall(18)
            netLbl:DockMargin(0, 4, 0, 4)
            netLbl:SetDark(true)
            netLbl:SetContentAlignment(5)
            netLbl:SetText(string.format("%d Mbit ( %s - %s)",
                targetNet, fmt_rate(dlKBs), fmt_rate(ulKBs)))

            local hUsed, hTotal = hdd_usage_for(inet)
            local hdd = usage_pie(rightCol, 140, "HDD", hUsed, hTotal)
            hdd:Dock(TOP)
            hdd:DockMargin(0, 4, 0, 8)

            local fileBtnRow = vgui.Create("DPanel", rightCol)
            fileBtnRow:Dock(TOP)
            fileBtnRow:SetTall(32)
            fileBtnRow:DockMargin(0, 4, 0, 0)
            fileBtnRow.Paint = function() end
            local newTxtB = vgui.Create("DButton", fileBtnRow)
            newTxtB:Dock(LEFT)
            newTxtB:SetWide(84)
            newTxtB:SetText("New text file")
            newTxtB.DoClick = function()
                MH.OS.OpenNewTextPopup(tostring(inet.ip), function(name, content)
                    send_cmd("remote_soft_text_create", { name = name, content = content })
                end)
            end
            local folderB = vgui.Create("DButton", fileBtnRow)
            folderB:Dock(RIGHT)
            folderB:SetWide(84)
            folderB:SetText("Create folder")
            folderB:SetEnabled(false)
            folderB:SetTooltip("Folder creation is disabled")

            local resetSoft = vgui.Create("DLabel", rightCol)
            resetSoft:Dock(TOP)
            resetSoft:SetTall(16)
            resetSoft:DockMargin(0, 14, 0, 0)
            resetSoft:SetDark(true)
            resetSoft:SetContentAlignment(5)
            local nowT = tonumber(MH.OS.State.server_now) or os.time()
            local nextSoftReset = tonumber(inet.next_software_reset or 0) or 0
            local soFar = math.max(0, nextSoftReset - nowT)
            if nextSoftReset > 0 then
                local mins = math.floor(soFar / 60)
                resetSoft:SetText("Next software reset: " .. mins .. " minutes")
            else
                resetSoft:SetText("Next software reset: ~15 minutes")
            end
            local resetHw = vgui.Create("DLabel", rightCol)
            resetHw:Dock(TOP)
            resetHw:SetTall(16)
            resetHw:DockMargin(0, 2, 0, 0)
            resetHw:SetDark(true)
            resetHw:SetContentAlignment(5)
            local nextHwReset = tonumber(inet.next_hardware_reset or 0) or 0
            if nextHwReset > 0 then
                local hrs = math.max(0, nextHwReset - nowT) / 3600
                resetHw:SetText(string.format("Next hardware reset: %.1f hours", hrs))
            else
                resetHw:SetText("Next hardware reset: ~1 hour")
            end

            local filesLbl = label(sub, "Files on remote target", "DermaDefaultBold")
            filesLbl:Dock(TOP)
            filesLbl:DockMargin(5.5, 0, 0, 0)
            local COL_LINES_X = { 240, 350, 410, 500 }
            local header = vgui.Create("DPanel", sub)
            header:Dock(TOP)
            header:SetTall(20)
            header:DockMargin(0, 4, 0, 0)
            header.PaintOver = function(self, w, h)
                surface.SetDrawColor(80, 80, 80, 180)
                for _, x in ipairs(COL_LINES_X) do
                    surface.DrawLine(x, 0, x, h)
                end
            end
            local function hcol(txt, wide, dock, marginL)
                local l = vgui.Create("DLabel", header)
                l:Dock(dock or LEFT)
                if wide then l:SetWide(wide) end
                if marginL then l:DockMargin(marginL, 0, 0, 0) end
                l:SetDark(true)
                l:SetFont("DermaDefaultBold")
                l:SetText("  " .. txt)
            end
            hcol("File",     180)
            hcol("Type",     110, nil, 60)
            hcol("Version",  60)
            hcol("Size",     60, nil, 30)
            local actionsL = vgui.Create("DLabel", header)
            actionsL:Dock(FILL)
            actionsL:SetDark(true)
            actionsL:SetFont("DermaDefaultBold")
            actionsL:SetText("  Actions")
            actionsL:SetTextInset(435, 0)

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
                row.PaintOver = function(self, w, h)
                    surface.SetDrawColor(80, 80, 80, 180)
                    for _, x in ipairs(COL_LINES_X) do
                        surface.DrawLine(x, 0, x, h)
                    end
                end
                local highlight = missionTargetSoft and tostring(s.soft_name or "") == missionTargetSoft
                    and HIGHLIGHT_COLOR[missionTargetKind] or nil
                local function rcol(txt, wide, dock, marginL, font)
                    local l = vgui.Create("DLabel", row)
                    l:Dock(dock or LEFT)
                    if wide then l:SetWide(wide) end
                    if marginL then l:DockMargin(marginL, 0, 0, 0) end
                    if font then l:SetFont(font) end
                    if highlight then
                        l:SetDark(false)
                        l:SetTextColor(highlight)
                    else
                        l:SetDark(true)
                    end
                    l:SetText("  " .. tostring(txt or ""))
                end
                local nameFont = tonumber(s.installed) == 1 and "DermaDefaultBold" or nil
                rcol((s.soft_name or "?") .. (meta.ext or ""), 180, nil, nil, nameFont)
                rcol(meta.name or ("#" .. tostring(s.soft_type)), 110, nil, 60)
                rcol("v" .. MH.Data.DotVersion(s.soft_version), 60)
                rcol(tostring(s.soft_size or 0) .. " MB", 60, nil, 30)
                local actions = vgui.Create("DPanel", row)
                actions:Dock(RIGHT)
                actions:SetWide(340)
                actions:DockPadding(90, 0, 0, 0)
                local primary = (MH.OS.State.servers or {})[1]
                local myTools = { [5] = 0, [6] = 0, [7] = 0 }
                for _, inv in ipairs(primary and primary.software or {}) do
                    local st = tonumber(inv.soft_type)
                    if myTools[st] ~= nil and tonumber(inv.installed) == 1 then
                        myTools[st] = math.max(myTools[st], tonumber(inv.soft_version) or 0)
                    end
                end
                local function remote_btn(text, action, needTool, needName, iconPath)
                    local b = vgui.Create("DButton", actions)
                    b:SetText("")
                    b:Dock(LEFT)
                    b:SetWide(28)
                    b:DockMargin(0, 2, 2, 2)
                    b:SetTooltip(text)
                    b.DoClick = function()
                        send_cmd("remote_soft_action", { soft_id = s.id, action = action })
                    end
                    if iconPath then
                        local mat = Material(iconPath)
                        b.PaintOver = function(self, w, h)
                            surface.SetDrawColor(255, 255, 255, 255)
                            surface.SetMaterial(mat)
                            surface.DrawTexturedRect(math.floor((w - 16) / 2), math.floor((h - 16) / 2), 16, 16)
                        end
                    end
                    if needTool and myTools[needTool] <= 0 then
                        b:SetEnabled(false)
                        b:SetTooltip("Install a " .. needName .. " on your rig first")
                    end
                    return b
                end
                local st = tonumber(s.soft_type)
                local isRiddle = st == 26
                local isFolder = st == 31
                local isText = st == 30
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
                elseif isFolder then
                    local isRoot = tostring(inet.auth_user or "root") == "root"
                    if isRoot then
                        remote_btn("Delete", "delete", nil, nil, "icon16/delete.png")
                    end
                else
                    local dl = vgui.Create("DButton", actions)
                    dl:SetText("")
                    dl:Dock(LEFT)
                    dl:SetWide(28)
                    dl:DockMargin(0, 2, 2, 2)
                    dl:SetTooltip("Download")
                    local dlMat = Material("icon16/arrow_down.png")
                    dl.PaintOver = function(self, w, h)
                        surface.SetDrawColor(255, 255, 255, 255)
                        surface.SetMaterial(dlMat)
                        surface.DrawTexturedRect(math.floor((w - 16) / 2), math.floor((h - 16) / 2), 16, 16)
                    end
                    dl.DoClick = function()
                        send_cmd("remote_soft_download", { soft_id = s.id })
                    end
                    local isRoot = tostring(inet.auth_user or "root") == "root"
                    if isRoot and not isText then
                        local running = tonumber(s.installed) == 1
                        remote_btn(running and "Stop" or "Run",
                            running and "uninstall" or "install",
                            nil, nil,
                            running and "icon16/stop.png" or "icon16/control_play.png")
                        local isHidden = tonumber(s.hidden) == 1
                        remote_btn(isHidden and "Seek" or "Hide",
                            isHidden and "seek" or "hide",
                            isHidden and 6 or 5,
                            isHidden and "Seeker" or "Hider",
                            isHidden and "icon16/magnifier.png" or "icon16/wand.png")
                    end
                    if isRoot then
                        remote_btn("Delete", "delete", nil, nil, "icon16/delete.png")
                    end
                end
                if isText then
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

        end
    end

    local tabs = { "Logs", "Softwares" }
    local showBanking = inet.is_bank and inet.authed and tostring(inet.auth_user or "root") == "root"
    if showBanking then
        tabs[#tabs + 1] = "Banking"
        tabs[#tabs + 1] = "Hack account"
    end
    tabs[#tabs + 1] = "Logout"
    local AUTHED_TAB_ICONS = {
        ["Logs"]         = "icon16/book.png",
        ["Softwares"]    = "icon16/folder.png",
        ["Banking"]      = "icon16/briefcase.png",
        ["Hack account"] = "icon16/user_gray.png",
        ["Logout"]       = "icon16/door_open.png",
    }
    for _, name in ipairs(tabs) do
        local b = vgui.Create("DButton", subbar)
        b:SetText(name)
        b:Dock(LEFT)
        b:SetWide(120)
        b:DockMargin(0, 0, 4, 0)
        if name == "Logout" then
            b.DoClick = function() send_cmd("internet_logout", {}) end
        else
            b.DoClick = function() MH.OS.InternetView = name paintRemote() end
        end
        if AUTHED_TAB_ICONS[name] then
            local iconMat = Material(AUTHED_TAB_ICONS[name])
            surface.SetFont("DermaDefault")
            local textW = select(1, surface.GetTextSize(name))
            local iconW, gap = 16, 8
            b:SetContentAlignment(6)
            b:SetTextInset(math.floor((120 - (iconW + gap + textW)) / 2), 0)
            b.PaintOver = function(self, w, h)
                local x = math.floor((w - (iconW + gap + textW)) / 2)
                local y = math.floor((h - iconW) / 2)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(iconMat)
                surface.DrawTexturedRect(x, y, iconW, iconW)
            end
        end
    end
    local validView = { Logs = true, Softwares = true, Banking = showBanking }
    if not validView[MH.OS.InternetView] then
        MH.OS.InternetView = "Logs"
    end
    if MH.OS.LastAuthedIP ~= tostring(inet.ip) then
        MH.OS.LastAuthedIP = tostring(inet.ip)
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
    tab_header(container, "Task Manager", current_server())

    local tmWrap = vgui.Create("DPanel", container)
    tmWrap:Dock(TOP)
    tmWrap:SetTall(620)
    tmWrap:DockMargin(0, 6, 0, 0)
    tmWrap.Paint = function() end

    local tmSidebar = vgui.Create("DPanel", tmWrap)
    if IsValid(tmSidebar) then
        MH.OS._FloatSidebar = tmSidebar
        tmSidebar:Dock(RIGHT)
        tmSidebar:SetWide(210)
        tmSidebar:DockMargin(6, 2, 0, 0)
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

    local tmContent = vgui.Create("DScrollPanel", tmWrap)
    tmContent:Dock(FILL)
    container = tmContent

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
    local TM_ICONS = {
        ["All"]     = "icon16/chart_curve.png",
        ["CPU"]     = "icon16/computer.png",
        ["Network"] = "icon16/drive_network.png",
        ["Running"] = "icon16/application_cascade.png",
    }
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
        if TM_ICONS[name] then
            local iconMat = Material(TM_ICONS[name])
            surface.SetFont("DermaDefault")
            local textW = select(1, surface.GetTextSize(name))
            local iconW, gap = 16, 8
            b:SetContentAlignment(6)
            b:SetTextInset(math.floor((110 - (iconW + gap + textW)) / 2), 0)
            b.PaintOver = function(self, w, h)
                local x = math.floor((w - (iconW + gap + textW)) / 2)
                local y = math.floor((h - iconW) / 2)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(iconMat)
                surface.DrawTexturedRect(x, y, iconW, iconW)
            end
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
    tab_header(container, "Log File", current_server())
    if not srv then label(container, "No server"):Dock(TOP) return end

    local body = vgui.Create("DPanel", container)
    body:Dock(TOP)
    body:SetTall(640)
    body:DockMargin(0, 6, 10, 0)
    body:DockPadding(80, 20, 80, 20)

    if srv.log_locked then
        local status = vgui.Create("DLabel", body)
        status:Dock(TOP)
        status:SetTall(18)
        status:SetDark(true)
        status:SetContentAlignment(5)
        status:SetText("A log process is already running.")
    end

    local text = vgui.Create("DTextEntry", body)
    text:Dock(TOP)
    text:SetTall(460)
    text:DockMargin(0, 10, 0, 0)
    text:SetMultiline(true)
    text:SetEditable(true)
    text:SetVerticalScrollbarEnabled(true)
    text:SetValue(tostring(srv.log_text or ""))

    local btnRow = vgui.Create("DPanel", body)
    btnRow:Dock(TOP)
    btnRow:SetTall(36)
    btnRow:DockMargin(0, 16, 0, 0)
    btnRow.Paint = function() end

    local editBtn = vgui.Create("DButton", btnRow)
    editBtn:SetSize(130, 32)
    editBtn:SetText("Edit log file")
    editBtn.DoClick = function()
        send_cmd("log_edit_submit", { server_id = srv.id, content = text:GetValue() })
    end

    local delBtn = vgui.Create("DButton", btnRow)
    delBtn:SetSize(130, 32)
    delBtn:SetText("Delete all")
    delBtn.DoClick = function()
        Derma_Query("Spawn a process to wipe this server's log?", "Delete log",
            "Delete", function() send_cmd("log_delete_all", { server_id = srv.id }) end,
            "Cancel", function() end)
    end

    local gap = 10
    btnRow.PerformLayout = function(self)
        local totalW = 130 + gap + 130
        local x = math.floor((self:GetWide() - totalW) / 2)
        editBtn:SetPos(x, 0)
        delBtn:SetPos(x + 130 + gap, 0)
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
    tab_header(container, "University", current_server())

    local subbar = vgui.Create("DPanel", container)
    subbar:Dock(TOP)
    subbar:SetTall(28)
    subbar:DockMargin(0, 2, 0, 6)
    local UNIV_ICONS = {
        ["Certifications"]      = "icon16/book_addresses.png",
        ["Research softwares"]  = "icon16/find.png",
    }
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
        if UNIV_ICONS[name] then
            local iconMat = Material(UNIV_ICONS[name])
            surface.SetFont("DermaDefault")
            local textW = select(1, surface.GetTextSize(name))
            local iconW, gap = 16, 8
            b:SetContentAlignment(6)
            b:SetTextInset(math.floor((170 - (iconW + gap + textW)) / 2), 0)
            b.PaintOver = function(self, w, h)
                local x = math.floor((w - (iconW + gap + textW)) / 2)
                local y = math.floor((h - iconW) / 2)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(iconMat)
                surface.DrawTexturedRect(x, y, iconW, iconW)
            end
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
                        "$" .. fmt_cash(cost),
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
                        "$" .. fmt_cash(cost),
                        "License")
                    line.MH_Mode = "license"
                    line.MH_Cost = cost
                end
                line.MH_SoftId = tonumber(s.id)
                line.MH_SoftTypeName = meta.name
                line:SetSortValue(3, curV)
                line:SetSortValue(5, tonumber(line.MH_Cost) or -1)
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
    local btcInfo = MH.OS.State.btc or {}
    tab_header(container, "Finances", current_server())

    local balanceWrap = vgui.Create("DPanel", container)
    balanceWrap:Dock(TOP)
    balanceWrap:SetTall(60)
    balanceWrap:DockMargin(0, 40, 0, 0)
    balanceWrap.Paint = function() end
    local balBox = vgui.Create("DPanel", balanceWrap)
    balBox:SetSize(260, 50)
    balanceWrap.PerformLayout = function(self)
        balBox:SetPos(math.floor((self:GetWide() - 260) / 2), 0)
    end
    local balLbl = vgui.Create("DLabel", balBox)
    balLbl:Dock(FILL)
    balLbl:SetDark(false)
    balLbl:SetTextColor(Color(60, 160, 70))
    balLbl:SetFont("DermaLarge")
    balLbl:SetContentAlignment(5)
    balLbl:SetTextInset(20, 0)
    balLbl:SetText("$" .. fmt_cash(p.cash))
    local finMoneyMat = Material("icon16/money.png")
    local finIconSize = 28
    balLbl.PaintOver = function(self, w, h)
        surface.SetFont("DermaLarge")
        local tw = select(1, surface.GetTextSize(self:GetText() or ""))
        local textX = math.floor((w - tw) / 2) + 10
        local iconX = textX - finIconSize - 56
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(finMoneyMat)
        surface.DrawTexturedRect(iconX, math.floor((h - finIconSize) / 2), finIconSize, finIconSize)
    end

    local function fin_card(title, iconPath, btnText, btnClick, bodyFiller)
        local wrap = vgui.Create("DPanel", container)
        wrap:Dock(TOP)
        wrap:SetTall(170)
        wrap:DockMargin(0, 16, 0, 0)
        wrap.Paint = function() end
        local card = vgui.Create("DPanel", wrap)
        card:SetSize(560, 170)
        wrap.PerformLayout = function(self, w, h)
            card:SetPos(math.floor((w - 560) / 2), 0)
        end
        local head = vgui.Create("DPanel", card)
        head:Dock(TOP)
        head:SetTall(28)
        local hIconMat = Material(iconPath)
        local hIcon = vgui.Create("DPanel", head)
        hIcon:Dock(LEFT)
        hIcon:SetWide(32)
        hIcon.Paint = function(self, w, h)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(hIconMat)
            surface.DrawTexturedRect(math.floor((w - 16) / 2), math.floor((h - 16) / 2), 16, 16)
        end
        local hLbl = vgui.Create("DLabel", head)
        hLbl:Dock(FILL)
        hLbl:SetFont("DermaDefaultBold")
        hLbl:SetDark(true)
        hLbl:SetText(title)
        local hBtn = vgui.Create("DButton", head)
        hBtn:Dock(RIGHT)
        hBtn:SetWide(110)
        hBtn:DockMargin(0, 2, 2, 2)
        hBtn:SetText(btnText)
        hBtn.DoClick = btnClick
        local body = vgui.Create("DPanel", card)
        body:Dock(FILL)
        body:DockPadding(10, 10, 10, 10)
        bodyFiller(body)
        return card
    end

    local function go_internet(ip)
        send_cmd("internet_goto", { ip = ip })
        MH.OS.ActiveTab = "Internet"
        MH.OS.InternetMainTab = "Index"
        if MH.OS.Rebuild then MH.OS.Rebuild() end
    end

    local banks = MH.OS.State.banks or {}
    for idx, b in ipairs(banks) do
        fin_card("Account #" .. idx, "icon16/computer.png", "Access bank",
            function() go_internet(tostring(b.bank_ip or "")) end,
            function(body)
                local nameLbl = vgui.Create("DLabel", body)
                nameLbl:Dock(TOP)
                nameLbl:SetTall(28)
                nameLbl:SetFont("DermaDefaultBold")
                nameLbl:SetDark(true)
                nameLbl:SetContentAlignment(5)
                nameLbl:SetText(tostring(b.bank_name or "?"))
                local balHdr = vgui.Create("DLabel", body)
                balHdr:Dock(TOP)
                balHdr:SetTall(22)
                balHdr:DockMargin(0, 12, 0, 0)
                balHdr:SetFont("DermaDefaultBold")
                balHdr:SetDark(true)
                balHdr:SetContentAlignment(5)
                balHdr:SetText("Account Balance")
                local balVal = vgui.Create("DPanel", body)
                balVal:Dock(TOP)
                balVal:SetTall(20)
                balVal.Paint = function(self, w, h)
                    local cash = "$" .. fmt_cash(b.cash)
                    local rest = " at #" .. tostring(b.acc_num or "")
                    surface.SetFont("DermaDefault")
                    local cw = select(1, surface.GetTextSize(cash))
                    local rw = select(1, surface.GetTextSize(rest))
                    local totalW = cw + rw
                    local x = math.floor((w - totalW) / 2)
                    local sk = self:GetSkin()
                    local tc = (sk and sk.Colours and sk.Colours.Label and sk.Colours.Label.Default) or color_black
                    draw.SimpleText(cash, "DermaDefault", x, h / 2,
                        Color(80, 140, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText(rest, "DermaDefault", x + cw, h / 2,
                        tc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
            end)
    end

    fin_card("BTC Wallet", "icon16/application_osx_terminal.png", "Access Market",
        function()
            local svcs = MH.OS.State.public_services or {}
            local btcSvc = svcs.BITCOIN
            if btcSvc and btcSvc.ip then go_internet(btcSvc.ip) end
        end,
        function(body)
            local addrHdr = vgui.Create("DLabel", body)
            addrHdr:Dock(TOP)
            addrHdr:SetTall(22)
            addrHdr:SetFont("DermaDefaultBold")
            addrHdr:SetDark(true)
            addrHdr:SetContentAlignment(5)
            addrHdr:SetText("Public Address")
            local addrVal = vgui.Create("DLabel", body)
            addrVal:Dock(TOP)
            addrVal:SetTall(20)
            addrVal:SetDark(true)
            addrVal:SetContentAlignment(5)
            addrVal:SetText(tostring(btcInfo.address or ""))
            local btcHdr = vgui.Create("DLabel", body)
            btcHdr:Dock(TOP)
            btcHdr:SetTall(22)
            btcHdr:DockMargin(0, 12, 0, 0)
            btcHdr:SetFont("DermaDefaultBold")
            btcHdr:SetDark(true)
            btcHdr:SetContentAlignment(5)
            btcHdr:SetText("Bitcoins")
            local btcVal = vgui.Create("DLabel", body)
            btcVal:Dock(TOP)
            btcVal:SetTall(20)
            btcVal:SetDark(true)
            btcVal:SetContentAlignment(5)
            btcVal:SetText(string.format("%.7f", tonumber(p.bitcoin or btcInfo.amount or 0)) .. " BTC")
        end)
end

MH.OS.HackedView = MH.OS.HackedView or "IP List"
MH.OS.CollectShowingResult = MH.OS.CollectShowingResult or false

Tabs["Hacked Database"] = function(container)
    clear(container)
    tab_header(container, "Hacked Database", current_server())

    local subbar = vgui.Create("DPanel", container)
    subbar:Dock(TOP)
    subbar:SetTall(28)
    subbar:DockMargin(0, 2, 0, 6)

    local body = vgui.Create("DScrollPanel", container)
    body:Dock(FILL)
    local bodyCanvas = body:GetCanvas()
    bodyCanvas:DockPadding(0, 0, 2, 0)

    local function paint()
        bodyCanvas:Clear()
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
            sortRow.Paint = function() end
            local sortLbl = vgui.Create("DLabel", sortRow)
            sortLbl:Dock(LEFT)
            sortLbl:DockMargin(4, 6, 6, 0)
            sortLbl:SetDark(true)
            sortLbl:SetText("Sort by:")
            sortLbl:SizeToContents()
            MH.OS.HackedSort = MH.OS.HackedSort or "newest"
            local combo = vgui.Create("DComboBox", sortRow)
            combo:Dock(LEFT)
            combo:SetWide(220)
            combo:DockMargin(0, 2, 0, 2)
            local sortOptions = {
                { k = "newest",   t = "Hacked time (newest)" },
                { k = "oldest",   t = "Hacked time (oldest)" },
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
                if MH.OS.HackedSort == "oldest" then return (tonumber(a.stamp) or 0) < (tonumber(b.stamp) or 0) end
                return (tonumber(a.stamp) or 0) > (tonumber(b.stamp) or 0)
            end)

            local virusByServer = {}
            for _, v in ipairs(MH.OS.State.installed_viruses or {}) do
                local sid = tonumber(v.server_id or 0)
                if sid > 0 and not virusByServer[sid] then virusByServer[sid] = v end
            end

            local USER_ICON = Material("icon16/computer.png")
            local PASS_ICON = Material("icon16/key.png")
            local BUG_ICON  = Material("icon16/bug.png")
            local NET_ICON  = Material("icon16/connect.png")
            local HDD_ICON  = Material("icon16/drive.png")
            local CPU_ICON  = Material("icon16/cog.png")
            local RAM_ICON  = Material("icon16/chart_bar.png")
            local DEL_ICON  = Material("icon16/delete.png")

            local function fmt_hdd(mb)
                mb = tonumber(mb) or 0
                if mb >= 1000 then return math.floor(mb / 1000) .. " GB" end
                return mb .. " MB"
            end

            local function ago_text(stamp)
                local s = tonumber(stamp) or 0
                if s <= 0 then return "never collected" end
                local nowT = os.time()
                local diff = math.max(0, nowT - s)
                if diff < 60 then return diff .. "s ago" end
                if diff < 3600 then return math.floor(diff / 60) .. "m ago" end
                if diff < 86400 then return math.floor(diff / 3600) .. "h ago" end
                if diff < 86400 * 30 then return math.floor(diff / 86400) .. "d ago" end
                if diff < 86400 * 365 then return math.floor(diff / (86400 * 30)) .. " months" end
                return math.floor(diff / (86400 * 365)) .. " years"
            end

            for _, h in ipairs(sortedHacked) do
                local netMb = (MH.Data.Hardware.net[tonumber(h.net_tier or 1) or 1] or {}).mbps or 1
                local hddMb = (MH.Data.Hardware.hdd[tonumber(h.hdd_tier or 1) or 1] or {}).mb or 100
                local cpuMhz = (MH.Data.Hardware.cpu[tonumber(h.cpu_tier or 1) or 1] or {}).mhz or 500
                local ramMb = (MH.Data.Hardware.ram[tonumber(h.ram_tier or 1) or 1] or {}).mb or 256
                local virus = virusByServer[tonumber(h.target_server or 0)]
                local virusMeta = virus and (MH.Data.Soft[tonumber(virus.soft_type or 0)] or {}) or {}

                local hrow = vgui.Create("DButton", body)
                hrow:SetText("")
                hrow:Dock(TOP)
                hrow:SetTall(60)
                hrow:DockMargin(0, 2, 0, 0)
                hrow.DoClick = function()
                    send_cmd("internet_goto", { ip = tostring(h.ip or "") })
                    MH.OS.ActiveTab = "Internet"
                    if MH.OS.Rebuild then MH.OS.Rebuild() end
                end
                hrow.Paint = function(self, w, hgt)
                    derma.SkinHook("Paint", "Panel", self, w, hgt)
                end

                local ipLbl = vgui.Create("DLabel", hrow)
                ipLbl:SetPos(14, 6)
                ipLbl:SetFont("DermaDefaultBold")
                ipLbl:SetDark(true)
                ipLbl:SetText(tostring(h.ip or "?"))
                ipLbl:SetSize(220, 20)

                local credStrip = vgui.Create("DPanel", hrow)
                credStrip:SetPos(14, 32)
                credStrip:SetSize(220, 18)
                local userTxt = "root"
                local passTxt = tostring(h.discovered_pass or "")
                credStrip.Paint = function(self, w, hgt)
                    local sk = self:GetSkin()
                    local tc = (sk and sk.Colours and sk.Colours.Label and sk.Colours.Label.Default) or color_black
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.SetMaterial(USER_ICON)
                    surface.DrawTexturedRect(0, 1, 16, 16)
                    draw.SimpleText(userTxt, "DermaDefault", 20, hgt / 2, tc,
                        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    surface.SetFont("DermaDefault")
                    local uw = select(1, surface.GetTextSize(userTxt))
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.SetMaterial(PASS_ICON)
                    surface.DrawTexturedRect(30 + uw, 1, 16, 16)
                    draw.SimpleText(passTxt, "DermaDefault", 50 + uw, hgt / 2,
                        Color(170, 120, 60), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end

                local virusCell = vgui.Create("DPanel", hrow)
                virusCell:SetPos(260, 6)
                virusCell:SetSize(380, 48)
                virusCell.Paint = function(self, w, hgt)
                    local sk = self:GetSkin()
                    local tc = (sk and sk.Colours and sk.Colours.Label and sk.Colours.Label.Default) or color_black
                    if virus then
                        local baseName = tostring(virus.soft_name ~= nil and virus.soft_name ~= "" and virus.soft_name or virusMeta.name or ("#" .. tostring(virus.soft_type)))
                        local name = baseName .. tostring(virusMeta.ext or "")
                        surface.SetDrawColor(255, 255, 255, 255)
                        surface.SetMaterial(BUG_ICON)
                        surface.DrawTexturedRect(0, 2, 16, 16)
                        draw.SimpleText(name, "DermaDefaultBold", 20, 10, tc,
                            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                        draw.SimpleText(ago_text(virus.last_collect), "DermaDefault", 20, 32,
                            Color(140, 140, 140), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    else
                        draw.SimpleText("No running virus", "DermaDefault", 0, hgt / 2,
                            Color(140, 140, 140), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end
                end

                local statsCell = vgui.Create("DPanel", hrow)
                statsCell:SetSize(140, 48)
                statsCell.Paint = function(self, w, hgt)
                    local sk = self:GetSkin()
                    local tc = (sk and sk.Colours and sk.Colours.Label and sk.Colours.Label.Default) or color_black
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.SetMaterial(NET_ICON)
                    surface.DrawTexturedRect(0, 4, 16, 16)
                    draw.SimpleText(netMb .. " Mbit/s", "DermaDefault", 20, 12, tc,
                        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.SetMaterial(HDD_ICON)
                    surface.DrawTexturedRect(0, 26, 16, 16)
                    draw.SimpleText(fmt_hdd(hddMb), "DermaDefault", 20, 34, tc,
                        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end

                local function fmt_ram(mb)
                    if mb >= 1024 then return math.floor(mb / 1024) .. " GB" end
                    return mb .. " MB"
                end
                local tierCell = vgui.Create("DPanel", hrow)
                tierCell:SetSize(110, 48)
                tierCell.Paint = function(self, w, hgt)
                    local sk = self:GetSkin()
                    local tc = (sk and sk.Colours and sk.Colours.Label and sk.Colours.Label.Default) or color_black
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.SetMaterial(CPU_ICON)
                    surface.DrawTexturedRect(0, 4, 16, 16)
                    draw.SimpleText(cpuMhz .. " MHz", "DermaDefault", 20, 12, tc,
                        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.SetMaterial(RAM_ICON)
                    surface.DrawTexturedRect(0, 26, 16, 16)
                    draw.SimpleText(fmt_ram(ramMb), "DermaDefault", 20, 34, tc,
                        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end

                local removeB = vgui.Create("DButton", hrow)
                removeB:SetText("")
                removeB:SetSize(28, 28)
                removeB:SetTooltip("Remove")
                removeB.Paint = function(self, w, hgt)
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.SetMaterial(DEL_ICON)
                    surface.DrawTexturedRect(math.floor((w - 16) / 2), math.floor((hgt - 16) / 2), 16, 16)
                end
                removeB.DoClick = function() send_cmd("hacked_remove", { hacked_id = h.id }) end

                hrow.PerformLayout = function(self, w, hgt)
                    local rightX = w - 48
                    removeB:SetPos(rightX, math.floor((hgt - 28) / 2))
                    tierCell:SetPos(rightX - 110 - 10, 6)
                    statsCell:SetPos(rightX - 110 - 10 - 140 - 10, 6)
                end

                hrow.OnMousePressed = function(self, mcode)
                    if mcode == MOUSE_RIGHT then
                        local m = DermaMenu()
                        m:AddOption("Open in Internet", function()
                            send_cmd("internet_goto", { ip = tostring(h.ip or "") })
                            MH.OS.ActiveTab = "Internet"
                            if MH.OS.Rebuild then MH.OS.Rebuild() end
                        end)
                        local vm = m:AddSubMenu("Install virus")
                        for _, st in ipairs({ 8, 9, 10, 11, 12, 20, 29 }) do
                            vm:AddOption(MH.Data.SoftName(st), function()
                                send_cmd("virus_install", { target_server = h.target_server, soft_type = st })
                            end)
                        end
                        m:AddOption("Launch DOOM", function()
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
                                Derma_Message("Install a Doom virus on this target first.",
                                    "No Doom planted", "OK")
                                return
                            end
                            Derma_Query("Release DOOM against " .. tostring(h.ip) .. "?",
                                "Launch DOOM", "Release",
                                function() send_cmd("doom_launch", { target_server = h.target_server, soft_id = myDoom.id }) end,
                                "Cancel", function() end)
                        end)
                        m:AddOption("Remove", function() send_cmd("hacked_remove", { hacked_id = h.id }) end)
                        m:Open()
                    end
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
            local p = MH.OS.State.player or {}
            local summary
            if p.last_collect_json and p.last_collect_json ~= "" and p.last_collect_json ~= "NULL" then
                summary = util.JSONToTable(tostring(p.last_collect_json))
            end
            local function fmt_hours(secs)
                secs = tonumber(secs) or 0
                local hours = math.floor(secs / 3600)
                local mins = math.floor((secs % 3600) / 60)
                return hours .. " hours and " .. mins .. " minutes"
            end
            local function render_collect_info(parent, withGoBack)
                local head = vgui.Create("DPanel", parent)
                head:Dock(TOP)
                head:SetTall(28)
                local hIconMat = Material("icon16/report.png")
                local hIcon = vgui.Create("DPanel", head)
                hIcon:Dock(LEFT)
                hIcon:SetWide(32)
                hIcon.Paint = function(self, w, hgt)
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.SetMaterial(hIconMat)
                    surface.DrawTexturedRect(math.floor((w - 16) / 2), math.floor((hgt - 16) / 2), 16, 16)
                end
                local hLbl = vgui.Create("DLabel", head)
                hLbl:Dock(FILL)
                hLbl:SetFont("DermaDefaultBold")
                hLbl:SetDark(true)
                hLbl:SetText(withGoBack and "Collect Information" or "Last Collect Information")
                if withGoBack then
                    local back = vgui.Create("DButton", head)
                    back:Dock(RIGHT)
                    back:SetWide(80)
                    back:DockMargin(0, 2, 2, 2)
                    back:SetText("Go Back")
                    back.DoClick = function()
                        MH.OS.CollectShowingResult = false
                        if MH.OS.Rebuild then MH.OS.Rebuild() end
                    end
                end
                local inner = vgui.Create("DPanel", parent)
                inner:Dock(FILL)
                inner:DockPadding(14, 12, 14, 12)
                if not summary or not summary.details or #summary.details == 0 then
                    local empty = vgui.Create("DLabel", inner)
                    empty:Dock(TOP)
                    empty:SetTall(22)
                    empty:SetDark(true)
                    empty:SetText("Oops. You still havent collected :(")
                    return
                end
                for _, d in ipairs(summary.details) do
                    if (d.cash or 0) > 0 and tonumber(d.soft_type) == 8 then
                        local line = vgui.Create("DPanel", inner)
                        line:Dock(TOP)
                        line:SetTall(18)
                        line.Paint = function(self, w, hgt)
                            local sk = self:GetSkin()
                            local tc = (sk and sk.Colours and sk.Colours.Label and sk.Colours.Label.Default) or color_black
                            local work = fmt_hours(d.work_time)
                            local emails = tostring(d.emails or 0)
                            local cash = "$" .. fmt_cash(d.cash)
                            local bonus = d.bonus and " - BONUS!" or ""
                            draw.SimpleText("Server " .. tostring(d.host_ip or "") .. " worked for ", "DermaDefault", 0, hgt / 2, tc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                            surface.SetFont("DermaDefault")
                            local x = select(1, surface.GetTextSize("Server " .. tostring(d.host_ip or "") .. " worked for "))
                            draw.SimpleText(work, "DermaDefaultBold", x, hgt / 2, tc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                            x = x + select(1, surface.GetTextSize(work))
                            surface.SetFont("DermaDefault")
                            draw.SimpleText(" and mailed ", "DermaDefault", x, hgt / 2, tc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                            x = x + select(1, surface.GetTextSize(" and mailed "))
                            draw.SimpleText(emails, "DermaDefault", x, hgt / 2, Color(200, 60, 60), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                            x = x + select(1, surface.GetTextSize(emails))
                            draw.SimpleText(" emails, generating ", "DermaDefault", x, hgt / 2, tc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                            x = x + select(1, surface.GetTextSize(" emails, generating "))
                            draw.SimpleText(cash, "DermaDefaultBold", x, hgt / 2, Color(80, 140, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                            if d.bonus then
                                surface.SetFont("DermaDefaultBold")
                                x = x + select(1, surface.GetTextSize(cash))
                                draw.SimpleText(bonus, "DermaDefaultBold", x, hgt / 2, Color(80, 140, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                            end
                        end
                    elseif (d.cash or 0) > 0 and tonumber(d.soft_type) == 9 then
                        local l = vgui.Create("DLabel", inner)
                        l:Dock(TOP)
                        l:SetTall(18)
                        l:SetDark(true)
                        l:SetText("Server " .. tostring(d.host_ip) .. " seeded warez, generating $" .. fmt_cash(d.cash))
                    elseif (d.btc or 0) > 0 and tonumber(d.soft_type) == 20 then
                        local l = vgui.Create("DLabel", inner)
                        l:Dock(TOP)
                        l:SetTall(18)
                        l:SetDark(true)
                        l:SetText("Server " .. tostring(d.host_ip) .. " mined " .. string.format("%.7f", d.btc) .. " BTC")
                    end
                end
                if (summary.collector_bonus_pct or 0) > 0 then
                    local spacer = vgui.Create("DPanel", inner)
                    spacer:Dock(TOP)
                    spacer:SetTall(10)
                    spacer.Paint = function() end
                    local cbRow = vgui.Create("DPanel", inner)
                    cbRow:Dock(TOP)
                    cbRow:SetTall(18)
                    cbRow.Paint = function(self, w, hgt)
                        local sk = self:GetSkin()
                        local tc = (sk and sk.Colours and sk.Colours.Label and sk.Colours.Label.Default) or color_black
                        draw.SimpleText("Collector bonus: ", "DermaDefault", 0, hgt / 2, tc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                        surface.SetFont("DermaDefault")
                        local x = select(1, surface.GetTextSize("Collector bonus: "))
                        draw.SimpleText(string.format("%g%%", summary.collector_bonus_pct), "DermaDefaultBold", x, hgt / 2, tc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end
                end
                if (summary.cash_total or 0) > 0 then
                    local spacer2 = vgui.Create("DPanel", inner)
                    spacer2:Dock(TOP)
                    spacer2:SetTall(10)
                    spacer2.Paint = function() end
                    local xferRow = vgui.Create("DPanel", inner)
                    xferRow:Dock(TOP)
                    xferRow:SetTall(18)
                    xferRow.Paint = function(self, w, hgt)
                        local sk = self:GetSkin()
                        local tc = (sk and sk.Colours and sk.Colours.Label and sk.Colours.Label.Default) or color_black
                        local cash = "$" .. fmt_cash(summary.cash_total)
                        local acc = "#" .. tostring(summary.account or "")
                        draw.SimpleText(cash, "DermaDefaultBold", 0, hgt / 2, Color(80, 140, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                        surface.SetFont("DermaDefaultBold")
                        local x = select(1, surface.GetTextSize(cash))
                        surface.SetFont("DermaDefault")
                        draw.SimpleText(" were transfered to ", "DermaDefault", x, hgt / 2, tc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                        x = x + select(1, surface.GetTextSize(" were transfered to "))
                        draw.SimpleText(acc, "DermaDefault", x, hgt / 2, tc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end
                end
            end

            if MH.OS.CollectShowingResult then
                local wrap = vgui.Create("DPanel", body)
                wrap:Dock(TOP)
                wrap:SetTall(220)
                render_collect_info(wrap, true)
                return
            end

            local cols = vgui.Create("DPanel", body)
            cols:Dock(TOP)
            cols:SetTall(220)
            cols.Paint = function() end

            local leftBox = vgui.Create("DPanel", cols)
            leftBox:Dock(FILL)
            leftBox:DockMargin(0, 0, 8, 0)
            render_collect_info(leftBox, false)

            local rightBox = vgui.Create("DPanel", cols)
            rightBox:Dock(RIGHT)
            rightBox:SetWide(300)
            local rHead = vgui.Create("DPanel", rightBox)
            rHead:Dock(TOP)
            rHead:SetTall(28)
            local rIconMat = Material("icon16/money.png")
            local rIcon = vgui.Create("DPanel", rHead)
            rIcon:Dock(LEFT)
            rIcon:SetWide(32)
            rIcon.Paint = function(self, w, hgt)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(rIconMat)
                surface.DrawTexturedRect(math.floor((w - 16) / 2), math.floor((hgt - 16) / 2), 16, 16)
            end
            local rLbl = vgui.Create("DLabel", rHead)
            rLbl:Dock(FILL)
            rLbl:SetFont("DermaDefaultBold")
            rLbl:SetDark(true)
            rLbl:SetText("Collect virus money")
            local rBody = vgui.Create("DPanel", rightBox)
            rBody:Dock(FILL)
            rBody:DockPadding(14, 14, 14, 14)
            local accRow = vgui.Create("DPanel", rBody)
            accRow:Dock(TOP)
            accRow:SetTall(28)
            accRow.Paint = function() end
            local accLbl = vgui.Create("DLabel", accRow)
            accLbl:Dock(LEFT)
            accLbl:SetWide(60)
            accLbl:DockMargin(0, 6, 4, 0)
            accLbl:SetDark(true)
            accLbl:SetText("Account:")
            local accCombo = vgui.Create("DComboBox", accRow)
            accCombo:Dock(FILL)
            local banks = MH.OS.State.banks or {}
            local pickedAcc
            for i, b in ipairs(banks) do
                local label = "#" .. tostring(b.acc_num) .. " ($" .. tostring(tonumber(b.cash or 0)) .. ")"
                accCombo:AddChoice(label, tostring(b.acc_num), i == 1)
                if i == 1 then pickedAcc = tostring(b.acc_num) end
            end
            accCombo.OnSelect = function(_, _, _, data) pickedAcc = data end
            if #banks == 0 then
                accCombo:SetValue("No bank account")
                accCombo:SetEnabled(false)
            end
            local btnWrap = vgui.Create("DPanel", rBody)
            btnWrap:Dock(TOP)
            btnWrap:SetTall(60)
            btnWrap:DockMargin(0, 20, 0, 0)
            btnWrap.Paint = function() end
            local collectBtn = vgui.Create("DButton", btnWrap)
            collectBtn:Dock(FILL)
            collectBtn:SetText("Collect my money!")
            collectBtn:SetTextColor(color_white)
            collectBtn.Paint = function(self, w, hgt)
                local col = self:IsHovered() and Color(90, 170, 80) or Color(100, 180, 90)
                surface.SetDrawColor(col.r, col.g, col.b, 255)
                surface.DrawRect(0, 0, w, hgt)
            end
            collectBtn.DoClick = function()
                local viruses = MH.OS.State.installed_viruses or {}
                if #viruses == 0 then
                    MH.OS.ShowNotify("warn", "No viruses installed to collect from")
                    return
                end
                send_cmd("virus_collect", { account = pickedAcc })
                MH.OS.CollectShowingResult = true
                if MH.OS.Rebuild then MH.OS.Rebuild() end
            end
        elseif MH.OS.HackedView == "DDoS" then
            local p = MH.OS.State.player or {}
            local certLvl = tonumber(p.cert_level or 0) or 0

            local activeDdos = {}
            for _, h in ipairs(MH.OS.State.hacked or {}) do
                for _, s in ipairs(MH.OS.State.servers or {}) do
                    for _, inv in ipairs(s.software or {}) do
                        if tonumber(inv.soft_type) == 10 and tonumber(inv.installed) == 1
                            and tonumber(inv.server_id) == tonumber(h.target_server)
                        then
                            table.insert(activeDdos, {
                                host_ip = tostring(h.ip or "?"),
                                host_name = tostring(h.target_name or ""),
                                version = tonumber(inv.soft_version) or 0,
                            })
                        end
                    end
                end
            end

            local cols = vgui.Create("DPanel", body)
            cols:Dock(TOP)
            cols:SetTall(260)
            cols.Paint = function() end

            local leftBox = vgui.Create("DPanel", cols)
            leftBox:Dock(FILL)
            leftBox:DockMargin(0, 0, 8, 0)
            local lHead = vgui.Create("DPanel", leftBox)
            lHead:Dock(TOP)
            lHead:SetTall(28)
            local lIconMat = Material("icon16/bomb.png")
            local lIcon = vgui.Create("DPanel", lHead)
            lIcon:Dock(LEFT)
            lIcon:SetWide(32)
            lIcon.Paint = function(self, w, hgt)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(lIconMat)
                surface.DrawTexturedRect(math.floor((w - 16) / 2), math.floor((hgt - 16) / 2), 16, 16)
            end
            local lLbl = vgui.Create("DLabel", lHead)
            lLbl:Dock(FILL)
            lLbl:SetFont("DermaDefaultBold")
            lLbl:SetDark(true)
            lLbl:SetText("Launch DDoS attack")

            local lBody = vgui.Create("DPanel", leftBox)
            lBody:Dock(FILL)
            lBody:DockPadding(14, 10, 14, 10)

            local warn = vgui.Create("DPanel", lBody)
            warn:Dock(TOP)
            warn:SetTall(28)
            warn.Paint = function(self, w, hgt)
                surface.SetDrawColor(250, 230, 230, 255)
                surface.DrawRect(0, 0, w, hgt)
                surface.SetDrawColor(230, 200, 200, 255)
                surface.DrawOutlinedRect(0, 0, w, hgt)
                draw.SimpleText("Atention:", "DermaDefaultBold", 10, hgt / 2,
                    Color(200, 60, 60), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                surface.SetFont("DermaDefaultBold")
                local aw = select(1, surface.GetTextSize("Atention: "))
                draw.SimpleText("Your IP will be logged on ", "DermaDefault", 10 + aw, hgt / 2,
                    Color(200, 60, 60), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                surface.SetFont("DermaDefault")
                local x = 10 + aw + select(1, surface.GetTextSize("Your IP will be logged on "))
                draw.SimpleText("all", "DermaDefaultBold", x, hgt / 2,
                    Color(200, 60, 60), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                surface.SetFont("DermaDefaultBold")
                x = x + select(1, surface.GetTextSize("all"))
                draw.SimpleText(" servers used to DDoS.", "DermaDefault", x, hgt / 2,
                    Color(200, 60, 60), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            if certLvl < 4 then
                local l = vgui.Create("DLabel", lBody)
                l:Dock(TOP)
                l:DockMargin(0, 14, 0, 0)
                l:SetDark(true)
                l:SetText("Requires DDoS Security (cert 4). Current level: " .. certLvl .. " / 5.")
            elseif #activeDdos < 3 then
                local l = vgui.Create("DLabel", lBody)
                l:Dock(TOP)
                l:DockMargin(0, 14, 0, 0)
                l:SetDark(true)
                l:SetText("You must have at least 3 DDoS virus running to perform an attack.")
            else
                local info = vgui.Create("DLabel", lBody)
                info:Dock(TOP)
                info:DockMargin(0, 14, 0, 6)
                info:SetDark(true)
                info:SetText("Active DDoS viruses: " .. #activeDdos .. " / 3 required.")
                local row = vgui.Create("DPanel", lBody)
                row:Dock(TOP)
                row:SetTall(32)
                row:DockMargin(0, 6, 0, 0)
                row.Paint = function() end
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

            local rightBox = vgui.Create("DPanel", cols)
            rightBox:Dock(RIGHT)
            rightBox:SetWide(340)
            local rHead = vgui.Create("DPanel", rightBox)
            rHead:Dock(TOP)
            rHead:SetTall(28)
            local rIconMat = Material("icon16/server_connect.png")
            local rIcon = vgui.Create("DPanel", rHead)
            rIcon:Dock(LEFT)
            rIcon:SetWide(32)
            rIcon.Paint = function(self, w, hgt)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(rIconMat)
                surface.DrawTexturedRect(math.floor((w - 16) / 2), math.floor((hgt - 16) / 2), 16, 16)
            end
            local rLbl = vgui.Create("DLabel", rHead)
            rLbl:Dock(FILL)
            rLbl:SetFont("DermaDefaultBold")
            rLbl:SetDark(true)
            rLbl:SetText("Running DDoS viruses")
            local badge = vgui.Create("DPanel", rHead)
            badge:Dock(RIGHT)
            badge:SetWide(32)
            badge:DockMargin(0, 2, 2, 2)
            badge.Paint = function(self, w, hgt)
                surface.SetDrawColor(58, 135, 173, 255)
                surface.DrawRect(0, 0, w, hgt)
                draw.SimpleText(tostring(#activeDdos), "DermaDefaultBold", w / 2, hgt / 2,
                    color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            local rBody = vgui.Create("DPanel", rightBox)
            rBody:Dock(FILL)
            rBody:DockPadding(14, 10, 14, 10)
            if #activeDdos == 0 then
                local l = vgui.Create("DLabel", rBody)
                l:Dock(TOP)
                l:SetTall(22)
                l:SetDark(true)
                l:SetText("You havent installed any DDoS Virus yet.")
            else
                for _, d in ipairs(activeDdos) do
                    local l = vgui.Create("DLabel", rBody)
                    l:Dock(TOP)
                    l:SetTall(18)
                    l:SetDark(true)
                    l:SetText(d.host_ip .. "   v" .. MH.Data.DotVersion(d.version))
                end
            end
        end
    end

    local HD_ICONS = {
        ["IP List"]       = "icon16/computer.png",
        ["Bank Accounts"] = "icon16/user_suit.png",
        ["Collect money"] = "icon16/money.png",
        ["DDoS"]          = "icon16/bomb.png",
    }
    for _, name in ipairs({ "IP List", "Bank Accounts", "Collect money", "DDoS" }) do
        local b = vgui.Create("DButton", subbar)
        b:SetText(name)
        b:Dock(LEFT)
        b:SetWide(150)
        b:DockMargin(0, 0, 4, 0)
        b.DoClick = function()
            MH.OS.HackedView = name == "Collect money" and "Collect" or name
            MH.OS.CollectShowingResult = false
            paint()
        end
        if HD_ICONS[name] then
            local iconMat = Material(HD_ICONS[name])
            surface.SetFont("DermaDefault")
            local textW = select(1, surface.GetTextSize(name))
            local iconW, gap = 16, 8
            b:SetContentAlignment(6)
            b:SetTextInset(math.floor((150 - (iconW + gap + textW)) / 2), 0)
            b.PaintOver = function(self, w, h)
                local x = math.floor((w - (iconW + gap + textW)) / 2)
                local y = math.floor((h - iconW) / 2)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(iconMat)
                surface.DrawTexturedRect(x, y, iconW, iconW)
            end
        end
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
    tab_header(container, "Missions", current_server())

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
                prizeTxt = "$" .. fmt_cash(m.prize)
                diffTxt = difficulty_for(m.prize)
                statusTxt = MISSION_STATUS_TXT[tonumber(m.status)] or tostring(m.status)
            end
            local line = list:AddLine(title, giver, targetTxt, prizeTxt, diffTxt, statusTxt)
            if not locked then
                line:SetSortValue(4, tonumber(m.prize) or 0)
            end
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

    local MISSION_ICONS = {
        ["Active"]    = "icon16/package.png",
        ["Completed"] = "icon16/package_green.png",
    }
    for _, name in ipairs({ "Active", "Completed" }) do
        local b = vgui.Create("DButton", subbar)
        b:SetText(name)
        b:Dock(LEFT)
        b:SetWide(110)
        b:DockMargin(0, 0, 4, 0)
        b.DoClick = function() MH.OS.MissionView = name paint() end
        if MISSION_ICONS[name] then
            local iconMat = Material(MISSION_ICONS[name])
            surface.SetFont("DermaDefault")
            local textW = select(1, surface.GetTextSize(name))
            local iconW, gap = 16, 8
            b:SetContentAlignment(6)
            b:SetTextInset(math.floor((110 - (iconW + gap + textW)) / 2), 0)
            b.PaintOver = function(self, w, h)
                local x = math.floor((w - (iconW + gap + textW)) / 2)
                local y = math.floor((h - iconW) / 2)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(iconMat)
                surface.DrawTexturedRect(x, y, iconW, iconW)
            end
        end
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
    tab_header(container, "Mail", current_server())

    local subbar = vgui.Create("DPanel", container)
    subbar:Dock(TOP)
    subbar:SetTall(28)
    subbar:DockMargin(0, 2, 0, 6)

    local MAIL_ICONS = {
        ["Inbox"]   = "icon16/email_open.png",
        ["Outbox"]  = "icon16/email_go.png",
        ["Compose"] = "icon16/email_edit.png",
    }
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
        if MAIL_ICONS[name] then
            local iconMat = Material(MAIL_ICONS[name])
            surface.SetFont("DermaDefault")
            local textW = select(1, surface.GetTextSize(name))
            local iconW, gap = 16, 8
            b:SetContentAlignment(6)
            b:SetTextInset(math.floor((100 - (iconW + gap + textW)) / 2), 0)
            b.PaintOver = function(self, w, h)
                local x = math.floor((w - (iconW + gap + textW)) / 2)
                local y = math.floor((h - iconW) / 2)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(iconMat)
                surface.DrawTexturedRect(x, y, iconW, iconW)
            end
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
            lineRef:SetSortValue(4, tonumber(m.stamp) or 0)
        end

        local selected = nil
        list.OnRowSelected = function(_, _, lineRef)
            local m = lineRef and lineRef.MH_Mail
            if not m then return end
            selected = m
            local party = isInbox and m.from_sid or m.to_sid
            local partyName = resolve_sender_name(party)
            local partyStr = partyName
            if not SYSTEM_SENDERS[tostring(party or "")] and tostring(party or "") ~= "" then
                partyStr = partyName .. " (" .. tostring(party) .. ")"
            end
            senderInfo:SetText(tostring(m.subject or "(no subject)") ..
                "\n" .. (isInbox and ("From " .. partyStr) or ("To " .. partyStr)) ..
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
        local captchaWrap = vgui.Create("DPanel", container)
        captchaWrap:Dock(TOP)
        captchaWrap:SetTall(80)
        captchaWrap:DockMargin(0, 8, 0, 0)
        local captchaPrompt = vgui.Create("DLabel", captchaWrap)
        captchaPrompt:Dock(TOP)
        captchaPrompt:SetTall(20)
        captchaPrompt:DockMargin(10, 8, 10, 0)
        captchaPrompt:SetDark(true)
        captchaPrompt:SetFont("DermaDefaultBold")
        captchaPrompt:SetContentAlignment(5)
        captchaPrompt:SetText("Loading captcha...")
        local captchaRow = vgui.Create("DPanel", captchaWrap)
        captchaRow:Dock(TOP)
        captchaRow:SetTall(44)
        captchaRow:DockMargin(10, 6, 10, 0)
        captchaRow.Paint = function() end
        local tileBtns = {}
        for i = 1, 4 do
            local b = vgui.Create("DButton", captchaRow)
            b:SetText("")
            b:SetSize(44, 40)
            b.Paint = function(self, w, h)
                derma.SkinHook("Paint", "Button", self, w, h)
                local pick = MH.OS.MailCaptcha and MH.OS.MailCaptcha.choices[i]
                if pick then
                    local mat = Material("icon16/" .. pick .. ".png")
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.SetMaterial(mat)
                    surface.DrawTexturedRect(math.floor((w - 16) / 2), math.floor((h - 16) / 2), 16, 16)
                end
                if MH.OS.MailCaptcha and MH.OS.MailCaptcha.choice == i then
                    surface.SetDrawColor(70, 160, 195, 255)
                    surface.DrawOutlinedRect(0, 0, w, h)
                    surface.DrawOutlinedRect(1, 1, w - 2, h - 2)
                end
            end
            b.DoClick = function()
                if not MH.OS.MailCaptcha then return end
                MH.OS.MailCaptcha.choice = i
            end
            tileBtns[i] = b
        end
        captchaRow.PerformLayout = function(self, w, h)
            local total = 44 * 4 + 10 * 3
            local x = math.max(0, math.floor((w - total) / 2))
            for i, b in ipairs(tileBtns) do
                b:SetPos(x + (i - 1) * (44 + 10), math.floor((h - 40) / 2))
            end
        end
        MH.OS.MailCaptcha = nil
        MH.OS.OnMailCaptcha = function(challenge)
            MH.OS.MailCaptcha = challenge
            if IsValid(captchaPrompt) then
                captchaPrompt:SetText("Click on " .. tostring(challenge.prompt or ""))
                captchaPrompt:SizeToContents()
            end
        end
        send_cmd("mail_captcha_request", {})

        local sendB = vgui.Create("DButton", container)
        sendB:Dock(TOP)
        sendB:SetTall(32)
        sendB:DockMargin(0, 8, 0, 0)
        sendB:SetText("Send")
        sendB.DoClick = function()
            local ch = MH.OS.MailCaptcha
            if not ch or not ch.choice then
                MH.OS.ShowNotify("warn", "Solve the captcha before sending")
                return
            end
            send_cmd("mail_send", {
                to = toEntry:GetValue(),
                subject = subEntry:GetValue(),
                body = bodyEntry:GetValue(),
                captcha_token = ch.token,
                captcha_choice = ch.choice,
            })
            MH.OS.MailCaptcha = nil
            send_cmd("mail_captcha_request", {})
        end
        end
end

local TAB_ORDER = { "Home", "Task Manager", "Software", "Internet", "Log File", "Hardware", "University", "Finances", "Hacked Database", "Missions", "Mail", "Ranking", "Settings", "Admin" }
local ADMIN_ONLY_TABS = { Admin = true }

Tabs["Ranking"] = function(container)
    clear(container)
    tab_header(container, "Hall of Fame", current_server())

    local CATEGORIES = {
        { key = "reputation", title = "Reputation",     valueFmt = function(v) return tostring(math.floor(v)) end },
        { key = "hacks",      title = "Hacks",          valueFmt = function(v) return tostring(math.floor(v)) end },
        { key = "software",   title = "Software",       software = true },
        { key = "money",      title = "Money earned",   valueFmt = function(v) return "$" .. fmt_cash(v) end },
        { key = "transfers",  title = "Money moved",    valueFmt = function(v) return "$" .. fmt_cash(v) end },
        { key = "wealth",     title = "Current wealth", valueFmt = function(v) return "$" .. fmt_cash(v) end },
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
                local valNum
                if c.software then
                    local meta = MH.Data.Soft[tonumber(r.soft_type or 0)] or {}
                    valStr = tostring(r.soft_name or "?") .. (meta.ext or "") ..
                        " v" .. MH.Data.DotVersion(r.soft_version)
                    valNum = tonumber(r.soft_version) or 0
                else
                    valNum = tonumber(r.val) or 0
                    valStr = c.valueFmt(valNum)
                end
                local line = list:AddLine(tostring(rank), tostring(r.nick or "?"), valStr)
                line:SetSortValue(1, rank)
                line:SetSortValue(3, valNum)
            end
        end
    end
end

Tabs["Settings"] = function(container)
    clear(container)
    tab_header(container, "Settings", current_server())
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
        tab_header(container, "Admin", current_server())
        label(container, "You are not an administrator."):Dock(TOP)
        return
    end
    tab_header(container, "Admin", current_server())
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
        line:SetSortValue(3, tonumber(s.abuse_cmd_hits) or 0)
        line:SetSortValue(4, tonumber(s.abuse_mail_hits) or 0)
        line:SetSortValue(5, tonumber(s.total_cmds) or 0)
        line:SetSortValue(6, tonumber(s.total_mails_sent) or 0)
        line:SetSortValue(7, last)
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
        line:SetSortValue(3, tonumber(m.cnt) or 0)
        line:SetSortValue(4, last)
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

    label(container, "Set reputation", "DermaDefaultBold"):Dock(TOP)
    label(container, "Set a player's rep (exp). Enter SteamID64 and new rep value."):Dock(TOP)
    local repRow = vgui.Create("DPanel", container)
    repRow:Dock(TOP) repRow:SetTall(30) repRow:DockMargin(0, 4, 0, 0)
    local repSidEntry = vgui.Create("DTextEntry", repRow)
    repSidEntry:Dock(LEFT) repSidEntry:SetWide(220) repSidEntry:SetPlaceholderText("SteamID64")
    local repValEntry = vgui.Create("DTextEntry", repRow)
    repValEntry:Dock(LEFT) repValEntry:SetWide(120) repValEntry:DockMargin(6, 0, 0, 0)
    repValEntry:SetPlaceholderText("New rep")
    repValEntry:SetNumeric(true)
    local repSetB = button(repRow, "Set rep", function()
        local sid = string.Trim(tostring(repSidEntry:GetValue() or ""))
        local val = tonumber(repValEntry:GetValue())
        if sid == "" or not val then
            MH.OS.ShowNotify("warn", "Enter SteamID64 and a numeric rep")
            return
        end
        send_cmd("admin_set_rep", { sid64 = sid, rep = val })
    end)
    repSetB:Dock(LEFT) repSetB:SetWide(120) repSetB:DockMargin(6, 0, 0, 0)
end

surface.CreateFont("MH_Hackerman", {
    font = "Lucida Console", size = 14, weight = 500, antialias = true,
})

local HACKERMAN_GLYPHS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<>#$%&?!@*+="
local HACKERMAN_CHAR_W = 9
local HACKERMAN_CHAR_H = 14
local HACKERMAN_TRAIL = 12
local HACKERMAN_HEAD = Color(220, 190, 230)
local HACKERMAN_BODY = Color(159, 75, 163)
local HACKERMAN_SPARK = Color(255, 240, 170)
local HACKERMAN_SPARK_CORE = Color(255, 250, 210)
local HACKERMAN_WORDS = {
    "GOOSE", "PYTHON", "META", "HACK", "GARRY", "RAK", "DOOM",
    "ROOT", "SUDO", "BTC", "WIRE", "WAREZ", "VIRUS", "0DAY",
}
local HACKERMAN_LEET_SUB = { E = "3", A = "4", O = "0", I = "1", S = "5", T = "7" }
local HACKERMAN_LEET_CHANCE = 0.5
local HACKERMAN_WORD_CHANCE = 0.3
local HACKERMAN_CHAR_FLIP_CHANCE = 0.22

local function hackerman_rand_char()
    local n = #HACKERMAN_GLYPHS
    local i = math.random(1, n)
    return string.sub(HACKERMAN_GLYPHS, i, i)
end

local function hackerman_pick_word()
    local base = HACKERMAN_WORDS[math.random(1, #HACKERMAN_WORDS)]
    local out = {}
    for i = 1, #base do
        local c = string.sub(base, i, i)
        local sub = HACKERMAN_LEET_SUB[c]
        if sub and math.random() < HACKERMAN_LEET_CHANCE then
            out[i] = sub
        else
            out[i] = c
        end
    end
    return table.concat(out)
end

local function hackerman_maybe_apply_word(col)
    col.word_len = 0
    if math.random() > HACKERMAN_WORD_CHANCE then return end
    local word = hackerman_pick_word()
    local n = math.min(#word, HACKERMAN_TRAIL)
    for j = 1, n do
        col.chars[j] = string.sub(word, n - j + 1, n - j + 1)
    end
    col.word_len = n
end

local function attach_hackerman(panel)
    local cols = {}
    local last_time = SysTime()
    local last_w, last_h = 0, 0
    local function roll_char_lifecycle(col, j)
        col.char_life[j] = math.Rand(1.2, 3.0)
        col.char_age[j] = 0
    end
    local function reset_column(col, h)
        col.y = -math.random() * h * 0.5
        col.speed = 24 + math.random() * 48
        col.phase = math.random() * math.pi * 2
        col.shimmer_speed = 1.5 + math.random() * 3.5
        col.chars = col.chars or {}
        col.char_life = col.char_life or {}
        col.char_age = col.char_age or {}
        for j = 1, HACKERMAN_TRAIL do
            col.chars[j] = hackerman_rand_char()
            col.char_life[j] = math.Rand(1.2, 3.0)
            col.char_age[j] = math.Rand(0, col.char_life[j])
        end
        hackerman_maybe_apply_word(col)
    end
    local base_paint = panel.Paint
    panel.Paint = function(self, w, h)
        if base_paint then base_paint(self, w, h) end
        if w ~= last_w or h ~= last_h then
            cols = {}
            local n = math.max(1, math.floor(w / HACKERMAN_CHAR_W))
            for i = 1, n do
                cols[i] = {}
                reset_column(cols[i], h)
                cols[i].y = math.random() * h
            end
            last_w, last_h = w, h
        end
        local nowT = SysTime()
        local dt = math.min(0.1, nowT - last_time)
        last_time = nowT

        surface.SetFont("MH_Hackerman")
        for i, col in ipairs(cols) do
            col.y = col.y + col.speed * dt
            local x = (i - 1) * HACKERMAN_CHAR_W + 2
            if col.y > h + HACKERMAN_TRAIL * HACKERMAN_CHAR_H then
                reset_column(col, h)
            end
            if math.random() < HACKERMAN_CHAR_FLIP_CHANCE then
                local flips = math.random(1, 3)
                for _ = 1, flips do
                    local idx = math.random(1, HACKERMAN_TRAIL)
                    if idx > (col.word_len or 0) then
                        col.chars[idx] = hackerman_rand_char()
                    end
                end
            end
            for j = 1, HACKERMAN_TRAIL do
                local y = col.y - (j - 1) * HACKERMAN_CHAR_H
                if y >= 0 and y + HACKERMAN_CHAR_H <= h then
                    col.char_age[j] = col.char_age[j] + dt
                    local t = col.char_age[j] / col.char_life[j]
                    if t >= 1 then
                        if j > (col.word_len or 0) then
                            col.chars[j] = hackerman_rand_char()
                        end
                        roll_char_lifecycle(col, j)
                        t = 0
                    end
                    local fade = 1 - math.abs((t * 2) - 1)
                    local shimmer = 0.75 + 0.25 * math.sin(nowT * col.shimmer_speed + col.phase + j * 0.9)
                    local r, g, b, a
                    if j == 1 then
                        r, g, b = HACKERMAN_HEAD.r, HACKERMAN_HEAD.g, HACKERMAN_HEAD.b
                        a = math.floor(220 * shimmer * fade)
                    else
                        r, g, b = HACKERMAN_BODY.r, HACKERMAN_BODY.g, HACKERMAN_BODY.b
                        a = math.floor(180 * (1 - (j - 1) / HACKERMAN_TRAIL) * shimmer * fade)
                    end
                    if a > 0 then
                        surface.SetTextColor(r, g, b, a)
                        surface.SetTextPos(x, y)
                        surface.DrawText(col.chars[j])
                    end
                end
            end
        end

    end
end

local function build_frame()
    if IsValid(MH.OS.Frame) then MH.OS.Frame:Remove() end
    local f = vgui.Create("DFrame")
    f:SetSize(ScrW() * 0.8, ScrH() * 0.82)
    f:Center()
    f:SetTitle("MetaHacker")
    f:SetDeleteOnClose(true)
    f:MakePopup()
    f:SetSkin("mh_dark")
    MH.OS.Frame = f
    attach_hackerman(f)

    local body = vgui.Create("DPanel", f)
    body:Dock(FILL)
    body:DockMargin(4, 4, 4, 4)

    local sidebar = vgui.Create("DPanel", body)
    sidebar:Dock(LEFT)
    sidebar:SetWide(170)
    sidebar:DockMargin(0, 70, 0, 0)

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
        MH.OS.LastTab = name
        local fn = Tabs[name]
        if fn then fn(content) end
        restore_scroll(name)
    end

    local SIDEBAR_ICONS = {
        ["Home"]            = "icon16/house.png",
        ["Task Manager"]    = "icon16/chart_bar.png",
        ["Software"]        = "icon16/folder.png",
        ["Internet"]        = "icon16/world.png",
        ["Log File"]        = "icon16/book.png",
        ["Hardware"]        = "icon16/monitor.png",
        ["University"]      = "icon16/building.png",
        ["Finances"]        = "icon16/money.png",
        ["Hacked Database"] = "icon16/database.png",
        ["Missions"]        = "icon16/group.png",
        ["Mail"]            = "icon16/email.png",
        ["Ranking"]         = "icon16/award_star_gold_1.png",
        ["Settings"]        = "icon16/cog.png",
        ["Admin"]           = "icon16/user_red.png",
    }
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
        if SIDEBAR_ICONS[name] then
            local iconMat = Material(SIDEBAR_ICONS[name])
            b:SetContentAlignment(4)
            b:SetTextInset(28, 0)
            b.PaintOver = function(self, w, h)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(iconMat)
                surface.DrawTexturedRect(6, math.floor((h - 16) / 2), 16, 16)
            end
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

    MH.OS.Rebuild = function()
        local tab = MH.OS.ActiveTab or "Home"
        local fn = Tabs[tab]
        if fn then fn(content) end
        restore_scroll(tab)
    end

    local resumeTab = MH.OS.LastTab or "Home"
    if not Tabs[resumeTab] then resumeTab = "Home" end
    switch_tab(resumeTab)
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

net.Receive(N.MailCaptcha, function()
    local token = net.ReadString()
    local prompt = net.ReadString()
    local count = net.ReadUInt(8)
    local choices = {}
    for i = 1, count do choices[i] = net.ReadString() end
    local challenge = { token = token, prompt = prompt, choices = choices, choice = nil }
    if MH.OS.OnMailCaptcha then MH.OS.OnMailCaptcha(challenge) end
end)

net.Receive(N.PuzzleToken, function()
    local pid = net.ReadUInt(16)
    local token = net.ReadString()
    MH.OS.PuzzleTokens = MH.OS.PuzzleTokens or {}
    MH.OS.PuzzleTokens[pid] = token
end)

net.Receive(N.OpenOS, function()
    build_frame()
end)
