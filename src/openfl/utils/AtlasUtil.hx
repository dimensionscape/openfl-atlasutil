package openfl.utils;

import haxe.ds.StringMap;
import haxe.io.Path;
import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.FrameLabel;
import openfl.display.MovieClip;
import openfl.display.PixelSnapping;
import openfl.display.Scene;
import openfl.display.Sprite;
import openfl.display.Tile;
import openfl.display.Tileset;
import openfl.display.Timeline;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;

/**
	Loads Sparrow atlases from OpenFL assets and exposes fast helpers for
	reconstructing trimmed or rotated frames as `BitmapData`, `Bitmap`, or
	`MovieClip` instances.

	`AtlasUtil` caches both loaded atlases and reconstructed frame bitmaps so the
	common lookup path stays cheap after the first request.

	Basic usage:

	```haxe
	var atlas = AtlasUtil.load("assets/atlas/mage_demo.xml");
	var stand = atlas.createBitmap("stand");
	var walk = atlas.createMovieClip("walk", 12);
	```

	`AtlasUtil` can also expose atlas-aware helpers on `openfl.display.Tileset`
	using Haxe static extensions. This does not modify or subclass `Tileset` at
	the call site. Instead, Haxe lets compatible static methods on `AtlasUtil`
	behave like instance methods when you add:

	```haxe
	using openfl.utils.AtlasUtil;
	```

	Example:

	```haxe
	using openfl.utils.AtlasUtil;

	var atlas = AtlasUtil.load("assets/atlas/mage_demo.xml");
	var tileset = atlas.createTileset();

	if (tileset.hasSubTextureId("walk0001")) {
		var tile = tileset.createTile("walk0001", 64, 32);
		tilemap.addTile(tile);
	}
	```
**/
@:beta
class AtlasUtil {
	@:noCompletion
	private static var __atlasCache:StringMap<AtlasUtil> = new StringMap();

	/**
		Loads a Sparrow atlas from the OpenFL asset system.

		If `imageAssetId` is omitted, the atlas image path is resolved from the
		Sparrow XML `imagePath` attribute.

		@param xmlAssetId The asset ID for the Sparrow XML file.
		@param imageAssetId The optional asset ID for the atlas image.
		@return A cached `AtlasUtil` instance for the requested atlas.
	**/
	public static function load(xmlAssetId:String, ?imageAssetId:String):AtlasUtil {
		var cacheKey = xmlAssetId + "|" + (imageAssetId == null ? "" : imageAssetId);
		var cachedAtlas = __atlasCache.get(cacheKey);

		if (cachedAtlas != null) {
			return cachedAtlas;
		}

		var atlasXml = __normalizeXmlRoot(Xml.parse(Assets.getText(xmlAssetId)));
		var resolvedImageAssetId = imageAssetId;

		if (resolvedImageAssetId == null || resolvedImageAssetId == "") {
			resolvedImageAssetId = __resolveImageAssetId(xmlAssetId, atlasXml.get("imagePath"));
		}

		var atlas = new AtlasUtil(Assets.getBitmapData(resolvedImageAssetId), atlasXml, resolvedImageAssetId, xmlAssetId);
		__atlasCache.set(cacheKey, atlas);
		return atlas;
	}

	/**
		Loads a single atlas frame as reconstructed `BitmapData`.

		@param xmlAssetId The asset ID for the Sparrow XML file.
		@param subTextureId The sub texture ID to resolve.
		@param imageAssetId The optional asset ID for the atlas image.
		@param clone Whether to return a clone instead of the cached bitmap data.
		@return A reconstructed frame bitmap.
	**/
	public static function createBitmapDataFromAssets(xmlAssetId:String, subTextureId:String, ?imageAssetId:String, clone:Bool = false):BitmapData {
		return load(xmlAssetId, imageAssetId).createBitmapData(subTextureId, clone);
	}

	/**
		Loads a single atlas frame as a `Bitmap`.

		@param xmlAssetId The asset ID for the Sparrow XML file.
		@param subTextureId The sub texture ID to resolve.
		@param imageAssetId The optional asset ID for the atlas image.
		@param smoothing Whether bitmap smoothing should be enabled.
		@param pixelSnapping The bitmap pixel snapping mode.
		@param cloneBitmapData Whether to clone the underlying cached bitmap data.
		@return A bitmap displaying the requested sub texture.
	**/
	public static function createBitmapFromAssets(xmlAssetId:String, subTextureId:String, ?imageAssetId:String, smoothing:Bool = true,
			pixelSnapping:PixelSnapping = PixelSnapping.AUTO, cloneBitmapData:Bool = false):Bitmap {
		return load(xmlAssetId, imageAssetId).createBitmap(subTextureId, smoothing, pixelSnapping, cloneBitmapData);
	}

