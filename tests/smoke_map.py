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
# the square by default, smaller and at half opacity
assert m.shown and close(m.alpha, 0.5) and close(m.w, 145) and m.tex.path.endswith("map_night_elf"), (m.alpha, m.w, m.tex.path)
lua.execute("click()")
p = lua.eval("named('HomelandPanel')")
assert p.shown and close(p.alpha.cur, 0.5) and close(p.size.cur, 1.45) and close(p.size.min, 1.2)
lua.execute("named('HomelandPanel').size:SetValue(1.62); named('HomelandPanel').alpha:SetValue(0.31)")
assert close(m.w, 160) and close(m.alpha, 0.3), (m.w, m.alpha)         # snapped to 0.05 steps
# the Art nouveau tab: its own defaults, and its size can't go under 1.6
lua.execute("tab(2)")
assert m.tex.path.endswith("nouveau_night_elf") and close(m.alpha, 1) and close(m.w, 170), (m.tex.path, m.alpha, m.w)
assert close(p.size.min, 1.6) and close(p.size.cur, 1.7) and close(p.alpha.cur, 1)
lua.execute("named('HomelandPanel').size:SetValue(1.0)")
assert close(m.w, 160), m.w
# back to the square: its settings were kept
lua.execute("tab(1)")
assert m.tex.path.endswith("map_night_elf") and close(m.w, 160) and close(m.alpha, 0.3), (m.w, m.alpha)
# opacity 0 turns it off, raising it brings it back
lua.execute("named('HomelandPanel').alpha:SetValue(0)")
assert not m.shown
lua.execute("named('HomelandPanel').alpha:SetValue(0.6)")
assert m.shown and close(m.alpha, 0.6)
# slash commands
lua.execute("SlashCmdList.HOMELAND('map nouveau')")
assert m.tex.path.endswith("nouveau_night_elf") and close(m.w, 160)
lua.execute("SlashCmdList.HOMELAND('map square'); SlashCmdList.HOMELAND('map 9')")
assert close(m.w, 220), m.w                                            # clamped to the square's 2.2
lua.execute("click()")
assert not p.shown
assert lua.eval("UISpecialFrames[1]") == "HomelandPanel"
# the bar art: its own opacity, from the panel's slider or /homeland caps, kept when the bar fades
lua.execute("named('HomelandPanel').caps:SetValue(0.42)")
assert close(lua.eval("HomelandDB.capAlpha"), 0.4)
lua.execute("SlashCmdList.HOMELAND('caps 0.7')")
assert close(lua.eval("HomelandDB.capAlpha"), 0.7)
print("map and panel checks pass")
