package;

import openfl.Lib;
import openfl.display.Sprite;
import openfl.display.StageScaleMode;

import flixel.FlxG;
import flixel.FlxGame;
import flixel.input.keyboard.FlxKey;

import funkin.backend.DebugDisplay;

#if android
import mobile.Storage;
import lime.system.JNI;
import sys.FileSystem;
import sys.io.File;
#end

@:nullSafety(Strict)
class Main extends Sprite
{
	public static final PSYCH_VERSION:String  = '0.5.2h';
	public static final NMV_VERSION:String    = '1.0';
	public static final FUNKIN_VERSION:String = '0.2.7';
	public static final LEGACY_VERSION:String = '1.1.0';

	public static final startMeta =
	{
		width:           1280,
		height:          720,
		fps:             60,
		skipSplash:      #if debug true #else false #end,
		startFullScreen: false,
		initialState:    funkin.states.TitleState
	};

	#if android
	static final _PERMISSIONS:Array<String> = [
		'android.permission.READ_EXTERNAL_STORAGE',
		'android.permission.WRITE_EXTERNAL_STORAGE',
		'android.permission.READ_MEDIA_IMAGES',
		'android.permission.READ_MEDIA_VIDEO',
		'android.permission.READ_MEDIA_AUDIO'
	];

	static final _GRANTED:Int = 0;

	static final _COPY_DIRS:Array<String> = [
		'assets',
		'content'
	];
	#end

	static function __init__():Void
	{
		funkin.utils.MacroUtil.haxeVersionEnforcement();
		openfl.utils._internal.Log.level = openfl.utils._internal.Log.LogLevel.INFO;
	}

	public function new()
	{
		super();

		#if android
		Storage.init();
		_requestAndroidPermissions(function():Void
		{
			_copyAssetsToExternal(function():Void
			{
				_initGame();
			});
		});
		#else
		_initGame();
		#end
	}

	function _initGame():Void
	{
		funkin.Mods.updateModList();
		funkin.Mods.loadTopMod();

		#if (CRASH_HANDLER && !debug)
		funkin.backend.CrashHandler.init();
		#end

		initHaxeUI();

		#if (windows && cpp)
		cpp.Windows.setDpiAware();
		#end

		ClientPrefs.loadDefaultKeys();
		ClientPrefs.tryBindingSave('funkin');

		final game = new funkin.backend.FunkinGame(
			startMeta.width, startMeta.height,
			Init,
			startMeta.fps, startMeta.fps,
			true,
			startMeta.startFullScreen
		);

		@:privateAccess
		game._customSoundTray = funkin.objects.FunkinSoundTray;
		addChild(game);

		FlxG.stage.addEventListener(openfl.events.KeyboardEvent.KEY_DOWN, function(e):Void
		{
			if (e.keyCode == FlxKey.ENTER && e.altKey) e.stopImmediatePropagation();
		}, false, 100);

		DebugDisplay.init();
		FlxG.signals.gameResized.add(onResize);

		#if DISABLE_TRACES
		haxe.Log.trace = (v:Dynamic, ?infos:haxe.PosInfos) -> {}
		#end

		#if sys
		FlxG.stage.window.onClose.add(function():Void
		{
			@:privateAccess MusicBeatState.addPlayTimeDelta();
			ClientPrefs.flush();
			funkin.Mods.writeModList();

			#if hxvlc
			hxvlc.util.Handle.dispose();
			#end

			Sys.exit(0);
		});
		#end
	}

	#if android
	function _requestAndroidPermissions(onDone:Void->Void):Void
	{
		var pending:Array<String> = _PERMISSIONS.filter(function(p:String):Bool
		{
			return !_hasPermission(p);
		});

		if (pending.length == 0) { onDone(); return; }

		try
		{
			var requestMethod = JNI.createStaticMethod(
				'org/haxe/lime/GameActivity',
				'requestPermissions',
				'([Ljava/lang/String;I)V'
			);
			requestMethod(pending, 1001);
		}
		catch (e:Dynamic) {}

		var elapsed:Float  = 0.0;
		var maxWait:Float  = 15.0;
		var interval:Float = 0.3;

		var timer = new flixel.util.FlxTimer();
		timer.start(interval, function(t:flixel.util.FlxTimer):Void
		{
			elapsed += interval;
			var allDone:Bool = true;
			for (p in pending)
				if (!_hasPermission(p)) { allDone = false; break; }

			if (allDone || elapsed >= maxWait)
			{
				t.cancel();
				onDone();
			}
		}, 0);
	}

