package mobile;

#if android
import lime.system.System as LimeSystem;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;

class Storage
{
	public static final APP_NAME:String = "ImpostorLegacy";

	public static var externalStorage(get, never):String;
	public static var dataStorage(get, never):String;

	static function get_externalStorage():String
	{
		return "/sdcard/Android/data/com.motorfrog.impostor/files";
	}

	static function get_dataStorage():String
	{
		return LimeSystem.applicationStorageDirectory;
	}

	public static function init():Void
	{
		ensureDirectory(externalStorage);
		ensureDirectory(externalStorage + "/assets");
		ensureDirectory(externalStorage + "/mods");
		copyAssetsIfNeeded();
	}

	public static function ensureDirectory(path:String):Void
	{
		if (!FileSystem.exists(path))
			FileSystem.createDirectory(path);
	}

	public static function copyAssetsIfNeeded():Void
	{
		final internalBase:String = dataStorage;
		final externalBase:String = externalStorage;

		if (!FileSystem.exists(internalBase))
			return;

		copyDirectoryRecursive(internalBase, externalBase);
	}

	public static function copyDirectoryRecursive(src:String, dst:String):Void
	{
		ensureDirectory(dst);

		for (entry in FileSystem.readDirectory(src))
		{
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
		if (!FileSystem.exists(dst))
		{
			File.copy(src, dst);
			return;
		}

		final srcStat = FileSystem.stat(src);
		final dstStat = FileSystem.stat(dst);

		if (srcStat.mtime.getTime() > dstStat.mtime.getTime())
			File.copy(src, dst);
	}

	public static function resolveAsset(relativePath:String):String
	{
		final externalPath:String = Path.join([externalStorage, relativePath]);

		if (FileSystem.exists(externalPath))
			return externalPath;

		return Path.join([dataStorage, relativePath]);
	}

	public static function resolveModsPath():String
	{
		return Path.join([externalStorage, "mods"]);
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

	public static function writeToExternal(relative:String, content:String):Void
	{
		final fullPath:String = Path.join([externalStorage, relative]);
		ensureDirectory(Path.directory(fullPath));
		File.saveContent(fullPath, content);
	}

	public static function readFromExternal(relative:String):String
	{
		final fullPath:String = Path.join([externalStorage, relative]);

		if (!FileSystem.exists(fullPath))
			return null;

		return File.getContent(fullPath);
	}
}
#end
