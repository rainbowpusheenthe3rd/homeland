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

local function Apply()
    local caps = MainActionBar and MainActionBar.EndCaps
    if not caps or not caps.LeftEndCap then return end
    local _, file = UnitRace("player")
    local name = RACE[file or ""]
    if not name or not on then return end
    local out, up = Offset()
    for side, cap in pairs({ left = caps.LeftEndCap, right = caps.RightEndCap }) do
        local t = cap.Texture
        t:SetTexture(DIR .. "cap_" .. name .. "_" .. side .. (Mode() == "hug" and "_hug" or ""))
        t:SetTexCoord(0, 1, 0, FILL)
        t:ClearAllPoints()
        local x = (side == "left" and -1 or 1) * out
        t:SetPoint("TOPLEFT", cap, "TOPLEFT", x, up)
        t:SetPoint("BOTTOMRIGHT", cap, "BOTTOMRIGHT", x, up)
    end
    caps:Show()                 -- Neutral characters (pandaren before choosing) get no caps from Blizzard
end

-- The whole concept square behind the minimap, its empty centre round the map. Size is the square's width as a
-- multiple of the minimap's: the concepts' open centre is about 60% of their width, so 1.65 frames the map.
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
    -- "nouveau" (the default): line art drawn to sit on the map's ring, so its size is fixed at 1.5 x the map.
    -- "painted": the whole concept square, quietened to half strength and dimmed.
    local nouveau = DB().mapStyle ~= "painted"
    local s = (nouveau and 1.5 or (DB().mapSize or 1.65)) * Minimap:GetWidth()
    map:SetSize(s, s)
    map:ClearAllPoints()
    map:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
    map.tex:SetTexture(DIR .. (nouveau and "nouveau_" or "map_") .. name)
    local dim = nouveau and 1 or 0.8
    map.tex:SetVertexColor(dim, dim, dim)
    map:SetAlpha(DB().mapAlpha or (nouveau and 1 or 0.5))
    map:SetShown(on and DB().map ~= false)
end

local function Strength()
    return DB().mapAlpha or (DB().mapStyle ~= "painted" and 1 or 0.5)
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
        handles[side]:SetAllPoints(cap.Texture)     -- follows the art as it moves
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
    if msg == "off" then
        on = false
        Move(false)
        Map()
        for _, cap in pairs({ MainActionBar.EndCaps.LeftEndCap, MainActionBar.EndCaps.RightEndCap }) do
            cap.Texture:ClearAllPoints()
            cap.Texture:SetAllPoints(cap)
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
        elseif arg == "nouveau" or arg == "painted" then
            DB().mapStyle = arg
            DB().mapAlpha = nil                 -- each style starts at its own strength
        elseif arg == "fade" and tonumber(val) then
            DB().mapAlpha = math.max(0, math.min(1, tonumber(val)))
        elseif tonumber(arg) then
            DB().mapSize = tonumber(arg)
        end
        Map()
        local nouveau = DB().mapStyle ~= "painted"
        print(("Homeland: minimap frame %s, %s, strength %.2f. /homeland map nouveau | painted | on | off | fade <0-1> | <size> (painted)")
            :format(DB().map == false and "off" or "on", nouveau and "nouveau" or "painted",
                DB().mapAlpha or (nouveau and 1 or 0.5)))
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
        print(("Homeland: race %s, %s mode, %d out, %d up. /homeland move | hug | corner | reset | off | on")
            :format(tostring(file), Mode(), out, up))
    end
end

-- Minimap button, in Wayfinder's style: half opacity until you point at it, drag to move it round the edge.
-- Click opens a small panel with the frame's strength slider; Escape or another click closes it.
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

    local panel
    local function Panel()
        if panel then return panel end
        panel = CreateFrame("Frame", "HomelandPanel", UIParent)
        panel:SetSize(190, 64)
        panel:SetFrameStrata("DIALOG")
        panel:EnableMouse(true)
        local bg = panel:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.04, 0.08, 0.88)
        local line = panel:CreateTexture(nil, "BORDER")                 -- one thin line along the top, nothing more
        line:SetColorTexture(0.77, 0.73, 0.89, 0.8)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT")
        line:SetPoint("TOPRIGHT")
        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        title:SetPoint("TOPLEFT", 10, -8)
        title:SetText("Homeland: frame strength")
        local value = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        value:SetPoint("TOPRIGHT", -10, -8)
        local sl = CreateFrame("Slider", nil, panel)
        sl:SetOrientation("HORIZONTAL")
        sl:SetSize(166, 16)
        sl:SetPoint("BOTTOM", 0, 12)
        sl:SetMinMaxValues(0, 1)
        sl:SetValueStep(0.05)
        if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
        sl:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        local track = sl:CreateTexture(nil, "BACKGROUND")
        track:SetColorTexture(0.77, 0.73, 0.89, 0.35)
        track:SetHeight(2)
        track:SetPoint("LEFT")
        track:SetPoint("RIGHT")
        sl:SetScript("OnValueChanged", function(_, v)
            v = math.floor(v * 20 + 0.5) / 20
            DB().mapAlpha = v
            DB().map = v > 0                                           -- at 0 the frame is simply off
            Map()
            value:SetText(("%d%%"):format(v * 100))
        end)
        panel.slider = sl
        tinsert(UISpecialFrames, "HomelandPanel")                      -- Escape closes it
        panel:Hide()
        return panel
    end

    b:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Homeland")
        GameTooltip:AddLine("Click: frame strength", 1, 1, 1)
        GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self) self:SetAlpha(REST); GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
        local p = Panel()
        if p:IsShown() then return p:Hide() end
        p:ClearAllPoints()
        p:SetPoint("TOPRIGHT", self, "BOTTOMLEFT", 0, -4)
        p.slider:SetValue(DB().map == false and 0 or Strength())
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
