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

template bit(size_t n) {
    static if (n <= 8) {
        alias bit = ubyte;
    }
    else static if (n <= 16) {
        alias bit = ushort;
    }
    else static if (n <= 32) {
        alias bit = uint;
    }
    else static if (n <= 64) {
        alias bit = ulong;
    }
}

unittest {
    assert(is(bit!4 == ubyte));
    assert(is(bit!8 == ubyte));
    assert(is(bit!16 == ushort));
    assert(is(bit!24 == uint));
    assert(is(bit!32 == uint));
    assert(is(bit!64 == ulong));
}
