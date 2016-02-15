
package game;

import luxe.Vector;

typedef Point = { x :Int, y :Int };

class GridLayout {
    @:isVar public var width(default, null) :Int;
    @:isVar public var height(default, null) :Int;
    @:isVar public var tile_size(default, null) :Float;
    var pos :Vector;

    public function new(width :Int, height :Int, tile_size :Float, center :Vector) {
        this.width = width;
        this.height = height;
        this.tile_size = tile_size;
        pos = new Vector(center.x - (width / 2) * tile_size, center.y - (height / 2) * tile_size);
    }

    public function get_width() {
        return width;
    }

    public function get_height() {
        return height;
    }

    public function get_tile_size() {
        return tile_size;
    }

    public function get_rect() {
        return new luxe.Rectangle(pos.x, pos.y, width * tile_size, height * tile_size);
    }

public function get_pos(x :Int, y :Int /* corner */) {
        return new Vector(pos.x + x * tile_size + tile_size / 2, pos.y + y * tile_size + tile_size / 2);
    }

    public function get_point(p :Vector) :Null<Point> {
        var x = Math.floor((p.x - pos.x) / tile_size);
        var y = Math.floor((p.y - pos.y) / tile_size);
        if (x < 0 || x >= width || y < 0 || y >= height) return null;
        return { x: x, y: y };
    }

    public function inside_map(x :Int, y :Int) {
        return (x >= 0 && x < width && y >= 0 && y < height);
    }

    // get height, width
    // convert pos to x,y and vice versa
    // handle resize (emit events)
    //
}
