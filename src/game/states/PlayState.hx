
package game.states;

import luxe.Input.MouseEvent;
import luxe.States.State;
import luxe.tween.Actuate;
import luxe.Vector;
import luxe.Visual;
import luxe.Color;
import snow.api.Promise;

enum ConnectColor {
    None;
    Invalid;
    Orange;
    Green;
    Blue;
}

typedef ColorLine = {
    color :ConnectColor,
    points :Array<{x :Int, y :Int}>,
    connections :Int
}

typedef Tile = {
    color :ConnectColor,
    connect :Bool,
    length :Int,
    visited :Bool
}

class PlayState extends State {
    static public var StateId :String = 'PlayState';
    var tiles :Array<Array<Tile>>;
    var lines :Array<ColorLine>;

    var mapWidth :Int = 5;
    var mapHeight :Int = 5;
    var tileSize :Int = 128;
    var connectionLengths = 3;

    public function new() {
        super({ name: StateId });
        tiles = [];
        lines = [];
    }

    override function init() {
        reset(87634.34);
    }

    function reset(seed :Float) {
        Luxe.scene.empty();

        lines.push({
            color: Blue,
            connections: 2,
            points: [
                { x: 1, y: 0 },
                { x: 1, y: 1 },
                { x: 2, y: 1 },
                { x: 2, y: 2 },
                { x: 3, y: 2 },
                { x: 3, y: 3 },
                { x: 3, y: 4 }
            ]
        });

        lines.push({
            color: Orange,
            connections: 1,
            points: [
                { x: 3, y: 0 },
                { x: 3, y: 1 },
                { x: 4, y: 1 }
            ]
        });

        for (y in 0 ... mapHeight) {
            var arr = [];
            for (x in 0 ... mapWidth) {
                Luxe.draw.line({
                    p0: new Vector(0, y * tileSize),
                    p1: new Vector(mapWidth * tileSize, y * tileSize),
                    color: new Color(0.2, 0.2, 0.2)
                });
                var col = 0.2 * Math.random();
                Luxe.draw.line({
                    p0: new Vector(x * tileSize, 0),
                    p1: new Vector(x * tileSize, mapHeight * tileSize),
                    color: new Color(0.2, 0.2, 0.2)
                });
                arr.push({ connect: false, color: None, length: 0, visited: false });
            }
            tiles.push(arr);
        }

        Luxe.renderer.state.lineWidth(4);
        for (line in lines) {
            Luxe.draw.poly({
                color: convert_color(line.color),
                points: [ for (p in line.points) new Vector(tileSize / 2 + p.x * tileSize, tileSize / 2 + p.y * tileSize) ],
                solid : false,
                depth: 2
            });
        }
    }

    override public function onmouseup(event :luxe.Input.MouseEvent) {
        var x = Math.floor(event.x / tileSize);
        var y = Math.floor(event.y / tileSize);
        tiles[y][x].connect = !tiles[y][x].connect;
        calc_colors();
        has_won();
    }

    function calc_colors() {
        for (y in 0 ... mapHeight) {
            for (x in 0 ... mapWidth) {
                tiles[y][x].color = None;
                tiles[y][x].length = 1;
                tiles[y][x].visited = false;
            }
        }

        for (line in lines) {
            for (p in line.points) {
                tiles[p.y][p.x].color = line.color;
            }
        }

        var connections = [];
        for (line in lines) {
            for (p in line.points) {
                if (can_visit(p.x, p.y)) {
                    var tiles = get_connection(p.x, p.y);
                    var color = None;
                    for (tile in tiles) {
                        color = mix_colors(tile.color, color);
                    }
                    connections.push({
                        color: color,
                        tiles: tiles
                    });
                }
            }
        }

        for (connection in connections) {
            for (tile in connection.tiles) {
                tile.color = connection.color;
                tile.length = connection.tiles.length;
            }
        }
    }

    function has_won() {

    }

    override function onrender() {
        for (y in 0 ... mapHeight) {
            for (x in 0 ... mapWidth) {
                if (!tiles[y][x].connect) continue;
                Luxe.draw.box({
                    rect: new luxe.Rectangle(x * tileSize + tileSize / 4, y * tileSize + tileSize / 4, (tileSize / 2) * tiles[y][x].length / connectionLengths, (tileSize / 2) * tiles[y][x].length / connectionLengths),
                    color: convert_color(tiles[y][x].color),
                    immediate: true
                });
            }
        }
    }

    function can_visit(x :Int, y :Int) :Bool {
        if (x < 0 || x >= mapWidth) return false;
        if (y < 0 || y >= mapHeight) return false;
        return tiles[y][x].connect && !tiles[y][x].visited;
    }

    function get_connection(x: Int, y: Int) :Array<Tile> {
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

    function convert_color(color :ConnectColor) :Color {
        return switch (color) {
            case Invalid: new Color(0.2 * Math.random(), 0.2 * Math.random(), 0.2 * Math.random());
            case None: new Color(0.2, 0.2, 0.2);
            case Orange: new Color(1, 0.5, 0.1);
            case Green: new Color(0, 0.5, 0);
            case Blue: new Color(0, 0.45, 0.85);
        }
    }

    function mix_colors(color1 :ConnectColor, color2 :ConnectColor) :ConnectColor {
        if (color1 == color2) return color1;
        if (color1 == None) return color2;
        if (color2 == None) return color1;
        return Invalid;
    }

    override public function onkeyup(event :luxe.Input.KeyEvent) {
        switch (event.keycode) {
            case luxe.Input.Key.key_r: reset(1000 * Math.random());
            case luxe.Input.Key.kp_minus: Luxe.camera.zoom -= 0.05;
            case luxe.Input.Key.kp_period: Luxe.camera.zoom += 0.05;
        }
    }
}