	/**
		Builds an atlas-backed `MovieClip` from sub texture IDs that share a base
		name and a numeric suffix, such as `walk0001`, `walk0002`, `walk0003`.

		@param xmlAssetId The asset ID for the Sparrow XML file.
		@param sequenceName The sequence base name to resolve.
		@param imageAssetId The optional asset ID for the atlas image.
		@param frameRate The playback frame rate for the movie clip.
		@param smoothing Whether bitmap smoothing should be enabled.
		@param pixelSnapping The bitmap pixel snapping mode.
		@return A new movie clip instance for the requested sequence.
	**/
	public static function createMovieClipFromAssets(xmlAssetId:String, sequenceName:String, ?imageAssetId:String, frameRate:Float = 24,
			smoothing:Bool = true, pixelSnapping:PixelSnapping = PixelSnapping.AUTO):MovieClip {
		return load(xmlAssetId, imageAssetId).createMovieClip(sequenceName, frameRate, smoothing, pixelSnapping);
	}

	/**
		Creates an atlas-backed `Tileset` from a Sparrow atlas.

		The resulting object is still a normal `Tileset`, but it carries atlas
		metadata internally so `AtlasUtil` can provide `Tileset` extension helpers.

		With Haxe `using`, static methods on `AtlasUtil` become extension methods on
		compatible values such as `Tileset`.

		```haxe
		using openfl.utils.AtlasUtil;

		var tileset = AtlasUtil.createTilesetFromAssets("assets/atlas/mage_demo.xml");

		if (tileset.hasSubTextureId("walk0001")) {
			trace(tileset.getTileId("walk0001"));
		}
		```

		@param xmlAssetId The asset ID for the Sparrow XML file.
		@param imageAssetId The optional asset ID for the atlas image.
		@return A new atlas-backed tileset.
	**/
	public static function createTilesetFromAssets(xmlAssetId:String, ?imageAssetId:String):Tileset {
		return load(xmlAssetId, imageAssetId).createTileset();
	}

	/**
		Returns `true` when a `Tileset` was created by `AtlasUtil`.

		This is available as a static extension when you import
		`using openfl.utils.AtlasUtil`.

		@param tileset The tileset to inspect.
		@return `true` when atlas metadata is available on the tileset.
	**/
	public static function isAtlasTileset(tileset:Tileset):Bool {
		return Std.isOfType(tileset, AtlasTileset);
	}

	/**
		Returns `true` if an atlas-backed `Tileset` contains a sub texture.

		This is available as a static extension when you import
		`using openfl.utils.AtlasUtil`.

		@param tileset The tileset to inspect.
		@param subTextureId The atlas sub texture ID to test.
		@return `true` when the sub texture exists.
	**/
	public static function hasSubTextureId(tileset:Tileset, subTextureId:String):Bool {
		return __requireAtlasTileset(tileset).hasSubTexture(subTextureId);
	}

	/**
		Returns the tile ID for an atlas sub texture.

		This is available as a static extension when you import
		`using openfl.utils.AtlasUtil`.

		@param tileset The tileset to query.
		@param subTextureId The atlas sub texture ID to resolve.
		@return The tile ID for the requested sub texture.
	**/
	public static function getTileId(tileset:Tileset, subTextureId:String):Int {
		return __requireAtlasTileset(tileset).getTileId(subTextureId);
	}

	/**
		Returns the atlas sub texture ID for a tile ID.

		This is available as a static extension when you import
		`using openfl.utils.AtlasUtil`.

		@param tileset The tileset to query.
		@param tileId The tile ID to resolve.
		@return The atlas sub texture ID for the requested tile ID.
	**/
	public static function getSubTextureId(tileset:Tileset, tileId:Int):String {
		return __requireAtlasTileset(tileset).getSubTextureId(tileId);
	}

	/**
		Creates a `Tile` for an atlas sub texture.

		This is available as a static extension when you import
		`using openfl.utils.AtlasUtil`.

		@param tileset The tileset to query.
		@param subTextureId The atlas sub texture ID to resolve.
		@param x The base x position before atlas frame offsets are applied.
		@param y The base y position before atlas frame offsets are applied.
		@param assignTileset Whether to assign the tileset directly on the tile.
		@return A configured tile for the requested sub texture.
	**/
	public static function createTile(tileset:Tileset, subTextureId:String, x:Float = 0, y:Float = 0, assignTileset:Bool = false):Tile {
		return __requireAtlasTileset(tileset).createTile(subTextureId, x, y, assignTileset);
	}

