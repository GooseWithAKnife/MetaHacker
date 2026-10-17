-- mh_dark: Metahacker's own derma skin.
-- Copies the metastruct dark_meta palette and paint functions, with the
-- borders/outlines bumped a notch brighter so tables and inputs read better
-- against the translucent panel tints that are shared across the OS.

local surface = _G.surface

local box_color = Color(20, 20, 20, 200)
local box_sleep_color = Color(20, 20, 20, 160)
local field_color = Color(15, 15, 15, 215)
local box_solid_color = Color(23, 23, 23)
local field_solid_color = Color(17, 17, 17)
local border_color = Color(10, 10, 10)
local primary_color = Color(159, 75, 163)
local primary_dark_color = Color(125, 59, 128)
local accent_bright_color = Color(12, 227, 172)
local danger_color = Color(241, 70, 104)
local text_color = Color(254, 254, 254)
local text_muted_color = Color(150, 150, 150)
local grip_color = Color(70, 70, 70)
local grip_faint_color = Color(70, 70, 70, 120)
local hover_color = Color(42, 42, 42)
local row_color = Color(28, 28, 28)
local row_alt_color = Color(23, 23, 23)
local selection_color = Color(90, 44, 92)
local accent_border_color = Color(159, 75, 163, 140)

local blur_mat = Material("pp/blurscreen")
local blur_frame = -1
local function draw_blur(panel, amount)
    local x, y = panel:LocalToScreen(0, 0)
    local frame = FrameNumber()
    if blur_frame ~= frame then
        blur_frame = frame
        render.UpdateScreenEffectTexture()
    end
    surface.SetMaterial(blur_mat)
    for i = 1, 3 do
        blur_mat:SetFloat("$blur", (i / 3) * amount)
        blur_mat:Recompute()
        surface.SetDrawColor(255, 255, 255, i == 1 and 255 or 128)
        surface.DrawTexturedRect(-x, -y, ScrW(), ScrH())
    end
end

local function draw_check(cx, cy, size, col)
    surface.SetDrawColor(col)
    for i = 0, 1 do
        surface.DrawLine(cx - size, cy + i, cx - size / 3, cy + size * 0.66 + i)
        surface.DrawLine(cx - size / 3, cy + size * 0.66 + i, cx + size, cy - size * 0.66 + i)
    end
end

local function draw_triangle(cx, cy, size, dir, col)
    draw.NoTexture()
    surface.SetDrawColor(col)
    if dir == "down" then
        surface.DrawPoly({
            { x = cx - size, y = cy - size / 2 },
            { x = cx + size, y = cy - size / 2 },
            { x = cx, y = cy + size / 2 },
        })
    elseif dir == "up" then
        surface.DrawPoly({
            { x = cx, y = cy - size / 2 },
            { x = cx + size, y = cy + size / 2 },
            { x = cx - size, y = cy + size / 2 },
        })
    elseif dir == "right" then
        surface.DrawPoly({
            { x = cx - size / 2, y = cy - size },
            { x = cx + size / 2, y = cy },
            { x = cx - size / 2, y = cy + size },
        })
    else
        surface.DrawPoly({
            { x = cx + size / 2, y = cy - size },
            { x = cx + size / 2, y = cy + size },
            { x = cx - size / 2, y = cy },
        })
    end
end

SKIN = {}

SKIN.PrintName = "Metahacker Dark"
SKIN.Author = "Metahacker"
SKIN.DermaVersion = 1

local tex = Material("gwenskin/meta6.png")
if not tex or tex:IsError() then
    tex = Material("gwenskin/gmoddefault.png")
end
SKIN.GwenTexture = tex

SKIN.bg_color = box_solid_color
SKIN.bg_color_sleep = Color(17, 17, 17, 255)
SKIN.bg_color_dark = Color(15, 15, 15, 255)
SKIN.bg_color_bright = Color(42, 42, 42, 255)

SKIN.fontFrame = "DermaDefault"

SKIN.control_color = box_solid_color
SKIN.control_color_highlight = hover_color
SKIN.control_color_active = primary_color
SKIN.control_color_bright = accent_bright_color
SKIN.control_color_dark = field_solid_color

SKIN.bg_alt1 = row_color
SKIN.bg_alt2 = row_alt_color

SKIN.listview_hover = hover_color
SKIN.listview_selected = selection_color

SKIN.text_bright = text_color
SKIN.text_normal = text_color
SKIN.text_dark = text_color
SKIN.text_highlight = primary_color

SKIN.texGradientUp = Material("gui/gradient_up")
SKIN.texGradientDown = Material("gui/gradient_down")

SKIN.combobox_selected = SKIN.listview_selected

SKIN.panel_transback = Color(255, 255, 255, 20)
SKIN.tooltip = text_color

SKIN.colPropertySheet = box_solid_color
SKIN.colTab = SKIN.colPropertySheet
SKIN.colTabInactive = field_solid_color
SKIN.colTabShadow = Color(0, 0, 0, 170)
SKIN.colTabText = text_color
SKIN.colTabTextInactive = text_muted_color
SKIN.fontTab = "DermaDefault"

