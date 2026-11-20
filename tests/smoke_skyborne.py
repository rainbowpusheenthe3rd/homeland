r"""Smoke-test Homeland's Skyborne art: the shared wreath on Zephras Isle, a fade to the side's wreath on leaving it,
the side remembered after that, a Neutral Skyborne kept on the shared wreath, and one icon for every Skyborne.

    uv run --no-project --with lupa python tests/smoke_skyborne.py

The game stubs are smoke_map.py's (its setup, read up to where it loads the addon), with textures that also know
their parent, draw layer and opacity, and a clock.
"""
from pathlib import Path

import lupa

HERE = Path(__file__).resolve().parent
SRC = (HERE.parent / "Homeland.lua").read_text(encoding="utf-8")
setup = (HERE / "smoke_map.py").read_text(encoding="utf-8")
setup = setup[setup.index('lua.execute(r"""') + len('lua.execute(r"""'):setup.index('""")\nlua.execute(f"local f = load')]
lua = lupa.LuaRuntime()
lua.execute(setup)
lua.execute(r"""
NOW, SIDE, ZONE = 100, "Horde", "Zephras Isle"
function GetTime() return NOW end
function UnitFactionGroup() return SIDE end
function GetRealZoneText() return ZONE end
function UnitRace() return "Skyborne", "Skyborne" end
local CF = CreateFrame
CreateFrame = function(...)
  local fr = CF(...)
  local ct = fr.CreateTexture
  fr.CreateTexture = function(s, ...)
    local t = ct(s, ...)
    t.parent = s
    t.GetParent = function(x) return x.parent end
    t.GetDrawLayer = function() return "BACKGROUND", 0 end
    t.SetAlpha = function(x, a) x.alpha = a end
    t.Show = function(x) x.shown = true end
    t.Hide = function(x) x.shown = false end
    return t
  end
  return fr
end
function tick(at) NOW = at; for _, f in ipairs(frames) do if f.scripts.OnUpdate then f.scripts.OnUpdate(f) end end end
""")
lua.execute(f"local f = load([==[{SRC}]==], 'Homeland', 't', _G); f('Homeland')")
event = "frames[1].scripts.OnEvent(); named('HomelandMinimapButton').scripts.OnEvent()"
fails = 0


def check(ok, what):
    global fails
    print(("ok   " if ok else "FAIL ") + what)
    fails += not ok


lua.execute(event)
m = lua.eval("mapframe()")
check(m.tex.path.endswith("wreath_skyborne"), "on Zephras Isle: the shared Skyborne wreath")
check(lua.eval("named('HomelandMinimapButton').texs[1].path").endswith("icon_skyborne"), "the Skyborne icon")
check(lua.eval("HomelandDB.skySide") is None, "no side remembered yet")

lua.execute(f'ZONE = "Thunder Bluff"; {event}')
check(m.tex.path.endswith("wreath_skyborne") and m.tex.over.path.endswith("wreath_skyborne_horde"),
      "leaving the isle: the Horde wreath starts fading in over the shared one")
lua.execute("tick(102)")
check(abs(m.tex.over.alpha - 0.5) < 1e-6 and abs(m.tex.alpha - 0.5) < 1e-6, "halfway through the fade: half and half")
lua.execute(f"{event}; tick(102.5)")
check(m.tex.alpha < 0.5, "a refresh mid-fade doesn't restart or jump it")
lua.execute("tick(105)")
check(m.tex.path.endswith("wreath_skyborne_horde") and m.tex.alpha == 1 and not m.tex.over.shown,
      "after the fade: the Horde wreath, full strength, the overlay gone")
check(lua.eval("HomelandDB.skySide") == "Horde", "the side is remembered")
check(lua.eval("named('HomelandMinimapButton').texs[1].path").endswith("icon_skyborne"), "the icon stays the Skyborne one")

lua.execute(f'ZONE = "Zephras Isle"; {event}')
check(m.tex.path.endswith("wreath_skyborne_horde") and not m.tex.over.shown, "back on the isle: still Horde, no fade back")

lua.execute(f'HomelandDB.skySide = nil; SIDE, ZONE = "Neutral", "Stormwind City"; {event}; tick(200)')
check(m.tex.path.endswith("wreath_skyborne") and not m.tex.path.endswith("horde"), "a Neutral Skyborne keeps the shared wreath")

lua.execute(f'SIDE = "Alliance"; {event}; tick(210)')
check(m.tex.path.endswith("wreath_skyborne_alliance"), "choosing Alliance off the isle fades to the Alliance wreath")

lua.execute(f'UnitRace = function() return "Night Elf", "NightElf" end; {event}')
check(m.tex.path.endswith("wreath_night_elf"), "other races are set at once, unchanged")
print(f"{fails} failed")
raise SystemExit(1 if fails else 0)
