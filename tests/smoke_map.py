r"""Smoke-test Homeland's minimap art and its panel: the square by default (opacity 0.5, size 1.45), the Art
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
UIParent = {}
UISpecialFrames = {}
tinsert = table.insert
GameTooltip = stub({})
function print() end
Minimap = stub({ GetParent = function() return UIParent end, GetFrameStrata = function() return "LOW" end,
                 GetFrameLevel = function() return 2 end, GetWidth = function() return 100 end })
frames = {}
function CreateFrame(kind, name)
  local fr = stub({ kind = kind, name = name, scripts = {}, shown = false,
    SetScript = function(s, k, f) s.scripts[k] = f end, SetShown = function(s, v) s.shown = v end,
    Show = function(s) s.shown = true end, Hide = function(s) s.shown = false end,
    SetAlpha = function(s, a) s.alpha = a end, IsShown = function(s) return s.shown end,
    SetSize = function(s, w) s.w = w end,
    SetMinMaxValues = function(s, a, b) s.min, s.max = a, b end,
    SetValue = function(s, v)
      if s.min then v = math.max(s.min, math.min(s.max, v)) end
      s.cur = v; if s.scripts.OnValueChanged then s.scripts.OnValueChanged(s, v) end end,
    CreateTexture = function() return stub({ SetVertexColor = function(t, r) t.dim = r end,
                                             SetTexture = function(t, p) t.path = p end }) end,
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
assert m.shown and close(m.alpha, 1) and close(m.w, 145) and m.tex.path.endswith("map_night_elf"), (m.alpha, m.w, m.tex.path)
lua.execute("click()")
p = lua.eval("named('HomelandPanel')")
assert p.shown and close(p.opacity.cur, 1) and close(p.opacity.max, 1), "one slider, 0 to 100%"
assert p.size is None and p.caps is None and p.alpha is None, "no other sliders"
lua.execute("named('HomelandPanel').opacity:SetValue(0.31)")
assert close(m.alpha, 0.3) and close(lua.eval("HomelandDB.opacity"), 0.3), m.alpha     # snapped to 0.05 steps
# the Art nouveau tab keeps the same opacity; size comes from its own default
lua.execute("tab(2)")
assert m.tex.path.endswith("nouveau_night_elf") and close(m.alpha, 0.3) and close(m.w, 170), (m.tex.path, m.alpha, m.w)
lua.execute("tab(1)")
assert m.tex.path.endswith("map_night_elf") and close(m.w, 145)
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
print("map and panel checks pass")
