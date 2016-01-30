
import luxe.States;
import luxe.Input.KeyEvent;
import luxe.Input.Key;

import game.states.*;

class Main extends luxe.Game {
    static public var states :States;

    override function config(config :luxe.AppConfig) {
        config.preload.textures.push({ id: 'assets/images/line.png' });
        config.preload.textures.push({ id: 'assets/images/turn.png' });
        config.preload.textures.push({ id: 'assets/images/circle.png' });

        config.preload.jsons.push({ id: 'assets/particle_systems/fireworks.json' });

        config.preload.jsons.push({ id: 'assets/levels/level0.json' });
        config.preload.jsons.push({ id: 'assets/levels/level1.json' });
        config.preload.jsons.push({ id: 'assets/levels/level2.json' });

        config.render.antialiasing = 4;
        return config;
    }

    override function ready() {
        luxe.tween.Actuate.defaultEase = luxe.tween.easing.Quad.easeInOut;

        Luxe.renderer.clear_color.set(1, 1, 1);

        states = new States({ name: 'state_machine' });
        states.add(new PlayState());
        states.add(new EditState());
        states.set(PlayState.StateId);
    }

    // Scale camera's viewport accordingly when game is scaled, common and suitable for most games
	override function onwindowsized(e: luxe.Screen.WindowEvent) {
        Luxe.camera.viewport = new luxe.Rectangle(0, 0, e.event.x, e.event.y);
    }

    override function onkeyup(e :KeyEvent) {
        if (e.keycode == Key.enter && e.mod.alt) {
            app.app.window.fullscreen = !app.app.window.fullscreen;
        }
        #if desktop
        if (e.keycode == Key.escape) {
            if (!Luxe.core.shutting_down) Luxe.shutdown();
        }
        #end
    }
}
