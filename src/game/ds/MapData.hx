package game.ds;

import game.ds.Point;
import game.ds.GridLayout;

enum ConnectColor {
    None;
    Invalid;
    Orange;
    Green;
    Blue;
}

enum ConnectType {
    Unconnected;
    Connected;
}

typedef LineData = {
    color :ConnectColor,
    points :Array<Point>,
    requiredConnections :Int,
    connections :Array<Array<Tile>>,
    completedConnections :Int,
    sprites :Array<luxe.Sprite>
}

typedef Tile = {
    color :ConnectColor,
    connectType :ConnectType,
    length :Int,
    visited :Bool,
    sprite :luxe.Sprite
}

// enum LineEvent {
//     Added;
// }
//
// enum ConnectionEvent {
//
// }

// enum Event {
//     Clear;
//     AddedLine;
//     RemovedLine;
//     AddedConnection;
// }

class MapData {
    public var tiles :Array<Array<Tile>>;
    public var lines :Array<LineData>;
    public var layout :GridLayout;
    public var connectionLengths = 4;

    static var instance :MapData = null;

    function new() {

    }

    static public function get_instance() {
        if (instance == null) {
            instance = new MapData();
        }
        return instance;
    }

    public function load_level(data :Dynamic) {
        connectionLengths = data.connection_lengths;
        lines = data.lines;
        for (i in 0 ... lines.length) {
            var line = lines[i];
            line.color = switch (i) {
                case 0: Orange;
                case 1: Blue;
                case _: Green;
            };
            line.connections = [];
            line.completedConnections = 0;
            line.sprites = [];
        }
        make_grid_layout(data.width, data.height);
    }

    public function make_grid_layout(w :Int, h :Int, clear :Bool = true /* hack */) {
        var margin_tiles = 2;

        var tile_size = Math.min(Luxe.screen.w / (w + margin_tiles), Luxe.screen.h / (h + margin_tiles));
        layout = new GridLayout(w, h, tile_size, Luxe.screen.mid.clone());

        //redraw_level(clear);
    }

    public function can_visit(x :Int, y :Int) :Bool {
        if (!layout.inside_map(x, y)) return false;
        return tiles[y][x].connectType == Connected && !tiles[y][x].visited;
    }

    public function get_connection(x: Int, y: Int) :Array<Tile> {
        if (!can_visit(x, y)) return [];
        tiles[y][x].visited = true;

        var list = [];
        list.push(tiles[y][x]);
        if (can_visit(x - 1, y)) list = list.concat(get_connection(x - 1, y));
        if (can_visit(x + 1, y)) list = list.concat(get_connection(x + 1, y));
        if (can_visit(x, y - 1)) list = list.concat(get_connection(x, y - 1));
        if (can_visit(x, y + 1)) list = list.concat(get_connection(x, y + 1));
        return list;
    }

    public function line_at(x :Int, y :Int) :Null<LineData> {
        for (line in lines) {
            for (point in line.points) {
                if (point.x == x && point.y == y) return line;
            }
        }
        return null;
    }

    public function line_by_color(color :ConnectColor) :Null<LineData> {
        for (line in lines) {
            if (line.color == color) return line;
        }
        return null;
    }

    public function mix_colors(color1 :ConnectColor, color2 :ConnectColor) :ConnectColor {
        if (color1 == color2) return color1;
        if (color1 == None) return color2;
        if (color2 == None) return color1;
        return Invalid;
    }
}
