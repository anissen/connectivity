
package game.states;

import luxe.Input.MouseEvent;
import luxe.States.State;
import luxe.tween.Actuate;
import luxe.Vector;
import luxe.Visual;
import luxe.Color;

using Lambda;

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
    Marked;
}

typedef ColorLine = {
    color :ConnectColor,
    points :Array<{x :Int, y :Int}>,
    requiredConnections :Int,
    connections :Int,
    completedConnections :Int
}

typedef Tile = {
    color :ConnectColor,
    connectType :ConnectType,
    length :Int,
    visited :Bool
}

class PlayState extends State {
    static public var StateId :String = 'PlayState';
    var tiles :Array<Array<Tile>>;
    var lines :Array<ColorLine>;

    var mapWidth :Int = 5;
    var mapHeight :Int = 5;
    var tileSize :Float = 128;
    var connectionLengths = 4;

    var margin :Float = 64;
    var invalidColor :Color;

    public function new() {
        super({ name: StateId });
    }

    override function init() {
        invalidColor = new Color();
        invalidColor.set(0.4, 0.4, 0.4);
        invalidColor.tween(0.6, { r: 0.8, g: 0.8, b: 0.8 }).reflect().repeat();

        reset(0);
    }

    function get_lines_from_data(data :Dynamic) :Array<ColorLine> {
        connectionLengths = data.connection_lengths;
        mapWidth = data.width;
        mapHeight = data.height;
        var lines :Array<ColorLine> = data.lines;
        for (i in 0 ... lines.length) {
            var line = lines[i];
            line.color = switch (i) {
                case 0: Orange;
                case 1: Blue;
                case _: Green;
            };
            line.connections = 0;
            line.completedConnections = 0;
        }
        return lines;
    }

    function reset(level :Int) {
        Luxe.scene.empty();

        tiles = [];
        lines = get_lines_from_data(Luxe.resources.json('assets/levels/level${level}.json').asset.json);

        tileSize = Math.min(Luxe.screen.w, Luxe.screen.h) / (Math.max(mapWidth, mapHeight) + 1 /* margin */);
        margin = tileSize / 2;

        for (y in 0 ... mapHeight) {
            var arr = [];
            for (x in 0 ... mapWidth) {
                var sprite = new luxe.Sprite({
                    pos: new Vector(margin + x * tileSize + tileSize / 2, margin + y * tileSize + tileSize / 2),
                    color: new Color(0.9, 0.9, 0.9),
                    size: new Vector(tileSize, tileSize),
                    texture: Luxe.resources.texture('assets/images/dot.png'),
                    depth: -3
                });
                arr.push({ connectType: Unconnected, color: None, length: 0, visited: false });
            }
            tiles.push(arr);
        }

        Luxe.renderer.state.lineWidth(6);
        for (line in lines) {
            for (i in 1 ... line.points.length - 1) {
                var p_before = line.points[i - 1];
                var p = line.points[i];
                var p_after = line.points[i + 1];

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

                new luxe.Sprite({
                    pos: new Vector(margin + p.x * tileSize + tileSize / 2, margin + p.y * tileSize + tileSize / 2),
                    color: convert_color(line.color),
                    size: new Vector(tileSize, tileSize),
                    texture: Luxe.resources.texture(is_line ? 'assets/images/line.png' : 'assets/images/turn.png'),
                    rotation_z: rotation * 90,
                    depth: -2
                });
            }
        }
    }

    function clamp_to_map(v :Vector) {
        return new Vector(luxe.utils.Maths.clamp(v.x, 0, mapWidth * tileSize), luxe.utils.Maths.clamp(v.y, 0, mapHeight * tileSize));
    }

    function pos_from_tile(x :Int, y :Int) {
        return new Vector(tileSize / 2 + x * tileSize, tileSize / 2 + y * tileSize);
    }

    function tile_from_pos(pos :Vector) :Null<{x :Int, y :Int}> {
        var x = Math.floor((pos.x - margin) / tileSize);
        var y = Math.floor((pos.y - margin) / tileSize);
        if (x < 0 || x >= mapWidth || y < 0 || y >= mapHeight) return null;
        return { x: x, y: y };
    }