SKIN.colCollapsibleCategory = Color(255, 255, 255, 10)

SKIN.colCategoryText = text_color
SKIN.colCategoryTextInactive = text_muted_color
SKIN.fontCategoryHeader = "TabLarge"

SKIN.colNumberWangBG = field_solid_color
SKIN.colTextEntryBG = field_solid_color
SKIN.colTextEntryBorder = border_color
SKIN.colTextEntryText = text_color
SKIN.colTextEntryTextPlaceholder = text_muted_color
SKIN.colTextEntryTextHighlight = primary_dark_color
SKIN.colTextEntryTextCursor = primary_color

SKIN.colMenuBG = box_solid_color
SKIN.colMenuBorder = border_color

SKIN.colButtonText = text_color
SKIN.colButtonTextDisabled = text_muted_color
SKIN.colButtonBorder = grip_color
SKIN.colButtonBorderHighlight = Color(255, 255, 255, 30)
SKIN.colButtonBorderShadow = Color(0, 0, 0, 100)

SKIN.frame_border = border_color

SKIN.tex = {}

SKIN.tex.Selection = GWEN.CreateTextureBorder(384, 32, 31, 31, 4, 4, 4, 4)

SKIN.tex.Panels = {}
SKIN.tex.Panels.Normal = GWEN.CreateTextureBorder(256, 0, 63, 63, 16, 16, 16, 16)
SKIN.tex.Panels.Bright = GWEN.CreateTextureBorder(256 + 64, 0, 63, 63, 16, 16, 16, 16)
SKIN.tex.Panels.Dark = GWEN.CreateTextureBorder(256, 64, 63, 63, 16, 16, 16, 16)
SKIN.tex.Panels.Highlight = GWEN.CreateTextureBorder(256 + 64, 64, 63, 63, 16, 16, 16, 16)

SKIN.tex.Button = GWEN.CreateTextureBorder(480, 0, 31, 31, 8, 8, 8, 8)
SKIN.tex.Button_Hovered = GWEN.CreateTextureBorder(480, 32, 31, 31, 8, 8, 8, 8)
SKIN.tex.Button_Dead = GWEN.CreateTextureBorder(480, 64, 31, 31, 8, 8, 8, 8)
SKIN.tex.Button_Down = GWEN.CreateTextureBorder(480, 96, 31, 31, 8, 8, 8, 8)
SKIN.tex.Shadow = GWEN.CreateTextureBorder(448, 0, 31, 31, 8, 8, 8, 8)

SKIN.tex.Tree = GWEN.CreateTextureBorder(256, 128, 127, 127, 16, 16, 16, 16)
SKIN.tex.Checkbox_Checked = GWEN.CreateTextureNormal(448, 32, 15, 15)
SKIN.tex.Checkbox = GWEN.CreateTextureNormal(464, 32, 15, 15)
SKIN.tex.CheckboxD_Checked = GWEN.CreateTextureNormal(448, 48, 15, 15)
SKIN.tex.CheckboxD = GWEN.CreateTextureNormal(464, 48, 15, 15)
SKIN.tex.TreePlus = GWEN.CreateTextureNormal(448, 96, 15, 15)
SKIN.tex.TreeMinus = GWEN.CreateTextureNormal(464, 96, 15, 15)
SKIN.tex.TextBox = GWEN.CreateTextureBorder(0, 150, 127, 21, 4, 4, 4, 4)
SKIN.tex.TextBox_Focus = GWEN.CreateTextureBorder(0, 172, 127, 21, 4, 4, 4, 4)
SKIN.tex.TextBox_Disabled = GWEN.CreateTextureBorder(0, 194, 127, 21, 4, 4, 4, 4)
SKIN.tex.MenuBG_Column = GWEN.CreateTextureBorder(128, 128, 127, 63, 24, 8, 8, 8)
SKIN.tex.MenuBG = GWEN.CreateTextureBorder(128, 192, 127, 63, 8, 8, 8, 8)
SKIN.tex.MenuBG_Hover = GWEN.CreateTextureBorder(128, 256, 127, 31, 8, 8, 8, 8)
SKIN.tex.MenuBG_Spacer = GWEN.CreateTextureNormal(128, 288, 127, 3)
SKIN.tex.Menu_Strip = GWEN.CreateTextureBorder(0, 128, 127, 21, 8, 8, 8, 8)
SKIN.tex.Menu_Check = GWEN.CreateTextureNormal(448, 112, 15, 15)
SKIN.tex.Tab_Control = GWEN.CreateTextureBorder(0, 256, 127, 127, 8, 8, 8, 8)
SKIN.tex.TabB_Active = GWEN.CreateTextureBorder(0, 416, 63, 31, 8, 8, 8, 8)
SKIN.tex.TabB_Inactive = GWEN.CreateTextureBorder(0 + 128, 416, 63, 31, 8, 8, 8, 8)
SKIN.tex.TabT_Active = GWEN.CreateTextureBorder(0, 384, 63, 31, 8, 8, 8, 8)
SKIN.tex.TabT_Inactive = GWEN.CreateTextureBorder(0 + 128, 384, 63, 31, 8, 8, 8, 8)
SKIN.tex.TabL_Active = GWEN.CreateTextureBorder(64, 384, 31, 63, 8, 8, 8, 8)
SKIN.tex.TabL_Inactive = GWEN.CreateTextureBorder(64 + 128, 384, 31, 63, 8, 8, 8, 8)
SKIN.tex.TabR_Active = GWEN.CreateTextureBorder(96, 384, 31, 63, 8, 8, 8, 8)
SKIN.tex.TabR_Inactive = GWEN.CreateTextureBorder(96 + 128, 384, 31, 63, 8, 8, 8, 8)
SKIN.tex.Tab_Bar = GWEN.CreateTextureBorder(128, 352, 127, 31, 4, 4, 4, 4)

