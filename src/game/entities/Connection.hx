
package game.entities;

import luxe.Color;
import luxe.Sprite;
import luxe.Vector;

typedef ConnectionOptions = {
    point :{ x :Int, y :Int },
    layout :GridLayout
}

class Connection extends Sprite {
    var options :ConnectionOptions;

    public function new(options :ConnectionOptions) {
        super({
            pos: options.layout.point_to_pos(options.point),
            color: new Color(1, 1, 1, 0),
            size: options.layout.tile_size,
            scale: new Vector(0, 0),
            texture: Luxe.resources.texture('assets/images/circle.png'),
            depth: 0
        });
        this.options = options;
    }
}
