package mobile.controls;

#if mobile
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.input.touch.FlxTouch;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

enum abstract MobileButton(Int) to Int
{
	var LEFT = 0;
	var DOWN = 1;
	var UP = 2;
	var RIGHT = 3;
	var EXTRA_1 = 4;
	var EXTRA_2 = 5;
}

typedef MobileButtonState =
{
	var pressed:Bool;
	var justPressed:Bool;
	var justReleased:Bool;
}

class MobileControls extends FlxSpriteGroup
{
	public static var instance(default, null):MobileControls;

	public static final BUTTON_SIZE:Float = 110;
	public static final BUTTON_ALPHA:Float = 0.65;
	public static final BUTTON_ALPHA_PRESSED:Float = 0.95;
	public static final BUTTON_MARGIN:Float = 18;

	var _buttons:Array<FlxSprite> = [];
	var _states:Array<MobileButtonState> = [];
	var _touchMap:Map<Int, Int> = [];

	public var visible_buttons:Int = 4;

	public function new(buttonCount:Int = 4)
	{
		super();

		instance = this;
		visible_buttons = buttonCount;

		for (i in 0...6)
		{
			_states.push({pressed: false, justPressed: false, justReleased: false});
		}

		_buildButtons();

		scrollFactor.set(0, 0);
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}

	function _buildButtons():Void
	{
		final colors:Array<FlxColor> = [
			0xFF00AAFF,
			0xFF00DDAA,
			0xFFDD4400,
			0xFFAA00FF,
			0xFFFFAA00,
			0xFFFF0066
		];

		final labels:Array<String> = ["◄", "▼", "▲", "►", "!", "?"];

		final sw:Float = FlxG.width;
		final sh:Float = FlxG.height;
		final bSize:Float = BUTTON_SIZE;
		final margin:Float = BUTTON_MARGIN;

		final leftBaseX:Float = margin;
		final leftBaseY:Float = sh - bSize * 2 - margin * 2;

		final rightBaseX:Float = sw - bSize * 2 - margin;
		final rightBaseY:Float = sh - bSize * 2 - margin * 2;

		final positions:Array<{x:Float, y:Float}> = [
			{x: leftBaseX, y: leftBaseY + bSize * 0.5 + margin * 0.5},
			{x: leftBaseX + bSize + margin, y: leftBaseY + bSize + margin},
			{x: leftBaseX + bSize + margin, y: leftBaseY},
			{x: leftBaseX + bSize * 2 + margin * 2, y: leftBaseY + bSize * 0.5 + margin * 0.5},
			{x: rightBaseX, y: sh - bSize - margin},
			{x: rightBaseX + bSize + margin, y: sh - bSize - margin}
		];

		for (i in 0...visible_buttons)
		{
			final btn = new FlxSprite(positions[i].x, positions[i].y);
			btn.makeGraphic(Std.int(bSize), Std.int(bSize), FlxColor.TRANSPARENT);

			_drawRoundedButton(btn, colors[i], labels[i]);

			btn.alpha = BUTTON_ALPHA;
			btn.scrollFactor.set(0, 0);

			_buttons.push(btn);
			add(btn);
		}
	}