SKIN.tex.Window = {}
SKIN.tex.Window.Normal = GWEN.CreateTextureBorder(0, 0, 127, 127, 8, 32, 8, 8)
SKIN.tex.Window.Inactive = GWEN.CreateTextureBorder(128, 0, 127, 127, 8, 32, 8, 8)
SKIN.tex.Window.Close = GWEN.CreateTextureNormal(32, 448, 31, 31)
SKIN.tex.Window.Close_Hover = GWEN.CreateTextureNormal(64, 448, 31, 31)
SKIN.tex.Window.Close_Down = GWEN.CreateTextureNormal(96, 448, 31, 31)
SKIN.tex.Window.Maxi = GWEN.CreateTextureNormal(32 + 96 * 2, 448, 31, 31)
SKIN.tex.Window.Maxi_Hover = GWEN.CreateTextureNormal(64 + 96 * 2, 448, 31, 31)
SKIN.tex.Window.Maxi_Down = GWEN.CreateTextureNormal(96 + 96 * 2, 448, 31, 31)
SKIN.tex.Window.Restore = GWEN.CreateTextureNormal(32 + 96 * 2, 448 + 32, 31, 31)
SKIN.tex.Window.Restore_Hover = GWEN.CreateTextureNormal(64 + 96 * 2, 448 + 32, 31, 31)
SKIN.tex.Window.Restore_Down = GWEN.CreateTextureNormal(96 + 96 * 2, 448 + 32, 31, 31)
SKIN.tex.Window.Mini = GWEN.CreateTextureNormal(32 + 96, 448, 31, 31)
SKIN.tex.Window.Mini_Hover = GWEN.CreateTextureNormal(64 + 96, 448, 31, 31)
SKIN.tex.Window.Mini_Down = GWEN.CreateTextureNormal(96 + 96, 448, 31, 31)

