package mobile;

#if android
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
import haxe.io.Bytes;
import lime.system.System as LimeSystem;
import androidtools.Environment;
import androidtools.PermissionManager;
import androidtools.content.Context;

class Storage
{
	public static final PACKAGE:String  = 'com.motorfrog.impostor';
	public static final APP_NAME:String = 'ImpostorLegacy';

	static final _VERSION_FILE:String   = '.storage_version';
	static final _STORAGE_VERSION:Int   = 2;

	public static var externalStorage(get, never):String;
	public static var dataStorage(get, never):String;
	public static var modsStorage(get, never):String;
	public static var savesStorage(get, never):String;
	public static var logsStorage(get, never):String;
	public static var cacheStorage(get, never):String;

	static var _externalStorage:Null<String> = null;
	static var _initialized:Bool             = false;

	static function get_externalStorage():String
	{
		if (_externalStorage != null) return _externalStorage;

		_externalStorage = _resolveExternalPath();
		return _externalStorage;
	}

	static function get_dataStorage():String     { return LimeSystem.applicationStorageDirectory; }
	static function get_modsStorage():String     { return Path.join([externalStorage, 'content']); }
	static function get_savesStorage():String    { return Path.join([externalStorage, 'saves']); }
	static function get_logsStorage():String     { return Path.join([externalStorage, 'logs']); }
	static function get_cacheStorage():String    { return Path.join([externalStorage, 'cache']); }

	static function _resolveExternalPath():String
	{
		try
		{
			var extDir:String = Environment.getExternalStorageDirectory();
			if (extDir != null && extDir.length > 0)
				return Path.join([extDir, 'Android', 'data', PACKAGE, 'files']);
		}
		catch (e:Dynamic) {}

		try
		{
			var ctx = Context.getContext();
			if (ctx != null)
			{
				var dirs = ctx.getExternalFilesDirs(null);
				if (dirs != null && dirs.length > 0 && dirs[0] != null)
					return dirs[0];
			}
		}
		catch (e:Dynamic) {}

		for (candidate in [
			'/sdcard/Android/data/$PACKAGE/files',
			'/storage/emulated/0/Android/data/$PACKAGE/files',
			'/mnt/sdcard/Android/data/$PACKAGE/files'
		])
		{
			var base = candidate.split('/Android/')[0];
			if (FileSystem.exists(base)) return candidate;
		}

		return LimeSystem.applicationStorageDirectory;
	}

	public static function init():Void
	{
		if (_initialized) return;
		_initialized = true;

		_ensureCoreDirs();
	}

	public static function requestPermissionsAndInit(onDone:Bool->Void):Void
	{
		var perms:Array<String> = _getRequiredPermissions();
		var pending:Array<String> = perms.filter(function(p:String):Bool
		{
			return !PermissionManager.hasPermission(p);
		});

		if (pending.length == 0)
		{
			init();
			onDone(true);
			return;
		}

		PermissionManager.requestPermissions(pending, function(results:Map<String, Bool>):Void
		{
			var allGranted:Bool = true;
			for (_ => granted in results) if (!granted) { allGranted = false; break; }

			init();
			onDone(allGranted);
		});
	}

	public static function checkStoragePermission():Bool
	{
		for (p in _getRequiredPermissions())
			if (PermissionManager.hasPermission(p)) return true;
		return false;
	}

	public static function isExternalAvailable():Bool
	{
		try
		{
			var state:String = Environment.getExternalStorageState();
			return state == Environment.MEDIA_MOUNTED;
		}
		catch (e:Dynamic) {}

		return FileSystem.exists(externalStorage);
	}

	public static function ensureDirectory(path:String):Void
	{
		if (path == null || path.length == 0) return;
		try { if (!FileSystem.exists(path)) FileSystem.createDirectory(path); }
		catch (e:Dynamic) {}
	}

