
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
    Red;
    Green;
    Blue;
}

typedef ColorLine = {
    color :ConnectColor,
    points :Array<{x :Int, y :Int}>
}

class PlayState extends State {
    static public var StateId :String = 'PlayState';
    var colors :Array<Array<ConnectColor>>;
    var connects :Array<Array<Bool>>;
    var lines :Array<ColorLine>;

    var mapWidth :Int = 5;
    var mapHeight :Int = 5;
    var tileSize :Int = 128;

    public function new() {
        super({ name: StateId });
        connects = [];
        lines = [];
        colors = [];
    }

    override function init() {
        reset(87634.34);
    }

    function reset(seed :Float) {
        Luxe.scene.empty();

        lines.push({
            color: Blue,
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
            color: Green,
            points: [
                { x: 3, y: 0 },
                { x: 3, y: 1 },
                { x: 4, y: 1 }
            ]
        });

        for (y in 0 ... mapHeight) {
            var arr = [];
            var colorArr = [];
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
                arr.push(false);
                colorArr.push(None);
            }
            connects.push(arr);
            colors.push(colorArr);
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
        connects[y][x] = !connects[y][x];
        calc_colors();
    }

    function calc_colors() {
        for (y in 0 ... mapHeight) {
            for (x in 0 ... mapWidth) {
                colors[y][x] = None;
            }
        }
        for (line in lines) {
            for (p in line.points) {
            if (connects[p.y][p.x] && colors[p.y][p.x] != line.color /* not already colored this color */) {
                    if (colors[p.y][p.x] == None) { // not yet colored
                        propagate_color(p.x, p.y, line.color);
                    } else {  // colored a different color -- error
                        propagate_color(p.x, p.y, Invalid);
                    }
                }
            }
        }
    }

    override function onrender() {
        for (y in 0 ... mapHeight) {
            for (x in 0 ... mapWidth) {
                if (!connects[y][x]) continue;
                Luxe.draw.box({
                    rect: new luxe.Rectangle(x * tileSize + tileSize / 4, y * tileSize + tileSize / 4, tileSize / 2, tileSize / 2),
                    color: convert_color(colors[y][x]),
                    immediate: true
                });
            }
        }
    }

    function propagate_color(x: Int, y: Int, color :ConnectColor) {
        Luxe.draw.box({
            rect: new luxe.Rectangle(x * tileSize + tileSize / 4, y * tileSize + tileSize / 4, Math.random() * tileSize / 2, Math.random() * tileSize / 2),
            color: convert_color(color),
            immediate: true
        });

        colors[y][x] = color;
        var new_color = color;
        if (x > 0 && connects[y][x - 1] && colors[y][x - 1] != new_color)
            new_color = mix_colors(propagate_color(x - 1, y, color), new_color);
        if (x < mapWidth - 1 && connects[y][x + 1] && colors[y][x+ 1] != new_color)
            new_color = mix_colors(propagate_color(x + 1, y, color), new_color);
        if (y > 0 && connects[y - 1][x] && colors[y - 1][x] != new_color)
            new_color = mix_colors(propagate_color(x, y - 1, color), new_color);
        if (y < mapHeight - 1 && connects[y + 1][x] && colors[y + 1][x] != new_color)
            new_color = mix_colors(propagate_color(x, y + 1, color), new_color);
        colors[y][x] = new_color;
        return new_color;
    }

    function convert_color(color :ConnectColor) :Color {
        return switch (color) {
            case Invalid: new Color(Math.random(), Math.random(), Math.random());
            case None: new Color(0, 0, 0);
            case Red: new Color(0.5, 0, 0);
            case Green: new Color(0, 0.5, 0);
            case Blue: new Color(0, 0, 0.5);
        }
    }

    // function get_color_for_tile(x :Int, y :Int) :ConnectColor {
    //     var color = colors[y][x];
    //     if (x > 0) color = mix_colors(colors[y][x - 1], color);
    //     if (x < mapWidth - 1) color = mix_colors(colors[y][x + 1], color);
    //     if (y > 0) color = mix_colors(colors[y - 1][x], color);
    //     if (y < mapHeight - 1) color = mix_colors(colors[y + 1][x], color);
    //     return color;
    // }

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
