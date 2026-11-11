--[[ Homeland (trial): the main action bar's end caps show your race's homeland plants instead of the
gryphon (Alliance) or wyvern (Horde).

Forever's caps are MainActionBar.EndCaps.LeftEndCap.Texture and .RightEndCap.Texture, 154 x 95 frames
(Blizzard_ActionBar/Mainline/MainActionBar.xml and Camelot/MainMenuBarEndCaps.xml, wow-ui-source "forever"
branch). Blizzard's MainActionBarMixin:UpdateEndCaps sets the faction atlas each time it runs, so this re-applies
after it with hooksecurefunc. Only textures change; no protected frame is touched, so it is safe in combat.

Placement: each mode ("hug" (the default, placed in game: 31 out, 6 up): heavy end against the bar; "corner": heavy end at the screen edge) keeps its own
offset, in pixels outwards from the bar and upwards, mirrored for the two sides. /homeland move shows a handle
over each cap; dragging either moves both. The handles are this addon's own frames, so Blizzard's Edit Mode
frames are never moved.
]]
local ADDON = ...
local DIR = "Interface\\AddOns\\" .. ADDON .. "\\"
local FILL = 158 / 256          -- the cap occupies the TGA's top 158 rows
local RACE = {                  -- UnitRace's file name -> our texture name
    Human = "human", Dwarf = "dwarf", NightElf = "night_elf", Gnome = "gnome",
    Orc = "orc", Scourge = "undead", Tauren = "tauren", Troll = "troll",
}
local DEFAULT = { hug = { 31, 6 }, corner = { 0, 0 } }
local on = true
local handles = {}

local function DB()
    HomelandDB = HomelandDB or {}
    HomelandDB.offset = HomelandDB.offset or {}
    return HomelandDB
end

local function Mode() return DB().hug == false and "corner" or "hug" end

local function Offset()
    local o = DB().offset[Mode()] or DEFAULT[Mode()]
    return o[1], o[2]
end

-- The cap art is drawn on Homeland's own frame, not on Blizzard's cap textures, so nothing that fades the action
-- bar (Stillwater) can fade it; Blizzard's own cap textures are kept at 0 opacity while Homeland is on.
-- Bar art goes to 200% (11 Nov 2026): the painted caps are only partly opaque (night elf: a third of the visible
-- pixels fully opaque, median alpha 192/255, /homeland debug showed ours at 1.00 while it still looked faint), so
-- above 100% a second copy is stacked on top at the extra opacity.
local holder, own = nil, {}
local function Own(side, cap)
    if not holder then
        holder = CreateFrame("Frame", nil, UIParent)
        holder:SetAllPoints(UIParent)
    end
    holder:SetFrameStrata(cap:GetFrameStrata())
    holder:SetFrameLevel(cap:GetFrameLevel())
    holder:Show()
    own[side] = own[side] or holder:CreateTexture(nil, "OVERLAY")
    own[side .. "2"] = own[side .. "2"] or holder:CreateTexture(nil, "OVERLAY", nil, 1)
    return own[side], own[side .. "2"]
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
        local a = DB().capAlpha or 1   -- /homeland caps, the panel's Bar art slider: 0 to 2
        local x = (side == "left" and -1 or 1) * out
        for i, t in ipairs({ Own(side, cap) }) do
            t:SetTexture(DIR .. "cap_" .. name .. "_" .. side .. (Mode() == "hug" and "_hug" or ""))
            t:SetTexCoord(0, 1, 0, FILL)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", cap, "TOPLEFT", x, up)
            t:SetPoint("BOTTOMRIGHT", cap, "BOTTOMRIGHT", x, up)
            local layer = math.max(0, math.min(1, a - (i - 1)))   -- the first copy to 100%, the second above it
            t:SetAlpha(layer)
            t:SetShown(layer > 0)
        end
    end
    caps:Show()                 -- Neutral characters (pandaren before choosing) get no caps from Blizzard
end

