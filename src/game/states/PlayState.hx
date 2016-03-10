
package game.states;

import luxe.Input.MouseEvent;
import luxe.States.State;
import luxe.tween.Actuate;
import luxe.Vector;
import luxe.Visual;
import luxe.Color;

import game.ds.MapData;
import game.ds.GridLayout;

using Lambda;

class PlayState extends State {
    static public var StateId :String = 'PlayState';
    var map_data :MapData;
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
        map_data = MapData.get_instance();

        invalidColor = new Color();
        invalidColor.set(0.4, 0.4, 0.4);
        invalidColor.tween(0.6, { r: 0.8, g: 0.8, b: 0.8 }).reflect().repeat();

        circleLineScene = new luxe.Scene();
        keepScene = new luxe.Scene();

        Luxe.events.listen('load_level', reset);
        #if cpp
        Luxe.events.listen('save_level', function(path) {
            var raw_lines = [];
            for (line in map_data.lines) {
                raw_lines.push({
                    required_connections: line.requiredConnections,
                    points: line.points
                });
            }

            var level = {
                connection_lengths: map_data.connectionLengths,
                width: map_data.layout.width,
                height: map_data.layout.height,
                lines: raw_lines
            };

            var json = haxe.Json.stringify(level);
            sys.io.File.saveContent(path, json);
        });
        #end
        // Luxe.events.listen('grid_width', function(v) {
        //     make_grid_layout(v, map_data.layout.height);
        // });
        // Luxe.events.listen('grid_height', function(v) {
        //     make_grid_layout(map_data.layout.width, v);
        // });
        Luxe.events.listen('redraw', function(_) {
            redraw_level();
        });

