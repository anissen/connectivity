
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
    length :Int
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
                arr.push({ connect: false, color: None, length: 0 });
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
            }
        }
        for (line in lines) {
            for (p in line.points) {
            if (tiles[p.y][p.x].connect && tiles[p.y][p.x].color != line.color /* not already colored this color */) {
                    if (tiles[p.y][p.x].color == None) { // not yet colored
                        propagate_color(p.x, p.y, line.color, 1);
                    } else {  // colored a different color -- error
                        propagate_color(p.x, p.y, Invalid, 1);
                    }
                }
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

    function propagate_color(x: Int, y: Int, color :ConnectColor, length :Int) {
        tiles[y][x].color = color;
        var new_color = color;
        var new_length = length;
        if (x > 0 && tiles[y][x - 1].connect && tiles[y][x - 1].color != new_color)
            new_color = mix_colors(propagate_color(x - 1, y, color, length + 1), new_color);
            // if (new_color == color) new_length++;
        if (x < mapWidth - 1 && tiles[y][x + 1].connect && tiles[y][x+ 1].color != new_color)
            new_color = mix_colors(propagate_color(x + 1, y, color, length + 1), new_color);
            // if (new_color == color) new_length++;
        if (y > 0 && tiles[y - 1][x].connect && tiles[y - 1][x].color != new_color)
            new_color = mix_colors(propagate_color(x, y - 1, color, length + 1), new_color);
            // if (new_color == color) new_length++;
        if (y < mapHeight - 1 && tiles[y + 1][x].connect && tiles[y + 1][x].color != new_color)
            new_color = mix_colors(propagate_color(x, y + 1, color, length + 1), new_color);
            // if (new_color == color) new_length++;
        tiles[y][x].length = new_length;
        tiles[y][x].color = new_color;
        return new_color;
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
