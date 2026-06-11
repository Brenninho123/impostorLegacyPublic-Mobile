package funkin;

import haxe.io.Path;
import haxe.Json;

import openfl.system.System;
import openfl.utils.AssetType;
import openfl.utils.Assets;
import openfl.display.BitmapData;
import openfl.media.Sound;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;

#if android
import mobile.Storage;
#end

enum PathsTestMode
{
	NORMAL;
	STRICT;
	LOOSE;
}

class Paths
{
	#if ASSET_REDIRECT
	public static inline final trail = #if macos '../../../../../../../' #else '../../../../' #end;
	#end

	public static inline final CORE_DIRECTORY = #if ASSET_REDIRECT trail + 'assets/legacy' #else 'assets' #end;
	public static inline final MODS_DIRECTORY = #if ASSET_REDIRECT trail + 'content' #else 'content' #end;

	public static var DEFAULT_FONT:String = 'vcr.ttf';

	@:allow(funkin.backend.FunkinCache)
	static var tempAtlasFramesCache:Map<String, FlxAtlasFrames> = [];

	public static function getStoragePrefix():String
	{
		#if android
		return Storage.externalStorage;
		#else
		return '';
		#end
	}

	public static function getPath(file:String, ?parentFolder:String, checkMods:Bool = false, mode:PathsTestMode = NORMAL):String
	{
		if (parentFolder != null) file = '$parentFolder/$file';

		#if MODS_ALLOWED
		if (checkMods)
		{
			final modPath:String = modFolders(file, mode);
			if (FunkinAssets.exists(modPath)) return modPath;
		}
		#end

		#if ASSET_REDIRECT
		final embedPath = '${trail}assets/embeds/$file';
		if (FunkinAssets.exists(embedPath)) return embedPath;
		#end

		return getCorePath(file);
	}

	public static function getCorePath(file:String = ''):String
	{
		#if android
		final external:String = Storage.getExternalFilePath('assets/$file');
		if (sys.FileSystem.exists(external)) return external;
		#end

		return '$CORE_DIRECTORY/$file';
	}

	public static inline function txt(key:String, ?parentFolder:String, checkMods:Bool = true):String
	{
		return getPath('data/$key.txt', parentFolder, checkMods);
	}

	public static inline function xml(key:String, ?parentFolder:String, checkMods:Bool = true):String
	{
		return getPath('data/$key.xml', parentFolder, checkMods);
	}

	public static inline function json(key:String, ?parentFolder:String, checkMods:Bool = true):String
	{
		return getPath('songs/$key.json', parentFolder, checkMods);
	}

	public static inline function noteskin(key:String, ?parentFolder:String, checkMods:Bool = true):String
	{
		var path = getPath('data/noteskins/$key.json', parentFolder, checkMods);
		if (!FunkinAssets.exists(path, TEXT)) path = getPath('noteskins/$key.json', parentFolder, checkMods);
		return path;
	}

	public static inline function fragment(key:String, checkMods:Bool = true):String
	{
		return getPath('shaders/$key.frag', null, checkMods);
	}

	public static inline function vertex(key:String, checkMods:Bool = true):String
	{
		return getPath('shaders/$key.vert', null, checkMods);
	}

	public static function video(key:String, checkMods:Bool = true):String
	{
		return findFileWithExts('videos/$key', ['mp4', 'mov'], null, checkMods);
	}

	public static function textureAtlas(key:String, ?parentFolder:String, checkMods:Bool = true):String
	{
		return getPath('images/$key', parentFolder, checkMods);
	}

	public static function sound(key:String, ?parentFolder:String, checkMods:Bool = true):Sound
	{
		final key = findFileWithExts('sounds/$key', ['ogg', 'wav'], parentFolder, checkMods);
		return FunkinAssets.getSound(key);
	}

	public static inline function soundRandom(key:String, min:Int = 0, max:Int = 0, ?parentFolder:String, checkMods:Bool = true):Sound
	{
		return sound(key + FlxG.random.int(min, max), parentFolder, checkMods);
	}

	public static inline function music(key:String, ?parentFolder:String, checkMods:Bool = true):Sound
	{
		final key = findFileWithExts('music/$key', ['ogg', 'wav'], parentFolder, checkMods);
		return FunkinAssets.getSound(key);
	}

	public static inline function trackSwap(song:String, ?postFix:String, checkMods:Bool = true):Null<Sound>
	{
		var name = sanitize(song);

		var songKey:String = '$name/Track';
		if (FunkinAssets.isDirectory(getPath('songs/$name/audio', null, checkMods))) songKey = '$name/audio/Track';

		if (postFix != null) songKey += '-$postFix';

		songKey = findFileWithExts('songs/$songKey', ['ogg', 'wav'], null, checkMods);

		if (ClientPrefs.streamedMusic) return FunkinAssets.getVorbisSound(songKey);

		return FunkinAssets.getSoundUnsafe(songKey);
	}

