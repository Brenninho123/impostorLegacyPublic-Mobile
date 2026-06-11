package funkin.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.effects.FlxFlicker;
import flixel.addons.transition.FlxTransitionableState;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;

#if mobile
import flixel.input.touch.FlxTouch;
#end

class FlashingState extends MusicBeatState
{
	public static var leftState:Bool = false;

	var warnText:FlxText;

	override function create()
	{
		super.create();

		warnText = new FlxText(0, 0, FlxG.width, "
WARNING!\n
This mod contains effects that may trigger photosensitivity.\n
Press ESCAPE to disable these effects now.\n
Press ENTER to keep them on.\n
You may change this anytime in the Options menu.
		", 32);
		warnText.setFormat(Paths.DEFAULT_FONT, 32, FlxColor.WHITE, CENTER);
		warnText.screenCenter();
		add(warnText);
	}

	override function update(elapsed:Float)
	{
		var accept:Bool = controls.ACCEPT;
		var back:Bool = controls.BACK;

		#if mobile
		for (touch in FlxG.touches.justStarted())
		{
			if (touch.x < FlxG.width * 0.5)
				back = true;
			else
				accept = true;
		}
		#end

		if (!leftState && (accept || back))
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;

			ClientPrefs.photosensitive = back;
			FlxG.sound.play(Paths.sound('confirmMenu'));

			if (back)
			{
				FlxTween.tween(warnText, {alpha: 0}, 1,
				{
					onComplete: function(twn:FlxTween)
					{
						FlxG.switchState(TitleState.new);
					}
				});
			}
			else
			{
				FlxFlicker.flicker(warnText, 1, 0.1, false, true, function(flk:FlxFlicker)
				{
					new FlxTimer().start(0.5, function(tmr:FlxTimer)
					{
						FlxG.switchState(TitleState.new);
					});
				});
			}

			leftState = true;
		}

		super.update(elapsed);
	}
}