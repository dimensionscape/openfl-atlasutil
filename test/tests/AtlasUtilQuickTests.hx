package tests;

import haxe.CallStack;
import haxe.Timer;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.MovieClip;
import openfl.display.Tile;
import openfl.display.Tileset;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.utils.AtlasUtil;
import sys.FileSystem;
import sys.io.File;

using openfl.utils.AtlasUtil;

class AtlasUtilQuickTests {
	private static inline var __DEMO_IMAGE_PATH = "demo/Assets/atlas/mage_demo.png";
	private static inline var __DEMO_XML_PATH = "demo/Assets/atlas/mage_demo.xml";
	private static inline var __REPORT_PATH = "artifacts/atlasutil-quick-tests.txt";

	private static var __passed:Int = 0;
	private static var __failed:Int = 0;
	private static var __reportLines:Array<String> = [];

	public static function main():Void {
		var startedAt = Timer.stamp();

		__reportLines.push("AtlasUtil quick tests");
		__reportLines.push("Generated: " + Date.now().toString());
		__reportLines.push("");

		__run("real atlas basics", __testRealAtlasBasics);
		__run("sequence movie clips", __testSequenceMovieClips);
		__run("tileset extension interop", __testTilesetInterop);
		__run("rotated frame reconstruction", __testRotatedFrameReconstruction);
		__run("rotated tile placement", __testRotatedTilePlacement);

		var durationMs = Std.int((Timer.stamp() - startedAt) * 1000);

		__reportLines.push("");
		__reportLines.push('Summary: $__passed passed, $__failed failed, ${durationMs} ms');

		var report = __reportLines.join("\n");

		if (!FileSystem.exists("artifacts")) {
			FileSystem.createDirectory("artifacts");
		}

		File.saveContent(__REPORT_PATH, report);
		Sys.println(report);
		Sys.println("");
		Sys.println("Report artifact: " + __REPORT_PATH);

		if (__failed > 0) {
			Sys.exit(1);
		}
	}

	private static function __run(name:String, test:Void->Void):Void {
		try {
			test();
			__passed++;
			__reportLines.push("[PASS] " + name);
		} catch (error:Dynamic) {
			__failed++;
			__reportLines.push("[FAIL] " + name);
			__reportLines.push("  " + Std.string(error));

			var stack = CallStack.toString(CallStack.exceptionStack());

			if (stack != null && stack != "") {
				for (line in stack.split("\n")) {
					if (line != null && line != "") {
						__reportLines.push("  " + line);
					}
				}
			}
		}
	}

	private static function __testRealAtlasBasics():Void {
		var atlas = __createDemoAtlas();
		var standBitmap = atlas.createBitmapData("stand");

		__assertArrayEquals(["stand", "walk0001", "walk0002", "walk0003"], atlas.subTextureIds);
		__assertTrue(atlas.hasSubTexture("stand"), "Expected stand frame to exist.");
		__assertFalse(atlas.hasSubTexture("missing"), "Missing frame should not exist.");

		var standFrame = atlas.getSubTextureFrame("stand");
		__assertEquals(32, standFrame.frameWidth);
		__assertEquals(74, standFrame.frameHeight);
		__assertEquals(2, Std.int(standFrame.region.x));
		__assertEquals(2, Std.int(standFrame.region.y));
		__assertEquals(32, Std.int(standFrame.region.width));
		__assertEquals(60, Std.int(standFrame.region.height));
		__assertEquals(-4, standFrame.frameY);

		standFrame.region.x = -999;
		__assertEquals(2, Std.int(atlas.getSubTextureFrame("stand").region.x), "Frame metadata should be returned as a snapshot.");

		__assertEquals(32, standBitmap.width);
		__assertEquals(74, standBitmap.height);
		__assertEquals(0, standBitmap.getPixel32(0, 0));
		__assertTrue(__hasVisiblePixels(standBitmap), "Expected reconstructed frame to contain visible pixels.");
		__assertTrue(standBitmap == atlas.createBitmapData("stand"), "BitmapData lookups should hit the cache.");
		__assertTrue(standBitmap != atlas.createBitmapData("stand", true), "Cloned bitmap data should return a new instance.");

		atlas.dispose(true);
		__assertThrows(function():Void {
			atlas.createBitmapData("stand");
		}, "AtlasUtil has been disposed.");
	}

