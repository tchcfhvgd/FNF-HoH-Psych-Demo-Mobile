package;

import cpp.vm.Gc;
import flixel.FlxCamera;
import flixel.FlxGame;
import flixel.FlxState;
import flixel.graphics.FlxGraphic;
import flixel.input.keyboard.FlxKey;
import lime.app.Application;
import openfl.Assets;
import openfl.Lib;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.display.StageScaleMode;
import openfl.events.Event;
import openfl.system.System;
import openfl.utils.AssetCache;
import states.MainMenuState;
import mobile.states.CopyState;
#if linux
import lime.graphics.Image;
#end
// crash handler stuff
#if CRASH_HANDLER
import haxe.CallStack;
import haxe.io.Path;
import openfl.events.UncaughtErrorEvent;
import sys.io.Process;
#end

#if android
import android.content.Context;
import android.os.Build;
#end

class Main extends Sprite {
	var game = {
		width: 1280, // WINDOW width
		height: 720, // WINDOW height
		initialState: states.SplashScreen, // initial game state
		zoom: -1.0, // game state bounds
		framerate: 60, // default framerate
		skipSplash: true, // if the default flixel splash screen should be skipped
		startFullscreen: false // if the game should start at fullscreen mode
	};

	public static var fpsVar:FPS;

	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

	public static var pathBack =
		#if windows
		"../../../../"
		#elseif mac
		"../../../../../../../"
		#else
		""
		#end;

	// You can pretty much ignore everything from here on - your code should go in your states.

	public static function main():Void {
		Lib.current.addChild(new Main());
		#if cpp
		cpp.NativeGc.enable(true);
		#elseif hl
		hl.Gc.enable(true);
		#end
	}

	public function new() {
		super();

		#if android
		Sys.setCwd(Path.addTrailingSlash(Context.getExternalFilesDir()));
		#elseif ios
		Sys.setCwd(System.documentsDirectory);
		#end
		
		if (stage != null) {
			init();
		} else {
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
	}

	private function init(?E:Event):Void {
		if (hasEventListener(Event.ADDED_TO_STAGE)) {
			removeEventListener(Event.ADDED_TO_STAGE, init);
		}

		setupGame();
	}

	private function setupGame():Void {
		#if LUA_ALLOWED Lua.set_callbacks_function(cpp.Callable.fromStaticFunction(psychlua.CallbackHandler.call)); #end
		Controls.instance = new Controls();
		ClientPrefs.loadDefaultKeys();
		addChild(new FlxGame(game.width, game.height, game.initialState, #if (flixel < "5.0.0") game.zoom, #end game.framerate, game.framerate, game.skipSplash, game.startFullscreen));

		FlxG.fixedTimestep = false;
		FlxG.game.focusLostFramerate = 60;
		FlxG.keys.preventDefaultKeys = [TAB];
		FlxG.mouse.visible = false;

		#if android
		FlxG.android.preventDefaultKeys = [BACK];
		#end
				     
		FlxG.signals.gameResized.add(onResizeGame);
		FlxG.signals.preStateSwitch.add(function() {
			Paths.clearStoredMemory(true);
			FlxG.bitmap.dumpCache();

			var cache = cast(Assets.cache, AssetCache);
			for (key => font in cache.font)
				cache.removeFont(key);
			for (key => sound in cache.sound)
				cache.removeSound(key);

		});
		FlxG.signals.postStateSwitch.add(function() {
			Paths.clearUnusedMemory();
		});

		fpsVar = new FPS(10, 3, 0xFFFFFF);
		FlxG.game.addChild(fpsVar);
		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
		if (fpsVar != null) {
			fpsVar.visible = ClientPrefs.data.showFPS;
		}

		#if linux
		var icon = Image.fromFile("icon.png");
		Lib.current.stage.window.setIcon(icon);
		#end

		#if html5
		FlxG.autoPause = false;
		#end

		#if CRASH_HANDLER
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#end

		#if desktop
		DiscordClient.start();
		#end

		/*// shader coords fix
			FlxG.signals.gameResized.add(function(w, h) {
				if (FlxG.cameras != null) {
					for (cam in FlxG.cameras.list) {
						@:privateAccess
						if (cam != null && cam._filters != null)
							resetSpriteCache(cam.flashSprite);
					}
				}

				if (FlxG.game != null)
					resetSpriteCache(FlxG.game);
		});*/

		setExitHandler(function() {
			DataSaver.saveSettings(DataSaver.saveFile);
			DataSaver.doFlush(true);
			trace("YAY!!");
		});
	}

	static function setExitHandler(func:Void->Void):Void {
		#if openfl_legacy
		openfl.Lib.current.stage.onQuit = function() {
			func();
			openfl.Lib.close();
		};
		#else
		openfl.Lib.current.stage.application.onExit.add(function(code) {
			func();
		});
		#end
	}

	static function resetSpriteCache(sprite:Sprite):Void {
		@:privateAccess {
			sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
		}
	}

	// Code was entirely made by sqirra-rng for their fnf engine named "Izzy Engine", big props to them!!!
	// very cool person for real they don't get enough credit for their work
	#if CRASH_HANDLER
	function onCrash(e:UncaughtErrorEvent):Void {
		var errMsg:String = "";
		var path:String;
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var dateNow:String = Date.now().toString();

		dateNow = dateNow.replace(" ", "_");
		dateNow = dateNow.replace(":", "'");

		path = "crash/" + "PsychEngine_" + dateNow + ".txt";

		for (stackItem in callStack) {
			switch (stackItem) {
				case FilePos(s, file, line, column): errMsg += file + " (line " + line + ")\n";
				default: Sys.println(stackItem);
			}
		}

		errMsg += "\nUncaught Error: " + e.error + "\nPlease report this error to the GitHub page: https://github.com/ShadowMario/FNF-PsychEngine\n\n> Crash Handler written by: sqirra-rng";

		if (!FileSystem.exists("crash/"))
			FileSystem.createDirectory("crash/");

		File.saveContent(path, errMsg + "\n");

		Sys.println(errMsg);
		Sys.println("Crash dump saved in " + Path.normalize(path));

		Application.current.window.alert(errMsg, "Error!");
		#if desktop
		DiscordClient.shutdown();
		#end
		Sys.exit(1);
	}
	#end

	function onResizeGame(w:Int, h:Int) {
		if (FlxG.cameras == null)
			return;

		for (cam in FlxG.cameras.list) {
			@:privateAccess
			if (cam != null && cam._filters != null && cam._filters.length > 0)
				fixShaderSize(cam);
		}
	}

	function fixShaderSize(camera:FlxCamera) {
		@:privateAccess {
			var sprite:Sprite = camera.flashSprite;

			if (sprite != null) {
				sprite.__cacheBitmap = null;
				sprite.__cacheBitmapData = null;
				sprite.__cacheBitmapData2 = null;
				sprite.__cacheBitmapData3 = null;
			}
		}
	}
}
