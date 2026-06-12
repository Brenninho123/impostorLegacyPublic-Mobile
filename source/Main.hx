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
#end

@:nullSafety(Strict)
class Main extends Sprite
{
	public static final PSYCH_VERSION:String   = '0.5.2h';
	public static final NMV_VERSION:String     = '1.0';
	public static final FUNKIN_VERSION:String  = '0.2.7';
	public static final LEGACY_VERSION:String  = '1.1.0';

	public static final startMeta =
	{
		width:        1280,
		height:       720,
		fps:          60,
		skipSplash:   #if debug true #else false #end,
		startFullScreen: false,
		initialState: funkin.states.TitleState
	};

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
			_initGame();
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
	static final _PERMISSIONS:Array<String> = [
		'android.permission.READ_EXTERNAL_STORAGE',
		'android.permission.WRITE_EXTERNAL_STORAGE',
		'android.permission.READ_MEDIA_IMAGES',
		'android.permission.READ_MEDIA_VIDEO',
		'android.permission.READ_MEDIA_AUDIO'
	];

	static final _PERMISSION_DENIED:Int  = -1;
	static final _PERMISSION_GRANTED:Int =  0;

	function _requestAndroidPermissions(onGranted:Void->Void):Void
	{
		var pending:Array<String> = _PERMISSIONS.filter(function(p:String):Bool
		{
			return !_hasPermission(p);
		});

		if (pending.length == 0) { onGranted(); return; }

		_requestPermissions(pending, function(results:Map<String, Bool>):Void
		{
			var allGranted:Bool  = true;
			var denied:Array<String> = [];

			for (perm => granted in results)
			{
				if (!granted)
				{
					allGranted = false;
					denied.push(perm.split('.').pop());
				}
			}

			if (allGranted)
			{
				onGranted();
			}
			else
			{
				_showPermissionDialog(denied, onGranted);
			}
		});
	}

	function _hasPermission(permission:String):Bool
	{
		try
		{
			var checkPermission = JNI.createStaticMethod(
				'org/haxe/lime/GameActivity',
				'checkCallingOrSelfPermission',
				'(Ljava/lang/String;)I'
			);
			return checkPermission(permission) == _PERMISSION_GRANTED;
		}
		catch (e:Dynamic) { return false; }
	}

	function _requestPermissions(permissions:Array<String>, callback:Map<String, Bool>->Void):Void
	{
		try
		{
			var requestMethod = JNI.createStaticMethod(
				'org/haxe/lime/GameActivity',
				'requestPermissions',
				'([Ljava/lang/String;I)V'
			);

			var results:Map<String, Bool> = new Map();
			var remaining:Int = permissions.length;

			for (perm in permissions)
			{
				new flixel.util.FlxTimer().start(0.1, function(_):Void
				{
					results.set(perm, _hasPermission(perm));
					remaining--;
					if (remaining <= 0) callback(results);
				});
			}

			requestMethod(permissions, 1001);
		}
		catch (e:Dynamic)
		{
			var results:Map<String, Bool> = new Map();
			for (perm in permissions) results.set(perm, false);
			callback(results);
		}
	}

	function _showPermissionDialog(denied:Array<String>, onContinue:Void->Void):Void
	{
		try
		{
			var alertMethod = JNI.createStaticMethod(
				'org/haxe/lime/GameActivity',
				'runOnUiThread',
				'(Ljava/lang/Runnable;)V'
			);

			var deniedStr:String = denied.join(', ');

			var showDialog = JNI.createStaticMethod(
				'android/app/AlertDialog$Builder',
				'create',
				'()Landroid/app/AlertDialog;'
			);

			_showNativeAlert(
				'Storage Permission Required',
				'This game needs storage access to load mods and save data.\n\nDenied: $deniedStr\n\nThe game will continue with limited functionality.',
				'Continue',
				'Open Settings',
				function(openSettings:Bool):Void
				{
					if (openSettings) _openAppSettings();
					onContinue();
				}
			);
		}
		catch (e:Dynamic)
		{
			onContinue();
		}
	}

	function _showNativeAlert(title:String, message:String, positiveLabel:String, negativeLabel:String, callback:Bool->Void):Void
	{
		try
		{
			var showAlert = JNI.createStaticMethod(
				'org/haxe/lime/GameActivity',
				'showAlert',
				'(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V'
			);
			showAlert(title, message, positiveLabel, negativeLabel);
		}
		catch (e:Dynamic) {}

		new flixel.util.FlxTimer().start(0.5, function(_):Void { callback(false); });
	}

	function _openAppSettings():Void
	{
		try
		{
			var openSettings = JNI.createStaticMethod(
				'org/haxe/lime/GameActivity',
				'startActivity',
				'(Landroid/content/Intent;)V'
			);
			var intent = JNI.createStaticMethod(
				'android/content/Intent',
				'<init>',
				'(Ljava/lang/String;)V'
			);
			openSettings(intent('android.settings.APPLICATION_DETAILS_SETTINGS'));
		}
		catch (e:Dynamic) {}
	}
	#end

	@:access(flixel.FlxCamera)
	static function onResize(w:Int, h:Int):Void
	{
		final scale:Float = Math.max(1, Math.min(w / FlxG.width, h / FlxG.height));

		if (FlxG.cameras != null)
		{
			for (i in FlxG.cameras.list)
				if (i != null && i.filters != null) resetSpriteCache(i.flashSprite);
		}

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