        reset(data);
    }

    override function onwindowsized(e: luxe.Screen.WindowEvent) {
        // make_grid_layout(map_data.layout.width, map_data.layout.height, false);
    }

    function reset(level :Int) {
        levelIndex = level;
        if (particleSystem != null) particleSystem.stop();

        var ps_data = Luxe.resources.json('assets/particle_systems/fireworks.json').asset.json;
        particleSystem = load_particle_system(ps_data);
        particleSystem.start();

        map_data.load_level(Luxe.resources.json('assets/levels/level${level}.json').asset.json);
        redraw_level();
    }

    function redraw_level(clear :Bool = true) {
        Luxe.scene.empty();

        particleSystem.stop();

        if (clear) map_data.tiles = [];

        for (y in 0 ... map_data.layout.height) {
            var arr = [];
            for (x in 0 ... map_data.layout.width) {
                var sprite = new luxe.Sprite({
                    pos: map_data.layout.get_pos(x, y),
                    color: new Color(1, 1, 1, 0),
                    size: new Vector(map_data.layout.tile_size, map_data.layout.tile_size),
                    scale: new Vector(0, 0),
                    texture: Luxe.resources.texture('assets/images/circle.png'),
                    depth: 0
                });
                // sprite = new Connection()
                if (clear) {
                    arr.push({ connectType: Unconnected, color: None, length: 0, visited: false, sprite: sprite });
                } else {
                    map_data.tiles[y][x].sprite = sprite;
                }
            }
            if (clear) {
                map_data.tiles.push(arr);
            }
        }

        for (line in map_data.lines) {
            new game.entities.ColorLine({
                points: line.points,
                color: convert_color(line.color),
                layout: map_data.layout
            });
        }

        calc_colors();
    }

    function play_sound(sound :String, ?x :Int) {
        var handle = Luxe.audio.play(Luxe.resources.audio('assets/sounds/$sound').source);
        if (x == null) return;
        Luxe.audio.pan(handle, map_data.layout.get_width() / (x + 1));
    }

    override public function onmouseup(event :luxe.Input.MouseEvent) {
        if (Main.states.enabled(EditState.StateId)) return; // disable play events when editing

        var tile_pos = map_data.layout.get_point(event.pos);
        if (tile_pos == null) return;

        var tile = map_data.tiles[tile_pos.y][tile_pos.x];
        tile.connectType = switch (tile.connectType) {
            case Unconnected: Connected;
            case Connected:   Unconnected;
        };

        calc_colors(/* TODO: must take the tile as argument to be able to trigger the correct sounds */);

        if (tile.connectType == Unconnected) {
            play_sound('remove.ogg', tile_pos.x);
        } else {
            switch (tile.color) {
                case None: play_sound('misplace.ogg', tile_pos.x);
                case Invalid: play_sound('invalid.ogg', tile_pos.x);
                default: play_sound('place.ogg', tile_pos.x);
            }
        }

        if (tile.connectType == Connected) {
            Luxe.camera.shake((tile.color == Invalid) ? 5 : 1);
            emitter.start_color = convert_color(tile.color);
            particleSystem.pos = map_data.layout.get_pos(tile_pos.x, tile_pos.y);
            particleSystem.start(1);

            for (line in map_data.lines) {
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
        for (y in 0 ... map_data.layout.height) {
            for (x in 0 ... map_data.layout.width) {
                var tile = map_data.tiles[y][x];
                tile.color = None;
                tile.length = 0;
                tile.visited = false;
            }
        }

        for (line in map_data.lines) {
            for (p in line.points) {
                if (!map_data.layout.inside_map(p.x, p.y)) continue;
                map_data.tiles[p.y][p.x].color = line.color;
            }
        }

        var has_won = true;
        var connections = [];
        for (line in map_data.lines) {
            line.connections = [];
            line.completedConnections = 0;
            for (p in line.points) {
                if (map_data.can_visit(p.x, p.y)) {
                    var tiles = map_data.get_connection(p.x, p.y);
                    var color = None;
                    for (tile in tiles) {
                        color = map_data.mix_colors(tile.color, color);
                    }
                    line.connections.push(tiles);
                    connections.push({
                        color: color,
                        tiles: tiles
                    });
                    if (color == Invalid || tiles.length != map_data.connectionLengths) {
                        has_won = false;
                    } else {
                        line.completedConnections++;
                        // play_sound('connection_complete.ogg');
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

        for (y in 0 ... map_data.layout.height) {
            for (x in 0 ... map_data.layout.width) {
                var tile = map_data.tiles[y][x];
                var connected = (tile.connectType == Connected);

                var color = convert_color(connected ? tile.color : None);
                var changedColor = color.toColorHSV();
                changedColor.v *= (tile.length == map_data.connectionLengths ? 0.8 : 0.6);

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
                if (connected && x > 0 && map_data.tiles[y][x-1].connectType == Connected) {
                    var sprite = new luxe.Sprite({
                        pos: Vector.Divide(Vector.Add(map_data.layout.get_pos(x, y), map_data.layout.get_pos(x - 1, y)), 2),
                        color: changedColor,
                        size: new Vector(map_data.layout.tile_size, map_data.layout.tile_size),
                        texture: Luxe.resources.texture('assets/images/circle_line.png'),
                        // scale: new Vector(1, 0),
                        depth: -1,
                        scene: circleLineScene
                    });
                    // luxe.tween.Actuate.tween(sprite.scale, tween_speed, { x: scale_size, y: scale_size });
                }

                // // vertical line
                if (connected && y > 0 && map_data.tiles[y-1][x].connectType == Connected) {
                    var sprite = new luxe.Sprite({
                        pos: Vector.Divide(Vector.Add(map_data.layout.get_pos(x, y), map_data.layout.get_pos(x, y - 1)), 2),
                        color: changedColor,
                        size: new Vector(map_data.layout.tile_size, map_data.layout.tile_size),
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
            play_sound('level_completed.ogg');
            Main.states.set(LevelSelectState.StateId, levelIndex + 1);
        }
    }

    override function onrender() {
        // TEMP CODE to be able to see board outline...
        var rect = map_data.layout.get_rect();
        Luxe.draw.rectangle({
            rect: rect,
            color: new Color(0, 0, 0),
            immediate: true
        });

        rect.x -= map_data.layout.tile_size;
        rect.y -= map_data.layout.tile_size;
        rect.w += map_data.layout.tile_size * 2;
        rect.h += map_data.layout.tile_size * 2;
        Luxe.draw.rectangle({
            rect: rect,
            color: new Color(0.5, 0.5, 0.5),
            immediate: true
        });
        // ... TEMP CODE

        for (line in map_data.lines) {
            if (line.points.length == 0) continue;
            for (c in 0 ... line.requiredConnections) {
                    var connection = (line.connections.length > c ? line.connections[c] : []);
                    var color = new Color(0, 0, 0);
                    var positions = [line.points[0], line.points[line.points.length - 1]];
                    var displacement =  ((line.requiredConnections + 1) / 2 - c - 1) * 15;
                    for (p in positions) {
                        var vertical = (p.y == -1 || p.y == map_data.layout.height);
                        var pos = map_data.layout.get_pos(p.x, p.y);
                        var size = 7;
                        if (connection.length > map_data.connectionLengths) {
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
                        for (l in 0 ... map_data.connectionLengths) {
                            Luxe.draw.circle({
                                x: pos.x,
                                y: pos.y,
                                origin: new Vector((vertical ? 0 : displacement), (!vertical ? 0 : displacement)),
                                r: (connection.length <= map_data.connectionLengths ? size : size * 0.8),
                                color: (connection.length > l ? convert_color(line.color) : color),
                                start_angle: l * (360 / map_data.connectionLengths),
                                end_angle: (l + 1) * (360 / map_data.connectionLengths),
                                immediate: true,
                                depth: 1
                            });
                        }
                }
            }
        }
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
                    Main.states.enable(EditState.StateId, { layout_width: map_data.layout.width, layout_height: map_data.layout.height, connection_lengths: map_data.connectionLengths });
                }
            #end
        }
    }
}
