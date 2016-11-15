module gameboy.app;

import std.stdio;
import dsfml.system;
import dsfml.window;
import dsfml.graphics;
import gameboy.cpu;
import gameboy.memory;
import gameboy.video;
import gameboy.rom;
import gameboy.utils;

void main(string[] args)
{
    readROMs();
    auto cart = Cartage.fromFile("roms/Tetris.gb");
    auto ram = new Memory;
    ram.loadCartage(cart);
    auto cpu = new Processor(ram);
    auto gpu = new Video(ram);
    cpu.boot();

    enum PixelSize = 2;
    immutable screenSize = Vector2u(160, 144) * PixelSize;

    auto window = new RenderWindow(VideoMode(screenSize.x, screenSize.y), cart.title.capitalized, Window.Style.Close);

    //test triangle
    immutable triangle = [Vertex(Vector2f(0, 0), Color.Red),
                          Vertex(Vector2f(screenSize.x, 0), Color.Green),
                          Vertex(Vector2f(screenSize.x, screenSize.y), Color.White),
                          Vertex(Vector2f(0, screenSize.y), Color.Blue)];

    while (window.isOpen())
    {
        Event event;
        while (window.pollEvent(event))
        {
            if (event.type == event.EventType.Closed)
            {
                window.close();
            }
        }
        debug debugCPU(cpu);
        debug debugGPU(gpu);
        cpu.step();
        gpu.step(1);
        cpu.fireInterrupts();
        //update here
        window.clear();
        //draw here
        window.draw(triangle, PrimitiveType.Quads);
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

void debugGPU(Video gpu) {
    auto frame = new Image;
    frame.create(Video.Width, Video.Height, Color.Black);
    for (int y = 0; y < Video.Height; y++) {
        for (int x = 0; x < Video.Width; x++) {
            frame.setPixel(x, y, gpu.buffer[y * Video.Width + x]);
        }
    }
    frame.saveToFile("buffer.png");
}

void readROMs() {
    import std.file;
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