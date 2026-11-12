r"""Smoke-test Homeland.lua with stub frames: caps drawn on Homeland's own frame on login (Blizzard's cap textures
kept at 0 opacity, so whatever fades the bar can't dim them), re-applied after Blizzard's UpdateEndCaps, off/on,
hug/corner, and a drag in move mode that shifts both caps mirrored."""
from pathlib import Path

import lupa

SRC = (Path(__file__).resolve().parents[1] / "Homeland.lua").read_text(encoding="utf-8")
lua = lupa.LuaRuntime()
lua.execute(r"""
log = {}
local noop = function() end
local function stub(t)   -- any method we don't define is a no-op
  return setmetatable(t, { __index = function(_, k) if k:match("^%u") then return noop end end })
end
local function tex(name)
  return stub({ name = name, points = {},
    SetTexture = function(s, p) s.path = p end, SetAtlas = function(s, a) s.path = "atlas:" .. a end,
    SetAlpha = function(s, a) s.alpha = a end, Show = function(s) s.shown = true end, Hide = function(s) s.shown = false end,
    SetShown = function(s, v) s.shown = v and true or false end,
    SetPoint = function(s, p, rel, rp, x, y) s.points[p] = { x, y } end, ClearAllPoints = function(s) s.points = {} end })
end
local function cap(t) t.GetFrameStrata = function() return "MEDIUM" end; t.GetFrameLevel = function() return 3 end; return t end
MainActionBar = { EndCaps = stub({ LeftEndCap = cap({ Texture = tex("L") }), RightEndCap = cap({ Texture = tex("R") }) }) }
function MainActionBar:UpdateEndCaps()
  self.EndCaps.LeftEndCap.Texture:SetAtlas("ui-hud-actionbar-gryphon-left")
  self.EndCaps.RightEndCap.Texture:SetAtlas("ui-hud-actionbar-gryphon-right")
end
function hooksecurefunc(t, k, f) local o = t[k]; t[k] = function(...) local r = o(...); f(...); return r end end
function UnitRace() return "Night Elf", "NightElf" end
SlashCmdList = {}
tickers = {}
C_Timer = { NewTicker = function(_, f) tickers[#tickers + 1] = f end, After = function(_, f) f() end }
UIParent = {}
cursor = { 500, 300 }
function GetCursorPosition() return cursor[1], cursor[2] end
function print(...) log[#log + 1] = table.concat({...}, " ") end
frames = {}
function CreateFrame()
  local fr = stub({ scripts = {}, shown = false,
    SetScript = function(s, k, f) s.scripts[k] = f end, SetShown = function(s, v) s.shown = v end,
    IsShown = function(s) return s.shown end, GetEffectiveScale = function() return 1 end,
    CreateTexture = function(s) local t = tex("own"); s.texs = s.texs or {}; s.texs[#s.texs + 1] = t; return t end,
    CreateFontString = function() return stub({}) end })
  frames[#frames + 1] = fr
  return fr
end
function fire() frames[1].scripts.OnEvent() end
-- Homeland's own cap texture for a side ("left"/"right"): frames[2] is the holder it makes on the first apply
function own(side)
  for _, t in ipairs(frames[2].texs or {}) do if t.path and t.path:find("_" .. side) then return t end end
end
""")
lua.execute(f"local f = load([==[{SRC}]==], 'Homeland', 't', _G); f('Homeland')")
L = lambda: lua.eval("own('left').path")
B = lambda: lua.eval("MainActionBar.EndCaps.LeftEndCap.Texture")
pt = lambda side: tuple(lua.eval(f"own('{side.lower()}').points.TOPLEFT").values())
lua.eval("fire")()
assert B().alpha == 0, "Blizzard's cap texture is hidden under ours"
assert lua.eval("own('left').shown") and lua.eval("own('left').alpha") == 1, "ours shows at its own opacity"
assert L() == r"Interface\AddOns\Homeland\cap_night_elf_left_hug", L()   # hug is the default
assert pt("Left") == (-31, 6), pt("Left")
lua.execute("MainActionBar:UpdateEndCaps()")
assert L().endswith("cap_night_elf_left_hug"), "not re-applied after Blizzard's update: " + L()
lua.execute("SlashCmdList.HOMELAND('off')")
assert B().path == "atlas:ui-hud-actionbar-gryphon-left" and B().alpha == 1, (B().path, B().alpha)
assert not lua.eval("own('left').shown"), "ours is hidden when off"
lua.execute("SlashCmdList.HOMELAND('on')")
lua.execute("SlashCmdList.HOMELAND('hug')")
assert lua.eval("own('left').shown") and B().alpha == 0
assert L().endswith("cap_night_elf_left_hug"), L()
assert pt("Left") == (-31, 6) and pt("Right") == (31, 6), (pt("Left"), pt("Right"))
# drag the left handle 20 px left (outwards) and 5 px up: both caps move out 20, up 5
lua.execute("SlashCmdList.HOMELAND('move')")
h = lua.eval("frames[3]")
assert h.shown
lua.execute("frames[3].scripts.OnMouseDown(frames[3]); cursor = { 480, 305 }; frames[3].scripts.OnUpdate(frames[3]); frames[3].scripts.OnMouseUp(frames[3])")
# handles are made in pairs() order, so frames[3] may be either side: dragging left is outwards for the left
# cap (31 + 20) and inwards for the right cap (31 - 20); either way both caps move, mirrored
out = tuple(lua.eval("HomelandDB.offset.hug").values())
assert out in ((51, 11), (11, 11)), out
assert pt("Left") == (-out[0], 11) and pt("Right") == (out[0], 11), (pt("Left"), pt("Right"))
lua.execute("SlashCmdList.HOMELAND('corner')")
assert pt("Left") == (0, 0), "corner keeps its own offset"
lua.execute("SlashCmdList.HOMELAND('hug'); SlashCmdList.HOMELAND('reset')")
assert pt("Left") == (-31, 6), pt("Left")
# one opacity, 0 to 1, from /homeland opacity (or the old /homeland caps)
lua.execute("SlashCmdList.HOMELAND('opacity 0.5')")
assert lua.eval("own('left').alpha") == 0.5 and lua.eval("own('right').alpha") == 0.5
lua.execute("SlashCmdList.HOMELAND('caps 9')")
assert lua.eval("own('left').alpha") == 1, "capped at 100%"
lua.execute("SlashCmdList.HOMELAND('opacity 0')")
assert not lua.eval("own('left').shown"), "0 hides the caps"
print("all checks pass;", list(lua.eval("log").values()))
