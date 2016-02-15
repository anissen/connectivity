
package game.states;

import luxe.Input.MouseEvent;
import luxe.States.State;
import luxe.tween.Actuate;
import luxe.Vector;
import luxe.Visual;
import luxe.Color;
import game.GridLayout;

using Lambda;

typedef LevelCircles = {
    point :Point,
    level :Int
}

class LevelSelectState extends State {
    static public var StateId :String = 'LevelSelectState';

    var layout :GridLayout;
    var tween_speed :Float = 0.25;
    var levelIndex :Int;

    var levelCircles :Array<LevelCircles>;

    public function new() {
        super({ name: StateId });
    }

    override function onenter(data :Dynamic) {
        reset(data);
    }

    function load_level(data :Dynamic) {
        var w :Int = data.width;
        var h :Int = data.height;
        var margin_tiles = 2;

        var tile_size = Math.min(Luxe.screen.w / (w + margin_tiles), Luxe.screen.h / (h + margin_tiles));
        layout = new GridLayout(w, h, tile_size, Luxe.screen.mid.clone());

        for (y in 0 ... layout.height) {
            var arr = [];
            for (x in 0 ... layout.width) {
                var sprite = new luxe.Sprite({
                    pos: layout.get_pos(x, y),
                    color: new Color(0, 0.8, 1.0, 0.2),
                    size: new Vector(layout.tile_size, layout.tile_size),
                    scale: new Vector(0.2, 0.2),
                    texture: Luxe.resources.texture('assets/images/circle.png'),
                    depth: 0
                });
            }
        }

        levelCircles = [];
        for (i in 0 ... data.lines.length) {
            var line = data.lines[i];
            var points :Array<{ x :Int, y :Int, level :Null<Int> }> = line.points;
            new game.entities.ColorLine({
                points: points,
                color: new Color(0, 0.5, 1.0), //convert_color(line.color),
                layout: layout
            });
            for (p in line.points) {
                if (p.level == null) continue;
                levelCircles.push({ point: p, level: p.level });
                var sprite = new luxe.Sprite({
                    pos: layout.get_pos(p.x, p.y),
                    color: (levelIndex >= p.level ? new Color(0, 0.8, 1.0, 1) : new Color(0, 0.4, 0.5, 1)),
                    size: new Vector(layout.tile_size, layout.tile_size),
                    // scale: new Vector(0, 0),
                    texture: Luxe.resources.texture('assets/images/circle.png'),
                    depth: 0
                });
                // new luxe.Text({ // TEMP!
                //     text: '' + p.level,
                //     pos: layout.get_pos(p.x, p.y),
                //     align: luxe.Text.TextAlign.center,
                //     align_vertical: luxe.Text.TextAlign.center,
                //     color: new Color()
                // });
            }
        }

        // lines = data.lines;
        // for (i in 0 ... lines.length) {
        //     var line = lines[i];
        //     line.color = switch (i) {
        //         case 0: Orange;
        //         case 1: Blue;
        //         case _: Green;
        //     };
        //     line.connections = [];
        //     line.completedConnections = 0;
        //     line.sprites = [];
        // }
    }

    function reset(level :Int) {
        Luxe.scene.empty();

        levelIndex = level;

        load_level(Luxe.resources.json('assets/level_selections/selection0.json').asset.json);
    }

    override public function onmouseup(event :luxe.Input.MouseEvent) {
        var point = layout.get_point(event.pos);
        if (point == null) return;

        for (levelCircle in levelCircles) {
            if (levelCircle.point.x == point.x && levelCircle.point.y == point.y && levelCircle.level <= levelIndex) {
                Main.states.set(PlayState.StateId, levelCircle.level);
                return;
            }
        }
        // var tile = tiles[tile_pos.y][tile_pos.x];
        // tile.connectType = switch (tile.connectType) {
        //     case Unconnected: Connected;
        //     case Connected: Unconnected;
        // };
    }
}