-- The whole concept square behind the minimap, its empty centre round the map (the default, "painted"), or the
-- line-art frame ("nouveau"). Size is the art's width as a multiple of the minimap's: the concepts' open centre is
-- about 60% of their width, so 1.65 just frames the map and the default 1.45 tucks the art in closer. The
-- nouveau frame is drawn for exactly 1.7 (FIT in tools/homeland_nouveau.py). Each style keeps its own settings.
-- per style: default opacity and size, and the size range the panel's slider allows (the line frame can't go
-- under 1.6 or its stems would cross onto the map)
local STYLE = {
    painted = { label = "Square", alpha = 0.5, size = 1.45, min = 1.2, max = 2.2 },
    nouveau = { label = "Art nouveau", alpha = 1, size = 1.7, min = 1.6, max = 2.2 },
}
local function Style() return DB().mapStyle == "nouveau" and "nouveau" or "painted" end
local function Setting(key)
    DB().style = DB().style or {}
    local own = DB().style[Style()] or {}
    return own[key] or STYLE[Style()][key]
end
local function Set(key, v)
    DB().style = DB().style or {}
    DB().style[Style()] = DB().style[Style()] or {}
    DB().style[Style()][key] = v
end
local function Alpha() return Setting("alpha") end
local function Size() return Setting("size") end

local map
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
    local nouveau = Style() == "nouveau"
    local s = Size() * Minimap:GetWidth()
    map:SetSize(s, s)
    map:ClearAllPoints()
    map:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
    map.tex:SetTexture(DIR .. (nouveau and "nouveau_" or "map_") .. name)
    local dim = nouveau and 1 or 0.8
    map.tex:SetVertexColor(dim, dim, dim)
    map:SetAlpha(Alpha())
    map:SetShown(on and DB().map ~= false)
end

local function Handle(side)
    local h = CreateFrame("Frame", nil, UIParent)
    h:SetFrameStrata("DIALOG")
    h:EnableMouse(true)
    local bg = h:CreateTexture(nil, "OVERLAY")
    bg:SetAllPoints()
    bg:SetColorTexture(0.3, 0.8, 0.4, 0.25)
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
    Apply()
    Map()
end)

