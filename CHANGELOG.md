# Changelog

## 0.1.1 (2026-11-12)

- Fixed: the coordinates' tab raised a Lua error every time it refreshed ("bad argument #1 to 'SetColorTexture'"),
  which soon brought up the game's "large number of errors" warning. Its fill colour shared a name with the
  settings panel's tab colours.

## 0.1.0 (2026-11-12)

First release.

- Your race's homeland plants in place of the gryphons or wyverns at the ends of the main action bar, for the eight
  original races. Drawn on Homeland's own frame, so addons that fade the action bar don't dim them.
- `/homeland hug` (heavy end against the bar, the default) or `corner` (heavy end at the screen edge); `/homeland move`
  shows drag handles, `reset` puts the caps back.
- A minimap frame of the same plants: square painted art (1.4x the map by default) or art nouveau, `/homeland map`.
- The minimap's coordinates set into the bottom of the frame as an engraved tab, black with a rim in your race's colour.
- Minimap button: a small panel with the frame style, one Opacity slider (0-100%, all of Homeland's art) and Size.
  The coordinates' white numbers stay at full strength whatever the opacity.
- `/homeland off` brings Blizzard's art back.