	/**
		Creates a `Tile` for an atlas-backed tile ID.

		This is available as a static extension when you import
		`using openfl.utils.AtlasUtil`.

		@param tileset The tileset to query.
		@param tileId The tile ID to resolve.
		@param x The base x position before atlas frame offsets are applied.
		@param y The base y position before atlas frame offsets are applied.
		@param assignTileset Whether to assign the tileset directly on the tile.
		@return A configured tile for the requested tile ID.
	**/
	public static function createTileById(tileset:Tileset, tileId:Int, x:Float = 0, y:Float = 0, assignTileset:Bool = false):Tile {
		return __requireAtlasTileset(tileset).createTileById(tileId, x, y, assignTileset);
	}

	/** The original atlas image bitmap data. */
	public var atlasBitmapData(get, never):BitmapData;

	/** The image asset ID used to load the atlas bitmap data. */
	public var imageAssetId(default, null):String;

	/** All sub texture IDs in the order they were declared in the Sparrow XML. */
	public var subTextureIds(get, never):Array<String>;

	/** The XML asset ID used to load the atlas metadata. */
	public var xmlAssetId(default, null):String;

	@:noCompletion
	private var __atlasBitmapData:BitmapData;

	@:noCompletion
	private var __copyPoint:Point;

	@:noCompletion
	private var __disposed:Bool = false;

	@:noCompletion
	private var __frames:StringMap<AtlasFrame>;

	@:noCompletion
	private var __bitmapDataCache:StringMap<BitmapData>;

	@:noCompletion
	private var __numberedSequenceSubTextureIdsByName:StringMap<Array<String>>;

	@:noCompletion
	private var __sequenceBitmapDataCache:StringMap<Array<BitmapData>>;

	@:noCompletion
	private var __sequenceIdsCache:StringMap<Array<String>>;

	@:noCompletion
	private var __subTextureIds:Array<String>;

	/**
		Creates a new atlas from bitmap data and Sparrow XML content.

		In most cases you should prefer `AtlasUtil.load` over calling this
		constructor directly.

		@param bitmapData The source atlas bitmap data.
		@param xmlSource The Sparrow XML as `Xml` or `String`.
		@param imageAssetId The optional source image asset ID.
		@param xmlAssetId The optional source XML asset ID.
	**/
	public function new(bitmapData:BitmapData, xmlSource:Dynamic, ?imageAssetId:String, ?xmlAssetId:String) {
		this.imageAssetId = imageAssetId;
		this.xmlAssetId = xmlAssetId;

		__atlasBitmapData = bitmapData;
		__frames = new StringMap();
		__bitmapDataCache = new StringMap();
		__numberedSequenceSubTextureIdsByName = new StringMap();
		__sequenceBitmapDataCache = new StringMap();
		__sequenceIdsCache = new StringMap();
		__subTextureIds = [];
		__copyPoint = new Point();

		__parseXml(__coerceXml(xmlSource));
	}

	/**
		Returns `true` if the atlas contains a sub texture with the requested ID.

		@param subTextureId The sub texture ID to test.
		@return `true` when the sub texture exists.
	**/
	public function hasSubTexture(subTextureId:String):Bool {
		__assertNotDisposed();
		return __frames.exists(subTextureId);
	}

	/**
		Returns metadata for a single sub texture.

		The returned value is a metadata snapshot. Mutating it does not affect the
		atlas cache.

		@param subTextureId The sub texture ID to resolve.
		@return The parsed frame metadata.
		@throws String If the sub texture does not exist.
	**/
	public function getSubTextureFrame(subTextureId:String):{
		name:String,
		region:Rectangle,
		rotation:Int,
		frameX:Int,
		frameY:Int,
		frameWidth:Int,
		frameHeight:Int,
		sourceWidth:Int,
		sourceHeight:Int,
		pivotX:Float,
		pivotY:Float
	} {
		__assertNotDisposed();

		var frame = __getSubTextureFrame(subTextureId);
		return {
			name: frame.name,
			region: frame.region.clone(),
			rotation: frame.rotation,
			frameX: frame.frameX,
			frameY: frame.frameY,
			frameWidth: frame.frameWidth,
			frameHeight: frame.frameHeight,
			sourceWidth: frame.sourceWidth,
			sourceHeight: frame.sourceHeight,
			pivotX: frame.pivotX,
			pivotY: frame.pivotY
		};
	}

	/**
		Returns a reconstructed frame bitmap for a sub texture.

		This method restores trim and rotation metadata from the Sparrow atlas and
		returns a full frame-sized bitmap.

		@param subTextureId The sub texture ID to resolve.
		@param clone Whether to clone the cached bitmap data before returning it.
		@return The reconstructed frame bitmap data.
	**/
	public function createBitmapData(subTextureId:String, clone:Bool = false):BitmapData {
		__assertNotDisposed();

		var cachedBitmapData = __bitmapDataCache.get(subTextureId);

		if (cachedBitmapData == null) {
			cachedBitmapData = __renderFrame(__getSubTextureFrame(subTextureId));
			__bitmapDataCache.set(subTextureId, cachedBitmapData);
		}

		return clone ? cachedBitmapData.clone() : cachedBitmapData;
	}

