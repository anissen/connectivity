
package game.states;

import luxe.Input;
import luxe.Color;
import luxe.Vector;

import mint.Control;
import mint.types.Types;
import mint.render.luxe.*;
import mint.layout.margins.Margins;
import mint.focus.Focus;

import game.ds.MapData;
import game.states.AutoCanvas;

class EditState extends luxe.States.State {
    static public var StateId :String = 'EditState';

    // var focus :Focus;
    // var layout :Margins;
    // var canvas :AutoCanvas;
    // var rendering :LuxeMintRender;

    var map_data :MapData;
    var line_color :game.ds.MapData.ConnectColor = None;

    public function new() {
        super({ name: StateId });

        // rendering = new LuxeMintRender();
        // layout = new Margins();
        map_data = MapData.get_instance();
    }

    override function onenabled(data :Dynamic) {
        map_data.make_grid_layout(9, 9, true);
    }

    override function ondisabled(data :Dynamic) {
        var w = 1;
        var h = 1;
        for (line in map_data.lines) {
            for (p in line.points) {
                if (p.x > w) w = p.x;
                if (p.y > h) h = p.y;
            }
        }
        map_data.make_grid_layout(w, h, true);
    }

    /*
    override function onenabled(data :Dynamic) {
        canvas = new AutoCanvas({
            name:'canvas',
            rendering: rendering,
            options: { color:new Color(1,1,1,0) },
            x: 0, y:0, w: Luxe.screen.w, h: Luxe.screen.h
        });

        focus = new Focus(canvas);
        canvas.auto_listen();

        var window = new mint.Window({
            parent: canvas,
            name: 'window',
            title: 'Level Editor',
            x: 160, y: 10, w: 256, h: 400,
            w_min: 256, h_min:256,
            collapsible: true,
            closable: false
        });

        layout.anchor(window, right, right);
        layout.anchor(window, center_y, center_y);

        var dropdown = new mint.Dropdown({
            parent: window,
            name: 'dropdown',
            text: 'Level...',
            // options: { color:new Color().rgb(0x343439) },
            x: 10, y: 32, w: 120, h: 32,
        });
        layout.margin(dropdown, right, fixed, 8);

        var plist = [ for (i in 1 ... 10) 'Level $i' ];

        inline function add_plat(name :String) {
            var first = plist.indexOf(name) == 0;
            dropdown.add_item(
                new mint.Label({
                    parent: dropdown,
                    text: '$name',
                    align: TextAlign.left,
                    name: 'level-$name', w: 225, h: 24, text_size: 14
                }),
                10, (first) ? 0 : 10
            );
        }

        for (p in plist) add_plat(p);
        dropdown.onselect.listen(function(idx, _, _) {
            dropdown.label.text = plist[idx];
            Main.states.disable(StateId);  // HACK!
            Luxe.events.fire('load_level', idx);
            Main.states.enable(StateId);  // HACK!
        });

        function do_save() {
            #if cpp
            var result = dialogs.Dialogs.save('Save level', { ext: 'json', desc: 'Level file' });
            Luxe.events.fire('save_level', result);
            #end
        }

        var buttons = [
            // { name: 'Load', onclick: function(e, c) { trace('Load!'); } },
            { name: 'Save', onclick: function(e, c) { do_save(); } },
            // { name: 'Try', onclick: function(e, c) { trace('try!'); } }
        ];
        for (i in 0 ... buttons.length) {
            var button = new mint.Button({
                parent: window,
                name: 'button_$i',
                x: 8, y: 32 + 8 + 32 + 40 * i, w: 60, h: 32,
                text: buttons[i].name,
                text_size: 14,
                align: TextAlign.left,
                options: { label: { color:new Color().rgb(0x9dca63) } },
                onclick: buttons[i].onclick
            });
            layout.margin(button, right, fixed, 8);
        }

        function make_slider(name, text, _x, _y, _w, _h, _min, _max, _initial) {
            var _s = new mint.Slider({
                parent: window, name: name, x:_x, y:_y, w:_w, h:_h,
                min: _min, max: _max, step: 1, value:_initial
            });

            var _l = new mint.Label({
                parent: _s, text_size: 14, x: _x, y:0, w:_s.w, h:_s.h,
                align: TextAlign.left, align_vertical: TextAlign.center,
                name : _s.name+'.label', text: '$text${_s.value}'
            });

            _s.onchange.listen(function(_val,_) { _l.text = '$text$_val'; });
            layout.margin(_s, right, fixed, 8);

            return _s;
        }

        make_slider('width_slider', 'Width: ', 10, 220, 128, 32, 2, 10, data.layout_width).onchange.listen(function(value, _) {
            // Main.states.disable(StateId); // HACK!
            // Luxe.events.fire('grid_width', value);
            data.layout_width = value;
            // Main.states.enable(StateId, data);  // HACK!
            map_data.make_grid_layout(Math.floor(value), map_data.layout.height);
            Main.states.disable(StateId); // HACK!
            // PlayState should redraw
            Luxe.events.fire('redraw');
            Main.states.enable(StateId); // HACK!
        });
        make_slider('height_slider', 'Height: ', 10, 255, 128, 32, 2, 10, data.layout_height).onchange.listen(function(value, _) {
            // Main.states.disable(StateId);  // HACK!
            // Luxe.events.fire('grid_height', value);
            data.layout_height = value;
            // Main.states.enable(StateId, data);  // HACK!
            map_data.make_grid_layout(map_data.layout.width, Math.floor(value));
            Main.states.disable(StateId); // HACK!
            // PlayState should redraw
            Luxe.events.fire('redraw');
            Main.states.enable(StateId); // HACK!
        });
        make_slider('length_slider', 'Lengths: ', 10, 290, 128, 32, 1, 5, data.connection_lengths).onchange.listen(function(value, _) {
            Luxe.events.fire('connection_length', value);
            data.connection_lengths = value;
        });
    }

    override function ondisabled(data) {
        canvas.destroy();
    }
    */