	public static inline function voices(song:String, ?postFix:String, checkMods:Bool = true):Null<Sound>
	{
		var name = sanitize(song);

		var songKey:String = '$name/Voices';
		if (FunkinAssets.isDirectory(getPath('songs/$name/audio', null, checkMods))) songKey = '$name/audio/Voices';

		if (postFix != null) songKey += '-$postFix';

		songKey = findFileWithExts('songs/$songKey', ['ogg', 'wav'], null, checkMods);

		if (ClientPrefs.streamedMusic) return FunkinAssets.getVorbisSound(songKey);

		return FunkinAssets.getSoundUnsafe(songKey);
	}

	public static inline function inst(song:String, ?postFix:String, checkMods:Bool = true):Sound
	{
		var name = sanitize(song);

		var songKey:String = '$name/Inst';
		if (FunkinAssets.isDirectory(getPath('songs/$name/audio', null, checkMods))) songKey = '$name/audio/Inst';

		if (postFix != null) songKey += '-$postFix';

		songKey = findFileWithExts('songs/$songKey', ['ogg', 'wav'], null, checkMods);

		if (ClientPrefs.streamedMusic) return FunkinAssets.getVorbisSound(songKey) ?? FunkinAssets.getSound(songKey);

		return FunkinAssets.getSound(songKey);
	}

	public static inline function image(key:String, ?parentFolder:String, allowGPU:Bool = true, checkMods:Bool = true, mode:PathsTestMode = NORMAL):FlxGraphic
	{
		return FunkinAssets.getGraphic(getPath('images/$key.png', parentFolder, checkMods, mode), true, allowGPU);
	}

	public static inline function font(key:String, overridable:Bool = true, checkMods:Bool = true):String
	{
		key = overridable ? Lang.getFont(key) : key;
		final path:String = findFileWithExts('fonts/$key', ['ttf', 'otf'], null, checkMods);
		return (Assets.exists(path, FONT) ? Assets.getFont(path).fontName : path);
	}

	public static function findFileWithExts(key:String, exts:Array<String>, ?parentFolder:String, checkMods:Bool = true, mode:PathsTestMode = NORMAL):String
	{
		for (ext in exts)
		{
			final joined = getPath('$key.$ext', parentFolder, checkMods, mode);
			if (FunkinAssets.exists(joined)) return joined;
		}

		return getPath(key, parentFolder, checkMods, mode);
	}

	public static function getTextFromFile(key:String, ?parentFolder:String, checkMods:Bool = true, mode:PathsTestMode = NORMAL):String
	{
		key = getPath(key, parentFolder, checkMods, mode);
		return FunkinAssets.exists(key) ? FunkinAssets.getContent(key) : '';
	}

	public static inline function fileExists(key:String, ?parentFolder:String, checkMods:Bool = true, mode:PathsTestMode = NORMAL):Bool
	{
		return FunkinAssets.exists(getPath(key, parentFolder, checkMods, mode));
	}

	public static inline function getMultiAtlas(keys:Array<String>, ?parentFolder:String, allowGPU:Bool = true, checkMods:Bool = true):FlxAtlasFrames
	{
		if (keys.length == 0) return null;

		final firstKey:Null<String> = keys.shift()?.trim();

		var frames = getAtlasFrames(firstKey, parentFolder, allowGPU, checkMods);

		if (keys.length != 0)
		{
			final originalCollection = frames;
			frames = new FlxAtlasFrames(originalCollection.parent);
			frames.addAtlas(originalCollection, true);
			for (i in keys)
			{
				final newFrames = getAtlasFrames(i.trim(), parentFolder, allowGPU, checkMods);
				if (newFrames != null)
					frames.addAtlas(newFrames, false);
			}
		}

		return frames;
	}

	public static inline function getAtlasFrames(key:String, ?parentFolder:String, allowGPU:Bool = true, checkMods:Bool = true, mode:PathsTestMode = NORMAL):FlxAtlasFrames
	{
		final directPath = getPath('images/$key.png', parentFolder, checkMods, mode).withoutExtension();

		final tempFrames = tempAtlasFramesCache.get(directPath);
		if (tempFrames != null) return tempFrames;

		final xmlPath = getPath('images/$key.xml', parentFolder, checkMods, mode);
		final txtPath = getPath('images/$key.txt', parentFolder, checkMods, mode);

		final graphic = image(key, parentFolder, allowGPU, checkMods, mode);

		if (FunkinAssets.exists(xmlPath))
		{
			@:nullSafety(Off)
			{
				final frames = FlxAtlasFrames.fromSparrow(graphic, FunkinAssets.exists(xmlPath) ? FunkinAssets.getContent(xmlPath) : null);
				if (frames != null) tempAtlasFramesCache.set(directPath, frames);
				return frames;
			}
		}

		@:nullSafety(Off)
		{
			final frames = FlxAtlasFrames.fromSpriteSheetPacker(graphic, FunkinAssets.exists(txtPath) ? FunkinAssets.getContent(txtPath) : null);
			if (frames != null) tempAtlasFramesCache.set(directPath, frames);
			return frames;
		}
	}

