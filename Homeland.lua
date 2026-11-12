--[[ Homeland (trial): the main action bar's end caps show your race's homeland plants instead of the
gryphon (Alliance) or wyvern (Horde), and the minimap gets a frame of the same plants.

Forever's caps are MainActionBar.EndCaps.LeftEndCap.Texture and .RightEndCap.Texture, 154 x 95 frames
(Blizzard_ActionBar/Mainline/MainActionBar.xml and Camelot/MainMenuBarEndCaps.xml, wow-ui-source "forever"
branch). Blizzard's MainActionBarMixin:UpdateEndCaps sets the faction atlas each time it runs, so this re-applies
after it with hooksecurefunc. No protected frame is touched, so it is safe in combat.

The cap art is drawn on Homeland's own frame, not on Blizzard's cap textures (kept at 0 opacity while Homeland is
on), so nothing that fades the action bar (Stillwater) fades it. One opacity, 0 to 100%, sets all of Homeland's
art: the caps and the minimap frame (11 Nov 2026). The minimap's coordinates are set into the bottom of the frame as
an engraved tab, black with a rim in the race's colour; the tab fades with the frame, the white numbers don't.

Placement: each mode ("hug", the default: heavy end against the bar; "corner": heavy end at the screen edge) keeps
its own offset, in pixels outwards from the bar and upwards, mirrored for the two sides. /homeland move shows a
handle over each cap; dragging either moves both. The handles are this addon's own frames, so Blizzard's Edit
Mode frames are never moved.
]]

---------------------------------------------------------------------------------------------- constants
local ADDON = ...
local DIR = "Interface\\AddOns\\" .. ADDON .. "\\"
local RACE = {                      -- UnitRace's file name -> our texture name
    Human = "human", Dwarf = "dwarf", NightElf = "night_elf", Gnome = "gnome",
    Orc = "orc", Scourge = "undead", Tauren = "tauren", Troll = "troll",
}
local OPACITY = 1                   -- default opacity of all Homeland's art (0-1)
local OPACITY_STEP = 0.05           -- the slider's step

-- bar end caps
local CAP_FILL = 158 / 256          -- the cap occupies the TGA's top 158 rows
local CAP_OFFSET = { hug = { 31, 6 }, corner = { 0, 0 } }   -- default {outwards, upwards} per mode, placed in game
local HANDLE_COLOUR = { 0.3, 0.8, 0.4, 0.25 }               -- /homeland move's drag handles

-- minimap frame: the whole concept square behind the map, its empty centre round the map ("painted", the default),
-- or the line-art frame ("nouveau"). Size is the art's width as a multiple of the minimap's: the concepts' open
-- centre is about 60% of their width, so 1.45 tucks the art in close; the nouveau frame is drawn for exactly 1.7
-- (FIT in tools/homeland_nouveau.py) and can't go under 1.6 or its stems would cross onto the map.
local STYLE = {
    painted = { label = "Square", size = 1.4, min = 1.2, max = 2.2, dim = 0.8 },
    nouveau = { label = "Art nouveau", size = 1.7, min = 1.6, max = 2.2, dim = 1 },
}
local STYLES = { "painted", "nouveau" }  -- tab order