    override function onrender() {
        Luxe.draw.circle({
            x: Luxe.screen.cursor.pos.x,
            y: Luxe.screen.cursor.pos.y,
            color: convert_color(line_color),
            r: 20,
            immediate: true
        });
    }

    function convert_color(color :ConnectColor) :Color { // TODO: Move this to MapData
        // TODO: Improve colors
        return switch (color) {
            case Invalid: new Color(Math.random(), Math.random(), Math.random());
            case None: new Color(0.5, 0.5, 0.5);
            case Orange: new Color(1, 0.5, 0.1);
            case Green: new Color(0, 0.5, 0);
            case Blue: new Color(0, 0.45, 0.85);
        }
    }

    override function onmouseup(event :luxe.Input.MouseEvent) {
        if (line_color == None) return;

        var tile_pos = map_data.layout.get_point(event.pos);
        // if (tile_pos == null) return;

        var line = map_data.line_by_color(line_color);
        line.points.push({ x: tile_pos.x, y: tile_pos.y });

        Luxe.events.fire('redraw');

        // if (event.button == luxe.MouseButton.right) { // copy color
        //     var line = map_data.line_at(tile_pos.x, tile_pos.y);
        //     line_color = (line == null ? None : line.color);
        // } else {
        //     var line = map_data.line_by_color(line_color);
        //     if (line == null) return;
        //     line.points.push({ x: tile_pos.x, y: tile_pos.y }); // TODO: Also handle insertions
        //     Main.states.disable(StateId); // HACK!
        //     // PlayState should redraw
        //     Luxe.events.fire('redraw');
        //     Main.states.enable(StateId); // HACK!
        // }
    }

    override function onkeydown(event :luxe.Input.KeyEvent) {
        switch (event.keycode) {
            case luxe.Input.Key.key_1: line_color = Orange;
            case luxe.Input.Key.key_2: line_color = Green;
            case luxe.Input.Key.key_3: line_color = Blue;
            case luxe.Input.Key.key_c: map_data.line_by_color(line_color).points = []; Luxe.events.fire('redraw'); line_color = None;
            default: line_color = None;
        };
    }
}