	private static function __testSequenceMovieClips():Void {
		var atlas = __createDemoAtlas();
		var clip = atlas.createMovieClip("walk", 12, true);
		var bitmap:Bitmap = cast clip.getChildAt(0);

		__assertTrue(atlas.hasSequence("walk", false), "walk sequence should exist.");
		__assertFalse(atlas.hasSequence("idle", false), "idle sequence should not exist.");
		__assertArrayEquals(["walk0001", "walk0002", "walk0003"], atlas.getSequenceSubTextureIds("walk", false));

		__assertEquals(3, clip.totalFrames);
		__assertEquals(1, clip.currentFrame);
		__assertTrue(bitmap.bitmapData == atlas.createBitmapData("walk0001"), "MovieClip should start on the first walk frame.");

		clip.gotoAndStop(2);
		__assertEquals(2, clip.currentFrame);
		__assertTrue(bitmap.bitmapData == atlas.createBitmapData("walk0002"), "Frame 2 should resolve to walk0002.");

		clip.gotoAndStop("walk0003");
		__assertEquals(3, clip.currentFrame);
		__assertTrue(bitmap.bitmapData == atlas.createBitmapData("walk0003"), "Label lookup should resolve to walk0003.");

		atlas.dispose(true);
	}

	private static function __testTilesetInterop():Void {
		var atlas = __createDemoAtlas();
		var tileset = atlas.createTileset();
		var standTileId = tileset.getTileId("stand");
		var standTile = tileset.createTile("stand", 10, 20);
		var assignedTile = tileset.createTileById(standTileId, 1, 2, true);

		__assertTrue(AtlasUtil.isAtlasTileset(tileset), "Expected AtlasUtil-created tileset metadata.");
		__assertTrue(tileset.hasSubTextureId("stand"), "stand tile should exist.");
		__assertFalse(tileset.hasSubTextureId("missing"), "Missing tile should not exist.");
		__assertEquals("stand", tileset.getSubTextureId(standTileId));
		__assertEquals(standTileId, standTile.id);
		__assertFloatEquals(10, standTile.x);
		__assertFloatEquals(24, standTile.y);
		__assertFloatEquals(0, standTile.rotation);
		__assertEquals(standTileId, assignedTile.id);
		__assertFloatEquals(1, assignedTile.x);
		__assertFloatEquals(6, assignedTile.y);
		__assertTrue(assignedTile.tileset == tileset, "assignTileset should populate tile.tileset.");

		atlas.dispose(true);
	}

	private static function __testRotatedFrameReconstruction():Void {
		for (rotation in [90, 180, 270]) {
			var fixture = __createRotatedFixture(rotation);
			var frame = fixture.atlas.getSubTextureFrame("rot");
			var restored = fixture.atlas.createBitmapData("rot");

			__assertBitmapEquals(fixture.expected, restored, "rotation " + rotation);
			__assertEquals(rotation, frame.rotation);
			__assertEquals(4, frame.frameWidth);
			__assertEquals(4, frame.frameHeight);
			__assertEquals(2, frame.sourceWidth);
			__assertEquals(3, frame.sourceHeight);

			if (rotation == 180) {
				__assertEquals(2, Std.int(frame.region.width));
				__assertEquals(3, Std.int(frame.region.height));
			} else {
				__assertEquals(3, Std.int(frame.region.width));
				__assertEquals(2, Std.int(frame.region.height));
			}

			fixture.expected.dispose();
			fixture.atlas.dispose(true);
		}
	}

	private static function __testRotatedTilePlacement():Void {
		for (rotation in [90, 180, 270]) {
			var fixture = __createRotatedFixture(rotation);
			var tileset = fixture.atlas.createTileset();
			var tile = tileset.createTile("rot", 10, 20);

			switch (rotation) {
				case 90:
					__assertFloatEquals(11, tile.x, "Unexpected x offset for 90 degree tile.");
					__assertFloatEquals(24, tile.y, "Unexpected y offset for 90 degree tile.");
					__assertFloatEquals(-90, tile.rotation, "Unexpected tile rotation for 90 degree frame.");
				case 180:
					__assertFloatEquals(13, tile.x, "Unexpected x offset for 180 degree tile.");
					__assertFloatEquals(24, tile.y, "Unexpected y offset for 180 degree tile.");
					__assertFloatEquals(180, tile.rotation, "Unexpected tile rotation for 180 degree frame.");
				case 270:
					__assertFloatEquals(13, tile.x, "Unexpected x offset for 270 degree tile.");
					__assertFloatEquals(21, tile.y, "Unexpected y offset for 270 degree tile.");
					__assertFloatEquals(90, tile.rotation, "Unexpected tile rotation for 270 degree frame.");
				default:
			}

			__assertEquals("rot", tileset.getSubTextureId(tile.id));
			__assertTrue(tileset.hasSubTextureId("rot"), "Rotated tile should resolve by sub texture ID.");

			fixture.expected.dispose();
			fixture.atlas.dispose(true);
		}
	}

	private static function __createDemoAtlas():AtlasUtil {
		var bitmapData = BitmapData.fromFile(__DEMO_IMAGE_PATH);
		__assertTrue(bitmapData != null, "Failed to load demo atlas bitmap data.");
		return new AtlasUtil(bitmapData, File.getContent(__DEMO_XML_PATH), __DEMO_IMAGE_PATH, __DEMO_XML_PATH);
	}

