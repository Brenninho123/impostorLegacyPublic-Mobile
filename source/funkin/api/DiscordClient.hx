package funkin.api;

#if DISCORD_ALLOWED
import sys.thread.Thread;
import hxdiscord_rpc.Types.DiscordEventHandlers;
import hxdiscord_rpc.Types.DiscordUser;
import hxdiscord_rpc.Discord;
import hxdiscord_rpc.Types.DiscordRichPresence;

class DiscordClient
{
	public static final NMV_ID:String = '1445524195864870996';

	static var thread:Null<Thread> = null;
	static var initiated:Bool      = false;

	public static var rpcId(default, set):String = NMV_ID;

	public static final discordPresence:DiscordRichPresence = DiscordRichPresence.create();

	public static function init():Void
	{
		if (!ClientPrefs.discordRPC) return;

		final discordEventHandlers = DiscordEventHandlers.create();
		discordEventHandlers.ready        = cpp.Function.fromStaticFunction(onReady);
		discordEventHandlers.errored      = cpp.Function.fromStaticFunction(onError);
		discordEventHandlers.disconnected = cpp.Function.fromStaticFunction(onDisconnect);

		Discord.Initialize(rpcId, cpp.RawPointer.addressOf(discordEventHandlers), 1, null);

		if (thread == null)
		{
			thread = Thread.create(() -> {
				while (true)
				{
					if (initiated)
					{
						#if DISCORD_DISABLE_IO_THREAD
						Discord.UpdateConnection();
						#end
						Discord.RunCallbacks();
					}
					Sys.sleep(2);
				}
			});
			FlxG.stage.window.onClose.add(close);
		}

		initiated = true;
	}

	public static function check():Void
	{
		if (ClientPrefs.discordRPC)
		{
			if (!initiated) init();
		}
		else if (initiated) close();
	}

	static function onError(errorCode:Int, message:cpp.ConstCharStar):Void
	{
		Logger.log('Discord Error. [$errorCode: ${(cast message : String)}]');
	}

	static function onDisconnect(errorCode:Int, message:cpp.ConstCharStar):Void
	{
		Logger.log('Discord Disconnected. [$errorCode: ${(cast message : String)}]');
	}

	public static function close():Void
	{
		if (initiated) Discord.Shutdown();
		initiated = false;
	}

	static function onReady(request:cpp.RawConstPointer<DiscordUser>):Void
	{
		final user:String          = cast request[0].username;
		final discriminator:String = cast request[0].discriminator;
		var discordUser:String     = discriminator != '0' ? '[$user#$discriminator]' : '[$user]';
		Logger.log('Successfully connect to user $discordUser', NOTICE);
		changePresence();
	}

	public static function changePresence(
		details:String        = 'In the Menus',
		?state:String,
		?smallImageKey:String,
		hasStartTimestamp:Bool = false,
		?endTimestamp:Float,
		largeImageKey:String   = 'icon'):Void
	{
		final startTimestamp:Float = hasStartTimestamp ? Date.now().getTime() : 0;
		if (endTimestamp > 0) endTimestamp = startTimestamp + endTimestamp;

		discordPresence.state          = state;
		discordPresence.details        = details;
		discordPresence.smallImageKey  = smallImageKey;
		discordPresence.largeImageKey  = largeImageKey;
		discordPresence.largeImageText = Main.LEGACY_VERSION;
		discordPresence.startTimestamp = Std.int(startTimestamp / 1000);
		discordPresence.endTimestamp   = Std.int(endTimestamp   / 1000);

		updatePresence();
	}

	static function updatePresence():Void
	{
		Discord.UpdatePresence(cpp.RawConstPointer.addressOf(discordPresence));
	}

	static function set_rpcId(value:String):String
	{
		if (rpcId != value && initiated)
		{
			rpcId = value;
			close();
			init();
			updatePresence();
		}
		return rpcId;
	}
}
#else

class DiscordClient
{
	public static final NMV_ID:String = '1252033037680513115';

	public static var rpcId(default, set):String = '';

	public static inline function init():Void {}

	public static inline function check():Void {}

	public static inline function close():Void {}

	public static inline function changePresence(
		details:String        = 'In the Menus',
		?state:String,
		?smallImageKey:String,
		hasStartTimestamp:Bool = false,
		?endTimestamp:Float,
		largeImageKey:String   = 'icon'):Void {}

	static function set_rpcId(value:String):String return (rpcId = value);
}
#end
