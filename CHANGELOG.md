# Changelog

## 0.3.0 (2026-11-20)

- Skyborne get their own art. On Zephras Isle, where both sides start, every Skyborne shares one wind-blown wreath (orchard blossom, gustberries, silverleaf, dandelion clocks) with matching bar end caps. On leaving the isle, or choosing a side, the frame fades over 4 seconds to the same wreath with two small cornflowers: red for the Horde, blue for the Alliance. Your side is remembered after that, even back on the isle.
- One minimap button icon for every Skyborne.
- The minimap button's flower has a thin dark ring outside its gold ring, so it stands out on light ground.

## 0.2.0 (2026-11-15)

- The minimap button has its own icon instead of the game's Peacebloom: a plant from your race's own art (a dog
  rose for humans, heather for dwarves, a moonflower for night elves, a glowing mushroom for gnomes, a desert
  flower for orcs, pale mushrooms for the undead, a feather for tauren, an orchid for trolls). A race Homeland has
  no art for gets the rose.
- Homeland has an icon in the addon list too (the night elf moonflower).

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
