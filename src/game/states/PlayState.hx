
package game.states;

import luxe.Input.MouseEvent;
import luxe.States.State;
import luxe.tween.Actuate;
import luxe.Vector;
import luxe.Visual;
import luxe.Color;
import game.GridLayout;

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
}

// TODO: Move game state elsewhere and have both play and edit state have access to it

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

class PlayState extends State {
    static public var StateId :String = 'PlayState';
    var tiles :Array<Array<Tile>>;
    var lines :Array<LineData>;

    var layout :GridLayout;
    var connectionLengths = 4;

    var invalidColor :Color;

    var tween_speed :Float = 0.25;

    var particleSystem :luxe.Particles.ParticleSystem;
    var emitter :luxe.Particles.ParticleEmitter;

    var circleLineScene :luxe.Scene;
    var keepScene :luxe.Scene;

    var levelIndex :Int = 0;

    public function new() {
        super({ name: StateId });
    }

    override function onenter(data :Dynamic) {
        invalidColor = new Color();
        invalidColor.set(0.4, 0.4, 0.4);
        invalidColor.tween(0.6, { r: 0.8, g: 0.8, b: 0.8 }).reflect().repeat();

        circleLineScene = new luxe.Scene();
        keepScene = new luxe.Scene();

        Luxe.events.listen('load_level', reset);
        #if cpp
        Luxe.events.listen('save_level', function(path) {
            var raw_lines = [];
            for (line in lines) {
                raw_lines.push({
                    required_connections: line.requiredConnections,
                    points: line.points
                });
            }

            var level = {
                connection_lengths: connectionLengths,
                width: layout.width,
                height: layout.height,
                lines: raw_lines
            };

            var json = haxe.Json.stringify(level);
            sys.io.File.saveContent(path, json);
        });
        #end
        Luxe.events.listen('grid_width', function(v) {
            make_grid_layout(v, layout.height);
        });
        Luxe.events.listen('grid_height', function(v) {
            make_grid_layout(layout.width, v);
        });

        reset(data);
    }

    override function onwindowsized(e: luxe.Screen.WindowEvent) {
        make_grid_layout(layout.width, layout.height, false);
    }

    function make_grid_layout(w :Int, h :Int, clear :Bool = true /* hack */) {
        var margin_tiles = 2;

        var tile_size = Math.min(Luxe.screen.w / (w + margin_tiles), Luxe.screen.h / (h + margin_tiles));
        layout = new GridLayout(w, h, tile_size, Luxe.screen.mid.clone());

        redraw_level(clear);
    }

