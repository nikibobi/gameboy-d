module gameboy.app;

import std.stdio;
import dsfml.system;
import dsfml.window;
import dsfml.graphics;
import gameboy.memory;
import gameboy.rom;
import gameboy.utils;

void main(string[] args)
{
    readROMs();
    auto cart = Cartage.fromFile("roms/Tetris.gb");

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
        //update here
        window.clear();
        //draw here
        window.draw(triangle, PrimitiveType.Quads);
        window.display();
    }
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