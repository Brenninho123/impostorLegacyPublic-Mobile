package mobile.play;

import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.util.FlxPool;

class TouchCursor extends FlxSprite
{
	public var touchID:Int    = -1;
	public var active:Bool    = false;

	private var _fadeTimer:Float = 0.0;
	private var _pulseTimer:Float = 0.0;
	private var _baseScale:Float  = 1.0;

	static final FADE_DURATION:Float  = 0.18;
	static final PULSE_SPEED:Float    = 8.0;
	static final PULSE_AMOUNT:Float   = 0.08;
	static final PRESS_SCALE:Float    = 0.82;
	static final RELEASE_SCALE:Float  = 1.0;

	public function new()
	{
		super(0, 0);
		loadGraphic(Paths.image('mobile/cursor'));
		setGraphicSize(48, 48);
		updateHitbox();
		scrollFactor.set(0, 0);
		antialiasing = true;
		alpha        = 0;
		visible      = false;
		active       = false;
	}

	public function spawn(x:Float, y:Float, id:Int):Void
	{
		touchID      = id;
		active       = true;
		visible      = true;
		_fadeTimer   = 0.0;
		_pulseTimer  = 0.0;
		_baseScale   = RELEASE_SCALE;
		alpha        = 0;
		scale.set(_baseScale * 1.2, _baseScale * 1.2);

		setPosition(x - width * 0.5, y - height * 0.5);

		FlxTween.cancelTweensOf(this);
		FlxTween.tween(this, {alpha: 0.85}, FADE_DURATION, {ease: FlxEase.quadOut});
		FlxTween.tween(scale, {x: _baseScale, y: _baseScale}, FADE_DURATION, {ease: FlxEase.backOut});
	}

	public function press():Void
	{
		_baseScale = PRESS_SCALE;
		FlxTween.cancelTweensOf(scale);
		FlxTween.tween(scale, {x: _baseScale, y: _baseScale}, 0.08, {ease: FlxEase.quadOut});
	}

	public function release():Void
	{
		_baseScale = RELEASE_SCALE;
		FlxTween.cancelTweensOf(scale);
		FlxTween.tween(scale, {x: _baseScale * 1.15, y: _baseScale * 1.15}, 0.06, {
			ease: FlxEase.quadOut,
			onComplete: function(_):Void
			{
				FlxTween.tween(scale, {x: _baseScale, y: _baseScale}, 0.1, {ease: FlxEase.quadIn});
			}
		});
	}

	public function moveTo(x:Float, y:Float):Void
	{
		this.x = x - width  * 0.5;
		this.y = y - height * 0.5;
	}

	public function despawn():Void
	{
		active  = false;
		touchID = -1;
		FlxTween.cancelTweensOf(this);
		FlxTween.tween(this, {alpha: 0}, FADE_DURATION, {
			ease: FlxEase.quadIn,
			onComplete: function(_):Void
			{
				visible = false;
				scale.set(RELEASE_SCALE, RELEASE_SCALE);
			}
		});
		FlxTween.tween(scale, {x: RELEASE_SCALE * 1.3, y: RELEASE_SCALE * 1.3}, FADE_DURATION, {ease: FlxEase.quadOut});
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!active || !visible) return;

		_pulseTimer += elapsed * PULSE_SPEED;
		var pulse:Float = 1.0 + Math.sin(_pulseTimer) * PULSE_AMOUNT * (_baseScale / RELEASE_SCALE);
		scale.x = _baseScale * pulse;
		scale.y = _baseScale * pulse;
	}

	override function destroy():Void
	{
		FlxTween.cancelTweensOf(this);
		FlxTween.cancelTweensOf(scale);
		super.destroy();
	}
}

class Cursor
{
	static final MAX_CURSORS:Int = 10;

	private static var _cursors:Array<TouchCursor>       = [];
	private static var _touchMap:Map<Int, TouchCursor>   = new Map();
	private static var _initialized:Bool                 = false;
	private static var _visible:Bool                     = true;
	private static var _camera:Null<FlxCamera>           = null;

	public static function init(?camera:FlxCamera):Void
	{
		if (_initialized) return;

		_camera      = camera;
		_initialized = true;
		_touchMap    = new Map();
		_cursors     = [];

		for (i in 0...MAX_CURSORS)
		{
			var c:TouchCursor = new TouchCursor();
			if (_camera != null) c.cameras = [_camera];
			FlxG.state.add(c);
			_cursors.push(c);
		}
	}

	public static function update():Void
	{
		if (!_initialized || !_visible) return;

		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				var cursor:TouchCursor = _getFreeCursor();
				if (cursor == null) continue;
				cursor.spawn(touch.screenX, touch.screenY, touch.touchPointID);
				cursor.press();
				_touchMap.set(touch.touchPointID, cursor);
			}
			else if (touch.pressed)
			{
				var cursor:TouchCursor = _touchMap.get(touch.touchPointID);
				if (cursor != null) cursor.moveTo(touch.screenX, touch.screenY);
			}
			else if (touch.justReleased)
			{
				var cursor:TouchCursor = _touchMap.get(touch.touchPointID);
				if (cursor != null)
				{
					cursor.release();
					new FlxTimer().start(0.12, function(_):Void { cursor.despawn(); });
					_touchMap.remove(touch.touchPointID);
				}
			}
		}
	}

	public static function show():Void
	{
		_visible = true;
		for (c in _cursors) if (c.active) c.visible = true;
	}

	public static function hide():Void
	{
		_visible = false;
		for (c in _cursors)
		{
			c.despawn();
			c.visible = false;
		}
		_touchMap.clear();
	}

	public static function setCamera(camera:FlxCamera):Void
	{
		_camera = camera;
		for (c in _cursors) c.cameras = [camera];
	}

	public static function setAlpha(value:Float):Void
	{
		for (c in _cursors) c.alpha = c.active ? value : 0;
	}

	public static function destroy():Void
	{
		if (!_initialized) return;

		for (c in _cursors)
		{
			FlxG.state.remove(c, true);
			c.destroy();
		}

		_cursors     = [];
		_touchMap    = new Map();
		_initialized = false;
		_camera      = null;
	}

	public static function isInitialized():Bool { return _initialized; }
	public static function isVisible():Bool     { return _visible; }

	private static function _getFreeCursor():Null<TouchCursor>
	{
		for (c in _cursors)
			if (!c.active) return c;
		return null;
	}
}