    override public function onmouseup(event :luxe.Input.MouseEvent) {
        var tile = tile_from_pos(event.pos);
        if (tile == null) return;
        tiles[tile.y][tile.x].connectType = switch (tiles[tile.y][tile.x].connectType) {
            case Unconnected: Connected;
            case Connected: Unconnected;
            case Marked: Unconnected;
        };
        calc_colors();
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
                if (!inside_map(p.x, p.y)) continue;
                tiles[p.y][p.x].color = line.color;
            }
        }

        var has_won = true;
        var connections = [];
        for (line in lines) {
            line.connections = 0;
            line.completedConnections = 0;
            for (p in line.points) {
                if (can_visit(p.x, p.y)) {
                    line.connections++;
                    var tiles = get_connection(p.x, p.y);
                    var color = None;
                    for (tile in tiles) {
                        color = mix_colors(tile.color, color);
                    }
                    connections.push({
                        color: color,
                        tiles: tiles
                    });
                    if (color == Invalid || tiles.length != connectionLengths) {
                        has_won = false;
                    } else {
                        line.completedConnections++;
                    }
                }
            }
            if (line.connections != line.requiredConnections) has_won = false;
        }

        for (connection in connections) {
            for (tile in connection.tiles) {
                tile.color = connection.color;
                tile.length = connection.tiles.length;
            }
        }

        if (has_won) {
            trace('You won!');
            reset(1);
        }
    }

    override function onrender() {
        for (y in 0 ... mapHeight) {
            for (x in 0 ... mapWidth) {
                switch (tiles[y][x].connectType) {
                    case Connected: draw_connect(x, y);
                    default:
                }
            }
        }
        for (line in lines) {
            for (c in 0 ... line.requiredConnections) {
                var color = convert_color(line.color);
                if (line.connections <= c) color.a = 0.5;
                if (line.completedConnections > c) color.set(0, 0, 0);
                Luxe.draw.box({
                    rect: new luxe.Rectangle(line.points[0].x * tileSize + tileSize / 2 - 5, line.points[0].y * tileSize + tileSize / 2 - 25, 10, 10),
                    color: color,
                    origin: new Vector(-margin + ((line.requiredConnections + 1) / 2 - c - 1) * 20, 0),
                    immediate: true,
                    depth: 1
                });
            }
        }
    }

    function draw_connect(x :Int, y :Int) {
        var boxSize = Math.min((tiles[y][x].length / connectionLengths) * tileSize / 2, tileSize / 2);
        var centerOffset = tileSize / 2 - boxSize / 2;

        var connectedLineColor = convert_color(tiles[y][x].color).toColorHSV();
        connectedLineColor.v *= 0.8;

        // horizontal line
        if (x > 0 && tiles[y][x-1].connectType == Connected) {
            Luxe.draw.line({
                p0: new Vector(x * tileSize, y * tileSize + tileSize / 2),
                p1: new Vector(x * tileSize + tileSize / 2, y * tileSize + tileSize / 2),
                color: connectedLineColor,
                origin: new Vector(-margin, -margin),
                immediate: true
            });
        }
        if (x < mapWidth - 1 && tiles[y][x+1].connectType == Connected) {
            Luxe.draw.line({
                p0: new Vector(x * tileSize + tileSize / 2, y * tileSize + tileSize / 2),
                p1: new Vector(x * tileSize + tileSize, y * tileSize + tileSize / 2),
                color: connectedLineColor,
                origin: new Vector(-margin, -margin),
                immediate: true
            });
        }

        // // vertical line
        if (y > 0 && tiles[y-1][x].connectType == Connected) {
            Luxe.draw.line({
                p0: new Vector(x * tileSize + tileSize / 2, y * tileSize),
                p1: new Vector(x * tileSize + tileSize / 2, y * tileSize + tileSize / 2),
                color: connectedLineColor,
                origin: new Vector(-margin, -margin),
                immediate: true
            });
        }
        if (y < mapHeight - 1 && tiles[y+1][x].connectType == Connected) {
            Luxe.draw.line({
                p0: new Vector(x * tileSize + tileSize / 2, y * tileSize + tileSize / 2),
                p1: new Vector(x * tileSize + tileSize / 2, y * tileSize + tileSize),
                color: connectedLineColor,
                origin: new Vector(-margin, -margin),
                immediate: true
            });
        }
        { // border
            var boxSizeBorder = Math.min((tiles[y][x].length / connectionLengths) * tileSize / 1.8, tileSize / 1.8);
            var centerOffsetBorder = tileSize / 2 - boxSizeBorder / 2;
            var complete = (tiles[y][x].color != Invalid && tiles[y][x].length == connectionLengths);
            Luxe.draw.circle({
                x: x * tileSize + tileSize / 2,
                y: y * tileSize +  tileSize / 2,
                r: tileSize / 5 + 2,
                color: (complete ? new Color(1, 1, 1) : new Color(0, 0, 0)),
                origin: new Vector(-margin, -margin),
                immediate: true
            });
        }
        Luxe.draw.circle({
            x: x * tileSize + tileSize / 2,
            y: y * tileSize +  tileSize / 2,
            r: tileSize / 5,
            color: convert_color(tiles[y][x].color),
            origin: new Vector(-margin, -margin),
            immediate: true
        });
        if (tiles[y][x].length < connectionLengths) { // draw center dot
            Luxe.draw.circle({
                x: x * tileSize + tileSize / 2,
                y: y * tileSize +  tileSize / 2,
                r: (tileSize / 5) - (tileSize / 5) * (tiles[y][x].length / connectionLengths),
                color: new Color(0, 0, 0),
                origin: new Vector(-margin, -margin),
                immediate: true
            });
        }
    }

    function inside_map(x :Int, y :Int) {
        return (x >= 0 && x < mapWidth && y >= 0 && y < mapHeight);
    }

    function can_visit(x :Int, y :Int) :Bool {
        if (!inside_map(x, y)) return false;
        return tiles[y][x].connectType == Connected && !tiles[y][x].visited;
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
            case Invalid: invalidColor;
            case None: new Color(0.4, 0.4, 0.4);
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
            case luxe.Input.Key.key_0: reset(0);
            case luxe.Input.Key.key_1: reset(1);
            case luxe.Input.Key.key_2: reset(2);
            case luxe.Input.Key.kp_minus: Luxe.camera.zoom -= 0.05;
            case luxe.Input.Key.kp_period: Luxe.camera.zoom += 0.05;
        }
    }
}