	public static function copyAssetsIfNeeded():Void
	{
		var versionPath:String = Path.join([externalStorage, _VERSION_FILE]);
		var needsCopy:Bool     = true;

		if (FileSystem.exists(versionPath))
		{
			try
			{
				var saved:Int = Std.parseInt(StringTools.trim(File.getContent(versionPath))) ?? 0;
				if (saved >= _STORAGE_VERSION) needsCopy = false;
			}
			catch (e:Dynamic) {}
		}

		if (!needsCopy) return;

		var internalBase:String = dataStorage;
		if (!FileSystem.exists(internalBase)) return;

		copyDirectoryRecursive(internalBase, externalStorage);

		try { File.saveContent(versionPath, Std.string(_STORAGE_VERSION)); }
		catch (e:Dynamic) {}
	}

	public static function copyAssetsAsync(onProgress:Float->Void, onDone:Bool->Void):Void
	{
		sys.thread.Thread.create(function():Void
		{
			var success:Bool = true;
			try
			{
				var internalBase:String = dataStorage;
				if (!FileSystem.exists(internalBase)) { haxe.MainLoop.runInMainThread(function():Void { onDone(false); }); return; }

				var allFiles:Array<String> = _collectFiles(internalBase);
				var total:Int   = allFiles.length;
				var done:Int    = 0;

				for (srcPath in allFiles)
				{
					var rel:String  = srcPath.substr(internalBase.length + 1);
					var dstPath:String = Path.join([externalStorage, rel]);

					if (!FileSystem.exists(dstPath))
					{
						ensureDirectory(Path.directory(dstPath));
						try { File.copy(srcPath, dstPath); }
						catch (e:Dynamic) {}
					}

					done++;
					var progress:Float = total > 0 ? done / total : 1.0;
					haxe.MainLoop.runInMainThread(function():Void { onProgress(progress); });
				}
			}
			catch (e:Dynamic) { success = false; }

			haxe.MainLoop.runInMainThread(function():Void { onDone(success); });
		});
	}

	public static function copyDirectoryRecursive(src:String, dst:String):Void
	{
		if (!FileSystem.exists(src) || !FileSystem.isDirectory(src)) return;
		ensureDirectory(dst);

		try
		{
			for (entry in FileSystem.readDirectory(src))
			{
				if (entry == '.' || entry == '..') continue;
				var srcPath:String = Path.join([src, entry]);
				var dstPath:String = Path.join([dst, entry]);

				if (FileSystem.isDirectory(srcPath)) copyDirectoryRecursive(srcPath, dstPath);
				else copyFileIfNewer(srcPath, dstPath);
			}
		}
		catch (e:Dynamic) {}
	}

	public static function copyFileIfNewer(src:String, dst:String):Void
	{
		if (!FileSystem.exists(src)) return;

		if (!FileSystem.exists(dst)) { _safeCopy(src, dst); return; }

		try
		{
			var srcMtime:Float = FileSystem.stat(src).mtime.getTime();
			var dstMtime:Float = FileSystem.stat(dst).mtime.getTime();
			if (srcMtime > dstMtime) _safeCopy(src, dst);
		}
		catch (e:Dynamic) {}
	}

	public static function resolveAsset(relativePath:String):String
	{
		var externalPath:String = Path.join([externalStorage, relativePath]);
		if (FileSystem.exists(externalPath)) return externalPath;

		var dataPath:String = Path.join([dataStorage, relativePath]);
		if (FileSystem.exists(dataPath)) return dataPath;

		return relativePath;
	}