	/**
		Creates a new `Bitmap` for a single sub texture.

		@param subTextureId The sub texture ID to resolve.
		@param smoothing Whether bitmap smoothing should be enabled.
		@param pixelSnapping The bitmap pixel snapping mode.
		@param cloneBitmapData Whether to clone the underlying cached bitmap data.
		@return A bitmap displaying the requested sub texture.
	**/
	public function createBitmap(subTextureId:String, smoothing:Bool = true, pixelSnapping:PixelSnapping = PixelSnapping.AUTO,
			cloneBitmapData:Bool = false):Bitmap {
		var bitmap = new Bitmap(createBitmapData(subTextureId, cloneBitmapData), pixelSnapping, smoothing);
		bitmap.smoothing = smoothing;
		return bitmap;
	}

	/**
		Returns `true` if the atlas can resolve a frame sequence with the requested
		base name.

		When `includeExactName` is `true`, a frame with the exact same name as the
		sequence is also considered part of the result.

		@param sequenceName The sequence base name to test.
		@param includeExactName Whether an exact frame name should be included.
		@return `true` when at least one sequence frame exists.
	**/
	public function hasSequence(sequenceName:String, includeExactName:Bool = true):Bool {
		__assertNotDisposed();
		return __resolveSequenceIds(sequenceName, includeExactName).length > 0;
	}

	/**
		Resolves the ordered sub texture IDs for a frame sequence.

		Matching uses the exact sequence name optionally followed by frames whose
		names start with the sequence name and end in a numeric suffix.

		@param sequenceName The sequence base name to resolve.
		@param includeExactName Whether an exact frame name should be included.
		@return The ordered list of sub texture IDs for the sequence.
		@throws String If the sequence does not exist.
	**/
	public function getSequenceSubTextureIds(sequenceName:String, includeExactName:Bool = true):Array<String> {
		__assertNotDisposed();

		var subTextureIds = __resolveSequenceIds(sequenceName, includeExactName);

		if (subTextureIds.length == 0) {
			throw 'Unknown atlas sequence "$sequenceName".';
		}

		return subTextureIds.copy();
	}

	/**
		Creates a timeline-backed `MovieClip` from an atlas sequence.

		The resulting clip uses OpenFL's `Timeline` and supports normal movie clip
		APIs such as `play`, `stop`, `gotoAndPlay`, `gotoAndStop`, and
		`addFrameScript`.

		@param sequenceName The sequence base name to resolve.
		@param frameRate The playback frame rate for the movie clip.
		@param smoothing Whether bitmap smoothing should be enabled.
		@param pixelSnapping The bitmap pixel snapping mode.
		@return A new movie clip instance for the requested sequence.
	**/
	public function createMovieClip(sequenceName:String, frameRate:Float = 24, smoothing:Bool = true,
			pixelSnapping:PixelSnapping = PixelSnapping.AUTO):MovieClip {
		__assertNotDisposed();

		var sequenceSubTextureIds = __resolveSequenceIds(sequenceName, true);

		if (sequenceSubTextureIds.length == 0) {
			throw 'Unknown atlas sequence "$sequenceName".';
		}

		var frameBitmapData = __resolveSequenceBitmapData(sequenceName, true, sequenceSubTextureIds);
		return AtlasMovieClipTimeline.create(sequenceName, sequenceSubTextureIds, frameBitmapData, frameRate, smoothing, pixelSnapping);
	}

	/**
		Creates an atlas-backed `Tileset`.

		The tileset uses atlas regions directly for efficient tile rendering. Trim and
		rotation metadata are preserved when you create `Tile` instances through the
		`AtlasUtil` static extension helpers.

		Example:

		```haxe
		using openfl.utils.AtlasUtil;

		var atlas = AtlasUtil.load("assets/atlas/mage_demo.xml");
		var tileset = atlas.createTileset();
		var tile = tileset.createTile("stand", 0, 0);
		```

		@return A new atlas-backed tileset.
	**/
	public function createTileset():Tileset {
		__assertNotDisposed();
		return new AtlasTileset(this);
	}

	/**
		Disposes cached reconstructed frame bitmaps and optionally the source atlas
		bitmap data.

		@param disposeAtlasBitmapData Whether the source atlas bitmap data should
		also be disposed.
	**/
	public function dispose(disposeAtlasBitmapData:Bool = false):Void {
		if (__disposed) {
			return;
		}

		for (bitmapData in __bitmapDataCache) {
			bitmapData.dispose();
		}

		__bitmapDataCache = new StringMap();
		__numberedSequenceSubTextureIdsByName = new StringMap();
		__sequenceBitmapDataCache = new StringMap();
		__sequenceIdsCache = new StringMap();
		__frames = new StringMap();
		__subTextureIds = [];
		__disposed = true;

		if (disposeAtlasBitmapData && __atlasBitmapData != null) {
			__atlasBitmapData.dispose();
		}

		__atlasBitmapData = null;
		__removeFromCache(this);
	}

