module gameboy.memory;

import std.stdio;
import std.format : format;
import std.typecons : Tuple, tuple;
import std.random : uniform;
import core.exception : RangeError;
import gameboy.rom;
import gameboy.utils;

struct Range
{
    size_t begin;
    size_t end;

    invariant
    {
        assert(begin < end);
    }

    int opCmp(ref const Range r) const
    {
        if (this.begin < r.begin)
            return -1;
        if (this.begin > r.begin)
            return +1;
        return 0;
    }
}

class Memory
{
    alias T = ushort;
    alias readfn = ubyte delegate(size_t);
    alias writefn = void delegate(size_t, ubyte);

    this() {
        xram = new ubyte[0x2000];
        wram = new ubyte[0x2000];
        zram = new ubyte[0x80];
        mount();
    }

    void mount() {
        mount(xram, 0xA000);
        mount(wram, 0xC000);
        mount(wram, 0xE000, 0xFE00);
        mount(zram, 0xFF80, 0xFFFF);
        mount((size_t address) => uniform!ubyte(), 0xFF04);
    }

    void mount(readfn fn, size_t begin, size_t end) {
        auto key = Range(begin, end);
        reads[key] = fn;
    }

    void mount(writefn fn, size_t begin, size_t end) {
        auto key = Range(begin, end);
        writes[key] = fn;
    }

    void mount(readfn fn, size_t begin) {
        mount(fn, begin, begin + 1);
    }

    void mount(writefn fn, size_t begin) {
        mount(fn, begin, begin + 1);
    }

    void mount(char mode : 'r')(ref const ubyte[] data, size_t begin, size_t end) {
        auto fn = (size_t address) { return data[address]; };
        mount(fn, begin, end);
    }

    void mount(char mode : 'r')(ref const ubyte[] data, size_t begin) {
        mount!'r'(data, begin, begin + data.length);
    }

    void mount(char mode : 'r')(ref const ubyte data, size_t begin) {
        auto fn = (size_t address) { return data; };
        mount(fn, begin);
    }

    void mount(char mode : 'w')(ref ubyte[] data, size_t begin, size_t end) {
        auto fn = (size_t address, ubyte value) { data[address] = value; };
        mount(fn, begin, end);
    }

    void mount(char mode : 'w')(ref ubyte[] data, size_t begin) {
        mount!'w'(data, begin, begin + data.length);
    }

    void mount(char mode : 'w')(ref ubyte data, size_t begin) {
        auto fn = (size_t address, ubyte value) { data = value; };
        mount(fn, begin);
    }

    void mount(ref ubyte[] data, size_t begin, size_t end) {
        mount!'r'(data, begin, end);
        mount!'w'(data, begin, end);
    }

    void mount(ref ubyte[] data, size_t begin) {
        mount!'r'(data, begin);
        mount!'w'(data, begin);
    }

    void mount(ref ubyte data, size_t begin) {
        mount!'r'(data, begin);
        mount!'w'(data, begin);
    }

    void umount() {
        reads.clear;
        writes.clear;
    }

    void umount(char mode : 'r')(size_t begin, size_t end) {
        reads.remove(Range(begin, end));
    }

    void umount(char mode : 'w')(size_t begin, size_t end) {
        writes.remove(Range(begin, end));
    }

    void umount(size_t begin, size_t end) {
        umount!'r'(begin, end);
        umount!'w'(begin, end);
    }

    ubyte opIndex(size_t address) inout {
        if (!inType!T(address))
            throw new RangeError(format("Address $%04X out of range", address));

        foreach (range; reads.byKey()) {
            if (inRange(address, range)) {
                return reads[range](address - range.begin);
            }
        }
        debug writefln("Unhandled Read: $%04X", address);
        return 0;
    }

    void opIndexAssign(ubyte value, size_t address) {
        if (!inType!T(address))
            throw new RangeError(format("Address $%04X out of range", address));

        foreach (range; writes.byKey()) {
            if (inRange(address, range)) {
                writes[range](address - range.begin, value);
                return;
            }
        }
        debug writefln("Unhandled Write: $%04X", address);
    }

    size_t opDollar() inout {
        return T.max + 1;
    }

    void loadCartage(Cartage cart) {
        mount(cast(readfn)&cart.opIndex, 0x0000, 0x8000);
    }

    private static bool inRange(size_t address, Range range) {
        return gameboy.utils.inRange(address, range.begin, range.end);
    }

private:
    readfn[Range] reads;
    writefn[Range] writes;
    ubyte[] xram, wram, zram;
}