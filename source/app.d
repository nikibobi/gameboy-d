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

void main(string[] args)
{
    enum PixelSize = 1;
    debug readROMs();
    auto cart = Cartage.fromFile("roms/DrMario.gb");
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
        } while (cpu.time < end);

        window.clear();
        window.draw(sprite);
        window.display();
    }
}

void debugCPU(Processor cpu) {
    auto file = File("debug.txt", "w");
    scope(exit) file.close();
    file.writefln("A: $%02X", cpu.reg!"a");
    file.writefln("F: %s%s%s%s", (cpu.flag!'z'?'z':'-'), (cpu.flag!'n'?'n':'-'), (cpu.flag!'h'?'h':'-'), (cpu.flag!'c'?'c':'-'));
    file.writefln("BC: $%04X", cpu.reg!"bc");
    file.writefln("DE: $%04X", cpu.reg!"de");
    file.writefln("HL: $%04X", cpu.reg!"hl");
    file.writefln("(HL): $%02X", cpu.reg!"(hl)");
    file.writefln("SP: $%04X", cpu.reg!"sp");
    file.writefln("PC: $%04X", cpu.reg!"pc");
}

void readROMs() {
    import std.file : dirEntries, SpanMode;
    foreach (string filename; dirEntries("roms", "*.gb", SpanMode.shallow)) {
        writeln();
        auto cart = Cartage.fromFile(filename);
        writeln("Title: ", cart.title);
        writeln("Color: ", cart.isColor ? "yes" : "no");
        writeln("Super: ", cart.isSuper ? "yes" : "no");
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