	public static function getExternalFilePath(relative:String):String  { return Path.join([externalStorage, relative]); }
	public static function getDataFilePath(relative:String):String      { return Path.join([dataStorage, relative]); }

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
			var fullPath:String = Path.join([externalStorage, relative]);
			ensureDirectory(Path.directory(fullPath));
			File.saveContent(fullPath, content);
			return true;
		}
		catch (e:Dynamic) { return false; }
	}

	public static function writeBytesToExternal(relative:String, bytes:Bytes):Bool
	{
		try
		{
			var fullPath:String = Path.join([externalStorage, relative]);
			ensureDirectory(Path.directory(fullPath));
			File.saveBytes(fullPath, bytes);
			return true;
		}
		catch (e:Dynamic) { return false; }
	}

	public static function readFromExternal(relative:String):Null<String>
	{
		try
		{
			var fullPath:String = Path.join([externalStorage, relative]);
			if (!FileSystem.exists(fullPath)) return null;
			return File.getContent(fullPath);
		}
		catch (e:Dynamic) { return null; }
	}

	public static function readBytesFromExternal(relative:String):Null<Bytes>
	{
		try
		{
			var fullPath:String = Path.join([externalStorage, relative]);
			if (!FileSystem.exists(fullPath)) return null;
			return File.getBytes(fullPath);
		}
		catch (e:Dynamic) { return null; }
	}

	public static function deleteFromExternal(relative:String):Bool
	{
		try
		{
			var fullPath:String = Path.join([externalStorage, relative]);
			if (!FileSystem.exists(fullPath)) return false;
			FileSystem.deleteFile(fullPath);
			return true;
		}
		catch (e:Dynamic) { return false; }
	}

	public static function listExternal(relative:String):Array<String>
	{
		try
		{
			var fullPath:String = Path.join([externalStorage, relative]);
			if (!FileSystem.exists(fullPath) || !FileSystem.isDirectory(fullPath)) return [];
			return FileSystem.readDirectory(fullPath);
		}
		catch (e:Dynamic) { return []; }
	}

	public static function clearCache():Bool
	{
		try
		{
			_deleteDirectory(cacheStorage);
			ensureDirectory(cacheStorage);
			return true;
		}
		catch (e:Dynamic) { return false; }
	}

	public static function getExternalStorageStateMb():{free:Float, total:Float}
	{
		try
		{
			var stat = Environment.getExternalStorageDirectory();
			if (stat != null)
			{
				var statFs = new androidtools.os.StatFs(stat);
				var block:Float  = statFs.getBlockSizeLong();
				var avail:Float  = statFs.getAvailableBlocksLong();
				var total:Float  = statFs.getBlockCountLong();
				return {free: (avail * block) / (1024 * 1024), total: (total * block) / (1024 * 1024)};
			}
		}
		catch (e:Dynamic) {}
		return {free: -1, total: -1};
	}

	public static function getStorageInfo():String
	{
		var info = getExternalStorageStateMb();
		return 'external=$externalStorage | data=$dataStorage | exists=${FileSystem.exists(externalStorage)} | available=${isExternalAvailable()} | free=${Math.round(info.free)}MB / ${Math.round(info.total)}MB';
	}

	static function _ensureCoreDirs():Void
	{
		for (dir in [externalStorage, modsStorage, savesStorage, logsStorage, cacheStorage,
			Path.join([externalStorage, 'assets']),
			Path.join([externalStorage, 'content'])
		]) ensureDirectory(dir);
	}

	static function _safeCopy(src:String, dst:String):Void
	{
		try { ensureDirectory(Path.directory(dst)); File.copy(src, dst); }
		catch (e:Dynamic) {}
	}

	static function _deleteDirectory(path:String):Void
	{
		if (!FileSystem.exists(path)) return;
		try
		{
			for (entry in FileSystem.readDirectory(path))
			{
				var full:String = Path.join([path, entry]);
				if (FileSystem.isDirectory(full)) _deleteDirectory(full);
				else FileSystem.deleteFile(full);
			}
			FileSystem.deleteDirectory(path);
		}
		catch (e:Dynamic) {}
	}

	static function _collectFiles(dir:String):Array<String>
	{
		var result:Array<String> = [];
		try
		{
			for (entry in FileSystem.readDirectory(dir))
			{
				var full:String = Path.join([dir, entry]);
				if (FileSystem.isDirectory(full)) result = result.concat(_collectFiles(full));
				else result.push(full);
			}
		}
		catch (e:Dynamic) {}
		return result;
	}

	static function _getRequiredPermissions():Array<String>
	{
		try
		{
			var sdk:Int = androidtools.Build.VERSION.SDK_INT;
			if (sdk >= 33)
				return [
					'android.permission.READ_MEDIA_IMAGES',
					'android.permission.READ_MEDIA_VIDEO',
					'android.permission.READ_MEDIA_AUDIO'
				];
			if (sdk >= 30)
				return ['android.permission.MANAGE_EXTERNAL_STORAGE'];
		}
		catch (e:Dynamic) {}

		return [
			'android.permission.READ_EXTERNAL_STORAGE',
			'android.permission.WRITE_EXTERNAL_STORAGE'
		];
	}
}
#end