	function _drawRoundedButton(btn:FlxSprite, color:FlxColor, label:String):Void
	{
		final size:Int = Std.int(BUTTON_SIZE);
		final radius:Int = 20;

		btn.makeGraphic(size, size, FlxColor.TRANSPARENT, true);

		final gfx = btn.pixels;

		for (py in 0...size)
		{
			for (px in 0...size)
			{
				final inCornerTL = px < radius && py < radius;
				final inCornerTR = px >= size - radius && py < radius;
				final inCornerBL = px < radius && py >= size - radius;
				final inCornerBR = px >= size - radius && py >= size - radius;

				var draw = true;

				if (inCornerTL)
				{
					final dx = px - radius;
					final dy = py - radius;
					if (dx * dx + dy * dy > radius * radius) draw = false;
				}
				else if (inCornerTR)
				{
					final dx = px - (size - radius);
					final dy = py - radius;
					if (dx * dx + dy * dy > radius * radius) draw = false;
				}
				else if (inCornerBL)
				{
					final dx = px - radius;
					final dy = py - (size - radius);
					if (dx * dx + dy * dy > radius * radius) draw = false;
				}
				else if (inCornerBR)
				{
					final dx = px - (size - radius);
					final dy = py - (size - radius);
					if (dx * dx + dy * dy > radius * radius) draw = false;
				}

				if (draw)
				{
					final border = 3;
					final onBorder = px < border || px >= size - border || py < border || py >= size - border;
					final pixelColor:FlxColor = onBorder ? FlxColor.WHITE : color;
					gfx.setPixel32(px, py, pixelColor);
				}
			}
		}

		btn.dirty = true;
	}

	override function update(elapsed:Float):Void
	{
		for (i in 0...visible_buttons)
		{
			_states[i].justPressed = false;
			_states[i].justReleased = false;
		}

		final toRemove:Array<Int> = [];

		for (touchID => btnIndex in _touchMap)
		{
			var found = false;
			for (touch in FlxG.touches.list)
			{
				if (touch.touchPointID == touchID && touch.pressed)
				{
					found = true;
					break;
				}
			}
			if (!found) toRemove.push(touchID);
		}

		for (id in toRemove)
		{
			final btnIndex = _touchMap.get(id);
			if (btnIndex != null && _states[btnIndex].pressed)
			{
				_states[btnIndex].pressed = false;
				_states[btnIndex].justReleased = true;
				_onButtonRelease(btnIndex);
			}
			_touchMap.remove(id);
		}

		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				for (i in 0...visible_buttons)
				{
					final btn = _buttons[i];
					if (_hitTest(btn, touch.x, touch.y))
					{
						_touchMap.set(touch.touchPointID, i);
						if (!_states[i].pressed)
						{
							_states[i].pressed = true;
							_states[i].justPressed = true;
							_onButtonPress(i);
						}
						break;
					}
				}
			}
		}

		super.update(elapsed);
	}

	function _hitTest(btn:FlxSprite, tx:Float, ty:Float):Bool
	{
		return tx >= btn.x && tx <= btn.x + btn.width && ty >= btn.y && ty <= btn.y + btn.height;
	}

	function _onButtonPress(index:Int):Void
	{
		final btn = _buttons[index];
		FlxTween.cancelTweensOf(btn);
		FlxTween.tween(btn, {alpha: BUTTON_ALPHA_PRESSED, "scale.x": 0.92, "scale.y": 0.92}, 0.06, {ease: FlxEase.quadOut});
	}

	function _onButtonRelease(index:Int):Void
	{
		final btn = _buttons[index];
		FlxTween.cancelTweensOf(btn);
		FlxTween.tween(btn, {alpha: BUTTON_ALPHA, "scale.x": 1.0, "scale.y": 1.0}, 0.1, {ease: FlxEase.quadOut});
	}

	public function pressed(button:MobileButton):Bool
	{
		final i:Int = (button : Int);
		if (i >= visible_buttons) return false;
		return _states[i].pressed;
	}

	public function justPressed(button:MobileButton):Bool
	{
		final i:Int = (button : Int);
		if (i >= visible_buttons) return false;
		return _states[i].justPressed;
	}

	public function justReleased(button:MobileButton):Bool
	{
		final i:Int = (button : Int);
		if (i >= visible_buttons) return false;
		return _states[i].justReleased;
	}

	public function setVisible(show:Bool):Void
	{
		visible = show;
		active = show;
	}

	public function setButtonCount(count:Int):Void
	{
		visible_buttons = count;
		for (i in 0..._buttons.length)
			_buttons[i].visible = i < count;
	}

	override function destroy():Void
	{
		instance = null;
		_touchMap.clear();
		super.destroy();
	}
}
#end
