include("shared.lua")

local RT_SIZE = 512

surface.CreateFont("MH_Screen_Big", {
    font = "Roboto", size = 60, weight = 700, antialias = true,
})
surface.CreateFont("MH_Screen_Small", {
    font = "Roboto", size = 24, weight = 500, antialias = true,
})
surface.CreateFont("MH_Screen_Hackerman", {
    font = "Lucida Console", size = 15, weight = 500, antialias = true,
})

local HACKERMAN_GLYPHS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<>#$%&?!@*+="
local HACKERMAN_CHAR_W = 9
local HACKERMAN_CHAR_H = 15
local HACKERMAN_TRAIL = 14
local HACKERMAN_HEAD = Color(220, 190, 230)
local HACKERMAN_BODY = Color(159, 75, 163)
local HACKERMAN_WORDS = {
    "GOOSE", "PYTHON", "META", "HACK", "GARRY", "RAK", "DOOM",
    "ROOT", "SUDO", "BTC", "WIRE", "WAREZ", "VIRUS", "0DAY",
}
local HACKERMAN_LEET_SUB = { E = "3", A = "4", O = "0", I = "1", S = "5", T = "7" }
local HACKERMAN_LEET_CHANCE = 0.5
local HACKERMAN_WORD_CHANCE = 0.3
local HACKERMAN_CHAR_FLIP_CHANCE = 0.22

local COL_SCREEN_BG = Color(10, 10, 14)
local COL_SCREEN_FRAME = Color(159, 75, 163)
local COL_SCREEN_TEXT = Color(230, 236, 246)
local COL_SCREEN_PRIMARY = Color(159, 75, 163)

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

function ENT:MH_InitMatrix(w, h)
    local n = math.max(1, math.floor(w / HACKERMAN_CHAR_W))
    local list = {}
    for i = 1, n do
        list[i] = {}
        reset_column(list[i], h)
        list[i].y = math.random() * h
    end
    self.MH_Matrix = { cols = list, w = w, h = h, last = SysTime() }
end

function ENT:MH_DrawMatrix(w, h)
    if not self.MH_Matrix or self.MH_Matrix.w ~= w or self.MH_Matrix.h ~= h then
        self:MH_InitMatrix(w, h)
    end
    local m = self.MH_Matrix
    local nowT = SysTime()
    local dt = math.min(0.1, nowT - (m.last or nowT))
    m.last = nowT

    surface.SetFont("MH_Screen_Hackerman")
    for i, col in ipairs(m.cols) do
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

function ENT:MH_GetRT()
    if not self.MH_RT then
        local idx = self:EntIndex()
        self.MH_RT = GetRenderTarget("mh_server_rt_" .. idx, RT_SIZE, RT_SIZE)
        self.MH_RTMatName = "mh_server_rtmat_" .. idx
        self.MH_RTMat = CreateMaterial(self.MH_RTMatName, "UnlitGeneric", {
            ["$basetexture"] = "vgui/white",
            ["$model"] = 1,
            ["$nolod"] = 1,
            ["$ignorez"] = 0,
        })
        self.MH_RTMat:SetTexture("$basetexture", self.MH_RT)
    end
    return self.MH_RT, self.MH_RTMat
end

function ENT:MH_RenderToRT()
    local rt = self:MH_GetRT()
    render.PushRenderTarget(rt)
        render.OverrideAlphaWriteEnable(true, true)
        render.Clear(COL_SCREEN_BG.r, COL_SCREEN_BG.g, COL_SCREEN_BG.b, 255, true, true)
        cam.Start2D()
            self:MH_DrawMatrix(RT_SIZE, RT_SIZE)
            surface.SetDrawColor(COL_SCREEN_FRAME)
            surface.DrawOutlinedRect(0, 0, RT_SIZE, RT_SIZE)

            surface.SetFont("MH_Screen_Big")
            local tw, th = surface.GetTextSize("MetaHacker")
            local tx = RT_SIZE * 0.5 - tw * 0.5
            local ty = 90 - th * 0.5
            surface.SetTextColor(40, 40, 40, 255)
            for _, o in ipairs({ {-1, 0}, {1, 0}, {0, -1}, {0, 1} }) do
                surface.SetTextPos(tx + o[1], ty + o[2])
                surface.DrawText("MetaHacker")
            end
            surface.SetTextColor(COL_SCREEN_PRIMARY)
            surface.SetTextPos(tx, ty)
            surface.DrawText("MetaHacker")

            local cursorOn = (CurTime() % 1) < 0.5
            draw.SimpleText("root@mh:~# " .. (cursorOn and "_" or ""), "MH_Screen_Small",
                16, RT_SIZE - 36, COL_SCREEN_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        cam.End2D()
        render.OverrideAlphaWriteEnable(false)
    render.PopRenderTarget()
end

function ENT:MH_BindScreenMat()
    if not self.MH_ScreenSlots then
        local mats = self:GetMaterials()
        if not mats or #mats == 0 then return end
        local slots = {}
        for i, name in ipairs(mats) do
            local lname = string.lower(name or "")
            if string.find(lname, "screen") or string.find(lname, "display") then
                slots[#slots + 1] = i - 1
            end
        end
        if #slots == 0 then return end
        self.MH_ScreenSlots = slots
    end
    local _, mat = self:MH_GetRT()
    local ref = "!" .. mat:GetName()
    for _, slot in ipairs(self.MH_ScreenSlots) do
        if self:GetSubMaterial(slot) ~= ref then
            self:SetSubMaterial(slot, ref)
        end
    end
end

function ENT:Draw()
    self:MH_BindScreenMat()
    self:DrawModel()
end

hook.Add("PreDrawOpaqueRenderables", "mh_server_rt_render", function(depth, skybox)
    if depth or skybox then return end
    for _, ent in ipairs(ents.FindByClass("metahacker_server")) do
        if not IsValid(ent) or ent:IsDormant() then continue end
        if ent.MH_RenderToRT then ent:MH_RenderToRT() end
    end
end)

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
