
package game.states;

import luxe.Input;
import luxe.Color;
import luxe.Vector;

import mint.Control;
import mint.types.Types;
import mint.render.luxe.*;
import mint.layout.margins.Margins;
import mint.focus.Focus;

import game.states.AutoCanvas;

class EditState extends luxe.States.State {
    static public var StateId :String = 'EditState';

    var focus: Focus;
    var layout: Margins;
    var canvas: AutoCanvas;
    var rendering: LuxeMintRender;

    public function new() {
        super({ name: StateId });

        rendering = new LuxeMintRender();
        layout = new Margins();
    }

    override function onenabled(data) {
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
        dropdown.onselect.listen(function(idx,_,_){ dropdown.label.text = plist[idx]; });

        var buttons = [
            { name: 'Load', onclick: function(e,c) { trace('Load!'); } },
            { name: 'Save', onclick: function(e,c) { trace('Save!'); } },
            { name: 'Try', onclick: function(e,c) { trace('try!'); } }
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
        }

        make_slider('width_slider', 'Width: ', 10, 220, 128, 32, 3, 8, 4);
        make_slider('height_slider', 'Height: ', 10, 255, 128, 32, 3, 8, 4);
        make_slider('length_slider', 'Length: ', 10, 290, 128, 32, 1, 5, 2);
    }

    override function ondisabled(data) {
        canvas.destroy();
    }
}