    function load_level(data :Dynamic) {
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

    function reset(level :Int) {
        levelIndex = level;
        if (particleSystem != null) particleSystem.stop();

        var ps_data = Luxe.resources.json('assets/particle_systems/fireworks.json').asset.json;
        particleSystem = load_particle_system(ps_data);
        particleSystem.start();

        load_level(Luxe.resources.json('assets/levels/level${level}.json').asset.json);
    }

    function redraw_level(clear :Bool = true) {
        Luxe.scene.empty();

        particleSystem.stop();

        if (clear) tiles = [];

        for (y in 0 ... layout.height) {
            var arr = [];
            for (x in 0 ... layout.width) {
                var sprite = new luxe.Sprite({
                    pos: layout.get_pos(x, y),
                    color: new Color(1, 1, 1, 0),
                    size: new Vector(layout.tile_size, layout.tile_size),
                    scale: new Vector(0, 0),
                    texture: Luxe.resources.texture('assets/images/circle.png'),
                    depth: 0
                });
                // sprite = new Connection()
                if (clear) {
                    arr.push({ connectType: Unconnected, color: None, length: 0, visited: false, sprite: sprite });
                } else {
                    tiles[y][x].sprite = sprite;
                }
            }
            if (clear) {
                tiles.push(arr);
            }
        }

        for (line in lines) {
            new game.entities.ColorLine({
                points: line.points,
                color: convert_color(line.color),
                layout: layout
            });
        }

        calc_colors();
    }

    override public function onmouseup(event :luxe.Input.MouseEvent) {
        var tile_pos = layout.get_point(event.pos);
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
            particleSystem.pos = layout.get_pos(tile_pos.x, tile_pos.y);
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
        for (y in 0 ... layout.height) {
            for (x in 0 ... layout.width) {
                var tile = tiles[y][x];
                tile.color = None;
                tile.length = 0;
                tile.visited = false;
            }
        }

        for (line in lines) {
            for (p in line.points) {
                if (!layout.inside_map(p.x, p.y)) continue;
                tiles[p.y][p.x].color = line.color;
            }
        }

        var has_won = true;
        var connections = [];
        for (line in lines) {
            line.connections = [];
            line.completedConnections = 0;
            for (p in line.points) {
                if (can_visit(p.x, p.y)) {
                    var tiles = get_connection(p.x, p.y);
                    var color = None;
                    for (tile in tiles) {
                        color = mix_colors(tile.color, color);
                    }
                    line.connections.push(tiles);
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
            if (line.connections.length != line.requiredConnections) has_won = false;
        }

        for (connection in connections) {
            for (tile in connection.tiles) {
                tile.color = connection.color;
                tile.length = connection.tiles.length;
            }
        }
        circleLineScene.empty();

        for (y in 0 ... layout.height) {
            for (x in 0 ... layout.width) {
                var tile = tiles[y][x];
                var connected = (tile.connectType == Connected);

                var color = convert_color(connected ? tile.color : None);
                var changedColor = color.toColorHSV();
                changedColor.v *= (tile.length == connectionLengths ? 0.8 : 0.6);

                if (tile.color == Invalid) {
                    tile.sprite.color = invalidColor;
                } else {
                    var alpha = (connected ? 1 : 0.15);
                    tile.sprite.color = tile.sprite.color.clone(); // to get rid of invalidColor
                    tile.sprite.color.tween(tween_speed, { r: changedColor.r, g: changedColor.g, b: changedColor.b, a: alpha });
                }

                var scale_size = (connected ? 1 : 0.3);
                luxe.tween.Actuate.tween(tile.sprite.scale, tween_speed, { x: scale_size, y: scale_size});

                // ---------------------

                // horizontal line
                if (connected && x > 0 && tiles[y][x-1].connectType == Connected) {
                    var sprite = new luxe.Sprite({
                        pos: Vector.Divide(Vector.Add(layout.get_pos(x, y), layout.get_pos(x - 1, y)), 2),
                        color: changedColor,
                        size: new Vector(layout.tile_size, layout.tile_size),
                        texture: Luxe.resources.texture('assets/images/circle_line.png'),
                        // scale: new Vector(1, 0),
                        depth: -1,
                        scene: circleLineScene
                    });
                    // luxe.tween.Actuate.tween(sprite.scale, tween_speed, { x: scale_size, y: scale_size });
                }

                // // vertical line
                if (connected && y > 0 && tiles[y-1][x].connectType == Connected) {
                    var sprite = new luxe.Sprite({
                        pos: Vector.Divide(Vector.Add(layout.get_pos(x, y), layout.get_pos(x, y - 1)), 2),
                        color: changedColor,
                        size: new Vector(layout.tile_size, layout.tile_size),
                        texture: Luxe.resources.texture('assets/images/circle_line.png'),
                        rotation_z: 90,
                        // scale: new Vector(1, 0),
                        depth: -1,
                        scene: circleLineScene
                    });
                    // luxe.tween.Actuate.tween(sprite.scale, tween_speed, { x: scale_size, y: scale_size });
                }
            }
        }

        if (has_won) {
            // reset(levelIndex + 1);
            Main.states.set(LevelSelectState.StateId, levelIndex + 1);
        }
    }

    override function onrender() {
        // TEMP CODE to be able to see board outline...
        var rect = layout.get_rect();
        Luxe.draw.rectangle({
            rect: rect,
            color: new Color(0, 0, 0),
            immediate: true
        });

        rect.x -= layout.tile_size;
        rect.y -= layout.tile_size;
        rect.w += layout.tile_size * 2;
        rect.h += layout.tile_size * 2;
        Luxe.draw.rectangle({
            rect: rect,
            color: new Color(0.5, 0.5, 0.5),
            immediate: true
        });
        // ... TEMP CODE

        for (line in lines) {
            for (c in 0 ... line.requiredConnections) {
                    var connection = (line.connections.length > c ? line.connections[c] : []);
                    var color = new Color(0, 0, 0);
                    var positions = [line.points[0], line.points[line.points.length - 1]];
                    var displacement =  ((line.requiredConnections + 1) / 2 - c - 1) * 15;
                    for (p in positions) {
                        var vertical = (p.y == -1 || p.y == layout.height);
                        var pos = layout.get_pos(p.x, p.y);
                        var size = 7;
                        if (connection.length > connectionLengths) {
                            Luxe.draw.circle({
                                x: pos.x,
                                y: pos.y,
                                origin: new Vector((vertical ? 0 : displacement), (!vertical ? 0 : displacement)),
                                r: size,
                                color: color,
                                immediate: true,
                                depth: 1
                            });
                        }
                        for (l in 0 ... connectionLengths) {
                            Luxe.draw.circle({
                                x: pos.x,
                                y: pos.y,
                                origin: new Vector((vertical ? 0 : displacement), (!vertical ? 0 : displacement)),
                                r: (connection.length <= connectionLengths ? size : size * 0.8),
                                color: (connection.length > l ? convert_color(line.color) : color),
                                start_angle: l * (360 / connectionLengths),
                                end_angle: (l + 1) * (360 / connectionLengths),
                                immediate: true,
                                depth: 1
                            });
                        }
                }
            }
        }
    }

    function can_visit(x :Int, y :Int) :Bool {
        if (!layout.inside_map(x, y)) return false;
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
        // TODO: Improve colors
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
            end_color: new Color(json.end_color.r, json.end_color.g, json.end_color.b, json.end_color.a)
        };
        emitter_template.particle_image = Luxe.resources.texture('assets/images/circle.png');

        var particles = new luxe.Particles.ParticleSystem({
            name: 'particles',
            scene: keepScene
        });
        particles.add_emitter(emitter_template);
        emitter = particles.emitters.get('template');
        particles.stop();
        return particles;
    }

    override public function onkeyup(event :luxe.Input.KeyEvent) {
        switch (event.keycode) {
            case luxe.Input.Key.key_r: reset(levelIndex);
            case luxe.Input.Key.escape:
                if (Main.states.enabled(EditState.StateId)) Main.states.disable(EditState.StateId);
                Main.states.set(LevelSelectState.StateId, levelIndex);
            #if debug
            case luxe.Input.Key.key_d:
                if (Main.states.enabled(EditState.StateId)) {
                    Main.states.disable(EditState.StateId);
                } else {
                    Main.states.enable(EditState.StateId, { layout_width: layout.width, layout_height: layout.height, connection_lengths: connectionLengths });
                }
            #end
        }
    }
}
