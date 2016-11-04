module gameboy.memory;

import gameboy.utils;

interface ReadOnly
{
    ubyte opIndex(size_t i);
}

interface WriteOnly
{
    void opIndexAssign(ubyte value, size_t i);
}

interface ReadWrite : ReadOnly, WriteOnly
{
    
}

class Memory(size_t bits)
{
    alias bit!bits T;
    enum max = 1L << bits;

    this() {
        data = new ubyte[max];
    }

    ubyte opIndex(size_t i) {
        return data[i];
    }

    void opIndexAssign(ubyte value, size_t i) {
        data[i] = value;
    }

    size_t opDollar() {
        return max;
    }

private:
    ubyte[] data;
}

alias Memory!16 GameboyMemory;

unittest
{
    static assert(GameboyMemory.T.max == GameboyMemory.max - 1);
    static assert(Memory!8.max == 256);
    static assert(Memory!16.max == 64.KB);
    static assert(Memory!32.max == 4.GB);

    auto mem = new Memory!8();
    mem[0x20] = 0xEE;
    assert(mem[0x20] == 0xEE);
    mem[$ - 1] = 0xAA;
    assert(mem[255] == 0xAA);

    import core.exception : RangeError;
    import std.exception : assertThrown;
    assertThrown!RangeError(mem[$]);
    assertThrown!RangeError(mem[0x100]);
    assertThrown!RangeError(mem[256]);
}