SKIN.tex.Scroller = {}
SKIN.tex.Scroller.TrackV = GWEN.CreateTextureBorder(384, 208, 15, 127, 4, 4, 4, 4)
SKIN.tex.Scroller.ButtonV_Normal = GWEN.CreateTextureBorder(384 + 16, 208, 15, 127, 4, 4, 4, 4)
SKIN.tex.Scroller.ButtonV_Hover = GWEN.CreateTextureBorder(384 + 32, 208, 15, 127, 4, 4, 4, 4)
SKIN.tex.Scroller.ButtonV_Down = GWEN.CreateTextureBorder(384 + 48, 208, 15, 127, 4, 4, 4, 4)
SKIN.tex.Scroller.ButtonV_Disabled = GWEN.CreateTextureBorder(384 + 64, 208, 15, 127, 4, 4, 4, 4)
SKIN.tex.Scroller.TrackH = GWEN.CreateTextureBorder(384, 128, 127, 15, 4, 4, 4, 4)
SKIN.tex.Scroller.ButtonH_Normal = GWEN.CreateTextureBorder(384, 128 + 16, 127, 15, 4, 4, 4, 4)
SKIN.tex.Scroller.ButtonH_Hover = GWEN.CreateTextureBorder(384, 128 + 32, 127, 15, 4, 4, 4, 4)
SKIN.tex.Scroller.ButtonH_Down = GWEN.CreateTextureBorder(384, 128 + 48, 127, 15, 4, 4, 4, 4)
SKIN.tex.Scroller.ButtonH_Disabled = GWEN.CreateTextureBorder(384, 128 + 64, 127, 15, 4, 4, 4, 4)
SKIN.tex.Scroller.LeftButton_Normal = GWEN.CreateTextureBorder(464, 208, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.LeftButton_Hover = GWEN.CreateTextureBorder(480, 208, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.LeftButton_Down = GWEN.CreateTextureBorder(464, 272, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.LeftButton_Disabled = GWEN.CreateTextureBorder(480 + 48, 272, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.UpButton_Normal = GWEN.CreateTextureBorder(464, 208 + 16, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.UpButton_Hover = GWEN.CreateTextureBorder(480, 208 + 16, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.UpButton_Down = GWEN.CreateTextureBorder(464, 272 + 16, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.UpButton_Disabled = GWEN.CreateTextureBorder(480 + 48, 272 + 16, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.RightButton_Normal = GWEN.CreateTextureBorder(464, 208 + 32, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.RightButton_Hover = GWEN.CreateTextureBorder(480, 208 + 32, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.RightButton_Down = GWEN.CreateTextureBorder(464, 272 + 32, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.RightButton_Disabled = GWEN.CreateTextureBorder(480 + 48, 272 + 32, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.DownButton_Normal = GWEN.CreateTextureBorder(464, 208 + 48, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.DownButton_Hover = GWEN.CreateTextureBorder(480, 208 + 48, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.DownButton_Down = GWEN.CreateTextureBorder(464, 272 + 48, 15, 15, 2, 2, 2, 2)
SKIN.tex.Scroller.DownButton_Disabled = GWEN.CreateTextureBorder(480 + 48, 272 + 48, 15, 15, 2, 2, 2, 2)

SKIN.tex.Menu = {}
SKIN.tex.Menu.RightArrow = GWEN.CreateTextureNormal(464, 112, 15, 15)

SKIN.tex.Input = {}
SKIN.tex.Input.ComboBox = {}
SKIN.tex.Input.ComboBox.Normal = GWEN.CreateTextureBorder(384, 336, 127, 31, 8, 8, 32, 8)
SKIN.tex.Input.ComboBox.Hover = GWEN.CreateTextureBorder(384, 336 + 32, 127, 31, 8, 8, 32, 8)
SKIN.tex.Input.ComboBox.Down = GWEN.CreateTextureBorder(384, 336 + 64, 127, 31, 8, 8, 32, 8)
SKIN.tex.Input.ComboBox.Disabled = GWEN.CreateTextureBorder(384, 336 + 96, 127, 31, 8, 8, 32, 8)
SKIN.tex.Input.ComboBox.Button = {}
SKIN.tex.Input.ComboBox.Button.Normal = GWEN.CreateTextureNormal(496, 272, 15, 15)
SKIN.tex.Input.ComboBox.Button.Hover = GWEN.CreateTextureNormal(496, 272 + 16, 15, 15)
SKIN.tex.Input.ComboBox.Button.Down = GWEN.CreateTextureNormal(496, 272 + 32, 15, 15)
SKIN.tex.Input.ComboBox.Button.Disabled = GWEN.CreateTextureNormal(496, 272 + 48, 15, 15)

SKIN.tex.Input.UpDown = {}
SKIN.tex.Input.UpDown.Up = {}
SKIN.tex.Input.UpDown.Up.Normal = GWEN.CreateTextureCentered(384, 112, 7, 7)
SKIN.tex.Input.UpDown.Up.Hover = GWEN.CreateTextureCentered(384 + 8, 112, 7, 7)
SKIN.tex.Input.UpDown.Up.Down = GWEN.CreateTextureCentered(384 + 16, 112, 7, 7)
SKIN.tex.Input.UpDown.Up.Disabled = GWEN.CreateTextureCentered(384 + 24, 112, 7, 7)
SKIN.tex.Input.UpDown.Down = {}
SKIN.tex.Input.UpDown.Down.Normal = GWEN.CreateTextureCentered(384, 120, 7, 7)
SKIN.tex.Input.UpDown.Down.Hover = GWEN.CreateTextureCentered(384 + 8, 120, 7, 7)
SKIN.tex.Input.UpDown.Down.Down = GWEN.CreateTextureCentered(384 + 16, 120, 7, 7)
SKIN.tex.Input.UpDown.Down.Disabled = GWEN.CreateTextureCentered(384 + 24, 120, 7, 7)

SKIN.tex.Input.Slider = {}
SKIN.tex.Input.Slider.H = {}
SKIN.tex.Input.Slider.H.Normal = GWEN.CreateTextureNormal(416, 32, 15, 15)
SKIN.tex.Input.Slider.H.Hover = GWEN.CreateTextureNormal(416, 32 + 16, 15, 15)
SKIN.tex.Input.Slider.H.Down = GWEN.CreateTextureNormal(416, 32 + 32, 15, 15)
SKIN.tex.Input.Slider.H.Disabled = GWEN.CreateTextureNormal(416, 32 + 48, 15, 15)
SKIN.tex.Input.Slider.V = {}
SKIN.tex.Input.Slider.V.Normal = GWEN.CreateTextureNormal(416 + 16, 32, 15, 15)
SKIN.tex.Input.Slider.V.Hover = GWEN.CreateTextureNormal(416 + 16, 32 + 16, 15, 15)
SKIN.tex.Input.Slider.V.Down = GWEN.CreateTextureNormal(416 + 16, 32 + 32, 15, 15)
SKIN.tex.Input.Slider.V.Disabled = GWEN.CreateTextureNormal(416 + 16, 32 + 48, 15, 15)

SKIN.tex.Input.ListBox = {}
SKIN.tex.Input.ListBox.Background = GWEN.CreateTextureBorder(256, 256, 63, 127, 8, 8, 8, 8)
SKIN.tex.Input.ListBox.Hovered = GWEN.CreateTextureBorder(320, 320, 31, 31, 8, 8, 8, 8)
SKIN.tex.Input.ListBox.EvenLine = GWEN.CreateTextureBorder(352, 256, 31, 31, 8, 8, 8, 8)
SKIN.tex.Input.ListBox.OddLine = GWEN.CreateTextureBorder(352, 288, 31, 31, 8, 8, 8, 8)
SKIN.tex.Input.ListBox.EvenLineSelected = GWEN.CreateTextureBorder(320, 270, 31, 31, 8, 8, 8, 8)
SKIN.tex.Input.ListBox.OddLineSelected = GWEN.CreateTextureBorder(320, 288, 31, 31, 8, 8, 8, 8)

SKIN.tex.ProgressBar = {}
SKIN.tex.ProgressBar.Back = GWEN.CreateTextureBorder(384, 0, 31, 31, 8, 8, 8, 8)
SKIN.tex.ProgressBar.Front = GWEN.CreateTextureBorder(384 + 32, 0, 31, 31, 8, 8, 8, 8)

SKIN.tex.CategoryList = {}
SKIN.tex.CategoryList.Outer = GWEN.CreateTextureBorder(256, 384, 63, 63, 8, 8, 8, 8)
SKIN.tex.CategoryList.Inner = GWEN.CreateTextureBorder(256 + 64, 384, 63, 63, 8, 21, 8, 8)
SKIN.tex.CategoryList.Header = GWEN.CreateTextureBorder(320, 352, 63, 31, 8, 8, 8, 8)

SKIN.tex.Tooltip = GWEN.CreateTextureBorder(384, 64, 31, 31, 8, 8, 8, 8)

SKIN.Colours = {}

SKIN.Colours.Window = {}
SKIN.Colours.Window.TitleActive = text_color
SKIN.Colours.Window.TitleInactive = text_muted_color

SKIN.Colours.Button = {}
SKIN.Colours.Button.Normal = text_color
SKIN.Colours.Button.Hover = text_color
SKIN.Colours.Button.Down = text_color
SKIN.Colours.Button.Disabled = text_muted_color

SKIN.Colours.Tab = {}
SKIN.Colours.Tab.Active = {}
SKIN.Colours.Tab.Active.Normal = text_color
SKIN.Colours.Tab.Active.Hover = text_color
SKIN.Colours.Tab.Active.Down = text_color
SKIN.Colours.Tab.Active.Disabled = text_muted_color
SKIN.Colours.Tab.Inactive = {}
SKIN.Colours.Tab.Inactive.Normal = text_muted_color
SKIN.Colours.Tab.Inactive.Hover = text_color
SKIN.Colours.Tab.Inactive.Down = text_color
SKIN.Colours.Tab.Inactive.Disabled = text_muted_color

SKIN.Colours.Label = {}
SKIN.Colours.Label.Default = text_color
SKIN.Colours.Label.Bright = text_color
SKIN.Colours.Label.Dark = text_color
SKIN.Colours.Label.Highlight = primary_color

SKIN.Colours.Tree = {}
SKIN.Colours.Tree.Lines = grip_color
SKIN.Colours.Tree.Normal = text_color
SKIN.Colours.Tree.Hover = text_color
SKIN.Colours.Tree.Selected = text_color

SKIN.Colours.Properties = {}
SKIN.Colours.Properties.Line_Normal = text_color
SKIN.Colours.Properties.Line_Selected = text_color
SKIN.Colours.Properties.Line_Hover = text_color
SKIN.Colours.Properties.Title = text_color
SKIN.Colours.Properties.Column_Normal = text_color
SKIN.Colours.Properties.Column_Selected = text_color
SKIN.Colours.Properties.Column_Hover = text_color
SKIN.Colours.Properties.Column_Disabled = Color(0, 0, 0, 100)
SKIN.Colours.Properties.Border = border_color
SKIN.Colours.Properties.Label_Normal = text_color
SKIN.Colours.Properties.Label_Selected = text_color
SKIN.Colours.Properties.Label_Hover = text_color
SKIN.Colours.Properties.Label_Disabled = text_muted_color

SKIN.Colours.Category = {}
SKIN.Colours.Category.Header = text_color
SKIN.Colours.Category.Header_Closed = text_color
SKIN.Colours.Category.Line = {}
SKIN.Colours.Category.Line.Text = text_color
SKIN.Colours.Category.Line.Text_Hover = text_color
SKIN.Colours.Category.Line.Text_Selected = text_color
SKIN.Colours.Category.Line.Button = text_color
SKIN.Colours.Category.Line.Button_Hover = text_color
SKIN.Colours.Category.Line.Button_Selected = text_color
SKIN.Colours.Category.LineAlt = {}
SKIN.Colours.Category.LineAlt.Text = text_color
SKIN.Colours.Category.LineAlt.Text_Hover = text_color
SKIN.Colours.Category.LineAlt.Text_Selected = text_color
SKIN.Colours.Category.LineAlt.Button = text_color
SKIN.Colours.Category.LineAlt.Button_Hover = text_color
SKIN.Colours.Category.LineAlt.Button_Selected = text_color

SKIN.Colours.TooltipText = text_color

local function paint_panel(_, panel, w, h)
    if not panel.m_bBackground then return end
    surface.SetDrawColor(20, 20, 20, 150)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(accent_border_color)
    surface.DrawOutlinedRect(0, 0, w, h)
end
SKIN.PaintPanel = paint_panel

function SKIN:PaintTree(panel, w, h)
    if not panel.m_bBackground then return end
    surface.SetDrawColor(0, 0, 0, 100)
    surface.DrawRect(0, 0, w, h)
end

function SKIN:PaintShadow(panel, w, h)
    SKIN.tex.Shadow(0, 0, w, h)
end

function SKIN:PaintFrame(panel, w, h)
    if panel.m_bPaintShadow then
        DisableClipping(true)
        SKIN.tex.Shadow(-4, -4, w + 10, h + 10)
        DisableClipping(false)
    end
    draw_blur(panel, 8)
    surface.SetDrawColor(panel:HasHierarchicalFocus() and box_color or box_sleep_color)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(field_color)
    surface.DrawRect(0, 0, w, 24)
    surface.SetDrawColor(primary_color)
    surface.DrawRect(0, 23, w, 1)
end

function SKIN:PaintButton(panel, w, h)
    if not panel.m_bBackground then return end
    if panel:GetDisabled() then
        surface.SetDrawColor(field_solid_color)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(accent_border_color)
        surface.DrawOutlinedRect(0, 0, w, h)
        return
    end
    if panel:IsSelected() or panel:GetToggle() or panel.Depressed then
        surface.SetDrawColor(primary_dark_color)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(accent_border_color)
        surface.DrawOutlinedRect(0, 0, w, h)
        return
    end
    if panel.Hovered then
        surface.SetDrawColor(primary_color)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(accent_border_color)
        surface.DrawOutlinedRect(0, 0, w, h)
        return
    end
    surface.SetDrawColor(box_solid_color)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(accent_border_color)
    surface.DrawOutlinedRect(0, 0, w, h)
end

function SKIN:PaintCheckBox(panel, w, h)
    surface.SetDrawColor(border_color)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(field_solid_color)
    surface.DrawRect(1, 1, w - 2, h - 2)
    if panel:GetChecked() then
        draw_check(w / 2, h / 2, math.max(3, math.floor(w / 4)), accent_bright_color)
    end
    if panel:GetDisabled() then
        surface.SetDrawColor(grip_faint_color)
        surface.DrawRect(1, 1, w - 2, h - 2)
    end
end

function SKIN:PaintExpandButton(panel, w, h)
    surface.SetDrawColor(field_solid_color)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(grip_color)
    surface.DrawOutlinedRect(0, 0, w, h)
    surface.SetDrawColor(panel.Hovered and text_color or text_muted_color)
    surface.DrawRect(3, h / 2, w - 6, 1)
    if not panel:GetExpanded() then
        surface.DrawRect(w / 2, 3, 1, h - 6)
    end
end

function SKIN:PaintTextEntry(panel, w, h)
    if panel.m_bBackground then
        surface.SetDrawColor(border_color)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(field_solid_color)
        surface.DrawRect(1, 1, w - 2, h - 2)
        if panel:HasFocus() then
            surface.SetDrawColor(primary_color)
        else
            surface.SetDrawColor(accent_border_color)
        end
        surface.DrawOutlinedRect(0, 0, w, h)
    end
    local placeholder = panel.GetPlaceholderText and panel:GetPlaceholderText()
    if placeholder and placeholder:Trim() ~= "" and (not panel:GetText() or panel:GetText() == "") then
        local old_text = panel:GetText()
        if placeholder:sub(1, 1) == "#" then placeholder = placeholder:sub(2) end
        placeholder = language.GetPhrase(placeholder)
        panel:SetText(placeholder)
        panel:DrawTextEntryText(panel:GetPlaceholderColor(), panel:GetHighlightColor(), panel:GetCursorColor())
        panel:SetText(old_text)
        return
    end
    panel:DrawTextEntryText(panel:GetTextColor(), panel:GetHighlightColor(), panel:GetCursorColor())
end

function SKIN:PaintMenu(panel, w, h)
    surface.SetDrawColor(border_color)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(box_solid_color)
    surface.DrawRect(1, 1, w - 2, h - 2)
end

function SKIN:PaintMenuSpacer(panel, w, h)
    surface.SetDrawColor(box_solid_color)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(grip_color)
    surface.DrawRect(4, h / 2, w - 8, 1)
end

function SKIN:PaintMenuOption(panel, w, h)
    if panel.m_bBackground and (panel.Hovered or panel.Highlight) then
        surface.SetDrawColor(primary_color)
        surface.DrawRect(0, 0, w, h)
    end
    if panel:GetChecked() then
        draw_check(12, h / 2 - 1, 4, accent_bright_color)
    end
end

function SKIN:PaintMenuRightArrow(panel, w, h)
    draw_triangle(w / 2, h / 2, 3, "right", text_muted_color)
end

function SKIN:PaintMenuBar(panel, w, h)
    surface.SetDrawColor(field_solid_color)
    surface.DrawRect(0, 0, w, h)
end

function SKIN:PaintPropertySheet(panel, w, h)
    local ActiveTab = panel:GetActiveTab()
    local Offset = 0
    if ActiveTab then
        Offset = ActiveTab:GetTall() - 8
    end
    draw_blur(panel, 8)
    if Offset > 0 then
        surface.SetDrawColor(field_color)
        surface.DrawRect(0, 0, w, Offset)
    end
    surface.SetDrawColor(box_color)
    surface.DrawRect(0, Offset, w, h - Offset)
end

function SKIN:PaintTab(panel, w, h)
    if panel:GetPropertySheet():GetActiveTab() == panel then
        return self:PaintActiveTab(panel, w, h)
    end
    if panel.Hovered then
        surface.SetDrawColor(hover_color)
    else
        surface.SetDrawColor(15, 15, 15, 200)
    end
    surface.DrawRect(0, 0, w - 5, h)
end

function SKIN:PaintActiveTab(panel, w, h)
    surface.SetDrawColor(23, 23, 23, 235)
    surface.DrawRect(0, 0, w, h - 8)
    surface.SetDrawColor(primary_color)
    surface.DrawRect(0, h - 10, w, 2)
end

local function paint_window_button(panel, w, h, hovercol)
    if panel:GetDisabled() then return false end
    if panel:IsSelected() or panel.Hovered then
        surface.SetDrawColor(hovercol)
        surface.DrawRect(0, 0, w, h)
    end
    return true
end

function SKIN:PaintWindowCloseButton(panel, w, h)
    if not paint_window_button(panel, w, h, danger_color) then return end
    local cx, cy, s = w / 2, h / 2 - 1, 3
    surface.SetDrawColor(text_color)
    surface.DrawLine(cx - s, cy - s, cx + s, cy + s)
    surface.DrawLine(cx - s, cy - s + 1, cx + s - 1, cy + s)
    surface.DrawLine(cx - s, cy + s, cx + s, cy - s)
    surface.DrawLine(cx - s, cy + s - 1, cx + s - 1, cy - s)
end

function SKIN:PaintWindowMinimizeButton(panel, w, h)
    if not paint_window_button(panel, w, h, hover_color) then return end
    surface.SetDrawColor(text_color)
    surface.DrawRect(w / 2 - 3, h / 2 + 2, 7, 2)
end

function SKIN:PaintWindowMaximizeButton(panel, w, h)
    if not paint_window_button(panel, w, h, hover_color) then return end
    surface.SetDrawColor(text_color)
    surface.DrawOutlinedRect(w / 2 - 4, h / 2 - 4, 8, 7)
end

function SKIN:PaintVScrollBar(panel, w, h)
    surface.SetDrawColor(15, 15, 15, 200)
    surface.DrawRect(0, 0, w, h)
end

function SKIN:PaintHScrollBar(panel, w, h)
    surface.SetDrawColor(15, 15, 15, 200)
    surface.DrawRect(0, 0, w, h)
end

function SKIN:PaintScrollBarGrip(panel, w, h)
    local col = grip_color
    if panel.Depressed then
        col = primary_dark_color
    elseif panel.Hovered then
        col = primary_color
    end
    surface.SetDrawColor(col)
    surface.DrawRect(1, 1, w - 2, h - 2)
end

local function paint_scroller_btn(panel, w, h, dir)
    if not panel.m_bBackground then return end
    if panel:IsSelected() or panel.Hovered then
        surface.SetDrawColor(primary_color)
    else
        surface.SetDrawColor(box_solid_color)
    end
    surface.DrawRect(1, 1, w - 2, h - 2)
    draw_triangle(w / 2, h / 2, 3, dir, panel.Hovered and text_color or text_muted_color)
end

function SKIN:PaintButtonUp(panel, w, h) paint_scroller_btn(panel, w, h, "up") end
function SKIN:PaintButtonDown(panel, w, h) paint_scroller_btn(panel, w, h, "down") end
function SKIN:PaintButtonLeft(panel, w, h) paint_scroller_btn(panel, w, h, "left") end
function SKIN:PaintButtonRight(panel, w, h) paint_scroller_btn(panel, w, h, "right") end

function SKIN:PaintComboDownArrow(panel, w, h)
    draw_triangle(w / 2, h / 2, 3, "down",
        panel.ComboBox and panel.ComboBox.Hovered and text_color or text_muted_color)
end

function SKIN:PaintComboBox(panel, w, h)
    surface.SetDrawColor(border_color)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(panel.Hovered and hover_color or field_solid_color)
    surface.DrawRect(1, 1, w - 2, h - 2)
    if panel:GetDisabled() then
        surface.SetDrawColor(grip_faint_color)
        surface.DrawOutlinedRect(0, 0, w, h)
    elseif panel:IsMenuOpen() then
        surface.SetDrawColor(primary_color)
        surface.DrawOutlinedRect(0, 0, w, h)
    end
end

function SKIN:PaintListBox(panel, w, h)
    surface.SetDrawColor(border_color)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(field_solid_color)
    surface.DrawRect(1, 1, w - 2, h - 2)
end

function SKIN:PaintNumberUp(panel, w, h)
    draw_triangle(w / 2, h / 2, 3, "up",
        panel.Depressed and primary_color or panel.Hovered and text_color or text_muted_color)
end

function SKIN:PaintNumberDown(panel, w, h)
    draw_triangle(w / 2, h / 2, 3, "down",
        panel.Depressed and primary_color or panel.Hovered and text_color or text_muted_color)
end

function SKIN:PaintTreeNode(panel, w, h)
    if not panel.m_bDrawLines then return end
    surface.SetDrawColor(grip_color)
    if panel.m_bLastChild then
        surface.DrawRect(9, 0, 1, 7)
        surface.DrawRect(9, 7, 9, 1)
    else
        surface.DrawRect(9, 0, 1, h)
        surface.DrawRect(9, 7, 9, 1)
    end
end

function SKIN:PaintTreeNodeButton(panel, w, h)
    if not panel.m_bSelected then return end
    local tw, _ = panel:GetTextSize()
    surface.SetDrawColor(selection_color)
    surface.DrawRect(38, 0, tw + 6, h)
    surface.SetDrawColor(primary_color)
    surface.DrawRect(38, 0, 2, h)
end

function SKIN:PaintSelection(panel, w, h)
    surface.SetDrawColor(159, 75, 163, 25)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(primary_color)
    surface.DrawOutlinedRect(0, 0, w, h)
end

function SKIN:PaintSliderKnob(panel, w, h)
    local col = text_muted_color
    if panel.Depressed then
        col = primary_dark_color
    elseif panel.Hovered then
        col = primary_color
    end
    draw.RoundedBox(4, 0, 0, w, h, col)
end

local function paint_notches(x, y, w, h, num)
    if not num then return end
    local space = w / num
    for i = 0, num do
        surface.DrawRect(x + i * space, y + 4, 1, 5)
    end
end

function SKIN:PaintNumSlider(panel, w, h)
    surface.SetDrawColor(grip_color)
    surface.DrawRect(8, h / 2 - 1, w - 15, 1)
    paint_notches(8, h / 2 - 1, w - 16, 1, panel.m_iNotches)
end

function SKIN:PaintProgress(panel, w, h)
    surface.SetDrawColor(border_color)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(field_solid_color)
    surface.DrawRect(1, 1, w - 2, h - 2)
    surface.SetDrawColor(primary_color)
    surface.DrawRect(2, 2, (w - 4) * panel:GetFraction(), h - 4)
end

function SKIN:PaintCollapsibleCategory(panel, w, h)
    if not panel:GetExpanded() and h < 40 then
        surface.SetDrawColor(field_solid_color)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(accent_border_color)
        surface.DrawOutlinedRect(0, 0, w, h)
        return
    end
    surface.SetDrawColor(20, 20, 20, 170)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(accent_border_color)
    surface.DrawOutlinedRect(0, 0, w, h)
end

function SKIN:PaintCategoryList(panel, w, h)
    surface.SetDrawColor(0, 0, 0, 80)
    surface.DrawRect(0, 0, w, h)
end

function SKIN:PaintCategoryButton(panel, w, h)
    if panel.Depressed or panel.m_bSelected then
        surface.SetDrawColor(primary_dark_color)
    elseif panel.Hovered then
        surface.SetDrawColor(primary_color)
    else
        surface.SetDrawColor(panel.AltLine and Color(38, 38, 38, 235) or Color(46, 46, 46, 235))
    end
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(accent_border_color)
    surface.DrawOutlinedRect(0, 0, w, h)
end

function SKIN:PaintListViewLine(panel, w, h)
    if panel:IsSelected() then
        surface.SetDrawColor(selection_color)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(primary_color)
        surface.DrawRect(0, 0, 2, h)
    elseif panel.Hovered then
        surface.SetDrawColor(255, 255, 255, 20)
        surface.DrawRect(0, 0, w, h)
    elseif panel.m_bAlt then
        surface.SetDrawColor(255, 255, 255, 8)
        surface.DrawRect(0, 0, w, h)
    end
    surface.SetDrawColor(accent_border_color)
    surface.DrawOutlinedRect(0, 0, w, h)
end

function SKIN:PaintListView(panel, w, h)
    surface.SetDrawColor(field_solid_color)
    surface.DrawRect(0, 0, w, h)
end

function SKIN:PaintTooltip(panel, w, h)
    surface.SetDrawColor(border_color)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(box_solid_color)
    surface.DrawRect(1, 1, w - 2, h - 2)
    surface.SetDrawColor(primary_color)
    surface.DrawRect(0, 0, 3, h)
end

derma.DefineSkin("mh_dark", "Metahacker's dark skin", SKIN)
