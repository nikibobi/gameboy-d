module gameboy.app;

import std.stdio;
import core.thread;
import dsfml.system;
import dsfml.window;
import dsfml.graphics;
import gameboy.cpu;
import gameboy.memory;
import gameboy.video;
import gameboy.rom;
import gameboy.input;
import gameboy.utils;

enum DefaultFile = "roms/DrMario.gb";
enum PixelSize = 1;

void main(string[] args)
{
    debug readROMs();
    immutable filename = (args.length > 1 ? args[1] : DefaultFile);
    auto cart = Cartage.fromFile(filename);
    auto ram = new Memory;
    ram.loadCartage(cart);
    auto cpu = new Processor(ram);
    auto gpu = new Video(ram);
    auto input = new Input(ram);
    cpu.boot();

    auto sprite = new Sprite;
    sprite.setTexture(gpu.texture);
    sprite.scale(Vector2f(PixelSize, PixelSize));

    immutable screenSize = Vector2u(Video.Width, Video.Height) * PixelSize;
    auto window = new RenderWindow(VideoMode(screenSize.x, screenSize.y), cart.title.capitalized, Window.Style.Close);

    while (window.isOpen()) {
        Event event;
        while (window.pollEvent(event)) {
            if (event.type == event.EventType.Closed) {
                window.close();
            }
            input.onevent(event);
        }

        immutable end = cpu.time + 70_224;
        do {
            debug debugCPU(cpu);
            immutable dt = cpu.step();
            gpu.step(dt);
            cpu.fireInterrupts();
            debug debugInput(ram);
        } while (cpu.time < end);

        window.clear();
        window.draw(sprite);
        window.display();
    }
}

void debugCPU(Processor cpu) {
    auto file = File("debug.txt", "w");
    scope(exit) file.close();
    char flag(char f)() {
        return cpu.flag!f ? f : '-';
    }
    file.writefln("A: $%02X", cpu.reg!"a");
    file.writefln("F: %s%s%s%s", flag!'z', flag!'n', flag!'h', flag!'c');
    file.writefln("BC: $%04X", cpu.reg!"bc");
    file.writefln("DE: $%04X", cpu.reg!"de");
    file.writefln("HL: $%04X", cpu.reg!"hl");
    file.writefln("(HL): $%02X", cpu.reg!"(hl)");
    file.writefln("SP: $%04X", cpu.reg!"sp");
    file.writefln("PC: $%04X", cpu.reg!"pc");
}

void debugInput(Memory ram) {
    ubyte i;
    ram[0xFF00] = 1 << 4;
    i = ram[0xFF00];
    if (i != 0xF)
    {
        write(i.bit!0 ? "_" : "A");
        write(i.bit!1 ? "_" : "B");
        write(i.bit!2 ? "_" : "S");
        write(i.bit!3 ? "_" : "~");
        writeln();
    }
    ram[0xFF00] = 1 << 5;
    i = ram[0xFF00];
    if (i != 0xF)
    {
        write(i.bit!0 ? "_" : "▶");
        write(i.bit!1 ? "_" : "◀");
        write(i.bit!2 ? "_" : "▲");
        write(i.bit!3 ? "_" : "▼");
        writeln();
    }
}

void readROMs() {
    import std.file : dirEntries, SpanMode;
    immutable yn = (bool b) => b ? "yes" : "no";

    foreach (string filename; dirEntries("roms", "*.gb", SpanMode.shallow)) {
        writeln();
        auto cart = Cartage.fromFile(filename);
        writeln("Title: ", cart.title);
        writeln("Color: ", yn(cart.isColor));
        writeln("Super: ", yn(cart.isSuper));
        writeln("Cartage: ", cart.type);
        writefln("ROM size: %dKB %d banks", cart.romSize, cart.romBanks);
        writefln("RAM size: %dKB", cart.ramSize);
        writeln("Destination: ", cart.destination);
        writeln("License: ", cart.license);
        writeln("Version: ", cart.ver);
    }
}

/*
*/