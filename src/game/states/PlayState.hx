
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
    // Marked;
}

typedef ColorLine = {
    color :ConnectColor,
    points :Array<{x :Int, y :Int}>,
    requiredConnections :Int,
    connections :Int,
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

    var tween_speed :Float = 0.25;

    var particleSystem :luxe.Particles.ParticleSystem;
    var emitter :luxe.Particles.ParticleEmitter;

    var levelIndex :Int = 0;

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
            line.sprites = [];
        }
        return lines;
    }

    function reset(level :Int) {
        levelIndex = level;
        if (particleSystem != null) particleSystem.stop();

        Luxe.scene.empty();

        var ps_data = Luxe.resources.json('assets/particle_systems/fireworks.json').asset.json;
        particleSystem = load_particle_system(ps_data);

        tiles = [];
        lines = get_lines_from_data(Luxe.resources.json('assets/levels/level${level}.json').asset.json);

        tileSize = Math.min(Luxe.screen.w, Luxe.screen.h) / (Math.max(mapWidth, mapHeight) + 1 /* margin */);
        margin = tileSize / 2;

        for (y in 0 ... mapHeight) {
            var arr = [];
            for (x in 0 ... mapWidth) {
                var sprite = new luxe.Sprite({
                    pos: new Vector(margin + x * tileSize + tileSize / 2, margin + y * tileSize + tileSize / 2),
                    color: new Color(1, 1, 1, 0),
                    size: new Vector(tileSize, tileSize),
                    scale: new Vector(0, 0),
                    texture: Luxe.resources.texture('assets/images/circle.png'),
                    depth: 0
                });
                arr.push({ connectType: Unconnected, color: None, length: 0, visited: false, sprite: sprite });
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

                var sprite = new luxe.Sprite({
                    pos: new Vector(margin + p.x * tileSize + tileSize / 2, margin + p.y * tileSize + tileSize / 2),
                    color: convert_color(line.color),
                    size: new Vector(tileSize, tileSize),
                    texture: Luxe.resources.texture(is_line ? 'assets/images/line.png' : 'assets/images/turn.png'),
                    rotation_z: rotation * 90,
                    depth: -2
                });
                line.sprites.push(sprite);
            }
        }

        calc_colors();
    }

    function pos_from_tile_pos(x :Int, y :Int) {
        return new Vector(margin + tileSize / 2 + x * tileSize, margin + tileSize / 2 + y * tileSize);
    }

    function tile_pos_from_pos(pos :Vector) :Null<{x :Int, y :Int}> {
        var x = Math.floor((pos.x - margin) / tileSize);
        var y = Math.floor((pos.y - margin) / tileSize);
        if (x < 0 || x >= mapWidth || y < 0 || y >= mapHeight) return null;
        return { x: x, y: y };
    }

    override public function onmouseup(event :luxe.Input.MouseEvent) {
        var tile_pos = tile_pos_from_pos(event.pos);
        if (tile_pos == null) return;

        var tile = tiles[tile_pos.y][tile_pos.x];
        tile.connectType = switch (tile.connectType) {
            case Unconnected: Connected;
            case Connected: Unconnected;
        };

        calc_colors();

        if (tile.connectType == Connected) {
            Luxe.camera.shake((tile.color == Invalid) ? 5 : 1);
            emitter.start_color = convert_color(tile.color);
            particleSystem.pos = pos_from_tile_pos(tile_pos.x, tile_pos.y);
            particleSystem.start(1);

            for (line in lines) {
                for (sprite in line.sprites) {
                    if (line.color == tile.color) {
                        var color = convert_color(line.color);
                        var changedColor = color.toColorHSV();
                        changedColor.v *= 0.9;
                        sprite.color.tween(tween_speed, { r: changedColor.r, g: changedColor.g, b: changedColor.b }).reflect().repeat(1);

                        luxe.tween.Actuate.tween(sprite.scale, tween_speed, { x: 1.02, y: 1.02 }).reflect().repeat(1);
                    }
                }
            }
        }
    }

    function calc_colors() {
        for (y in 0 ... mapHeight) {
            for (x in 0 ... mapWidth) {
                var tile = tiles[y][x];
                tile.color = None;
                tile.length = 0;
                tile.visited = false;
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

        for (y in 0 ... mapHeight) {
            for (x in 0 ... mapWidth) {
                var tile = tiles[y][x];
                var connected = (tile.connectType == Connected);

                if (tile.color == Invalid) {
                    tile.sprite.color = invalidColor;
                } else {
                    var color = convert_color(connected ? tile.color : None);
                    var changedColor = color.toColorHSV();
                    changedColor.v *= 0.8;
                    var alpha = (connected ? 1 : 0.1);
                    tile.sprite.color = tile.sprite.color.clone(); // to get rid of invalidColor
                    tile.sprite.color.tween(tween_speed, { r: changedColor.r, g: changedColor.g, b: changedColor.b, a: alpha });
                }

                var scale_size = (connected ? 1 : 0.3);
                luxe.tween.Actuate.tween(tile.sprite.scale, tween_speed, { x: scale_size, y: scale_size});
            }
        }

        if (has_won) {
            reset(levelIndex + 1);
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
                var color = new Color(0, 0, 0);
                if (line.connections <= c) color = convert_color(line.color);
                if (line.completedConnections > c) color.set(1, 1, 1);
                var positions = [line.points[0], line.points[line.points.length - 1]];
                var displacement =  ((line.requiredConnections + 1) / 2 - c - 1) * 20;
                for (p in positions) {
                    var vertical = (p.y == -1 || p.y == mapHeight);
                    Luxe.draw.box({
                        rect: new luxe.Rectangle(p.x * tileSize + tileSize / 2 + (p.x == -1 ? tileSize / 4 : 0), p.y * tileSize + tileSize / 2 - (p.y == mapHeight ? tileSize / 4 : 0), 10, 10),
                        color: color,
                        origin: new Vector(-margin + (vertical ? displacement : 0), -margin + (!vertical ? displacement : 0)),
                        immediate: true,
                        depth: 1
                    });
                }
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
            case None: new Color(0.5, 0.5, 0.5);
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

    function load_particle_system(json :Dynamic) :luxe.Particles.ParticleSystem {
        var emitter_template :luxe.options.ParticleOptions.ParticleEmitterOptions = {
            name: 'template',
            emit_time: json.emit_time,
            emit_count: json.emit_count,
            direction: json.direction,
            direction_random: json.direction_random,
            speed: json.speed,
            speed_random: json.speed_random,
            end_speed: json.end_speed,
            life: json.life,
            life_random: json.life_random,
            rotation: json.zrotation,
            rotation_random: json.rotation_random,
            end_rotation: json.end_rotation,
            end_rotation_random: json.end_rotation_random,
            rotation_offset: json.rotation_offset,
            pos_offset: new Vector(json.pos_offset.x, json.pos_offset.y),
            pos_random: new Vector(json.pos_random.x, json.pos_random.y),
            gravity: new Vector(json.gravity.x, json.gravity.y),
            start_size: new Vector(json.start_size.x, json.start_size.y),
            start_size_random: new Vector(json.start_size_random.x, json.start_size_random.y),
            end_size: new Vector(json.end_size.x, json.end_size.y),
            end_size_random: new Vector(json.end_size_random.x, json.end_size_random.y),
            start_color: new Color(json.start_color.r, json.start_color.g, json.start_color.b, json.start_color.a),
            end_color: new Color(json.end_color.r, json.end_color.g, json.end_color.b, json.end_color.a),
            //depth: -0.5 // below circles
        };
        emitter_template.particle_image = Luxe.resources.texture('assets/images/circle.png');

        var particles = new luxe.Particles.ParticleSystem({ name: 'particles' });
        particles.add_emitter(emitter_template);
        emitter = particles.emitters.get('template');
        particles.stop();
        return particles;
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
