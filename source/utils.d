module gameboy.utils;

import std.array : split, join;
import std.string : capitalize;
import std.algorithm : map;

@property
string capitalized(string value, string sep = " ") {
    return value.split(sep).map!capitalize().join(sep);
}

unittest {
    assert(capitalized("POKEMON RED") == "Pokemon Red");
    assert(capitalized("pokEmoN bLuE") == "Pokemon Blue");
    assert(capitalized("one,TWO,ThrEE", ",") == "One,Two,Three");
}

@property
bool isPowerOf2(size_t n) {
    return (n != 0) && !(n & (n - 1));
}

unittest {
    import std.conv : to;
    foreach (size_t n; [1, 2, 4, 8, 16, 32, 64, 128]) {
        assert(isPowerOf2(n), "Not power of 2: " ~ n.to!string);
    }
    foreach (size_t n; [0, 3, 6, 12, 24, 50]) {
        assert(!isPowerOf2(n), "Power of 2: " ~ n.to!string);
    }
}

@property
size_t KB(size_t n) {
    return n * 1024;
}

@property
size_t MB(size_t n) {
    return n.KB * 1024;
}

@property
size_t GB(size_t n) {
    return n.MB * 1024;
}

@property
size_t TB(size_t n) {
    return n.GB * 1024;
}

template bitness(size_t n) {
    static if (n <= 8) {
        alias bitness = ubyte;
    }
    else static if (n <= 16) {
        alias bitness = ushort;
    }
    else static if (n <= 32) {
        alias bitness = uint;
    }
    else static if (n <= 64) {
        alias bitness = ulong;
    }
}

unittest {
    assert(is(bitness!4 == ubyte));
    assert(is(bitness!8 == ubyte));
    assert(is(bitness!16 == ushort));
    assert(is(bitness!24 == uint));
    assert(is(bitness!32 == uint));
    assert(is(bitness!64 == ulong));
}

template bit(size_t offset, T) {
    @property
    T bit(T value)
    out(bit) {
        assert(bit == 0 || bit == 1);
    } body {
        value >>= offset; //move the bit to be first
        value &= 1; //mask with 1 to get the bit
        return value;
    }

    @property
    void bit(ref T value, size_t bit)
    in {
        assert(bit == 0 || bit == 1);
    } body {
        value &= ~(1 << offset); //clear bit at offset
        value |= bit << offset; //set it to bit at offset
    }
}

unittest {
    assert((0x02).bit!1 == 1);
    ubyte val = 0b10;
    val.bit!0 = 1;
    assert(val == 0b11);
    val.bit!1 = 0;
    assert(val == 0b01);
}

bool inType(T, U)(U value) {
    return T.min <= value && value <= T.max;
}

unittest {
    static assert(inType!ushort(0));
    static assert(inType!ushort(0xFFFF));
    static assert(!inType!ushort(-1));
    static assert(!inType!ushort(0x10000));

    static assert(inType!ubyte(0));
    static assert(inType!ubyte(0xFF));
    static assert(!inType!ubyte(-1));
    static assert(!inType!ubyte(0x100));

    static assert(inType!byte(-128));
    static assert(inType!byte(127));
    static assert(!inType!byte(-129));
    static assert(!inType!byte(128));
}

bool inRange(size_t address, size_t begin, size_t end) {
    return begin <= address && address < end;
}