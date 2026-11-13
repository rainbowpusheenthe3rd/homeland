r"""Smoke-test Homeland's minimap art and its panel: the square by default (size 1.4), the Art
nouveau tab (1, 1.7), each style keeping its own opacity and size, the size slider's range per style, opacity 0
turning it off, and the slash commands."""
from pathlib import Path

import lupa

SRC = (Path(__file__).resolve().parents[1] / "Homeland.lua").read_text(encoding="utf-8")
lua = lupa.LuaRuntime()
lua.execute(r"""
local noop = function() end
local function stub(t)
  return setmetatable(t, { __index = function(_, k) if k:match("^%u") then return noop end end })
end
MainActionBar = { EndCaps = stub({ LeftEndCap = stub({ Texture = stub({}) }), RightEndCap = stub({ Texture = stub({}) }) }) }
function MainActionBar:UpdateEndCaps() end
function hooksecurefunc() end
function UnitRace() return "Night Elf", "NightElf" end
SlashCmdList = {}
tickers = {}
C_Timer = { NewTicker = function(_, f) tickers[#tickers + 1] = f end, After = function(_, f) f() end }
-- the minimap's coordinate text, under the cluster, not Homeland's
coordsText = stub({ text = "37.6, 73.4", GetObjectType = function() return "FontString" end,
  GetText = function(s) return s.text end, GetStringWidth = function() return 50 end,
  GetStringHeight = function() return 12 end, GetPoint = function(s) return s.p, s.rel end,
  ClearAllPoints = function(s) s.p, s.rel = nil, nil end, SetPoint = function(s, p, rel) s.p, s.rel = p, rel end,
  SetTextColor = function(s, r, g, b) s.rgb = { r, g, b } end, SetShadowOffset = function(s, x, y) s.shadow = { x, y } end })
holder = stub({ GetRegions = function() return coordsText end, GetChildren = function() end })
MinimapCluster = stub({ GetRegions = function() end, GetChildren = function() return holder end })
UIParent = {}
UISpecialFrames = {}
tinsert = table.insert
GameTooltip = stub({})
function print() end
Minimap = stub({ GetParent = function() return UIParent end, GetFrameStrata = function() return "LOW" end,
                 GetFrameLevel = function() return 2 end, GetWidth = function() return 100 end })
frames = {}
function CreateFrame(kind, name, parent)
  local fr = stub({ kind = kind, name = name, parentFrame = parent, scripts = {}, shown = false,
    SetScript = function(s, k, f) s.scripts[k] = f end, SetShown = function(s, v) s.shown = v end,
    Show = function(s) s.shown = true end, Hide = function(s) s.shown = false end,
    SetAlpha = function(s, a) s.alpha = a end, IsShown = function(s) return s.shown end,
    SetSize = function(s, w) s.w = w end,
    SetMinMaxValues = function(s, a, b) s.min, s.max = a, b end,
    SetValue = function(s, v)
      if s.min then v = math.max(s.min, math.min(s.max, v)) end
      s.cur = v; if s.scripts.OnValueChanged then s.scripts.OnValueChanged(s, v) end end,
    CreateTexture = function(s) s.texs = s.texs or {}; s.texs[#s.texs + 1] = stub({ SetVertexColor = function(t, r) t.dim = r end,
                                             SetTexture = function(t, p) t.path = p end,
                                             -- like the game: four numbers, or it errors (12 Nov 2026: a nil
                                             -- fill fired 1,040 errors from the coordinates ticker)
                                             SetColorTexture = function(t, r, g, b, a)
                                               local v = { r, g, b }
                                               for i = 1, 3 do
                                                 assert(type(v[i]) == "number", "bad argument #" .. i .. " to 'SetColorTexture'")
                                               end
                                               t.colour = { r, g, b, a }
                                             end }); return s.texs[#s.texs] end,
    CreateFontString = function() return stub({ SetText = function(t, x) t.text = x end }) end })
  frames[#frames + 1] = fr
  return fr
end
function mapframe() for _, f in ipairs(frames) do if f.tex then return f end end end
function named(n) for _, f in ipairs(frames) do if f.name == n then return f end end end
function click() named('HomelandMinimapButton').scripts.OnClick(named('HomelandMinimapButton')) end
function tab(i) local p = named('HomelandPanel'); p.tabs[i].scripts.OnClick(p.tabs[i]) end
""")
lua.execute(f"local f = load([==[{SRC}]==], 'Homeland', 't', _G); f('Homeland')")
lua.execute("frames[1].scripts.OnEvent(); named('HomelandMinimapButton').scripts.OnEvent()")
m = lua.eval("mapframe()")
close = lambda a, b: abs(a - b) < 1e-6
# the square by default, at the one opacity (100%)
assert m.shown and close(m.alpha, 1) and close(m.w, 140) and m.tex.path.endswith("map_night_elf"), (m.alpha, m.w, m.tex.path)
lua.execute("click()")
p = lua.eval("named('HomelandPanel')")
assert p.shown and close(p.opacity.cur, 1) and close(p.opacity.max, 1), "opacity, 0 to 100%"
assert close(p.size.cur, 1.4) and close(p.size.min, 1.2) and close(p.size.max, 2.2), "size, the square's range"
assert p.caps is None and p.alpha is None, "no other sliders"
lua.execute("named('HomelandPanel').size:SetValue(1.62)")
assert close(m.w, 160) and close(lua.eval("HomelandDB.style.painted.size"), 1.6), m.w   # snapped to 0.05 steps
lua.execute("named('HomelandPanel').size:SetValue(1.4)")
lua.execute("named('HomelandPanel').opacity:SetValue(0.31)")
assert close(m.alpha, 0.3) and close(lua.eval("HomelandDB.opacity"), 0.3), m.alpha     # snapped to 0.05 steps
# the Art nouveau tab keeps the same opacity; size comes from its own default
lua.execute("tab(2)")
assert m.tex.path.endswith("nouveau_night_elf") and close(m.alpha, 0.3) and close(m.w, 170), (m.tex.path, m.alpha, m.w)
assert close(p.size.min, 1.6) and close(p.size.cur, 1.7), "the nouveau frame's own range and size"
lua.execute("named('HomelandPanel').size:SetValue(1.0)")
assert close(m.w, 160), m.w                                            # can't go under 1.6
lua.execute("tab(1)")
assert m.tex.path.endswith("map_night_elf") and close(m.w, 140)
# opacity 0 turns it off, raising it brings it back
lua.execute("named('HomelandPanel').opacity:SetValue(0)")
assert not m.shown
lua.execute("named('HomelandPanel').opacity:SetValue(0.6)")
assert m.shown and close(m.alpha, 0.6)
# slash commands: style, size (clamped per style), opacity
lua.execute("SlashCmdList.HOMELAND('map nouveau')")
assert m.tex.path.endswith("nouveau_night_elf")
lua.execute("SlashCmdList.HOMELAND('map square'); SlashCmdList.HOMELAND('map 9')")
assert close(m.w, 220), m.w                                            # clamped to the square's 2.2
lua.execute("SlashCmdList.HOMELAND('opacity 0.7')")
assert close(m.alpha, 0.7)
lua.execute("click()")
assert not p.shown
assert lua.eval("UISpecialFrames[1]") == "HomelandPanel"
# an old saved capAlpha seeds the one opacity, capped at 1
lua.execute("HomelandDB = { capAlpha = 1.5 }; SlashCmdList.HOMELAND('map on')")
assert close(m.alpha, 1) and close(lua.eval("HomelandDB.opacity"), 1)
# the coordinates' tab: a plaque under the map, a child of the frame (so it fades with it), the numbers on it in
# white with a 1 px shadow, and the numbers themselves not under the frame (so they don't fade)
tabf = lua.eval("coordsText.rel")
assert lua.eval("coordsText.rel ~= nil and coordsText.rel.parentFrame == mapframe()"), "the numbers sit on a tab that is a child of the frame"
assert lua.eval("coordsText.rel ~= nil and coordsText.rgb[1] == 1 and coordsText.rgb[3] == 1"), "white numbers"
assert list(lua.eval("coordsText.shadow").values()) == [1, -1], "1 px shadow"
for f in list(lua.eval("tickers").values()):   # the coordinates ticker runs clean
    f()
# the minimap button wears our own icon for your race, not the game's Peacebloom; a race we have no art for
# (a pandaren) gets the human one
icon = lua.eval("named('HomelandMinimapButton').texs[1].path")
assert icon.endswith("icon_night_elf") and "Interface\\AddOns\\" in icon, icon
lua.execute("UnitRace = function() return 'Pandaren', 'Pandaren' end; named('HomelandMinimapButton').scripts.OnEvent()")
assert lua.eval("named('HomelandMinimapButton').texs[1].path").endswith("icon_human")
print("map and panel checks pass")
