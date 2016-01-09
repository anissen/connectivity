
import luxe.States;
import luxe.Input.KeyEvent;
import luxe.Input.Key;

import game.states.*;

class Main extends luxe.Game {
    static public var states :States;

    override function config(config :luxe.AppConfig) {
        config.render.antialiasing = 4;
        return config;
    }

    override function ready() {
        // Optional, set a consistent scale camera mode for the entire game
		// this is a luxe's wip feature
		// Luxe.camera.size = new luxe.Vector(960, 640);
		// Luxe.camera.size_mode = luxe.Camera.SizeMode.cover;
		// Luxe.camera.center = new luxe.Vector();

        luxe.tween.Actuate.defaultEase = luxe.tween.easing.Quad.easeInOut;

        Luxe.renderer.clear_color.set(10/255, 10/255, 10/255);

        states = new States({ name: 'state_machine' });
        states.add(new PlayState());
        states.set(PlayState.StateId);
    }

    // Scale camera's viewport accordingly when game is scaled, common and suitable for most games
	override function onwindowsized(e: luxe.Screen.WindowEvent) {
        Luxe.camera.viewport = new luxe.Rectangle(0, 0, e.event.x, e.event.y);
    }

    // override function onrender() {
    //     Luxe.draw.rectangle({
    //         x: 20,
    //         y: 20,
    //         w: Luxe.screen.w - 40,
    //         h: Luxe.screen.h - 40,
    //         immediate: true
    //     });
    // }

    override function onkeyup(e :KeyEvent) {
        if (e.keycode == Key.enter && e.mod.alt) {
            app.app.window.fullscreen = !app.app.window.fullscreen;
        } else if (e.keycode == Key.escape) {
            if (!Luxe.core.shutting_down) Luxe.shutdown();
        }
    }
}