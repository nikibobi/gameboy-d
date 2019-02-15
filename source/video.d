module gameboy.video;

import dsfml.graphics : Color, Texture;
import gameboy.memory;
import gameboy.utils;

class Video
{
    struct Sprite
    {
        ubyte y;
        ubyte x;
        ubyte tile;
        ubyte options;
    @property:
        ubyte priority() {
            return options.bit!7;
        }
        ubyte flipY() {
            return options.bit!6;
        }
        ubyte flipX() {
            return options.bit!5;
        }
        ubyte palette() {
            return options.bit!4;
        }
    }

    unittest {
        const ubyte[4] data = [0x10, 0x20, 0x40, 0xA0];
        auto s = cast(Sprite)data;
        assert(s.y == 16);
        assert(s.x == 32);
        assert(s.tile == 64);
        assert(s.priority == 1);
        assert(s.flipY == 0);
        assert(s.flipX == 1);
        assert(s.palette == 0);
    }

    enum Mode
    {
        HBLANK,
        VBLANK,
        OAM,
        VRAM
    }

    unittest {
        static assert(Mode.HBLANK == 0);
        static assert(Mode.VBLANK == 1);
        static assert(Mode.OAM == 2);
        static assert(Mode.VRAM == 3);
    }

    enum {
        Width = 160,
        Height = 144
    }

    static immutable Color[4] Palette = [
        Color(255, 255, 255),
        Color(192, 192, 192),
        Color(96, 96, 96),
        Color(0, 0, 0)];

    this(Memory mem) {
        this.mem = mem;
        mode = Mode.HBLANK;
        vram = new ubyte[0x2000];
        oam = new ubyte[0x100];
        canvas = new Texture;
        canvas.create(Width, Height);
        mount();
    }

    @property
    const(Texture) texture() inout {
        return this.canvas;
    }

    void mount() {
        mem.mount!'r'(vram, 0x8000);
        mem.mount(&writeToVRAM, 0x8000, 0xA000);
        mem.mount(oam, 0xFE00);
        mem.mount(control, 0xFF40);
        mem.mount(scrollY, 0xFF42);
        mem.mount(scrollX, 0xFF43);
        mem.mount!'r'(scanline, 0xFF44);
        mem.mount(&oamToDmaTransfer, 0xFF46);
        mem.mount(mountPalette(backgroundPalette), 0xFF47);
        mem.mount(mountPalette(spritePalette[0]), 0xFF48);
        mem.mount(mountPalette(spritePalette[1]), 0xFF49);
    }

    void step(ulong dt) {
        ticks += dt;
        final switch (mode) {
            case Mode.HBLANK:
                if (ticks >= 204) {
                    scanline++;
                    if (scanline == 143) {
                        //interrupt event
                        if (mem[0xFFFF].bit!0) {
                            auto flags = mem[0xFF0F];
                            flags.bit!0 = 1;
                            mem[0xFF0F] = flags;
                        }
                        render();
                        mode = Mode.VBLANK;
                    } else {
                        mode = Mode.OAM;
                    }
                    ticks -= 204;
                }
                break;
            case Mode.VBLANK:
                if (ticks >= 456) {
                    scanline++;
                    if (scanline > 153) {
                        scanline = 0;
                        mode = Mode.OAM;
                    }
                    ticks -= 456;
                }
                break;
            case Mode.OAM:
                if (ticks >= 80) {
                    mode = Mode.VRAM;
                    ticks -= 80;
                }
                break;
            case Mode.VRAM:
                if (ticks >= 172) {
                    mode = Mode.HBLANK;
                    renderScanline();
                    ticks -= 172;
                }
                break;
        }
    }

private:
    auto mountPalette(ref Color[4] palette) {
        return (size_t address, ubyte value) {
            for (size_t i = 0; i < 4; i++) {
                palette[i] = Palette[(value >> (i * 2)) & 3];
            }
        };
    }

    void writeToVRAM(size_t address, ubyte value) {
        vram[address] = value;
        if (address <= 0x17FF) {
            updateTiles(address + 0x8000, value);
        }
    }

    void oamToDmaTransfer(size_t address, ubyte value) {
        for (size_t i = 0; i < 160; i++) {
            mem[0xFE00 + i] = mem[(value << 8) + i];
        }
    }

    void updateTiles(size_t address, ubyte value) {
        address &= 0x1FFE;
        ushort tile = (address >> 4) & 511;
        ushort y = (address >> 1) & 7;
        for (ubyte x = 0; x < 8; x++) {
            immutable bitIndex = cast(ubyte)(1 << (7 - x));
            tiles[x][y][tile] = ((vram[address] & bitIndex) ? 1 : 0) + ((vram[address + 1] & bitIndex) ? 2 : 0);
        }
    }

    void renderScanline() {
        size_t mapOffset = (control.bit!3 ? 0x1C00 : 0x1800);
        mapOffset += (((scanline + scrollY) & 0xFF) >> 3) << 5;
        size_t lineOffset = scrollX >> 3;
        size_t x = scrollX & 0b111;
        size_t y = (scanline + scrollY) & 0b111;
        size_t pixelOffset = scanline * Width;
        ushort tile = vram[mapOffset + lineOffset];
        //draw background
        auto scanlineRow = new ubyte[Width];
        if (control.bit!4 && tile < 128) {
            tile += 256;
        }
        for (size_t i = 0; i < Width; i++) {
            immutable ubyte color = tiles[x][y][tile];
            scanlineRow[i] = color;
            setColor(pixelOffset, backgroundPalette[color]);
            pixelOffset++;
            x++;
            if (x == 8) {
                x = 0;
                lineOffset = (lineOffset + 1) & 0b11111;
                tile = vram[mapOffset + lineOffset];
                if (control.bit!4 && tile < 128) {
                    tile += 256;
                }
            }
        }
        //draw sprites
        for (size_t i = 0; i < 40; i++) {
            immutable ubyte[4] data = oam[i..i + 4];
            Sprite sprite = cast(Sprite)data;
            int sx = sprite.x - 8;
            int sy = sprite.y - 16;
            if (sy <= scanline && (sy + 8) > scanline) {
                pixelOffset = scanline * Width + sx;
                auto tileRow = cast(ubyte)(scanline - sy);
                if (sprite.flipY) {
                    tileRow = cast(ubyte)(7 - tileRow);
                }

                for (x = 0; x < 8; x++) {
                    if (sx + x >= 0 && sx + x < Width && (sprite.priority == 0 || !scanlineRow[sx + x])) {
                        auto tileCol = cast(ubyte)x;
                        if (sprite.flipX) {
                            tileCol = cast(ubyte)(7 - tileCol);
                        }
                        ubyte color = tiles[tileCol][tileRow][sprite.tile];
                        if (color) {
                            setColor(pixelOffset, spritePalette[sprite.palette][color]);
                        }
                        pixelOffset++;
                    }
                }
            }
        }
    }

    void render() {
        canvas.updateFromPixels(framebuffer, Width, Height, 0, 0);
    }

    void setColor(size_t index, Color color) {
        framebuffer[index * 4 + 0] = color.r;
        framebuffer[index * 4 + 1] = color.g;
        framebuffer[index * 4 + 2] = color.b;
        framebuffer[index * 4 + 3] = color.a;
    }

private:
    ubyte[] vram, oam;
    ubyte control, scrollX, scrollY, scanline;
    Color[4] backgroundPalette;
    Color[4][2] spritePalette;
    ubyte[384][8][8] tiles;
    ulong ticks;
    Mode mode;
    ubyte[Width * Height * 4] framebuffer;
    Texture canvas;
    Memory mem;
}