	@:noCompletion
	private function get_atlasBitmapData():BitmapData {
		__assertNotDisposed();
		return __atlasBitmapData;
	}

	@:noCompletion
	private function get_subTextureIds():Array<String> {
		__assertNotDisposed();
		return __subTextureIds.copy();
	}

	@:noCompletion
	private function __assertNotDisposed():Void {
		if (__disposed) {
			throw "AtlasUtil has been disposed.";
		}
	}

	@:noCompletion
	private function __getSubTextureFrame(subTextureId:String):AtlasFrame {
		var frame = __frames.get(subTextureId);

		if (frame == null) {
			throw 'Unknown atlas sub texture id "$subTextureId".';
		}

		return frame;
	}

	@:noCompletion
	private function __coerceXml(xmlSource:Dynamic):Xml {
		if (Std.isOfType(xmlSource, Xml)) {
			return __normalizeXmlRoot(cast xmlSource);
		}

		if (Std.isOfType(xmlSource, String)) {
			return __normalizeXmlRoot(Xml.parse(cast xmlSource));
		}

		throw "AtlasUtil expected Xml or String xmlSource.";
	}

	@:noCompletion
	private function __parseXml(xml:Xml):Void {
		var sequenceFramesByName:StringMap<Array<AtlasSequenceFrame>> = new StringMap();

		for (node in xml.elementsNamed("SubTexture")) {
			var subTextureId = node.get("name");

			if (subTextureId == null || subTextureId == "") {
				continue;
			}

			var rotation = __parseRotation(node);
			var regionWidth = __parseInt(node.get("width"), 0);
			var regionHeight = __parseInt(node.get("height"), 0);
			var sourceWidth = rotation == 90 || rotation == 270 ? regionHeight : regionWidth;
			var sourceHeight = rotation == 90 || rotation == 270 ? regionWidth : regionHeight;
			var frameX = __parseInt(node.get("frameX"), 0);
			var frameY = __parseInt(node.get("frameY"), 0);
			var frameWidth = __parseInt(node.get("frameWidth"), sourceWidth);
			var frameHeight = __parseInt(node.get("frameHeight"), sourceHeight);

			__frames.set(subTextureId,
				new AtlasFrame(subTextureId, new Rectangle(__parseInt(node.get("x"), 0), __parseInt(node.get("y"), 0), regionWidth, regionHeight), rotation,
					frameX, frameY, frameWidth, frameHeight, sourceWidth, sourceHeight, __parseFloat(node.get("pivotX"), 0.0),
					__parseFloat(node.get("pivotY"), 0.0)));

			__subTextureIds.push(subTextureId);

			var numericSuffixStart = __getNumericSuffixStart(subTextureId);

			if (numericSuffixStart == -1) {
				continue;
			}

			var sequenceName = subTextureId.substring(0, numericSuffixStart);
			var sequenceFrames = sequenceFramesByName.get(sequenceName);

			if (sequenceFrames == null) {
				sequenceFrames = [];
				sequenceFramesByName.set(sequenceName, sequenceFrames);
			}

			sequenceFrames.push(new AtlasSequenceFrame(subTextureId, __parseInt(subTextureId.substr(numericSuffixStart), 0)));
		}

		for (sequenceName in sequenceFramesByName.keys()) {
			var sequenceFrames = sequenceFramesByName.get(sequenceName);

			sequenceFrames.sort(function(left:AtlasSequenceFrame, right:AtlasSequenceFrame):Int {
				if (left.frame < right.frame) {
					return -1;
				}

				if (left.frame > right.frame) {
					return 1;
				}

				if (left.subTextureId < right.subTextureId) {
					return -1;
				}

				if (left.subTextureId > right.subTextureId) {
					return 1;
				}

				return 0;
			});

			var sequenceSubTextureIds:Array<String> = [];

			for (sequenceFrame in sequenceFrames) {
				sequenceSubTextureIds.push(sequenceFrame.subTextureId);
			}

			__numberedSequenceSubTextureIdsByName.set(sequenceName, sequenceSubTextureIds);
		}
	}

