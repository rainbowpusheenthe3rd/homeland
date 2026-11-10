# Homeland

Trial: your race's homeland plants in place of the gryphons or wyverns at the ends of the main action bar. /homeland off|on

## Install

From a release zip: unzip the `Homeland` folder into `World of Warcraft\_forever_\Interface\AddOns`.

For development, link the game's folder to this repo (a directory junction, run once):

```powershell
New-Item -ItemType Junction -Path "<WoW folder>\_forever_\Interface\AddOns\Homeland" -Target "<this repo>"
```

`tools/` holds the generators for its art, `tests/` its smoke tests (`uv run --with lupa python tests/<file>.py`).

## Talks to

Nothing; works alone. Stillwater uses the same race palette.

## Releasing

```sh
git tag -a v1.2.0 -m "1.2.0" && git push origin v1.2.0      # builds the zip, makes the GitHub Release
git tag cf-v1.2.0 v1.2.0 && git push origin cf-v1.2.0        # uploads that same build to CurseForge
```

The CurseForge upload needs, once per repository: the variable `CURSEFORGE_PROJECT_ID` and the secret
`CF_API_TOKEN` (Settings → Secrets and variables → Actions). The game versions come from the `.toc`'s
`## Interface` line (16001 is WoW: Forever).
