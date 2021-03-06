module gameboy.rom;

import std.stdio;
import std.conv : to;
import std.algorithm : equal, max, sum, reduce, map;
import std.exception : enforce;
import gameboy.utils;

class Header
{
    static this() {
        cartages = [0x00: "ROM ONLY",
                    0x01: "ROM+MBC1",
                    0x02: "ROM+MBC1+RAM",
                    0x03: "ROM+MBC1+RAM+BATT",
                    0x05: "ROM+MBC2",
                    0x06: "ROM+MBC2+BATTERY",
                    0x08: "ROM+RAM",
                    0x09: "ROM+RAM+BATTERY",
                    0x0B: "ROM+MMM01",
                    0x0C: "ROM+MMM01+SRAM",
                    0x0D: "ROM+MMM01+SRAM+BATT",
                    0x0F: "ROM+MBC3+TIMER+BATT",
                    0x10: "ROM+MBC3+TIMER+RAM+BATT",
                    0x11: "ROM+MBC3",
                    0x12: "ROM+MBC3+RAM",
                    0x13: "ROM+MBC3+RAM+BATT",
                    0x19: "ROM+MBC5",
                    0x1A: "ROM+MBC5+RAM",
                    0x1B: "ROM+MBC5+RAM+BATT",
                    0x1C: "ROM+MBC5+RUMBLE",
                    0x1D: "ROM+MBC5+RUMBLE+SRAM",
                    0x1E: "ROM+MBC5+RUMBLE+SRAM+BATT",
                    0x1F: "Pocket Camera",
                    0xFD: "Bandai TAMA5",
                    0xFE: "Hudson HuC-3",
                    0xFF: "Hudson HuC-1"];
        manuf = [0x01: "Nintendo",
                 0x33: "Nintendo",
                 0x79: "Accolade",
                 0xA4: "Konami"];
    }

    this(immutable ubyte[] header) immutable {
        enforce(header.length == 0x180, "ROM header invalid size!");
        enforce(nintendoCheck(header), "Nintendo logo check failed!");
        enforce(complementCheck(header), "Complement check failed!");
        this.header = header;
    }

    @property
    string title() inout {
        return cast(string)header[0x0134..0x0143];
    }

    @property
    bool isColor() inout {
        return header[0x0143] == 0x80;
    }

    @property
    bool isSuper() inout {
        return header[0x0146] == 3;
    }

    @property
    string type() inout {
        return cartages[header[0x0147]];
    }

    @property
    int romSize() inout {
        return 32 << header[0x0148];
    }

    @property
    int romBanks() inout {
        return 2 << header[0x0148];
    }

    @property
    int ramSize() inout {
        return max(2 << (2 * (header[0x0149] - 1)), 0);
    }

    @property
    string destination() inout {
        return header[0x014A] ? "Japanese" : "English";
    }

    @property
    string license() inout {
        return header[0x014B] in manuf ? manuf[header[0x014B]] : header[0x014B].to!string;
    }

    @property
    int ver() inout {
        return header[0x014C];
    }

private:
    immutable ubyte[] header;

    static bool nintendoCheck(const ubyte[] header) {
        //Scrolling Nintendo text - same for every game
        immutable scrolling = [0xCE,0xED,0x66,0x66,0xCC,0x0D,0x00,0x0B,0x03,0x73,0x00,0x83,0x00,0x0C,0x00,0x0D,
                               0x00,0x08,0x11,0x1F,0x88,0x89,0x00,0x0E,0xDC,0xCC,0x6E,0xE6,0xDD,0xDD,0xD9,0x99,
                               0xBB,0xBB,0x67,0x63,0x6E,0x0E,0xEC,0xCC,0xDD,0xDC,0x99,0x9F,0xBB,0xB9,0x33,0x3E];
        return equal(header[0x0104..0x0134], scrolling);
    }

    static bool complementCheck(const ubyte[] header) {
        auto complement = reduce!((a, x) => cast(ubyte)(a - x - 1))(0, header[0x0134..0x014D]);
        return complement == header[0x014D];
    }

    static immutable string[ubyte] cartages;
    static immutable string[ubyte] manuf;
}

class Cartage
{
    static Cartage fromFile(string filename) {
        auto file = File(filename, "rb");
        scope(exit) file.close();
        auto rom = cast(immutable)file.rawRead(new ubyte[file.size]);
        auto cartage = new Cartage(rom);
        return cartage;
    }

    immutable Header header;

    this(immutable ubyte[] rom) {
        enforce(rom.length >= 0x180, "ROM size too small!");
        enforce(checksumCheck(rom), "Checksum check failed!");
        this.rom = rom;
        this.header = new immutable(Header)(rom[0..0x180]);
    }

    ubyte opIndex(size_t address) inout {
        if (address < 0 || address > 0x8000)
            return 0;
        return rom[address];
    }

private:
    static bool checksumCheck(const ubyte[] rom) {
        auto checksum = sum(rom[0..0x014E] ~ rom[0x0150..$]) & 0xFFFF;
        return checksum == (rom[0x014E] << 8 | rom[0x014F]);
    }

    immutable ubyte[] rom;
}
