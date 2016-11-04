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

/*
*/