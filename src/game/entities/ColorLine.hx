
package game.entities;

import luxe.Color;
import luxe.Sprite;
import luxe.Vector;
import luxe.Scene;

import game.GridLayout.Point;
import game.GridLayout.GridLayout;

typedef ColorLineOptions = {
    points :Array<Point>,
    color :Color,
    layout :GridLayout
}

class ColorLine {
    // var options :ColorLineOptions;
    var scene :Scene;
    var sprites :Array<Sprite>;

    public function new(options :ColorLineOptions) {
        scene = new Scene();
        sprites = [];
        // this.options = options;

        var points = options.points;
        for (i in 1 ... points.length - 1) {
            var p_before = points[i - 1];
            var p = points[i];
            var p_after = points[i + 1];

            var line_horizontal = (p_before.x == p_after.x);
            var line_vertical = (p_before.y == p_after.y);
            var rotation = line_horizontal ? 1 : 0;
            var is_line = line_horizontal || line_vertical;

            if (!is_line) {
                if (p_before.x == p.x) {
                    rotation = (p_before.y < p.y) ? ((p_after.x > p.x) ? 2 : 3) : ((p_after.x > p.x) ? 3 : 2);
                } else if (p_before.y == p.y) {
                    rotation = (p_before.x > p.x) ? ((p_after.y > p.y) ? 1 : 0) : ((p_after.y > p.y) ? 0 : 1);
                }
            }

            var sprite = new luxe.Sprite({
                pos: options.layout.get_pos(p.x, p.y),
                color: options.color,
                size: new Vector(options.layout.tile_size, options.layout.tile_size),
                texture: Luxe.resources.texture(is_line ? 'assets/images/line.png' : 'assets/images/turn.png'),
                rotation_z: rotation * 90,
                depth: -2,
                //scene: scene
            });
            sprites.push(sprite);
        }
    }
}
