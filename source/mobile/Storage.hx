package mobile;

#if android
import lime.system.System as LimeSystem;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
import haxe.io.Bytes;

class Storage
{
	public static final PACKAGE:String = "com.motorfrog.impostor";
	public static final APP_NAME:String = "ImpostorLegacy";

	public static var externalStorage(get, never):String;
	public static var dataStorage(get, never):String;
	public static var modsStorage(get, never):String;
	public static var savesStorage(get, never):String;
	public static var logsStorage(get, never):String;

	static var _externalStorage:Null<String> = null;

	static function get_externalStorage():String
	{
		if (_externalStorage != null)
			return _externalStorage;

		final sdcard:String = "/sdcard/Android/data/" + PACKAGE + "/files";
		final emulated:String = "/storage/emulated/0/Android/data/" + PACKAGE + "/files";

		if (FileSystem.exists("/sdcard"))
			_externalStorage = sdcard;
		else if (FileSystem.exists("/storage/emulated/0"))
			_externalStorage = emulated;
		else
			_externalStorage = LimeSystem.applicationStorageDirectory;

		return _externalStorage;
	}

	static function get_dataStorage():String
	{
		return LimeSystem.applicationStorageDirectory;
	}

	static function get_modsStorage():String
	{
		return Path.join([externalStorage, "content"]);
	}

	static function get_savesStorage():String
	{
		return Path.join([externalStorage, "saves"]);
	}

	static function get_logsStorage():String
	{
		return Path.join([externalStorage, "logs"]);
	}

	public static function init():Void
	{
		ensureDirectory(externalStorage);
		ensureDirectory(Path.join([externalStorage, "assets"]));
		ensureDirectory(modsStorage);
		ensureDirectory(savesStorage);
		ensureDirectory(logsStorage);

		copyAssetsIfNeeded();
	}

	public static function ensureDirectory(path:String):Void
	{
		if (path == null || path.length == 0)
			return;

		if (!FileSystem.exists(path))
			FileSystem.createDirectory(path);
	}

	public static function copyAssetsIfNeeded():Void
	{
		final internalBase:String = dataStorage;

		if (!FileSystem.exists(internalBase))
			return;

		copyDirectoryRecursive(internalBase, externalStorage);
	}

	public static function copyDirectoryRecursive(src:String, dst:String):Void
	{
		if (!FileSystem.exists(src) || !FileSystem.isDirectory(src))
			return;

		ensureDirectory(dst);

		for (entry in FileSystem.readDirectory(src))
		{
			if (entry == "." || entry == "..")
				continue;

			final srcPath:String = Path.join([src, entry]);
			final dstPath:String = Path.join([dst, entry]);

			if (FileSystem.isDirectory(srcPath))
				copyDirectoryRecursive(srcPath, dstPath);
			else
				copyFileIfNewer(srcPath, dstPath);
		}
	}

	public static function copyFileIfNewer(src:String, dst:String):Void
	{
		if (!FileSystem.exists(src))
			return;

		if (!FileSystem.exists(dst))
		{
			safeCopy(src, dst);
			return;
		}

		try
		{
			final srcStat = FileSystem.stat(src);
			final dstStat = FileSystem.stat(dst);

			if (srcStat.mtime.getTime() > dstStat.mtime.getTime())
				safeCopy(src, dst);
		}
		catch (e:Dynamic) {}
	}

	static function safeCopy(src:String, dst:String):Void
	{
		try
		{
			ensureDirectory(Path.directory(dst));
			File.copy(src, dst);
		}
		catch (e:Dynamic) {}
	}

	public static function resolveAsset(relativePath:String):String
	{
		final externalPath:String = Path.join([externalStorage, relativePath]);

		if (FileSystem.exists(externalPath))
			return externalPath;

		final dataPath:String = Path.join([dataStorage, relativePath]);

		if (FileSystem.exists(dataPath))
			return dataPath;

		return relativePath;
	}

	public static function getExternalFilePath(relative:String):String
	{
		return Path.join([externalStorage, relative]);
	}

	public static function getDataFilePath(relative:String):String
	{
		return Path.join([dataStorage, relative]);
	}

	public static function fileExistsExternal(relative:String):Bool
	{
		return FileSystem.exists(Path.join([externalStorage, relative]));
	}

	public static function fileExistsData(relative:String):Bool
	{
		return FileSystem.exists(Path.join([dataStorage, relative]));
	}

	public static function writeToExternal(relative:String, content:String):Bool
	{
		try
		{
			final fullPath:String = Path.join([externalStorage, relative]);
			ensureDirectory(Path.directory(fullPath));
			File.saveContent(fullPath, content);
			return true;
		}
		catch (e:Dynamic)
		{
			return false;
		}
	}

	public static function writeBytesToExternal(relative:String, bytes:Bytes):Bool
	{
		try
		{
			final fullPath:String = Path.join([externalStorage, relative]);
			ensureDirectory(Path.directory(fullPath));
			File.saveBytes(fullPath, bytes);
			return true;
		}
		catch (e:Dynamic)
		{
			return false;
		}
	}

	public static function readFromExternal(relative:String):Null<String>
	{
		try
		{
			final fullPath:String = Path.join([externalStorage, relative]);

			if (!FileSystem.exists(fullPath))
				return null;

			return File.getContent(fullPath);
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	public static function readBytesFromExternal(relative:String):Null<Bytes>
	{
		try
		{
			final fullPath:String = Path.join([externalStorage, relative]);

			if (!FileSystem.exists(fullPath))
				return null;

			return File.getBytes(fullPath);
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	public static function deleteFromExternal(relative:String):Bool
	{
		try
		{
			final fullPath:String = Path.join([externalStorage, relative]);

			if (!FileSystem.exists(fullPath))
				return false;

			FileSystem.deleteFile(fullPath);
			return true;
		}
		catch (e:Dynamic)
		{
			return false;
		}
	}

	public static function listExternal(relative:String):Array<String>
	{
		try
		{
			final fullPath:String = Path.join([externalStorage, relative]);

			if (!FileSystem.exists(fullPath) || !FileSystem.isDirectory(fullPath))
				return [];

			return FileSystem.readDirectory(fullPath);
		}
		catch (e:Dynamic)
		{
			return [];
		}
	}

	public static function getStorageInfo():String
	{
		return 'external=$externalStorage | data=$dataStorage | exists=${FileSystem.exists(externalStorage)}';
	}
}
#end