	function _hasPermission(permission:String):Bool
	{
		try
		{
			var check = JNI.createStaticMethod(
				'org/haxe/lime/GameActivity',
				'checkCallingOrSelfPermission',
				'(Ljava/lang/String;)I'
			);
			return (check(permission) : Int) == _GRANTED;
		}
		catch (e:Dynamic) { return false; }
	}

	function _copyAssetsToExternal(onDone:Void->Void):Void
	{
		var externalBase:String = Storage.externalStorage;
		if (externalBase == null || externalBase.length == 0) { onDone(); return; }

		var versionFile:String    = externalBase + '/.version';
		var currentVersion:String = LEGACY_VERSION;

		if (FileSystem.exists(versionFile))
		{
			try
			{
				var saved:String = StringTools.trim(File.getContent(versionFile));
				if (saved == currentVersion) { onDone(); return; }
			}
			catch (e:Dynamic) {}
		}

		sys.thread.Thread.create(function():Void
		{
			try
			{
				for (dir in _COPY_DIRS)
					_copyDir(dir, externalBase + '/' + dir);

				_ensureDir(externalBase + '/content');

				_ensureDir(haxe.io.Path.directory(versionFile));
				File.saveContent(versionFile, currentVersion);
			}
			catch (e:Dynamic) {}

			haxe.MainLoop.runInMainThread(function():Void
			{
				onDone();
			});
		});
	}

	function _copyDir(srcDir:String, destDir:String):Void
	{
		_ensureDir(destDir);

		var assetList:Array<String> = [];
		try
		{
			assetList = lime.utils.Assets.list().filter(function(p:String):Bool
			{
				return StringTools.startsWith(p, srcDir + '/') || p == srcDir;
			});
		}
		catch (e:Dynamic) {}

		for (assetPath in assetList)
		{
			var rel:String  = assetPath.substr(srcDir.length + 1);
			var dest:String = '$destDir/$rel';

			if (rel.length == 0) continue;
			if (FileSystem.exists(dest)) continue;

			_ensureDir(haxe.io.Path.directory(dest));
			try
			{
				var bytes = lime.utils.Assets.getBytes(assetPath);
				if (bytes != null) File.saveBytes(dest, bytes);
			}
			catch (e:Dynamic) {}
		}

		try
		{
			if (FileSystem.exists(srcDir) && FileSystem.isDirectory(srcDir))
			{
				for (file in FileSystem.readDirectory(srcDir))
				{
					var src:String  = '$srcDir/$file';
					var dest:String = '$destDir/$file';

					if (FileSystem.isDirectory(src))
						_copyDir(src, dest);
					else if (!FileSystem.exists(dest))
					{
						_ensureDir(haxe.io.Path.directory(dest));
						try { File.saveBytes(dest, File.getBytes(src)); }
						catch (e:Dynamic) {}
					}
				}
			}
		}
		catch (e:Dynamic) {}
	}

	function _ensureDir(path:String):Void
	{
		if (path == null || path.length == 0) return;
		if (!FileSystem.exists(path))
		{
			try { FileSystem.createDirectory(path); }
			catch (e:Dynamic) {}
		}
	}
	#end

	@:access(flixel.FlxCamera)
	static function onResize(w:Int, h:Int):Void
	{
		if (FlxG.cameras != null)
			for (i in FlxG.cameras.list)
				if (i != null && i.filters != null) resetSpriteCache(i.flashSprite);

		if (FlxG.game != null) resetSpriteCache(FlxG.game);
	}

	@:nullSafety(Off)
	public static function resetSpriteCache(sprite:Sprite):Void
	{
		if (sprite == null) return;
		@:privateAccess
		{
			sprite.__cacheBitmap     = null;
			sprite.__cacheBitmapData = null;
		}
	}

	function initHaxeUI():Void
	{
		#if haxeui_core
		haxe.ui.Toolkit.init();
		haxe.ui.Toolkit.theme              = 'dark';
		haxe.ui.Toolkit.autoScale          = false;
		haxe.ui.focus.FocusManager.instance.autoFocus = false;
		haxe.ui.tooltips.ToolTipManager.defaultDelay  = 200;
		#end
	}
}