	public static inline function getSparrowAtlas(key:String, ?parentFolder:String, ?allowGPU:Bool = true, checkMods:Bool = true):FlxAtlasFrames
	{
		final directPath = getPath('images/$key.png', parentFolder, checkMods).withoutExtension();
		final tempFrames = tempAtlasFramesCache.get(directPath);
		if (tempFrames != null) return tempFrames;

		final xmlPath = getPath('images/$key.xml', parentFolder, checkMods);
		@:nullSafety(Off)
		{
			final frames = FlxAtlasFrames.fromSparrow(image(key, parentFolder, allowGPU, checkMods), FunkinAssets.exists(xmlPath) ? FunkinAssets.getContent(xmlPath) : null);
			if (frames != null) tempAtlasFramesCache.set(directPath, frames);
			return frames;
		}
	}

	public static inline function getPackerAtlas(key:String, ?parentFolder:String, ?allowGPU:Bool = true, checkMods:Bool = true)
	{
		final directPath = getPath('images/$key.png', parentFolder, checkMods).withoutExtension();
		final tempFrames = tempAtlasFramesCache.get(directPath);
		if (tempFrames != null) return tempFrames;

		final txtPath = getPath('images/$key.txt', parentFolder, checkMods);
		@:nullSafety(Off)
		{
			final frames = FlxAtlasFrames.fromSpriteSheetPacker(image(key, parentFolder, allowGPU, checkMods), FunkinAssets.exists(txtPath) ? FunkinAssets.getContent(txtPath) : null);
			if (frames != null) tempAtlasFramesCache.set(directPath, frames);
			return frames;
		}
	}

	public static inline function sanitize(path:String):String
	{
		return ~/[^- a-zA-Z0-9..\/]+\//g.replace(path, '').replace(' ', '-').trim().toLowerCase();
	}

	public static function listAllFilesInDirectory(directory:String, checkMods:Bool = true, mode:PathsTestMode = NORMAL)
	{
		var folders:Array<String> = [];
		var files:Array<String> = [];

		#if MODS_ALLOWED
		if (checkMods)
		{
			final path:String = mods(directory);
			if (FunkinAssets.exists(path)) folders.push(path);

			if (overrideMode != null) mode = overrideMode;

			for (mod in Mods.enabled)
			{
				if (Mods.globalMods.contains(mod))
				{
					if (mode == STRICT) continue;
				}
				else if (mode != LOOSE && mod != Mods.currentModDirectory)
				{
					continue;
				}

				final path:String = mods('$mod/$directory');
				if (FunkinAssets.exists(path) && !folders.contains(path)) folders.push(path);
			}
		}
		#end

		#if android
		final externalDir:String = Storage.getExternalFilePath('assets/$directory');
		if (sys.FileSystem.exists(externalDir) && !folders.contains(externalDir)) folders.push(externalDir);
		#end

		if (FunkinAssets.exists(getCorePath(directory))) folders.push(getCorePath(directory));

		for (folder in folders)
		{
			for (file in FunkinAssets.readDirectory(folder)) files.push(Path.join([folder, file]));
		}

		return files;
	}

	#if MODS_ALLOWED
	public static inline function mods(key:String = ''):String
	{
		#if android
		return Storage.getExternalFilePath('$MODS_DIRECTORY/$key');
		#else
		return '$MODS_DIRECTORY/' + key;
		#end
	}

	public static function modFolders(key:String, mode:PathsTestMode = NORMAL):String
	{
		if (FunkinAssets.exists(mods(key))) return mods(key);

		if (overrideMode != null) mode = overrideMode;

		for (mod in Mods.enabled)
		{
			if (Mods.globalMods.contains(mod))
			{
				if (mode == STRICT) continue;
			}
			else if (mode != LOOSE && mod != Mods.currentModDirectory)
			{
				continue;
			}

			final fileToCheck:String = mods('$mod/$key');
			if (FunkinAssets.exists(fileToCheck)) return fileToCheck;
		}

		return mods(key);
	}
	#end

	public static var overrideMode:Null<PathsTestMode> = null;
}