SLASH_HOMELAND1 = "/homeland"
SlashCmdList.HOMELAND = function(msg)
    msg = (msg or ""):lower()
    if msg == "debug" then  -- 11 Nov: what sets the caps' opacity in game (the fix for Stillwater's fade didn't take)
        local function A(x, eff)
            if not x then return "none" end
            local ok, v = pcall(eff and x.GetEffectiveAlpha or x.GetAlpha, x)
            return ok and v and ("%.2f"):format(v) or "?"
        end
        local caps = MainActionBar and MainActionBar.EndCaps
        local left = caps and caps.LeftEndCap
        print(("Homeland debug: on %s, version own-frame; holder %s eff %s shown %s; own left alpha %s shown %s"):format(
            tostring(on), A(holder), A(holder, true), tostring(holder and holder:IsShown()), A(own.left),
            tostring(own.left and own.left:IsShown())))
        print(("Homeland debug: Blizzard left texture alpha %s; cap frame eff %s; MainActionBar alpha %s eff %s; "
            .. "UIParent %s; capAlpha %s"):format(A(left and left.Texture), A(left, true), A(MainActionBar),
            A(MainActionBar, true), A(UIParent), tostring(DB().capAlpha)))
        return
    end
    if msg == "off" then
        on = false
        Move(false)
        Map()
        for _, t in pairs(own) do t:Hide() end
        for _, cap in pairs({ MainActionBar.EndCaps.LeftEndCap, MainActionBar.EndCaps.RightEndCap }) do
            cap.Texture:ClearAllPoints()
            cap.Texture:SetAllPoints(cap)
            cap.Texture:SetAlpha(1)
        end
        MainActionBar:UpdateEndCaps(MainActionBar.hideBarArt)   -- Blizzard puts its own art back
        print("Homeland: the gryphons are back.")
    elseif msg == "hug" or msg == "corner" then
        DB().hug = (msg == "hug")
        Apply()
        print(msg == "hug" and "Homeland: heavy end against the bar." or "Homeland: heavy end at the screen edge.")
    elseif msg == "move" then
        local showing = handles.left and handles.left:IsShown()
        Move(not showing)
        print(showing and "Homeland: placed." or "Homeland: drag either cap; /homeland move again when done.")
    elseif msg:match("^map") then
        local arg, val = msg:match("^map%s+(%S+)%s*(%S*)")
        if arg == "off" or arg == "on" then
            DB().map = (arg == "on")
        elseif arg == "nouveau" or arg == "painted" or arg == "square" then
            DB().mapStyle = arg == "nouveau" and "nouveau" or "painted"
        elseif arg == "fade" and tonumber(val) then
            Set("alpha", math.max(0, math.min(1, tonumber(val))))
        elseif tonumber(arg) then
            local st = STYLE[Style()]
            Set("size", math.max(st.min, math.min(st.max, tonumber(arg))))
        end
        Map()
        print(("Homeland: minimap %s, %s, opacity %.2f, size %.2f. /homeland map square | nouveau | on | off | fade <0-1> | <size>")
            :format(DB().map == false and "off" or "on", STYLE[Style()].label, Alpha(), Size()))
    elseif msg:match("^caps%s+[%d%.]+$") then
        DB().capAlpha = math.max(0, math.min(2, tonumber(msg:match("[%d%.]+$"))))
        Apply()
        print(("Homeland: bar art opacity %.2f."):format(DB().capAlpha))
    elseif msg == "reset" then
        DB().offset[Mode()] = nil
        Apply()
        print(("Homeland: %s position reset."):format(Mode()))
    elseif msg == "on" then
        on = true
        Map()
        Apply()
        print("Homeland: homeland plants on the bar.")
    else
        local _, file = UnitRace("player")
        local out, up = Offset()
        print(("Homeland: race %s, %s mode, %d out, %d up. /homeland move | hug | corner | reset | caps <0-1> | off | on")
            :format(tostring(file), Mode(), out, up))
    end
end