	@:noCompletion
	private function __renderFrame(frame:AtlasFrame):BitmapData {
		var reconstructedBitmapData = new BitmapData(frame.frameWidth, frame.frameHeight, true, 0);
		__copyPoint.x = -frame.frameX;
		__copyPoint.y = -frame.frameY;

		if (frame.rotation == 0) {
			reconstructedBitmapData.copyPixels(__atlasBitmapData, frame.region, __copyPoint, null, null, true);
			return reconstructedBitmapData;
		}

		__copyPoint.x = 0;
		__copyPoint.y = 0;
		var extractedBitmapData = new BitmapData(Std.int(frame.region.width), Std.int(frame.region.height), true, 0);
		extractedBitmapData.copyPixels(__atlasBitmapData, frame.region, __copyPoint, null, null, true);
		var restoreMatrix = __createRotationRestoreMatrix(frame.rotation, Std.int(frame.region.width), Std.int(frame.region.height));
		restoreMatrix.translate(-frame.frameX, -frame.frameY);
		reconstructedBitmapData.draw(extractedBitmapData, restoreMatrix);
		extractedBitmapData.dispose();
		return reconstructedBitmapData;
	}

	@:noCompletion
	private function __createRotationRestoreMatrix(rotation:Int, width:Int, height:Int):Matrix {
		var matrix = new Matrix();

		switch (rotation) {
			case 90:
				matrix.rotate(-Math.PI * 0.5);
				matrix.translate(0, width);
			case 180:
				matrix.rotate(Math.PI);
				matrix.translate(width, height);
			case 270:
				matrix.rotate(Math.PI * 0.5);
				matrix.translate(height, 0);
			default:
		}

		return matrix;
	}

	@:noCompletion
	private function __resolveSequenceIds(sequenceName:String, includeExactName:Bool):Array<String> {
		var cacheKey = sequenceName + "|" + (includeExactName ? "1" : "0");
		var cachedSequenceIds = __sequenceIdsCache.get(cacheKey);

		if (cachedSequenceIds != null) {
			return cachedSequenceIds;
		}

		var resolvedSequenceIds:Array<String> = [];
		var numberedSequenceIds = __numberedSequenceSubTextureIdsByName.get(sequenceName);

		if (includeExactName && __frames.exists(sequenceName)) {
			resolvedSequenceIds.push(sequenceName);
		}

		if (numberedSequenceIds != null) {
			for (subTextureId in numberedSequenceIds) {
				resolvedSequenceIds.push(subTextureId);
			}
		}

		__sequenceIdsCache.set(cacheKey, resolvedSequenceIds);
		return resolvedSequenceIds;
	}

	@:noCompletion
	private function __resolveSequenceBitmapData(sequenceName:String, includeExactName:Bool, sequenceSubTextureIds:Array<String>):Array<BitmapData> {
		var cacheKey = sequenceName + "|" + (includeExactName ? "1" : "0");
		var cachedSequenceBitmapData = __sequenceBitmapDataCache.get(cacheKey);

		if (cachedSequenceBitmapData != null) {
			return cachedSequenceBitmapData;
		}

		var frameBitmapData:Array<BitmapData> = [];

		for (subTextureId in sequenceSubTextureIds) {
			frameBitmapData.push(createBitmapData(subTextureId));
		}

		__sequenceBitmapDataCache.set(cacheKey, frameBitmapData);
		return frameBitmapData;
	}

	@:noCompletion
	private static function __normalizeXmlRoot(xml:Xml):Xml {
		return xml.nodeType == Xml.Document ? xml.firstElement() : xml;
	}

	@:noCompletion
	private static function __resolveImageAssetId(xmlAssetId:String, imagePath:String):String {
		if (imagePath == null || imagePath == "") {
			return xmlAssetId;
		}

		var normalizedImagePath = imagePath.split("\\").join("/");

		if (Assets.exists(normalizedImagePath)) {
			return normalizedImagePath;
		}

		var baseDirectory = Path.directory(xmlAssetId);

		if (baseDirectory != null && baseDirectory != "" && baseDirectory != ".") {
			var candidatePath = baseDirectory + "/" + normalizedImagePath;

			if (Assets.exists(candidatePath)) {
				return candidatePath;
			}
		}

		return normalizedImagePath;
	}

	@:noCompletion
	private static function __removeFromCache(instance:AtlasUtil):Void {
		var keysToRemove:Array<String> = [];

		for (cacheKey in __atlasCache.keys()) {
			if (__atlasCache.get(cacheKey) == instance) {
				keysToRemove.push(cacheKey);
			}
		}

		for (cacheKey in keysToRemove) {
			__atlasCache.remove(cacheKey);
		}
	}

	@:noCompletion
	private static function __parseRotation(node:Xml):Int {
		var rotation = node.get("rotation");

		if (rotation != null && rotation != "") {
			return __normalizeRightAngleRotation(__parseInt(rotation, 0));
		}

		var angle = node.get("angle");

		if (angle != null && angle != "") {
			return __normalizeRightAngleRotation(__parseInt(angle, 0));
		}

		var rotated = node.get("rotated");

		if (rotated == null || rotated == "") {
			return 0;
		}

		var normalizedRotation = rotated.toLowerCase();

		if (normalizedRotation == "true") {
			return 90;
		}

		if (normalizedRotation == "false") {
			return 0;
		}

		var parsedRotation = __parseInt(normalizedRotation, 0);
		return parsedRotation == 1 ? 90 : __normalizeRightAngleRotation(parsedRotation);
	}

