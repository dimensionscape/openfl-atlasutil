package demo;

import openfl.display.Bitmap;
import openfl.display.PixelSnapping;
import openfl.display.Sprite;
import openfl.display.Tilemap;
import openfl.display.Tileset;
import openfl.utils.Atlas;

using openfl.utils.Atlas;

class Main extends Sprite {
	public function new() {
		super();

		mouseEnabled = false;
		mouseChildren = false;

		var margin = 16.0;
		var gap = 24.0;
		var frameGap = 12.0;
		var displayScale = 3.0;
		var atlas = Atlas.load("assets/atlas/mage_demo.xml");
		var sourceAtlasBitmap = new Bitmap(atlas.atlasBitmapData, PixelSnapping.AUTO, false);
		sourceAtlasBitmap.smoothing = false;
		sourceAtlasBitmap.scaleX = displayScale;
		sourceAtlasBitmap.scaleY = displayScale;
		sourceAtlasBitmap.x = margin;
		sourceAtlasBitmap.y = margin;
		addChild(sourceAtlasBitmap);

		var nextBlockX = sourceAtlasBitmap.x + sourceAtlasBitmap.width + gap;
		var contentBottom = sourceAtlasBitmap.y + sourceAtlasBitmap.height;

		if (atlas.hasSequence("walk", false)) {
			var walkClip = atlas.createMovieClip("walk", 8, false);
			walkClip.scaleX = displayScale;
			walkClip.scaleY = displayScale;
			walkClip.x = nextBlockX;
			walkClip.y = sourceAtlasBitmap.y;
			addChild(walkClip);
			nextBlockX = walkClip.x + walkClip.width + gap;
			contentBottom = Math.max(contentBottom, walkClip.y + walkClip.height);
		}

		var atlasTileset:Tileset = atlas.createTileset();
		var tilemap = new Tilemap(72, 156, atlasTileset, false);
		tilemap.scaleX = displayScale;
		tilemap.scaleY = displayScale;
		tilemap.x = nextBlockX;
		tilemap.y = sourceAtlasBitmap.y;
		addChild(tilemap);
		contentBottom = Math.max(contentBottom, tilemap.y + tilemap.height);

		if (atlasTileset.hasSubTextureId("stand")) {
			tilemap.addTile(atlasTileset.createTile("stand", 0, 0));
		}

		if (atlasTileset.hasSubTextureId("walk0001")) {
			tilemap.addTile(atlasTileset.createTile("walk0001", 36, 0));
		}

		if (atlasTileset.hasSubTextureId("walk0002")) {
			tilemap.addTile(atlasTileset.createTile("walk0002", 0, 78));
		}

		if (atlasTileset.hasSubTextureId("walk0003")) {
			tilemap.addTile(atlasTileset.createTile("walk0003", 36, 78));
		}

		var cursorX = margin;
		var cursorY = contentBottom + gap;

		for (subTextureId in atlas.subTextureIds) {
			var frameBitmap = atlas.createBitmap(subTextureId, false);
			frameBitmap.scaleX = displayScale;
			frameBitmap.scaleY = displayScale;
			frameBitmap.x = cursorX;
			frameBitmap.y = cursorY;
			addChild(frameBitmap);

			cursorX += frameBitmap.width + frameGap;
		}
	}
}
