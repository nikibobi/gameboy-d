module gameboy.input;

import std.stdio;
import dsfml.window : Event, Keyboard, Joystick;
import gameboy.memory;
import gameboy.utils;

class Input
{
    this(Memory mem) {
        this.mem = mem;
        buttons[] = 0x0F;
        mount();
    }

    void mount() {
        mem.mount((size_t address) { return read(); }, 0xFF00);
        mem.mount((size_t address, ubyte value) { write(value); }, 0xFF00);
    }

    void onevent(Event event) {
        switch (event.type) {
            case Event.EventType.KeyPressed:
                keyEvent(event.key.code, 0);
                break;
            case Event.EventType.KeyReleased:
                keyEvent(event.key.code, 1);
                break;
            case Event.EventType.JoystickButtonPressed:
                buttonEvent(event.joystickButton.button, 0);
                break;
            case Event.EventType.JoystickButtonReleased:
                buttonEvent(event.joystickButton.button, 1);
                break;
            case Event.EventType.JoystickMoved:
                axisEvent(event.joystickMove.axis, cast(int)event.joystickMove.position);
                break;
            default:
                break;
        }
    }

private:
    void keyEvent(Keyboard.Key key, ubyte state) {
        switch (key) {
            case Keyboard.Key.Right:
                right = state;
                break;
            case Keyboard.Key.Left:
                left = state;
                break;
            case Keyboard.Key.Up:
                up = state;
                break;
            case Keyboard.Key.Down:
                down = state;
                break;
            case Keyboard.Key.Z:
                buttonA = state;
                break;
            case Keyboard.Key.X:
                buttonB = state;
                break;
            case Keyboard.Key.Space:
                select = state;
                break;
            case Keyboard.Key.Return:
                start = state;
                break;
            default:
                break;
        }
    }

    void buttonEvent(uint button, ubyte state) {
        switch (button) {
            case 0:
                buttonA = state;
                break;
            case 1:
                buttonB = state;
                break;
            case 6:
                select = state;
                break;
            case 7:
                start = state;
                break;
            default:
                break;
        }
    }

    void axisEvent(int axis, int position) {
        switch (axis) {
            case 0:
            case 2:
            case 6:
                switch (position) {
                    case -100:
                        left = 0;
                        break;
                    case 100:
                        right = 0;
                        break;
                    case 0:
                        left = 1;
                        right = 1;
                        break;
                    default:
                        break;
                }
                break;
            case 1:
            case 3:
            case 7:
                switch (position) {
                    case -100:
                        up = 0;
                        break;
                    case 100:
                        down = 0;
                        break;
                    case 0:
                        up = 1;
                        down = 1;
                        break;
                    default:
                        break;
                }
                break;
            default:
                break;
        }
    }

    @property {
        ubyte right() {
            return buttons[0].bit!0;
        }
        void right(ubyte value) {
            buttons[0].bit!0 = value;
        }

        ubyte left() {
            return buttons[0].bit!1;
        }
        void left(ubyte value) {
            buttons[0].bit!1 = value;
        }

        ubyte up() {
            return buttons[0].bit!2;
        }
        void up(ubyte value) {
            buttons[0].bit!2 = value;
        }

        ubyte down() {
            return buttons[0].bit!3;
        }
        void down(ubyte value) {
            buttons[0].bit!3 = value;
        }

        ubyte buttonA() {
            return buttons[1].bit!0;
        }
        void buttonA(ubyte value) {
            buttons[1].bit!0 = value;
        }

        ubyte buttonB() {
            return buttons[1].bit!1;
        }
        void buttonB(ubyte value) {
            buttons[1].bit!1 = value;
        }

        ubyte select() {
            return buttons[1].bit!2;
        }
        void select(ubyte value) {
            buttons[1].bit!2 = value;
        }

        ubyte start() {
            return buttons[1].bit!3;
        }
        void start(ubyte value) {
            buttons[1].bit!3 = value;
        }
    }

    ubyte read() {
        if (data == 0) {
            return 0;
        } else if (data.bit!4 == 0) {
            return buttons[0];
        } else if (data.bit!5 == 0) {
            return buttons[1];
        } else {
            return 0;
        }
    }

    void write(ubyte value) {
        data = value & 0x30;
    }

    Memory mem;
    ubyte data;
    ubyte[2] buttons;
}