-- the coordinates' tab: an engraved plaque set into the bottom of the frame, like the label on a good photo frame.
-- The plaque (black, rimmed in the race's colour) fades with the frame's opacity; the numbers stay full strength.
local RACE_COLOUR = {               -- each race's main flower colour (tools/homeland_nouveau.py PALETTE), 0-255
    NightElf = { 240, 236, 255 }, Human = { 244, 196, 206 }, Dwarf = { 196, 136, 206 }, Gnome = { 124, 172, 240 },
    Orc = { 244, 130, 70 }, Scourge = { 156, 116, 186 }, Tauren = { 244, 212, 96 }, Troll = { 232, 112, 200 },
}
local COORDS_PATTERN = "^%s*%-?%d+%.%d+,%s*%-?%d+%.%d+%s*$"   -- "37.6, 73.4"
local COORDS_EVERY = 1              -- seconds between checks: find the text, keep it on the tab, fit the tab to it
local TAB_FILL = { 0, 0, 0, 0.85 }  -- the plaque
local TAB_RIM = 1                   -- its race-coloured rim, pixels ...
local TAB_INLAY = 0.35              -- ... and a fainter inlay line just inside it, as an engraved border
local TAB_PAD_X, TAB_PAD_Y = 8, 3   -- plaque round the numbers, pixels
local TAB_DROP = 0.5                -- how far down the frame's margin below the map the tab sits (0 = map edge)
local COORDS_TEXT = { 1, 1, 1 }     -- white numbers ...
local COORDS_SHADOW = { 1, -1 }     -- ... with a 1 px black shadow

-- minimap button and its panel
local BUTTON_ICON = "Interface\\Icons\\INV_Misc_Flower_02"              -- Peacebloom, the game's own icon
local BUTTON_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local BUTTON_SIZE = 24
local BUTTON_REST = 0.5             -- its opacity until you point at it
local BUTTON_ANGLE = 200            -- default place round the minimap's edge, degrees
local BUTTON_GAP = 6                -- outside the minimap's edge, pixels
local BUTTON_LEVEL = 8              -- frame levels above the minimap
local PANEL_W, PANEL_H = 210, 118
local PANEL_BG = { 0.05, 0.04, 0.08, 0.88 }
local LAV = { 0.77, 0.73, 0.89 }    -- the panel's lavender: top line, tabs, slider track
local LINE_ALPHA = 0.8              -- the one thin line along the panel's top
local TAB_W, TAB_H, TAB_X, TAB_Y, TAB_GAP = 95, 20, 8, -6, 4
local TAB_FILL = { on = 0.28, off = 0.06 }                      -- lavender behind the chosen / other tab
local TAB_TEXT = { on = { 1, 0.95, 1 }, off = { 0.6, 0.58, 0.68 } }
local SLIDER_X, SLIDER_Y, SLIDER_H, SLIDER_DROP = 10, -34, 16, 14  -- first label row; each slider sits 14 below its label
local SLIDER_ROW = 40               -- from one slider row to the next
local SIZE_STEP = 0.05              -- the size slider's step, in multiples of the map's width
local TRACK_ALPHA, TRACK_H = 0.35, 2
local PANEL_GAP = 4                 -- between the button and the panel
local SLIDER_THUMB = "Interface\\Buttons\\UI-SliderBar-Button-Horizontal"

---------------------------------------------------------------------------------------------- state
local on = true
local handles = {}
local holder, own = nil, {}         -- Homeland's frame for the caps, and its two cap textures
local map                           -- the minimap frame

local function DB()
    HomelandDB = HomelandDB or {}
    HomelandDB.offset = HomelandDB.offset or {}
    return HomelandDB
end

-- one opacity for everything; the old separate settings (capAlpha, per-style alpha) seed it once
local function Opacity()
    local db = DB()
    if db.opacity == nil then db.opacity = math.min(1, db.capAlpha or OPACITY) end
    return db.opacity
end

local function SetOpacity(v)
    DB().opacity = math.max(0, math.min(1, v))
end

local function Mode() return DB().hug == false and "corner" or "hug" end

local function Offset()
    local o = DB().offset[Mode()] or CAP_OFFSET[Mode()]
    return o[1], o[2]
end

local function Style() return DB().mapStyle == "nouveau" and "nouveau" or "painted" end

local function Size()
    DB().style = DB().style or {}
    local saved = DB().style[Style()] or {}
    return saved.size or STYLE[Style()].size
end

local function SetSize(v)
    local st = STYLE[Style()]
    DB().style = DB().style or {}
    DB().style[Style()] = DB().style[Style()] or {}
    DB().style[Style()].size = math.max(st.min, math.min(st.max, v))
end

---------------------------------------------------------------------------------------------- bar end caps
local function Own(side, cap)
    if not holder then
        holder = CreateFrame("Frame", nil, UIParent)
        holder:SetAllPoints(UIParent)
    end
    holder:SetFrameStrata(cap:GetFrameStrata())
    holder:SetFrameLevel(cap:GetFrameLevel())
    holder:Show()
    own[side] = own[side] or holder:CreateTexture(nil, "OVERLAY")
    return own[side]
end

local function Apply()
    local caps = MainActionBar and MainActionBar.EndCaps
    if not caps or not caps.LeftEndCap then return end
    local _, file = UnitRace("player")
    local name = RACE[file or ""]
    if not name or not on then return end
    local out, up = Offset()
    for side, cap in pairs({ left = caps.LeftEndCap, right = caps.RightEndCap }) do
        cap.Texture:SetAlpha(0)
        local t = Own(side, cap)
        t:SetTexture(DIR .. "cap_" .. name .. "_" .. side .. (Mode() == "hug" and "_hug" or ""))
        t:SetTexCoord(0, 1, 0, CAP_FILL)
        t:ClearAllPoints()
        local x = (side == "left" and -1 or 1) * out
        t:SetPoint("TOPLEFT", cap, "TOPLEFT", x, up)
        t:SetPoint("BOTTOMRIGHT", cap, "BOTTOMRIGHT", x, up)
        t:SetAlpha(Opacity())
        t:SetShown(Opacity() > 0)
    end
    caps:Show()                     -- Neutral characters (pandaren before choosing) get no caps from Blizzard
end

---------------------------------------------------------------------------------------------- minimap frame
local function Map()
    local _, file = UnitRace("player")
    local name = RACE[file or ""]
    if not name or not Minimap then return end
    if not map then
        map = CreateFrame("Frame", nil, Minimap:GetParent() or UIParent)
        map.tex = map:CreateTexture(nil, "BACKGROUND")
        map.tex:SetAllPoints()
    end
    map:SetFrameStrata(Minimap:GetFrameStrata())
    map:SetFrameLevel(math.max(0, Minimap:GetFrameLevel() - 1))   -- under the map and its buttons
    local s = Size() * Minimap:GetWidth()
    map:SetSize(s, s)
    map:ClearAllPoints()
    map:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
    map.tex:SetTexture(DIR .. (Style() == "nouveau" and "nouveau_" or "map_") .. name)
    local dim = STYLE[Style()].dim
    map.tex:SetVertexColor(dim, dim, dim)
    map:SetAlpha(Opacity())
    map:SetShown(on and DB().map ~= false and Opacity() > 0)
end

---------------------------------------------------------------------------------------------- the coordinates' tab
-- The minimap's coordinate text isn't Homeland's (nor in Blizzard's Camelot minimap code), so it's found by its look
-- under the minimap cluster, then anchored to the tab. The tab is a child of the frame, so it takes the frame's
-- opacity; the text keeps its own parent, so it stays at full strength.
local coords, tab
local function FindCoords(frame, depth)
    if not frame or depth > 6 or frame == map then return nil end
    for _, r in ipairs({ frame:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "FontString" then
            local t = r:GetText()
            if type(t) == "string" and not (issecretvalue and issecretvalue(t)) and t:match(COORDS_PATTERN) then return r end
        end
    end
    for _, c in ipairs({ frame:GetChildren() }) do
        local found = FindCoords(c, depth + 1)
        if found then return found end
    end
end

local function Tab()
    if not map then return end
    coords = coords or FindCoords(_G.MinimapCluster, 0) or FindCoords(Minimap, 0)
    if not coords then return end
    local _, file = UnitRace("player")
    local c = RACE_COLOUR[file or ""] or { 255, 255, 255 }
    local r, g, b = c[1] / 255, c[2] / 255, c[3] / 255
    if not tab then
        tab = CreateFrame("Frame", nil, map)
        local function Tex(layer, sub) return tab:CreateTexture(nil, layer, nil, sub) end
        tab.fill = Tex("BACKGROUND", 0)
        tab.fill:SetAllPoints()
        tab.rim, tab.inlay = {}, {}
        for i, e in ipairs({ { "TOPLEFT", "TOPRIGHT", "h" }, { "BOTTOMLEFT", "BOTTOMRIGHT", "h" },
                             { "TOPLEFT", "BOTTOMLEFT", "w" }, { "TOPRIGHT", "BOTTOMRIGHT", "w" } }) do
            local inset = { TOPLEFT = { 1, -1 }, TOPRIGHT = { -1, -1 }, BOTTOMLEFT = { 1, 1 }, BOTTOMRIGHT = { -1, 1 } }
            for k, list in ipairs({ tab.rim, tab.inlay }) do
                local t = Tex("BORDER", k)
                local d = (k - 1) * (TAB_RIM + 1)        -- the inlay sits one pixel inside the rim
                t:SetPoint(e[1], tab, e[1], inset[e[1]][1] * d, inset[e[1]][2] * d)
                t:SetPoint(e[2], tab, e[2], inset[e[2]][1] * d, inset[e[2]][2] * d)
                if e[3] == "h" then t:SetHeight(TAB_RIM) else t:SetWidth(TAB_RIM) end
                list[i] = t
            end
        end
    end
    tab.fill:SetColorTexture(TAB_FILL[1], TAB_FILL[2], TAB_FILL[3], TAB_FILL[4])
    for _, t in ipairs(tab.rim) do t:SetColorTexture(r, g, b, 1) end
    for _, t in ipairs(tab.inlay) do t:SetColorTexture(r, g, b, TAB_INLAY) end
    local w = Minimap:GetWidth()
    local margin = (Size() * w - w) / 2                 -- the frame's art below the map
    tab:SetSize((coords:GetStringWidth() or 40) + 2 * TAB_PAD_X, (coords:GetStringHeight() or 12) + 2 * TAB_PAD_Y)
    tab:ClearAllPoints()
    tab:SetPoint("CENTER", Minimap, "BOTTOM", 0, -margin * TAB_DROP)
    tab:SetShown(map:IsShown())
    local _, rel = coords:GetPoint(1)
    if rel ~= tab then
        coords:ClearAllPoints()
        coords:SetPoint("CENTER", tab, "CENTER", 0, 0)
    end
    coords:SetTextColor(COORDS_TEXT[1], COORDS_TEXT[2], COORDS_TEXT[3])
    coords:SetShadowColor(0, 0, 0, 1)
    coords:SetShadowOffset(COORDS_SHADOW[1], COORDS_SHADOW[2])
end

local function Refresh()
    Apply()
    Map()
    Tab()
end

---------------------------------------------------------------------------------------------- placing the caps
local function Handle(side)
    local h = CreateFrame("Frame", nil, UIParent)
    h:SetFrameStrata("DIALOG")
    h:EnableMouse(true)
    local bg = h:CreateTexture(nil, "OVERLAY")
    bg:SetAllPoints()
    bg:SetColorTexture(HANDLE_COLOUR[1], HANDLE_COLOUR[2], HANDLE_COLOUR[3], HANDLE_COLOUR[4])
    local label = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    label:SetText("drag")
    h:SetScript("OnMouseDown", function(self)
        local cx, cy = GetCursorPosition()
        local out, up = Offset()
        self.start = { cx, cy, out, up, self:GetEffectiveScale() }
    end)
    h:SetScript("OnMouseUp", function(self)
        self.start = nil
        local out, up = Offset()
        print(("Homeland: %s offset %d out, %d up (saved)."):format(Mode(), out, up))
    end)
    h:SetScript("OnUpdate", function(self)
        local s = self.start
        if not s then return end
        local cx, cy = GetCursorPosition()
        local dx, dy = (cx - s[1]) / s[5], (cy - s[2]) / s[5]
        local out = s[3] + (side == "left" and -dx or dx)   -- outwards is left for the left cap
        DB().offset[Mode()] = { math.floor(out + 0.5), math.floor(s[4] + dy + 0.5) }
        Apply()
    end)
    return h
end

local function Move(show)
    local caps = MainActionBar and MainActionBar.EndCaps
    if not caps then return end
    for side, cap in pairs({ left = caps.LeftEndCap, right = caps.RightEndCap }) do
        handles[side] = handles[side] or Handle(side)
        handles[side]:ClearAllPoints()
        handles[side]:SetAllPoints(own[side] or cap.Texture)     -- follows the art as it moves
        handles[side]:SetShown(show)
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
    if MainActionBar and MainActionBar.UpdateEndCaps and not f.hooked then
        hooksecurefunc(MainActionBar, "UpdateEndCaps", Apply)
        f.hooked = true
    end
    Refresh()
    if not f.ticking then              -- the coordinates appear late and their width changes: keep the tab fitted
        f.ticking = true
        C_Timer.NewTicker(COORDS_EVERY, Tab)
    end
end)

---------------------------------------------------------------------------------------------- slash commands
SLASH_HOMELAND1 = "/homeland"
SlashCmdList.HOMELAND = function(msg)
    msg = (msg or ""):lower()
    local value = tonumber(msg:match("^%a+%s+([%d%.]+)$") or "")
    if msg == "debug" then          -- what sets the caps' opacity in game (11 Nov 2026)
        local function A(x, eff)
            if not x then return "none" end
            local ok, v = pcall(eff and x.GetEffectiveAlpha or x.GetAlpha, x)
            return ok and v and ("%.2f"):format(v) or "?"
        end
        local caps = MainActionBar and MainActionBar.EndCaps
        local left = caps and caps.LeftEndCap
        print(("Homeland debug: on %s; holder %s eff %s shown %s; own left alpha %s shown %s; opacity %.2f"):format(
            tostring(on), A(holder), A(holder, true), tostring(holder and holder:IsShown()), A(own.left),
            tostring(own.left and own.left:IsShown()), Opacity()))
        print(("Homeland debug: Blizzard left texture alpha %s; cap frame eff %s; MainActionBar alpha %s eff %s; "
            .. "UIParent %s"):format(A(left and left.Texture), A(left, true), A(MainActionBar),
            A(MainActionBar, true), A(UIParent)))
    elseif msg == "off" then
        on = false
        Move(false)
        Map(); Tab()
        for _, t in pairs(own) do t:Hide() end
        for _, cap in pairs({ MainActionBar.EndCaps.LeftEndCap, MainActionBar.EndCaps.RightEndCap }) do
            cap.Texture:ClearAllPoints()
            cap.Texture:SetAllPoints(cap)
            cap.Texture:SetAlpha(1)
        end
        MainActionBar:UpdateEndCaps(MainActionBar.hideBarArt)   -- Blizzard puts its own art back
        print("Homeland: the gryphons are back.")
    elseif msg == "on" then
        on = true
        Refresh()
        print("Homeland: homeland plants on the bar.")
    elseif (msg:match("^opacity") or msg:match("^caps")) and value then
        SetOpacity(value)
        Refresh()
        print(("Homeland: opacity %d%%."):format(math.floor(Opacity() * 100 + 0.5)))
    elseif msg == "hug" or msg == "corner" then
        DB().hug = (msg == "hug")
        Apply()
        print(msg == "hug" and "Homeland: heavy end against the bar." or "Homeland: heavy end at the screen edge.")
    elseif msg == "move" then
        local showing = handles.left and handles.left:IsShown()
        Move(not showing)
        print(showing and "Homeland: placed." or "Homeland: drag either cap; /homeland move again when done.")
    elseif msg:match("^map") then
        local arg = msg:match("^map%s+(%S+)")
        if arg == "off" or arg == "on" then
            DB().map = (arg == "on")
        elseif arg == "nouveau" or arg == "painted" or arg == "square" then
            DB().mapStyle = arg == "nouveau" and "nouveau" or "painted"
        elseif tonumber(arg) then
            SetSize(tonumber(arg))
        end
        Map(); Tab()
        print(("Homeland: minimap %s, %s, size %.2f. /homeland map square | nouveau | on | off | <size>")
            :format(DB().map == false and "off" or "on", STYLE[Style()].label, Size()))
    elseif msg == "reset" then
        DB().offset[Mode()] = nil
        Apply()
        print(("Homeland: %s position reset."):format(Mode()))
    else
        local _, file = UnitRace("player")
        local out, up = Offset()
        print(("Homeland: race %s, %s mode, %d out, %d up, opacity %d%%. /homeland opacity <0-1> | move | hug | "
            .. "corner | reset | map | off | on"):format(tostring(file), Mode(), out, up, math.floor(Opacity() * 100 + 0.5)))
    end
end

---------------------------------------------------------------------------------------------- minimap button
-- In Wayfinder's style: faint until you point at it, drag to move it round the edge. Click opens a small panel:
-- Square / Art nouveau tabs, Opacity and Size; Escape or another click closes it.
if Minimap then
    local b = CreateFrame("Button", "HomelandMinimapButton", Minimap)
    b:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(Minimap:GetFrameLevel() + BUTTON_LEVEL)
    b:SetAlpha(BUTTON_REST)
    b:RegisterForDrag("LeftButton")
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(BUTTON_ICON)
    if icon.SetMask then icon:SetMask(BUTTON_MASK) end
    local function Place(angle)
        local r = Minimap:GetWidth() / 2 + BUTTON_GAP
        b:ClearAllPoints()
        b:SetPoint("CENTER", Minimap, "CENTER", r * math.cos(math.rad(angle)), r * math.sin(math.rad(angle)))
    end
    b:RegisterEvent("PLAYER_ENTERING_WORLD")                          -- saved variables are loaded by then
    b:SetScript("OnEvent", function() Place(DB().buttonAngle or BUTTON_ANGLE) end)

    local panel
    local function Panel()
        if panel then return panel end
        panel = CreateFrame("Frame", "HomelandPanel", UIParent)
        panel:SetSize(PANEL_W, PANEL_H)
        panel:SetFrameStrata("DIALOG")
        panel:EnableMouse(true)
        local bg = panel:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(PANEL_BG[1], PANEL_BG[2], PANEL_BG[3], PANEL_BG[4])
        local line = panel:CreateTexture(nil, "BORDER")                 -- one thin line along the top, nothing more
        line:SetColorTexture(LAV[1], LAV[2], LAV[3], LINE_ALPHA)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT")
        line:SetPoint("TOPRIGHT")
        panel.tabs = {}
        for i, key in ipairs(STYLES) do
            local t = CreateFrame("Button", nil, panel)
            t:SetSize(TAB_W, TAB_H)
            t:SetPoint("TOPLEFT", TAB_X + (i - 1) * (TAB_W + TAB_GAP), TAB_Y)
            t.bg = t:CreateTexture(nil, "BACKGROUND")
            t.bg:SetAllPoints()
            t.text = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            t.text:SetPoint("CENTER")
            t.text:SetText(STYLE[key].label)
            t.key = key
            t:SetScript("OnClick", function()
                DB().mapStyle = key
                Map(); Tab()
                panel.Refresh()
            end)
            panel.tabs[i] = t
        end
        -- two sliders: Opacity (0 to 100%, the caps and the minimap frame together) and Size (the minimap frame,
        -- each style its own)
        local function Slider(row, label)
            local y = SLIDER_Y - (row - 1) * SLIDER_ROW
            local name = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            name:SetPoint("TOPLEFT", SLIDER_X, y)
            name:SetText(label)
            local readout = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            readout:SetPoint("TOPRIGHT", -SLIDER_X, y)
            local sl = CreateFrame("Slider", nil, panel)
            sl:SetOrientation("HORIZONTAL")
            sl:SetSize(PANEL_W - 2 * (SLIDER_X + 2), SLIDER_H)
            sl:SetPoint("TOP", 0, y - SLIDER_DROP)
            sl:SetThumbTexture(SLIDER_THUMB)
            if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
            local track = sl:CreateTexture(nil, "BACKGROUND")
            track:SetColorTexture(LAV[1], LAV[2], LAV[3], TRACK_ALPHA)
            track:SetHeight(TRACK_H)
            track:SetPoint("LEFT")
            track:SetPoint("RIGHT")
            sl.readout = readout
            return sl
        end
        local quiet = false                                           -- Refresh sets values without saving them
        local opacity = Slider(1, "Opacity")
        opacity:SetMinMaxValues(0, 1)
        opacity:SetValueStep(OPACITY_STEP)
        opacity:SetScript("OnValueChanged", function(self, v)
            v = math.floor(v / OPACITY_STEP + 0.5) * OPACITY_STEP
            self.readout:SetText(("%d%%"):format(math.floor(v * 100 + 0.5)))
            if quiet then return end
            SetOpacity(v)
            Refresh()
        end)
        local size = Slider(2, "Size")
        size:SetValueStep(SIZE_STEP)
        size:SetScript("OnValueChanged", function(self, v)
            v = math.floor(v / SIZE_STEP + 0.5) * SIZE_STEP
            self.readout:SetText(("%.2fx the map"):format(v))
            if quiet then return end
            SetSize(v)
            Map(); Tab()
        end)
        function panel.Refresh()
            for _, t in ipairs(panel.tabs) do
                local chosen = t.key == Style()
                local k = chosen and "on" or "off"
                t.bg:SetColorTexture(LAV[1], LAV[2], LAV[3], TAB_FILL[k])
                t.text:SetTextColor(TAB_TEXT[k][1], TAB_TEXT[k][2], TAB_TEXT[k][3])
            end
            quiet = true
            opacity:SetValue(Opacity())
            local st = STYLE[Style()]
            size:SetMinMaxValues(st.min, st.max)
            size:SetValue(Size())
            quiet = false
        end
        panel.opacity, panel.size = opacity, size
        tinsert(UISpecialFrames, "HomelandPanel")                      -- Escape closes it
        panel:Hide()
        return panel
    end

    b:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Homeland")
        GameTooltip:AddLine("Click: map style, opacity and size", 1, 1, 1)
        GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self) self:SetAlpha(BUTTON_REST); GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
        local p = Panel()
        if p:IsShown() then return p:Hide() end
        p:ClearAllPoints()
        p:SetPoint("TOPRIGHT", self, "BOTTOMLEFT", 0, -PANEL_GAP)
        p.Refresh()
        p:Show()
    end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            DB().buttonAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
            Place(DB().buttonAngle)
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
end
