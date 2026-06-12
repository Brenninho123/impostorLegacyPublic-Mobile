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
		Storage.requestPermissionsAndInit(function(granted:Bool):Void
		{
			Storage.copyAssetsAsync(
				function(progress:Float):Void {},
				function(success:Bool):Void
				{
					_initGame();
				}
			);
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