	@:noCompletion
	private static function __normalizeRightAngleRotation(value:Int):Int {
		var normalized = value % 360;

		if (normalized < 0) {
			normalized += 360;
		}

		return switch (normalized) {
			case 90, 180, 270: normalized;
			default: 0;
		};
	}

	@:noCompletion
	private static function __parseInt(value:String, defaultValue:Int):Int {
		if (value == null || value == "") {
			return defaultValue;
		}

		var parsedValue = Std.parseInt(value);
		return parsedValue == null ? defaultValue : parsedValue;
	}

	@:noCompletion
	private static function __parseFloat(value:String, defaultValue:Float):Float {
		if (value == null || value == "") {
			return defaultValue;
		}

		var parsedValue = Std.parseFloat(value);
		return Math.isNaN(parsedValue) ? defaultValue : parsedValue;
	}

	@:noCompletion
	private static function __getNumericSuffixStart(value:String):Int {
		var index = value.length - 1;

		while (index >= 0) {
			var charCode = value.charCodeAt(index);

			if (charCode < 48 || charCode > 57) {
				break;
			}

			index--;
		}

		return index == value.length - 1 ? -1 : index + 1;
	}

	@:noCompletion
	private static function __requireAtlasTileset(tileset:Tileset):AtlasTileset {
		var atlasTileset = Std.downcast(tileset, AtlasTileset);

		if (atlasTileset == null) {
			throw "Tileset is not an AtlasUtil tileset.";
		}

		return atlasTileset;
	}
}

@:noCompletion
private class AtlasFrame {
	public var name(default, null):String;
	public var region(default, null):Rectangle;
	public var rotation(default, null):Int;
	public var frameX(default, null):Int;
	public var frameY(default, null):Int;
	public var frameWidth(default, null):Int;
	public var frameHeight(default, null):Int;
	public var sourceWidth(default, null):Int;
	public var sourceHeight(default, null):Int;
	public var pivotX(default, null):Float;
	public var pivotY(default, null):Float;

	public function new(name:String, region:Rectangle, rotation:Int, frameX:Int, frameY:Int, frameWidth:Int, frameHeight:Int, sourceWidth:Int,
			sourceHeight:Int, pivotX:Float, pivotY:Float) {
		this.name = name;
		this.region = region;
		this.rotation = rotation;
		this.frameX = frameX;
		this.frameY = frameY;
		this.frameWidth = frameWidth;
		this.frameHeight = frameHeight;
		this.sourceWidth = sourceWidth;
		this.sourceHeight = sourceHeight;
		this.pivotX = pivotX;
		this.pivotY = pivotY;
	}
}

@:noCompletion
@:access(openfl.utils.AtlasUtil)
private class AtlasTileset extends Tileset {
	public var atlas(default, null):AtlasUtil;

	@:noCompletion
	private var __subTextureIdByTileId:Array<String>;

	@:noCompletion
	private var __tileIdBySubTextureId:StringMap<Int>;

	@:noCompletion
	private var __tilePlacementsById:Array<AtlasTilePlacement>;

	public function new(atlas:AtlasUtil) {
		super(atlas.atlasBitmapData);

		this.atlas = atlas;
		__subTextureIdByTileId = [];
		__tileIdBySubTextureId = new StringMap();
		__tilePlacementsById = [];

		for (subTextureId in atlas.subTextureIds) {
			var frame = atlas.__getSubTextureFrame(subTextureId);
			var tileId = addRect(frame.region);

			__subTextureIdByTileId[tileId] = subTextureId;
			__tileIdBySubTextureId.set(subTextureId, tileId);
			__tilePlacementsById[tileId] = AtlasTilePlacement.fromFrame(frame);
		}
	}

	public function hasSubTexture(subTextureId:String):Bool {
		return __tileIdBySubTextureId.exists(subTextureId);
	}

	public function getTileId(subTextureId:String):Int {
		var tileId = __tileIdBySubTextureId.get(subTextureId);

		if (tileId == null) {
			throw 'Unknown atlas sub texture id "$subTextureId".';
		}

		return tileId;
	}

	public function getSubTextureId(tileId:Int):String {
		if (tileId < 0 || tileId >= __subTextureIdByTileId.length) {
			throw 'Unknown atlas tile id "$tileId".';
		}

		return __subTextureIdByTileId[tileId];
	}

	public function createTile(subTextureId:String, x:Float = 0, y:Float = 0, assignTileset:Bool = false):Tile {
		return createTileById(getTileId(subTextureId), x, y, assignTileset);
	}

