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
        io = [      0x00, 0x7C, 0xFF, 0x00, 0x00, 0x00, 0xF8, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01,
              0x80, 0xBF, 0xF3, 0xFF, 0xBF, 0xFF, 0x3F, 0x00, 0xFF, 0xBF, 0x7F, 0xFF, 0x9F, 0xFF, 0xBF, 0xFF,
              0xFF, 0x00, 0x00, 0xBF, 0x77, 0xF3, 0xF1, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
              0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF,
              0x91, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFC, 0x00, 0x00, 0x00, 0x00, 0xFF, 0x7E, 0xFF, 0xFE,
              0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x3E, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
              0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xC0, 0xFF, 0xC1, 0x00, 0xFE, 0xFF, 0xFF, 0xFF,
              0xF8, 0xFF, 0x00, 0x00, 0x00, 0x8F, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
              0xCE, 0xED, 0x66, 0x66, 0xCC, 0x0D, 0x00, 0x0B, 0x03, 0x73, 0x00, 0x83, 0x00, 0x0C, 0x00, 0x0D,
              0x00, 0x08, 0x11, 0x1F, 0x88, 0x89, 0x00, 0x0E, 0xDC, 0xCC, 0x6E, 0xE6, 0xDD, 0xDD, 0xD9, 0x99,
              0xBB, 0xBB, 0x67, 0x63, 0x6E, 0x0E, 0xEC, 0xCC, 0xDD, 0xDC, 0x99, 0x9F, 0xBB, 0xB9, 0x33, 0x3E,
              0x45, 0xEC, 0x52, 0xFA, 0x08, 0xB7, 0x07, 0x5D, 0x01, 0xFD, 0xC0, 0xFF, 0x08, 0xFC, 0x00, 0xE5,
              0x0B, 0xF8, 0xC2, 0xCE, 0xF4, 0xF9, 0x0F, 0x7F, 0x45, 0x6D, 0x3D, 0xFE, 0x46, 0x97, 0x33, 0x5E,
              0x08, 0xEF, 0xF1, 0xFF, 0x86, 0x83, 0x24, 0x74, 0x12, 0xFC, 0x00, 0x9F, 0xB4, 0xB7, 0x06, 0xD5,
              0xD0, 0x7A, 0x00, 0x9E, 0x04, 0x5F, 0x41, 0x2F, 0x1D, 0x77, 0x36, 0x75, 0x81, 0xAA, 0x70, 0x3A,
              0x98, 0xD1, 0x71, 0x02, 0x4D, 0x01, 0xC1, 0xFF, 0x0D, 0x00, 0xD3, 0x05, 0xF9, 0x00, 0x0B, 0x00];
        mount();
    }

    void mount() {
        mount(xram, 0xA000);
        mount(wram, 0xC000);
        mount(wram, 0xE000, 0xFE00);
        mount(io, 0xFF01, 0xFF80);
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
        return range.begin <= address && address < range.end;
    }

private:
    readfn[Range] reads;
    writefn[Range] writes;
    ubyte[] xram, wram, io, zram;
}