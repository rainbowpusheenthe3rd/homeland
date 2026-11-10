--[[ Homeland (trial): the main action bar's end caps show your race's homeland plants instead of the
gryphon (Alliance) or wyvern (Horde).

Forever's caps are MainActionBar.EndCaps.LeftEndCap.Texture and .RightEndCap.Texture, 154 x 95 frames
(Blizzard_ActionBar/Mainline/MainActionBar.xml and Camelot/MainMenuBarEndCaps.xml, wow-ui-source "forever"
branch). Blizzard's MainActionBarMixin:UpdateEndCaps sets the faction atlas each time it runs, so this re-applies
after it with hooksecurefunc. Only textures change; no protected frame is touched, so it is safe in combat.
]]
local ADDON = ...
local DIR = "Interface\\AddOns\\" .. ADDON .. "\\"
local FILL = 158 / 256          -- the cap occupies the TGA's top 158 rows
local RACE = {                  -- UnitRace's file name -> our texture name
    Human = "human", Dwarf = "dwarf", NightElf = "night_elf", Gnome = "gnome",
    Orc = "orc", Scourge = "undead", Tauren = "tauren", Troll = "troll",
}
local on = true
HomelandDB = HomelandDB or {}   -- .hug: heavy end against the bar, trailing off outwards (else the corner sits outside)

local function Apply()
    local caps = MainActionBar and MainActionBar.EndCaps
    if not caps or not caps.LeftEndCap then return end
    local _, file = UnitRace("player")
    local name = RACE[file or ""]
    if not name or not on then return end
    for side, cap in pairs({ left = caps.LeftEndCap, right = caps.RightEndCap }) do
        local t = cap.Texture
        t:SetTexture(DIR .. "cap_" .. name .. "_" .. side .. (HomelandDB.hug and "_hug" or ""))
        t:SetTexCoord(0, 1, 0, FILL)
        t:ClearAllPoints()
        t:SetAllPoints(cap)
    end
    caps:Show()                 -- Neutral characters (pandaren before choosing) get no caps from Blizzard
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
    if MainActionBar and MainActionBar.UpdateEndCaps and not f.hooked then
        hooksecurefunc(MainActionBar, "UpdateEndCaps", Apply)
        f.hooked = true
    end
    Apply()
end)

SLASH_HOMELAND1 = "/homeland"
SlashCmdList.HOMELAND = function(msg)
    msg = (msg or ""):lower()
    if msg == "off" then
        on = false
        MainActionBar:UpdateEndCaps(MainActionBar.hideBarArt)   -- Blizzard puts its own art back
        print("Homeland: the gryphons are back.")
    elseif msg == "hug" or msg == "corner" then
        HomelandDB.hug = (msg == "hug")
        Apply()
        print(msg == "hug" and "Homeland: heavy end against the bar." or "Homeland: heavy end at the screen edge.")
    elseif msg == "on" then
        on = true
        Apply()
        print("Homeland: homeland plants on the bar.")
    else
        local _, file = UnitRace("player")
        print(("Homeland: race %s, art %s. /homeland off | on | hug | corner"):format(tostring(file), tostring(RACE[file or ""])))
    end
end