	public function createTileById(tileId:Int, x:Float = 0, y:Float = 0, assignTileset:Bool = false):Tile {
		if (tileId < 0 || tileId >= __tilePlacementsById.length) {
			throw 'Unknown atlas tile id "$tileId".';
		}

		var placement = __tilePlacementsById[tileId];
		var tile = new Tile(tileId, x + placement.offsetX, y + placement.offsetY, 1, 1, placement.rotation);

		if (assignTileset) {
			tile.tileset = this;
		}

		return tile;
	}
}

@:noCompletion
private class AtlasTilePlacement {
	public var offsetX(default, null):Float;
	public var offsetY(default, null):Float;
	public var rotation(default, null):Float;

	public static function fromFrame(frame:AtlasFrame):AtlasTilePlacement {
		var offsetX:Float = -frame.frameX;
		var offsetY:Float = -frame.frameY;
		var rotation = 0.0;

		switch (frame.rotation) {
			case 90:
				offsetY += frame.region.width;
				rotation = -90.0;
			case 180:
				offsetX += frame.region.width;
				offsetY += frame.region.height;
				rotation = 180.0;
			case 270:
				offsetX += frame.region.height;
				rotation = 90.0;
			default:
		}

		return new AtlasTilePlacement(offsetX, offsetY, rotation);
	}

	public function new(offsetX:Float, offsetY:Float, rotation:Float) {
		this.offsetX = offsetX;
		this.offsetY = offsetY;
		this.rotation = rotation;
	}
}

@:noCompletion
private class AtlasSequenceFrame {
	public function new(subTextureId:String, frame:Int) {
		this.subTextureId = subTextureId;
		this.frame = frame;
	}

	public var subTextureId(default, null):String;
	public var frame(default, null):Int;
}

@:noCompletion
@:access(openfl.display.Timeline)
private class AtlasMovieClipTimeline extends Timeline {
	@:noCompletion
	private var __bitmap:Bitmap;

	@:noCompletion
	private var __frameBitmapData:Array<BitmapData>;

	@:noCompletion
	private var __frameLabels:Array<FrameLabel>;

	@:noCompletion
	private var __pixelSnapping:PixelSnapping;

	@:noCompletion
	private var __smoothing:Bool;

	public static function create(sequenceName:String, sequenceSubTextureIds:Array<String>, frameBitmapData:Array<BitmapData>, frameRate:Float,
			smoothing:Bool, pixelSnapping:PixelSnapping):MovieClip {
		return MovieClip.fromTimeline(new AtlasMovieClipTimeline(sequenceName, sequenceSubTextureIds, frameBitmapData, frameRate, smoothing, pixelSnapping));
	}

	public function new(sequenceName:String, sequenceSubTextureIds:Array<String>, frameBitmapData:Array<BitmapData>, frameRate:Float, smoothing:Bool,
			pixelSnapping:PixelSnapping) {
		super();

		__frameBitmapData = frameBitmapData;
		__pixelSnapping = pixelSnapping;
		__smoothing = smoothing;
		__frameLabels = __createFrameLabels(sequenceName, sequenceSubTextureIds);

		this.frameRate = frameRate;
		scenes = [new Scene(sequenceName, __frameLabels, frameBitmapData.length)];
	}

	override public function attachMovieClip(movieClip:MovieClip):Void {
		__bitmap = __createBitmap();
		movieClip.addChild(__bitmap);
		enterFrame(1);
	}

	override public function enterFrame(frame:Int):Void {
		if (__bitmap == null || __frameBitmapData.length == 0) {
			return;
		}

		var frameIndex = frame - 1;

		if (frameIndex < 0) {
			frameIndex = 0;
		} else if (frameIndex >= __frameBitmapData.length) {
			frameIndex = __frameBitmapData.length - 1;
		}

		__bitmap.bitmapData = __frameBitmapData[frameIndex];
		__bitmap.smoothing = __smoothing;
	}

	override public function initializeSprite(sprite:Sprite):Void {
		sprite.addChild(__createBitmap());
	}

	@:noCompletion
	private function __createBitmap():Bitmap {
		var firstFrameBitmapData = __frameBitmapData.length > 0 ? __frameBitmapData[0] : null;
		var bitmap = new Bitmap(firstFrameBitmapData, __pixelSnapping, __smoothing);
		bitmap.smoothing = __smoothing;
		return bitmap;
	}

	@:noCompletion
	private function __createFrameLabels(sequenceName:String, sequenceSubTextureIds:Array<String>):Array<FrameLabel> {
		var frameLabels:Array<FrameLabel> = [new FrameLabel(sequenceName, 1)];

		for (index in 0...sequenceSubTextureIds.length) {
			if (index == 0 && sequenceSubTextureIds[index] == sequenceName) {
				continue;
			}

			frameLabels.push(new FrameLabel(sequenceSubTextureIds[index], index + 1));
		}

		return frameLabels;
	}
}