-- Minimap button, in Wayfinder's style: half opacity until you point at it, drag to move it round the edge.
-- Click opens a small panel: Square / Art nouveau tabs, Opacity and Size; Escape or another click closes it.
if Minimap then
    local REST = 0.5
    local b = CreateFrame("Button", "HomelandMinimapButton", Minimap)
    b:SetSize(24, 24)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    b:SetAlpha(REST)
    b:RegisterForDrag("LeftButton")
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\Icons\\INV_Misc_Flower_02")          -- Peacebloom, the game's own icon
    if icon.SetMask then icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") end
    local function Place(angle)
        local r = Minimap:GetWidth() / 2 + 6
        b:ClearAllPoints()
        b:SetPoint("CENTER", Minimap, "CENTER", r * math.cos(math.rad(angle)), r * math.sin(math.rad(angle)))
    end
    b:RegisterEvent("PLAYER_ENTERING_WORLD")                          -- saved variables are loaded by then
    b:SetScript("OnEvent", function() Place(DB().buttonAngle or 200) end)

    -- the panel: a tab per style (Square, Art nouveau), then Opacity and Size sliders for the chosen style
    local panel
    local LAV = { 0.77, 0.73, 0.89 }
    local function Slider(parent, y, label)
        local name = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        name:SetPoint("TOPLEFT", 10, y)
        name:SetText(label)
        local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        value:SetPoint("TOPRIGHT", -10, y)
        local sl = CreateFrame("Slider", nil, parent)
        sl:SetOrientation("HORIZONTAL")
        sl:SetSize(186, 16)
        sl:SetPoint("TOP", 0, y - 14)
        sl:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
        local track = sl:CreateTexture(nil, "BACKGROUND")
        track:SetColorTexture(LAV[1], LAV[2], LAV[3], 0.35)
        track:SetHeight(2)
        track:SetPoint("LEFT")
        track:SetPoint("RIGHT")
        sl.readout = value
        return sl
    end
    local function Panel()
        if panel then return panel end
        panel = CreateFrame("Frame", "HomelandPanel", UIParent)
        panel:SetSize(210, 158)
        panel:SetFrameStrata("DIALOG")
        panel:EnableMouse(true)
        local bg = panel:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.04, 0.08, 0.88)
        local line = panel:CreateTexture(nil, "BORDER")                 -- one thin line along the top, nothing more
        line:SetColorTexture(LAV[1], LAV[2], LAV[3], 0.8)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT")
        line:SetPoint("TOPRIGHT")
        panel.tabs = {}
        for i, key in ipairs({ "painted", "nouveau" }) do
            local t = CreateFrame("Button", nil, panel)
            t:SetSize(95, 20)
            t:SetPoint("TOPLEFT", 8 + (i - 1) * 99, -6)
            t.bg = t:CreateTexture(nil, "BACKGROUND")
            t.bg:SetAllPoints()
            t.text = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            t.text:SetPoint("CENTER")
            t.text:SetText(STYLE[key].label)
            t.key = key
            t:SetScript("OnClick", function()
                DB().mapStyle = key
                Map()
                panel.Refresh()
            end)
            panel.tabs[i] = t
        end
        local alpha = Slider(panel, -34, "Opacity")
        alpha:SetMinMaxValues(0, 1)
        alpha:SetValueStep(0.05)
        local size = Slider(panel, -74, "Size")
        size:SetValueStep(0.05)
        local caps = Slider(panel, -114, "Bar art")                     -- the end caps, one setting for both styles
        caps:SetMinMaxValues(0, 2)                                    -- above 100% stacks a second copy
        caps:SetValueStep(0.05)
        local quiet = false                                           -- Refresh sets values without saving them
        alpha:SetScript("OnValueChanged", function(self, v)
            v = math.floor(v * 20 + 0.5) / 20
            self.readout:SetText(("%d%%"):format(v * 100))
            if quiet then return end
            Set("alpha", v)
            DB().map = v > 0                                           -- at 0 the frame is simply off
            Map()
        end)
        size:SetScript("OnValueChanged", function(self, v)
            v = math.floor(v * 20 + 0.5) / 20
            self.readout:SetText(("%.2fx the map"):format(v))
            if quiet then return end
            Set("size", v)
            Map()
        end)
        caps:SetScript("OnValueChanged", function(self, v)
            v = math.floor(v * 20 + 0.5) / 20
            self.readout:SetText(("%d%%"):format(v * 100))
            if quiet then return end
            DB().capAlpha = v
            Apply()
        end)
        function panel.Refresh()
            local st = STYLE[Style()]
            for _, t in ipairs(panel.tabs) do
                local on = t.key == Style()
                t.bg:SetColorTexture(LAV[1], LAV[2], LAV[3], on and 0.28 or 0.06)
                t.text:SetTextColor(on and 1 or 0.6, on and 0.95 or 0.58, on and 1 or 0.68)
            end
            quiet = true
            size:SetMinMaxValues(st.min, st.max)
            alpha:SetValue(DB().map == false and 0 or Alpha())
            size:SetValue(Size())
            caps:SetValue(DB().capAlpha or 1)
            quiet = false
        end
        panel.alpha, panel.size, panel.caps = alpha, size, caps
        tinsert(UISpecialFrames, "HomelandPanel")                      -- Escape closes it
        panel:Hide()
        return panel
    end

    b:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Homeland")
        GameTooltip:AddLine("Click: map style, opacity and size; bar art opacity", 1, 1, 1)
        GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self) self:SetAlpha(REST); GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
        local p = Panel()
        if p:IsShown() then return p:Hide() end
        p:ClearAllPoints()
        p:SetPoint("TOPRIGHT", self, "BOTTOMLEFT", 0, -4)
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
