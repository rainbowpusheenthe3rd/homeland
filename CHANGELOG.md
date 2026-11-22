# Changelog

## Unreleased

- Dream wreaths, for Shan'do's meditations: while one plays, the minimap can wear that meditation's own wreath, fading in at the start and back to yours as the frogs fade. Only Shan'do asks for it. Each dream wreath is drawn at its own size, so its inner edge rings the map (and grows with yours if you've made yours bigger), at your opacity, and only if your frame is showing; nothing is saved. Two so far: oak, acorns, bramble and stag beetles for The acorn; poppies and ember-red maple for the ember meditation.
- Fixed an issue where a change of art arriving while the frame was still fading was ignored. It now finishes the first fade at once and starts the second.

## 0.4.0 (2026-11-20)

- A new minimap style, Wreath, and the new default: a round wreath of your race's plants, sized so its inner edge rings the round map. Each race has its own: dog roses and wheat for humans, pine and heather for dwarves, moonflowers for night elves, blueberries and brass cogs for gnomes, a thorn ring with tusks for orcs, ivy and death caps for the undead, prairie flowers for tauren, palms and orchids for trolls, and blossom, maple and dandelion clocks for the Skyborne.
- The square painting and the art nouveau frame are still there: the panel now has three tabs (Wreath, Square, Art nouveau), and `/homeland map wreath | square | nouveau` switches too. Each style keeps its own size.
- If you never picked a style, you'll now see the Wreath; one click on Square brings the old look back. A style you picked yourself is kept.

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
