package funkin.backend;

import openfl.display.BitmapData;
import openfl.display.Bitmap;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.Assets;
import openfl.display.Sprite;

import flixel.util.FlxStringUtil;
import flixel.FlxG;

class FpsDisplayMode
{
	public static inline final DISABLED:Int = 0;
	public static inline final SIMPLE:Int = 1;
	public static inline final ADVANCED:Int = 2;

	public static inline function fromString(str:String):Int
	{
		return switch (str)
		{
			case 'Advanced': ADVANCED;
			case 'Simple': SIMPLE;
			default: DISABLED;
		}
	}
}

@:nullSafety
class DebugDisplay extends Sprite
{
	public static var instance:Null<DebugDisplay> = null;

	public static function init()
	{
		if (FlxG.game?.parent == null || instance != null) return;

		instance = new DebugDisplay(10, 3, 0xFFFFFF);

		#if mobile
		instance.visible = true;
		instance.displayType = FpsDisplayMode.SIMPLE;
		#else
		instance.visible = instance.displayType != FpsDisplayMode.DISABLED;
		#end

		FlxG.game.parent.addChild(instance);
	}

	final textField:TextField;
	final textUnderlay:Bitmap;

	var canUpdate:Bool = true;

	public var currentFPS(default, null):Int = 0;

	public var gcMemory(get, never):Float;
	public var taskMemory(get, never):Float;

	public var displayType:Int = FpsDisplayMode.SIMPLE;

	public var plugins:Array<Void->Null<String>> = [];

	var times:Array<Float> = [];
	var deltaTimeout:Float = 0.0;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();

		textUnderlay = new Bitmap();
		textUnderlay.bitmapData = new BitmapData(1, 1, true, 0x6F000000);

		#if mobile
		final fontSize:Int = 18;
		#else
		final fontSize:Int = 14;
		#end

		final textFormat = new TextFormat(Paths.font('aller.ttf'), fontSize, color);
		textFormat.leading = 5;

		textField = new TextField();
		textField.selectable = false;
		textField.mouseEnabled = false;
		textField.defaultTextFormat = textFormat;
		textField.autoSize = LEFT;
		textField.multiline = true;
		textField.text = "FPS: ";

		#if mobile
		displayType = FpsDisplayMode.SIMPLE;
		#else
		displayType = FpsDisplayMode.fromString(ClientPrefs.fpsDisplayType);
		#end

		addChild(textUnderlay);
		addChild(textField);

		this.x = x;
		this.y = y;
	}

	public static function addPlugin(fun:Void->String):Void->Null<String>
	{
		if (instance == null || instance.plugins.contains(fun)) return fun;

		instance.plugins.push(fun);

		return fun;
	}

	override function __enterFrame(deltaTime:Float):Void
	{
		final now:Float = haxe.Timer.stamp() * 1000;
		times.push(now);
		while (times[0] < now - 1000)
			times.shift();

		if (deltaTimeout < 100)
		{
			deltaTimeout += deltaTime;
			return;
		}

		currentFPS = times.length;
		updateText();
		textUnderlay.width = textField.width + 3;
		textUnderlay.height = textField.height + (displayType == FpsDisplayMode.ADVANCED ? 0 : -5);

		deltaTimeout = 0.0;
	}

	public dynamic function updateText():Void
	{
		__updateText();
	}

	function __updateText()
	{
		#if mobile
		visible = true;
		displayType = FpsDisplayMode.SIMPLE;
		#else
		displayType = FpsDisplayMode.fromString(ClientPrefs.fpsDisplayType);
		visible = displayType != FpsDisplayMode.DISABLED;
		#end

		if (!canUpdate || (displayType == FpsDisplayMode.DISABLED)) return;

		var str = 'FPS: $currentFPS • [GC: ${FlxStringUtil.formatBytes(gcMemory)} | Task: ${FlxStringUtil.formatBytes(taskMemory)}]';

		if (displayType == FpsDisplayMode.ADVANCED)
		{
			var className = Type.getClassName(Type.getClass(FlxG.state));
			if (className.indexOf("ScriptedState") != -1)
			{
				var scripted:funkin.scripting.ScriptedState = cast FlxG.state;
				var path = funkin.scripts.FunkinScript.getPath('scripts/states/${scripted.scriptName}');
				className = 'ScriptedState • (${path.replace('scripts/states/', '../../')})';
			}

			str += ' • $className';

			for (fun in plugins)
			{
				try
				{
					final pluginStr:Null<String> = fun();

					if (pluginStr != null && pluginStr.length > 0) str += '\n$pluginStr';
				}
				catch (e)
				{
					Logger.log('Error on debug display plugin: $e', WARN);

					plugins.remove(fun);
				}
			}
		}

		textField.text = str;
	}

	inline function get_gcMemory():Float
	{
		#if cpp
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
		#elseif hl
		return hl.Gc.stats().currentMemory;
		#else
		return (cast openfl.system.System.totalMemoryNumber : UInt);
		#end
	}

	inline function get_taskMemory():Float
	{
		return external.Native.getTaskMemory();
	}
}
