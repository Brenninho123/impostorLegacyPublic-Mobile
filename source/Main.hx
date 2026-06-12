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
		_requestAndroidPermissions(function():Void { _initGame(); });
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

	static final _GRANTED:Int = 0;

	function _requestAndroidPermissions(onDone:Void->Void):Void
	{
		var pending:Array<String> = _PERMISSIONS.filter(function(p:String):Bool
		{
			return !_hasPermission(p);
		});

		if (pending.length == 0) { onDone(); return; }

		_requestPermissions(pending, function(results:Map<String, Bool>):Void
		{
			var denied:Array<String> = [];
			for (perm => granted in results)
				if (!granted) denied.push(perm.split('.').pop() ?? perm);

			if (denied.length == 0) { onDone(); return; }

			_showNativeAlert(
				'Storage Permission Required',
				'Some permissions were denied: ${denied.join(", ")}.\nThe game will continue with limited functionality.',
				onDone
			);
		});
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

	function _requestPermissions(permissions:Array<String>, callback:Map<String, Bool>->Void):Void
	{
		try
		{
			var requestMethod = JNI.createStaticMethod(
				'org/haxe/lime/GameActivity',
				'requestPermissions',
				'([Ljava/lang/String;I)V'
			);
			requestMethod(permissions, 1001);
		}
		catch (e:Dynamic) {}

		var results:Map<String, Bool> = new Map();
		var remaining:Int = permissions.length;

		for (perm in permissions)
		{
			var p:String = perm;
			new flixel.util.FlxTimer().start(0.8, function(_):Void
			{
				results.set(p, _hasPermission(p));
				remaining--;
				if (remaining <= 0) callback(results);
			});
		}
	}

	function _showNativeAlert(title:String, message:String, onClose:Void->Void):Void
	{
		try
		{
			var getContext = JNI.createStaticMethod(
				'org/haxe/lime/GameActivity',
				'getInstance',
				'()Lorg/haxe/lime/GameActivity;'
			);
			var context:Dynamic = getContext();

			var builderNew = JNI.createMemberMethod(
				'android/app/AlertDialog_Builder',
				'<init>',
				'(Landroid/content/Context;)V'
			);
			var setTitle = JNI.createMemberMethod(
				'android/app/AlertDialog_Builder',
				'setTitle',
				'(Ljava/lang/CharSequence;)Landroid/app/AlertDialog_Builder;'
			);
			var setMessage = JNI.createMemberMethod(
				'android/app/AlertDialog_Builder',
				'setMessage',
				'(Ljava/lang/CharSequence;)Landroid/app/AlertDialog_Builder;'
			);
			var setButton = JNI.createMemberMethod(
				'android/app/AlertDialog_Builder',
				'setPositiveButton',
				'(Ljava/lang/CharSequence;Landroid/content/DialogInterface_OnClickListener;)Landroid/app/AlertDialog_Builder;'
			);
			var buildMethod = JNI.createMemberMethod(
				'android/app/AlertDialog_Builder',
				'create',
				'()Landroid/app/AlertDialog;'
			);
			var showMethod = JNI.createMemberMethod(
				'android/app/AlertDialog',
				'show',
				'()V'
			);

			var builder:Dynamic = builderNew(context);
			setTitle(builder, title);
			setMessage(builder, message);
			setButton(builder, 'OK', null);
			var dialog:Dynamic = buildMethod(builder);
			showMethod(dialog);
		}
		catch (e:Dynamic) {}

		new flixel.util.FlxTimer().start(0.5, function(_):Void { onClose(); });
	}

	function _openAppSettings():Void
	{
		try
		{
			var getContext = JNI.createStaticMethod(
				'org/haxe/lime/GameActivity',
				'getInstance',
				'()Lorg/haxe/lime/GameActivity;'
			);
			var startActivity = JNI.createMemberMethod(
				'android/app/Activity',
				'startActivity',
				'(Landroid/content/Intent;)V'
			);
			var intentNew = JNI.createMemberMethod(
				'android/content/Intent',
				'<init>',
				'(Ljava/lang/String;)V'
			);
			var context:Dynamic = getContext();
			var intent:Dynamic  = intentNew('android.settings.APPLICATION_DETAILS_SETTINGS');
			startActivity(context, intent);
		}
		catch (e:Dynamic) {}
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
