include("shared.lua")

surface.CreateFont("MH_Screen_Big", {
    font = "Roboto", size = 28, weight = 700, antialias = true,
})
surface.CreateFont("MH_Screen_Small", {
    font = "Roboto", size = 14, weight = 500, antialias = true,
})
surface.CreateFont("MH_Screen_Matrix", {
    font = "Lucida Console", size = 12, weight = 500, antialias = true,
})

local MATRIX_GLYPHS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<>#$%&?!@*+="
local MATRIX_CHAR_W = 8
local MATRIX_CHAR_H = 12
local MATRIX_TRAIL = 10
local MATRIX_WORDS = { "GOOSE", "PYTHON", "META", "HACK", "GARRY" }
local MATRIX_WORD_CHANCE = 0.18
local MATRIX_LEET_SUB = { E = "3", A = "4", O = "0" }
local MATRIX_LEET_CHANCE = 0.5

local function matrix_pick_word()
    local base = MATRIX_WORDS[math.random(1, #MATRIX_WORDS)]
    local out = {}
    for i = 1, #base do
        local c = string.sub(base, i, i)
        local sub = MATRIX_LEET_SUB[c]
        if sub and math.random() < MATRIX_LEET_CHANCE then
            out[i] = sub
        else
            out[i] = c
        end
    end
    return table.concat(out)
end
local MATRIX_HEAD = Color(220, 190, 230)
local MATRIX_BODY = Color(159, 75, 163)
local function matrix_rand_char()
    local n = #MATRIX_GLYPHS
    local i = math.random(1, n)
    return string.sub(MATRIX_GLYPHS, i, i)
end

MH = MH or {}
MH.ServerScreen = MH.ServerScreen or {
    ox = 10.8271, oy = -9.02256, oz = 22.2556,
    ap = 0, ay = 90, ar = 81.203,
    scale = 0.12,
    w = 150, h = 124.286,
}
local SS = MH.ServerScreen
local COL_SCREEN_BG = Color(10, 10, 14)
local COL_SCREEN_FRAME = Color(159, 75, 163)
local COL_SCREEN_SCANLINE = Color(159, 75, 163, 40)
local COL_SCREEN_TEXT = Color(230, 236, 246)
local COL_SCREEN_DIM = Color(140, 140, 150)
local COL_SCREEN_PRIMARY = Color(159, 75, 163)

local function push_obb_clip(ent)
    local ang = ent:GetAngles()
    local xAxis = ang:Forward()
    local yAxis = ang:Right() * -1
    local zAxis = ang:Up()
    local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
    local pairs6 = {
        { axis = xAxis, lo = Vector(mins.x, 0, 0), hi = Vector(maxs.x, 0, 0) },
        { axis = yAxis, lo = Vector(0, mins.y, 0), hi = Vector(0, maxs.y, 0) },
        { axis = zAxis, lo = Vector(0, 0, mins.z), hi = Vector(0, 0, maxs.z) },
    }
    for _, p in ipairs(pairs6) do
        local loPt = ent:LocalToWorld(p.lo)
        local hiPt = ent:LocalToWorld(p.hi)
        render.PushCustomClipPlane(p.axis, p.axis:Dot(loPt))
        local nInv = -p.axis
        render.PushCustomClipPlane(nInv, nInv:Dot(hiPt))
    end
end

local function pop_obb_clip()
    for _ = 1, 6 do render.PopCustomClipPlane() end
end

local function matrix_maybe_apply_word(col)
    col.word_len = 0
    if math.random() > MATRIX_WORD_CHANCE then return end
    local word = matrix_pick_word()
    local n = math.min(#word, MATRIX_TRAIL)
    for j = 1, n do
        col.chars[j] = string.sub(word, n - j + 1, n - j + 1)
    end
    col.word_len = n
end

function ENT:MH_InitMatrix(w, h)
    local cols = math.max(1, math.floor(w / MATRIX_CHAR_W))
    local list = {}
    for i = 1, cols do
        list[i] = {
            y = math.random() * -h,
            speed = 20 + math.random() * 40,
            chars = {},
            word_len = 0,
        }
        for j = 1, MATRIX_TRAIL do list[i].chars[j] = matrix_rand_char() end
        matrix_maybe_apply_word(list[i])
    end
    self.MH_Matrix = { cols = list, w = w, h = h, last = CurTime() }
end

function ENT:MH_DrawMatrix(w, h)
    if not self.MH_Matrix or self.MH_Matrix.w ~= w or self.MH_Matrix.h ~= h then
        self:MH_InitMatrix(w, h)
    end
    local m = self.MH_Matrix
    local now = CurTime()
    local dt = math.min(0.1, now - (m.last or now))
    m.last = now

    surface.SetFont("MH_Screen_Matrix")
    for i, col in ipairs(m.cols) do
        col.y = col.y + col.speed * dt
        local x = (i - 1) * MATRIX_CHAR_W + 2
        local headY = col.y
        if headY > h + MATRIX_TRAIL * MATRIX_CHAR_H then
            col.y = -math.random() * h * 0.5
            col.speed = 20 + math.random() * 40
            for j = 1, MATRIX_TRAIL do col.chars[j] = matrix_rand_char() end
            matrix_maybe_apply_word(col)
        end
        if math.random() < 0.08 then
            local idx = math.random(1, MATRIX_TRAIL)
            if idx > (col.word_len or 0) then
                col.chars[idx] = matrix_rand_char()
            end
        end
        for j = 1, MATRIX_TRAIL do
            local y = headY - (j - 1) * MATRIX_CHAR_H
            if y >= 0 and y + MATRIX_CHAR_H <= h then
                local alpha
                local col_r, col_g, col_b
                if j == 1 then
                    col_r, col_g, col_b = MATRIX_HEAD.r, MATRIX_HEAD.g, MATRIX_HEAD.b
                    alpha = 255
                else
                    col_r, col_g, col_b = MATRIX_BODY.r, MATRIX_BODY.g, MATRIX_BODY.b
                    alpha = math.max(20, 220 - (j - 1) * 22)
                end
                surface.SetTextColor(col_r, col_g, col_b, alpha)
                surface.SetTextPos(x, y)
                surface.DrawText(col.chars[j])
            end
        end
    end
end

function ENT:Draw()
    self:DrawModel()

    local s = MH.ServerScreen or {}
    local pos = self:LocalToWorld(Vector(
        tonumber(s.ox) or 0,
        tonumber(s.oy) or 0,
        tonumber(s.oz) or 0))
    local ang = self:LocalToWorldAngles(Angle(
        tonumber(s.ap) or 0,
        tonumber(s.ay) or 0,
        tonumber(s.ar) or 0))
    local w = tonumber(s.w) or 150
    local h = tonumber(s.h) or 124.286
    local scale = tonumber(s.scale) or 0.12

    cam.Start3D2D(pos, ang, scale)
        surface.SetDrawColor(COL_SCREEN_BG)
        surface.DrawRect(0, 0, w, h)

        self:MH_DrawMatrix(w, h)

        surface.SetDrawColor(COL_SCREEN_FRAME)
        surface.DrawOutlinedRect(0, 0, w, h)

        do
            surface.SetFont("MH_Screen_Big")
            local tw, th = surface.GetTextSize("MetaHacker")
            local tx = w * 0.5 - tw * 0.5
            local ty = 32 - th * 0.5
            surface.SetTextColor(40, 40, 40, 255)
            for _, o in ipairs({ {-0.5, 0}, {0.5, 0}, {0, -0.5}, {0, 0.5} }) do
                surface.SetTextPos(tx + o[1], ty + o[2])
                surface.DrawText("MetaHacker")
            end
            surface.SetTextColor(COL_SCREEN_PRIMARY)
            surface.SetTextPos(tx, ty)
            surface.DrawText("MetaHacker")
        end

        local cursorOn = (CurTime() % 1) < 0.5
        local prompt = "root@mh:~# " .. (cursorOn and "_" or "")
        draw.SimpleText(prompt, "MH_Screen_Small",
            8, h - 18, COL_SCREEN_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end

local HOVER_RANGE_SQR = 100 * 100
local COL_HINT_BG = Color(23, 23, 23, 220)
local COL_HINT_LINE = Color(159, 75, 163, 230)
local COL_HINT_TEXT = Color(254, 254, 254)

hook.Add("HUDPaint", "mh_server_hover_prompt", function()
    local lp = LocalPlayer()
    if not IsValid(lp) or not lp:Alive() then return end
    local tr = lp:GetEyeTrace()
    if not tr.Hit then return end
    local ent = tr.Entity
    if not IsValid(ent) or ent:GetClass() ~= "metahacker_server" then return end
    if lp:EyePos():DistToSqr(ent:GetPos()) > HOVER_RANGE_SQR then return end

    local useKey = string.upper(input.LookupBinding("+use") or "E")
    local text = "Press " .. useKey .. " to access MetaHacker"
    surface.SetFont("DermaDefaultBold")
    local tw, th = surface.GetTextSize(text)
    local w, h = tw + 24, th + 16
    local x = ScrW() * 0.5 - w * 0.5
    local y = ScrH() * 0.5 + 40
    surface.SetDrawColor(COL_HINT_BG)
    surface.DrawRect(x, y, w, h)
    surface.SetDrawColor(COL_HINT_LINE)
    surface.DrawOutlinedRect(x, y, w, h)
    draw.SimpleText(text, "DermaDefaultBold", x + w * 0.5, y + h * 0.5, COL_HINT_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
