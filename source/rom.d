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

abstract class Mbc
{
    static immutable size_t RomBankSize = 16.KB;
    static immutable size_t RamBankSize = 8.KB;

    this(immutable ubyte[] rom, size_t ramSize) {
        this.rom = rom;
        ram = new ubyte[ramSize];
        ramEnable = false;
    }
    ubyte opIndex(size_t address) inout;
    void opIndexAssign(ubyte value, size_t address);

protected:
    immutable ubyte[] rom;
    ubyte[] ram;
    size_t romBank, ramBank;
    bool ramEnable;
}

class NoMbc : Mbc
{
    this(immutable ubyte[] rom) {
        super(rom, 0);
    }

    override ubyte opIndex(size_t address) inout {
        if (address.inRange(0, 0x8000)) {
            return rom[address];
        }
        return 0;
    }

    override void opIndexAssign(ubyte value, size_t address) {
        
    }
}

class Mbc1 : Mbc
{
    this(immutable ubyte[] rom, size_t ramSize) {
        super(rom, ramSize);
        mode = Mode.ROM;
        romBank = 1;
        ramBank = 0;
    }

    override ubyte opIndex(size_t address) inout {
        if (address.inRange(0, 0x4000)) {
            return rom[address];
        }
        if (address.inRange(0x4000, 0x8000)) {
            size_t romBank = this.romBank;
            if (mode == Mode.ROM) {
                romBank += ramBank << 5;
            }
            size_t offset = romBank * RomBankSize;
            offset += address - 0x4000;
            return rom[offset];
        }
        if (address.inRange(0xA000, 0xC000)) {
            size_t ramBank = 0;
            if (mode == Mode.RAM) {
                ramBank = this.ramBank;
            }
            size_t offset = ramBank * RamBankSize;
            offset += address - 0xA000;
            return ram[offset];
        }
        return 0;
    }

    override void opIndexAssign(ubyte value, size_t address) {
        if (address.inRange(0, 0x2000)) {
            ramEnable = ((value & 0x0A) == 0x0A);
        } else if (address.inRange(0x2000, 0x4000)) {
            value &= 0x1F;
            if (value == 0) {
                value = 1;
            }
            romBank = value;
        } else if (address.inRange(0x4000, 0x6000)) {
            ramBank = value & 0x03;
        } else if (address.inRange(0x6000, 0x8000)) {
            mode = cast(Mode)(value & 0x01);
        } else if (address.inRange(0xA000, 0xC000)) {
            size_t ramBank = 0;
            if (mode == Mode.RAM) {
                ramBank = this.ramBank;
            }
            size_t offset = ramBank * RamBankSize;
            offset += address - 0xA000;
            ram[offset] = value;
        }
    }

private:
    enum Mode {
        ROM = 0,
        RAM = 1
    }
    Mode mode;
}

class Mbc2 : Mbc
{
    this(immutable ubyte[] rom, size_t ramSize) {
        super(rom, ramSize);
        romBank = 1;
    }

    override ubyte opIndex(size_t address) inout {
        if (address.inRange(0, 0x4000)) {
            return rom[address];
        }
        if (address.inRange(0x4000, 0x8000)) {
            size_t offset = romBank * RomBankSize;
            offset += address - 0x4000;
        }
        if (address.inRange(0xA000, 0xA200)) {
            if (ramEnable) {
                size_t offset = address - 0xA000;
                return ram[offset] & 0x0F;
            }
        }
        return 0;
    }

    override void opIndexAssign(ubyte value, size_t address) {
        if (address.inRange(0, 0x2000)) {
            if ((address & 0x0100) == 0) {
                ramEnable = ((value & 0x0A) == 0x0A);
            }
        } else if (address.inRange(0x2000, 0x4000)) {
            if ((address & 0x0100) != 0) {
                value &= 0x0F;
                if (value == 0) {
                    value = 1;
                }
                romBank = value;
            }
        } else if (address.inRange(0xA000, 0xC000)) {
            if (ramEnable) {
                value &= 0x0F;
                size_t offset = address - 0xA000;
                ram[offset] = value;
            }
        }
    }
}