	private static function __createRotatedFixture(rotation:Int):{atlas:AtlasUtil, expected:BitmapData} {
		var expected = new BitmapData(4, 4, true, 0);
		var source = new BitmapData(2, 3, true, 0);
		var colors = [
			0xFFFF0000,
			0xFF00FF00,
			0xFF0000FF,
			0xFFFFFF00,
			0xFFFF00FF,
			0xFF00FFFF
		];
		var colorIndex = 0;

		for (y in 0...3) {
			for (x in 0...2) {
				var color = colors[colorIndex++];
				source.setPixel32(x, y, color);
				expected.setPixel32(x + 1, y + 1, color);
			}
		}

		var packed = __rotateClockwise(source, rotation);
		var atlasBitmapData = new BitmapData(packed.width, packed.height, true, 0);
		atlasBitmapData.copyPixels(packed, packed.rect, new Point());

		var xml = '<TextureAtlas imagePath="">'
			+ '<SubTexture name="rot" x="0" y="0" width="${packed.width}" height="${packed.height}" rotation="$rotation" frameX="-1" frameY="-1" frameWidth="4" frameHeight="4"/>'
			+ "</TextureAtlas>";

		source.dispose();
		packed.dispose();

		return {
			atlas: new AtlasUtil(atlasBitmapData, xml),
			expected: expected
		};
	}

	private static function __rotateClockwise(source:BitmapData, rotation:Int):BitmapData {
		return switch (rotation) {
			case 90:
				var result = new BitmapData(source.height, source.width, true, 0);

				for (y in 0...source.height) {
					for (x in 0...source.width) {
						result.setPixel32(source.height - 1 - y, x, source.getPixel32(x, y));
					}
				}

				result;
			case 180:
				var result = new BitmapData(source.width, source.height, true, 0);

				for (y in 0...source.height) {
					for (x in 0...source.width) {
						result.setPixel32(source.width - 1 - x, source.height - 1 - y, source.getPixel32(x, y));
					}
				}

				result;
			case 270:
				var result = new BitmapData(source.height, source.width, true, 0);

				for (y in 0...source.height) {
					for (x in 0...source.width) {
						result.setPixel32(y, source.width - 1 - x, source.getPixel32(x, y));
					}
				}

				result;
			default:
				throw "Unsupported rotation fixture: " + rotation;
		};
	}

	private static function __hasVisiblePixels(bitmapData:BitmapData):Bool {
		for (y in 0...bitmapData.height) {
			for (x in 0...bitmapData.width) {
				if ((bitmapData.getPixel32(x, y) >>> 24) != 0) {
					return true;
				}
			}
		}

		return false;
	}

	private static function __assertBitmapEquals(expected:BitmapData, actual:BitmapData, label:String):Void {
		__assertEquals(expected.width, actual.width, label + " width mismatch.");
		__assertEquals(expected.height, actual.height, label + " height mismatch.");

		for (y in 0...expected.height) {
			for (x in 0...expected.width) {
				var expectedPixel = expected.getPixel32(x, y);
				var actualPixel = actual.getPixel32(x, y);

				if (expectedPixel != actualPixel) {
					throw '$label pixel mismatch at ($x, $y): expected 0x${StringTools.hex(expectedPixel, 8)}, got 0x${StringTools.hex(actualPixel, 8)}.';
				}
			}
		}
	}

	private static function __assertArrayEquals(expected:Array<String>, actual:Array<String>):Void {
		__assertEquals(expected.length, actual.length, "Array length mismatch.");

		for (index in 0...expected.length) {
			__assertEquals(expected[index], actual[index], "Array mismatch at index " + index + ".");
		}
	}

	private static function __assertThrows(callback:Void->Void, expectedMessage:String):Void {
		var threw = false;

		try {
			callback();
		} catch (error:Dynamic) {
			threw = true;
			__assertTrue(Std.string(error).indexOf(expectedMessage) != -1, 'Expected error containing "$expectedMessage", got "${Std.string(error)}".');
		}

		__assertTrue(threw, "Expected callback to throw.");
	}

	private static function __assertTrue(condition:Bool, ?message:String):Void {
		if (!condition) {
			throw message != null ? message : "Assertion failed.";
		}
	}

	private static function __assertFalse(condition:Bool, ?message:String):Void {
		__assertTrue(!condition, message != null ? message : "Assertion failed.");
	}

	private static function __assertEquals(expected:Dynamic, actual:Dynamic, ?message:String):Void {
		if (expected != actual) {
			throw (message != null ? message + " " : "") + 'Expected "$expected" but got "$actual".';
		}
	}

	private static function __assertFloatEquals(expected:Float, actual:Float, ?message:String, epsilon:Float = 0.0001):Void {
		if (Math.abs(expected - actual) > epsilon) {
			throw (message != null ? message + " " : "") + 'Expected "$expected" but got "$actual".';
		}
	}
}
