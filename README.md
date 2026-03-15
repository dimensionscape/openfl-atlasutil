# openfl-atlasutil

`openfl-atlasutil` is an OpenFL extension for working with Sparrow / TexturePacker atlases.

It focuses on a single utility class, `openfl.utils.AtlasUtil`, which can:

- load Sparrow atlas XML plus image assets from OpenFL `Assets`
- reconstruct trimmed subtextures as `BitmapData` or `Bitmap`
- restore right-angle rotated frames (`90`, `180`, `270`)
- build ordered atlas sequences as real `MovieClip` instances
- create atlas-backed `Tileset` values
- extend `openfl.display.Tileset` with atlas-aware helper methods through Haxe `using`

The library is currently packaged as a preview release.

## Why this is an OpenFL extension

This library does not replace OpenFL types. It layers atlas-specific behavior on top of them.

The best example is `Tileset` support. `AtlasUtil` creates a normal OpenFL `Tileset`, then Haxe static extensions make atlas helpers feel like native `Tileset` methods when you opt in with:

```haxe
using openfl.utils.AtlasUtil;
```

That means this:

```haxe
using openfl.utils.AtlasUtil;

var atlas = AtlasUtil.load("assets/atlas/mage_demo.xml");
var tileset = atlas.createTileset();

if (tileset.hasSubTextureId("walk0001")) {
    var tile = tileset.createTile("walk0001", 64, 32);
    tilemap.addTile(tile);
}
```

is resolved by Haxe to compatible static methods on `AtlasUtil`. It is an OpenFL extension pattern, not a custom `Tileset` API that replaces OpenFL.

## Install

Once published:

```bash
haxelib install openfl-atlasutil
```

Then add it to your OpenFL project:

```xml
<haxelib name="openfl-atlasutil" />
```

## Quick start

```haxe
import openfl.display.Bitmap;
import openfl.display.MovieClip;
import openfl.utils.AtlasUtil;

var atlas = AtlasUtil.load("assets/atlas/mage_demo.xml");

var stand:Bitmap = atlas.createBitmap("stand", true);
addChild(stand);

var walk:MovieClip = atlas.createMovieClip("walk", 12, true);
walk.x = 160;
addChild(walk);
```

## Tileset extension usage

```haxe
import openfl.display.Tilemap;
import openfl.display.Tileset;
import openfl.utils.AtlasUtil;

using openfl.utils.AtlasUtil;

var atlas = AtlasUtil.load("assets/atlas/mage_demo.xml");
var tileset:Tileset = atlas.createTileset();
var tilemap = new Tilemap(512, 512, tileset, true);

if (tileset.hasSubTextureId("stand")) {
    tilemap.addTile(tileset.createTile("stand", 0, 0));
}

var walkTileId = tileset.getTileId("walk0001");
trace(tileset.getSubTextureId(walkTileId));
tilemap.addTile(tileset.createTileById(walkTileId, 128, 0, true));
```

## API summary

Main entry points on `AtlasUtil`:

- `load`
- `createBitmapDataFromAssets`
- `createBitmapFromAssets`
- `createMovieClipFromAssets`
- `createTilesetFromAssets`
- `createBitmapData`
- `createBitmap`
- `createMovieClip`
- `createTileset`

`Tileset` extension helpers exposed through `using AtlasUtil`:

- `isAtlasTileset`
- `hasSubTextureId`
- `getTileId`
- `getSubTextureId`
- `createTile`
- `createTileById`

## Demo

A complete OpenFL demo project is included under [`demo/`](demo).

From the library root:

```bash
cd demo
openfl test html5
```

The demo uses the bundled sample atlas in `demo/Assets/atlas`.

The bundled demo atlas is derived from `Mage sprites (Idle and Walking)` by
Sollision on OpenGameArt, licensed `CC0 / Public Domain`.

## Tests

A lightweight correctness runner is included under [`test/`](test).

Compile and run it from the library root:

```bash
haxe test/AtlasUtilQuickTests.hxml
neko bin/tests/atlasutil_quick_tests.n
```

It writes a text report to:

```text
artifacts/atlasutil-quick-tests.txt
```

Coverage includes:

- real atlas parsing and bitmap reconstruction
- sequence `MovieClip` behavior
- `Tileset` static extension interop
- synthetic rotated and trimmed frame restoration
- rotated tile placement

## Haxelib submission checklist

Suggested release flow:

```bash
haxelib submit openfl-atlasutil.zip
```

Typical prep:

1. Zip the library root contents, not the parent folder.
2. Exclude generated output such as `demo/bin`, `bin`, and `artifacts`.
3. Confirm `haxelib.json` version and releasenote are updated.
4. Confirm the public repo URL in `haxelib.json` is the final one you want to publish.

## License

MIT
