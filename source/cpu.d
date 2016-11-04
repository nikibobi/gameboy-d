module gameboy.cpu;

import std.stdio;
import std.conv;
import std.string : indexOf;
import std.format : format;
import gameboy.memory;
import gameboy.utils : bitness, isPowerOf2, bit;

struct Instruction
{
    private this(string mnemonic) {
        this.mnemonic = mnemonic;
    }

    this(string mnemonic, void delegate() op) {
        this(mnemonic);
        this.nullary = op;
        args = 0;
    }

    this(string mnemonic, void delegate(ubyte) op) {
        this(mnemonic);
        this.unary = op;
        args = 1;
    }

    this(string mnemonic, void delegate(ushort) op) {
        this(mnemonic);
        this.binary = op;
        args = 2;
    }

    string mnemonic;
    union
    {
        void delegate() nullary;
        void delegate(ubyte) unary;
        void delegate(ushort) binary;
    }
    int args;
}

class CPU(size_t bits, string registers)
if (bits.isPowerOf2)
{
    alias bitness!bits T;

    this(Memory!(bits * 2) mem) {
        this.mem = mem;
    }

    @property
    auto reg(string select)() inout {
        static if (select == "pc") {
            return pc;
        } else static if (select == "sp") {
            return sp;
        } else {
            bitness!(select.length * bits) res = 0;
            foreach (i, r; select) {
                auto shift = (select.length - i - 1) * bits;
                res |= cast(typeof(res))regs[r] << shift;
            }
            return res;
        }
    }

    unittest {
        auto mem = new Memory!16;
        auto cpu = new CPU!(8, "abcdefhl")(mem);
        assert(is(typeof(cpu.reg!"pc") == ushort));
        assert(is(typeof(cpu.reg!"sp") == ushort));

        assert(is(typeof(cpu.reg!"a") == ubyte));
        assert(is(typeof(cpu.reg!"ab") == ushort));
        assert(is(typeof(cpu.reg!"abc") == uint));
        assert(is(typeof(cpu.reg!"abcd") == uint));
        assert(is(typeof(cpu.reg!"abcde") == ulong));
        assert(is(typeof(cpu.reg!"abcdef") == ulong));
        assert(is(typeof(cpu.reg!"abcdefh") == ulong));
        assert(is(typeof(cpu.reg!"abcdefhl") == ulong));
    }

    @property
    void reg(string select)(bitness!(select.length * bits) value) {
        static if (select == "pc") {
            pc = value;
        } else static if (select == "sp") {
            sp = value;
        } else {
            foreach (i, r; select) {
                auto shift = (select.length - i - 1) * bits;
                regs[r] = T.max & (value >> shift);
            }
        }
    }

    unittest {
        auto mem = new Memory!16;
        auto cpu = new CPU!(8, "abcdefhl")(mem);
        cpu.reg!"abcdefhl" = 0x0001020304050607;

        assert(cpu.reg!"baef" == 0x01000405);
        cpu.reg!"ab" = cpu.reg!"ba";
        assert(cpu.reg!"ab" == 0x0100);
        assert(cpu.reg!"aaa" == 0x010101);
        cpu.reg!"af" = cpu.reg!"bc";
        assert(cpu.reg!"a" == cpu.reg!"b" && cpu.reg!"f" == cpu.reg!"c");
    }

protected:
    Instruction[ubyte] set;

private:
    T[char] regs;
    bitness!(bits * 2) pc, sp;
    Memory!(bits * 2) mem;
}

class GameboyCPU : CPU!(8, "abcdefhl")
{
    static immutable string flags = "chnz";

    this(GameboyMemory mem) {
        super(mem);
        set = [
            0x00: Instruction("NOP", &nop),
            0x76: Instruction("HALT", &halt),
            0x10: Instruction("STOP 0", &stop),

            0x01: Instruction("LD BC,d16", (ushort n) { reg!"bc" = n; }),
            0x11: Instruction("LD DE,d16", (ushort n) { reg!"de" = n; }),
            0x21: Instruction("LD HL,d16", (ushort n) { reg!"hl" = n; }),
            0x31: Instruction("LD SP,d16", (ushort n) { reg!"sp" = n; }),

            0x06: Instruction("LD B,d8", (ubyte n) { reg!"b" = n; }),
            0x0E: Instruction("LD C,d8", (ubyte n) { reg!"c" = n; }),
            0x16: Instruction("LD D,d8", (ubyte n) { reg!"d" = n; }),
            0x1E: Instruction("LD E,d8", (ubyte n) { reg!"e" = n; }),
            0x26: Instruction("LD H,d8", (ubyte n) { reg!"h" = n; }),
            0x2E: Instruction("LD L,d8", (ubyte n) { reg!"l" = n; }),
            0x36: Instruction("LD (HL),d8", (ubyte n) { mem[reg!"hl"] = n; }),
            0x3E: Instruction("LD A,d8", (ubyte n) { reg!"a" = n; }),

            0x40: Instruction("LD B,B", { reg!"b" = reg!"b"; }),
            0x41: Instruction("LD B,C", { reg!"b" = reg!"c"; }),
            0x42: Instruction("LD B,D", { reg!"b" = reg!"d"; }),
            0x43: Instruction("LD B,E", { reg!"b" = reg!"e"; }),
            0x44: Instruction("LD B,H", { reg!"b" = reg!"h"; }),
            0x45: Instruction("LD B,L", { reg!"b" = reg!"l"; }),
            0x46: Instruction("LD B,(HL)", { reg!"b" = mem[reg!"hl"]; }),
            0x47: Instruction("LD B,A", { reg!"b" = reg!"a"; }),

            0x48: Instruction("LD C,B", { reg!"c" = reg!"b"; }),
            0x49: Instruction("LD C,C", { reg!"c" = reg!"c"; }),
            0x4A: Instruction("LD C,D", { reg!"c" = reg!"d"; }),
            0x4B: Instruction("LD C,E", { reg!"c" = reg!"e"; }),
            0x4C: Instruction("LD C,H", { reg!"c" = reg!"h"; }),
            0x4D: Instruction("LD C,L", { reg!"c" = reg!"l"; }),
            0x4E: Instruction("LD C,(HL)", { reg!"c" = mem[reg!"hl"]; }),
            0x4F: Instruction("LD C,A", { reg!"c" = reg!"a"; }),

            0x50: Instruction("LD D,B", { reg!"d" = reg!"b"; }),
            0x51: Instruction("LD D,C", { reg!"d" = reg!"c"; }),
            0x52: Instruction("LD D,D", { reg!"d" = reg!"d"; }),
            0x53: Instruction("LD D,E", { reg!"d" = reg!"e"; }),
            0x54: Instruction("LD D,H", { reg!"d" = reg!"h"; }),
            0x55: Instruction("LD D,L", { reg!"d" = reg!"l"; }),
            0x56: Instruction("LD D,(HL)", { reg!"d" = mem[reg!"hl"]; }),
            0x57: Instruction("LD D,A", { reg!"d" = reg!"a"; }),

            0x58: Instruction("LD E,B", { reg!"e" = reg!"b"; }),
            0x59: Instruction("LD E,C", { reg!"e" = reg!"c"; }),
            0x5A: Instruction("LD E,D", { reg!"e" = reg!"d"; }),
            0x5B: Instruction("LD E,E", { reg!"e" = reg!"e"; }),
            0x5C: Instruction("LD E,H", { reg!"e" = reg!"h"; }),
            0x5D: Instruction("LD E,L", { reg!"e" = reg!"l"; }),
            0x5E: Instruction("LD E,(HL)", { reg!"e" = mem[reg!"hl"]; }),
            0x5F: Instruction("LD E,A", { reg!"e" = reg!"a"; }),

            0x60: Instruction("LD H,B", { reg!"h" = reg!"b"; }),
            0x61: Instruction("LD H,C", { reg!"h" = reg!"c"; }),
            0x62: Instruction("LD H,D", { reg!"h" = reg!"d"; }),
            0x63: Instruction("LD H,E", { reg!"h" = reg!"e"; }),
            0x64: Instruction("LD H,H", { reg!"h" = reg!"h"; }),
            0x65: Instruction("LD H,L", { reg!"h" = reg!"l"; }),
            0x66: Instruction("LD H,(HL)", { reg!"h" = mem[reg!"hl"]; }),
            0x67: Instruction("LD H,A", { reg!"h" = reg!"a"; }),
            
            0x68: Instruction("LD L,B", { reg!"l" = reg!"b"; }),
            0x69: Instruction("LD L,C", { reg!"l" = reg!"c"; }),
            0x6A: Instruction("LD L,D", { reg!"l" = reg!"d"; }),
            0x6B: Instruction("LD L,E", { reg!"l" = reg!"e"; }),
            0x6C: Instruction("LD L,H", { reg!"l" = reg!"h"; }),
            0x6D: Instruction("LD L,L", { reg!"l" = reg!"l"; }),
            0x6E: Instruction("LD L,(HL)", { reg!"l" = mem[reg!"hl"]; }),
            0x6F: Instruction("LD L,A", { reg!"l" = reg!"a"; }),

            0x70: Instruction("LD (HL),B", { mem[reg!"hl"] = reg!"b"; }),
            0x71: Instruction("LD (HL),C", { mem[reg!"hl"] = reg!"c"; }),
            0x72: Instruction("LD (HL),D", { mem[reg!"hl"] = reg!"d"; }),
            0x73: Instruction("LD (HL),E", { mem[reg!"hl"] = reg!"e"; }),
            0x74: Instruction("LD (HL),H", { mem[reg!"hl"] = reg!"h"; }),
            0x75: Instruction("LD (HL),L", { mem[reg!"hl"] = reg!"l"; }),
            0x77: Instruction("LD (HL),A", { mem[reg!"hl"] = reg!"a"; }),

            0x78: Instruction("LD A,B", { reg!"a" = reg!"b"; }),
            0x79: Instruction("LD A,C", { reg!"a" = reg!"c"; }),
            0x7A: Instruction("LD A,D", { reg!"a" = reg!"d"; }),
            0x7B: Instruction("LD A,E", { reg!"a" = reg!"e"; }),
            0x7C: Instruction("LD A,H", { reg!"a" = reg!"h"; }),
            0x7D: Instruction("LD A,L", { reg!"a" = reg!"l"; }),
            0x7E: Instruction("LD A,(HL)", { reg!"a" = mem[reg!"hl"]; }),
            0x7F: Instruction("LD A,A", { reg!"a" = reg!"a"; }),

            0x0A: Instruction("LD A,(BC)", { reg!"a" = mem[reg!"bc"]; }),
            0x1A: Instruction("LD A,(DE)", { reg!"a" = mem[reg!"de"]; }),
            0xFA: Instruction("LD A,(a16)", (ushort n) { reg!"a" = mem[n]; }),
            0x02: Instruction("LD (BC),A", { mem[reg!"bc"] = reg!"a"; }),
            0x12: Instruction("LD (DE),A", { mem[reg!"de"] = reg!"a"; }),
            0xEA: Instruction("LD (a16),A", (ushort n) { mem[n] = reg!"a"; }),

            0xF2: Instruction("LD A,(C)", { reg!"a" = mem[0xFF00 + reg!"c"]; }),
            0xE2: Instruction("LD (C),A", { mem[0xFF00 + reg!"c"] = reg!"a"; }),

            0x22: Instruction("LD (HL+),A", { mem[reg!"hl"] = reg!"a"; inc!"hl"; }),
            0x32: Instruction("LD (HL-),A", { mem[reg!"hl"] = reg!"a"; dec!"hl"; }),
            0x2A: Instruction("LD A,(HL+)", { reg!"a" = mem[reg!"hl"]; inc!"hl"; }),
            0x3A: Instruction("LD A,(HL-)", { reg!"a" = mem[reg!"hl"]; dec!"hl"; }),

            0xE0: Instruction("LDH (a8),A", (ubyte n) { mem[0xFF00 + n] = reg!"a"; }),
            0xF0: Instruction("LDH A,(a8)", (ubyte n) { reg!"a" = mem[0xFF00 + n]; }),

            0xF9: Instruction("LD SP,HL", { reg!"sp" = reg!"hl"; }),
            0xF8: Instruction("LD HL,SP+r8", &ldhl),
            0x08: Instruction("LD (a16),SP", &ldsp),

            0xC5: Instruction("PUSH BC", { push(reg!"bc"); }),
            0xD5: Instruction("PUSH DE", { push(reg!"de"); }),
            0xE5: Instruction("PUSH HL", { push(reg!"hl"); }),
            0xF5: Instruction("PUSH AF", { push(reg!"af"); }),

            0x80: Instruction("ADD A,B", { add(reg!"b"); }),
            0x81: Instruction("ADD A,C", { add(reg!"c"); }),
            0x82: Instruction("ADD A,D", { add(reg!"d"); }),
            0x83: Instruction("ADD A,E", { add(reg!"e"); }),
            0x84: Instruction("ADD A,H", { add(reg!"h"); }),
            0x85: Instruction("ADD A,L", { add(reg!"l"); }),
            0x86: Instruction("ADD A,(HL)", { add(mem[reg!"hl"]); }),
            0x87: Instruction("ADD A,A", { add(reg!"a"); }),
            0xC6: Instruction("ADD A,d8", &add),

            0x88: Instruction("ADC A,B", { adc(reg!"b"); }),
            0x89: Instruction("ADC A,C", { adc(reg!"c"); }),
            0x8A: Instruction("ADC A,D", { adc(reg!"d"); }),
            0x8B: Instruction("ADC A,E", { adc(reg!"e"); }),
            0x8C: Instruction("ADC A,H", { adc(reg!"h"); }),
            0x8D: Instruction("ADC A,L", { adc(reg!"l"); }),
            0x8E: Instruction("ADC A,(HL)", { adc(mem[reg!"hl"]); }),
            0x8F: Instruction("ADC A,A", { adc(reg!"a"); }),
            0xCE: Instruction("ADC A,d8", &adc),

            0x90: Instruction("SUB B", { sub(reg!"b"); }),
            0x91: Instruction("SUB C", { sub(reg!"c"); }),
            0x92: Instruction("SUB D", { sub(reg!"d"); }),
            0x93: Instruction("SUB E", { sub(reg!"e"); }),
            0x94: Instruction("SUB H", { sub(reg!"h"); }),
            0x95: Instruction("SUB L", { sub(reg!"l"); }),
            0x96: Instruction("SUB (HL)", { sub(mem[reg!"hl"]); }),
            0x97: Instruction("SUB A", { sub(reg!"a"); }),
            0xD6: Instruction("SUB d8", &sub),

            0x98: Instruction("SBC A,B", { sbc(reg!"b"); }),
            0x99: Instruction("SBC A,C", { sbc(reg!"c"); }),
            0x9A: Instruction("SBC A,D", { sbc(reg!"d"); }),
            0x9B: Instruction("SBC A,E", { sbc(reg!"e"); }),
            0x9C: Instruction("SBC A,H", { sbc(reg!"h"); }),
            0x9D: Instruction("SBC A,L", { sbc(reg!"l"); }),
            0x9E: Instruction("SBC A,(HL)", { sbc(mem[reg!"hl"]); }),
            0x9F: Instruction("SBC A,A", { sbc(reg!"a"); }),
            0xDE: Instruction("SBC A,d8", &sbc),

            0xA0: Instruction("AND B", { and(reg!"b"); }),
            0xA1: Instruction("AND C", { and(reg!"c"); }),
            0xA2: Instruction("AND D", { and(reg!"d"); }),
            0xA3: Instruction("AND E", { and(reg!"e"); }),
            0xA4: Instruction("AND H", { and(reg!"h"); }),
            0xA5: Instruction("AND L", { and(reg!"l"); }),
            0xA6: Instruction("AND (HL)", { and(mem[reg!"hl"]); }),
            0xA7: Instruction("AND A", { and(reg!"a"); }),
            0xE6: Instruction("AND d8", &and),

            0xB0: Instruction("OR B", { or(reg!"b"); }),
            0xB1: Instruction("OR C", { or(reg!"c"); }),
            0xB2: Instruction("OR D", { or(reg!"d"); }),
            0xB3: Instruction("OR E", { or(reg!"e"); }),
            0xB4: Instruction("OR H", { or(reg!"h"); }),
            0xB5: Instruction("OR L", { or(reg!"l"); }),
            0xB6: Instruction("OR (HL)", { or(mem[reg!"hl"]); }),
            0xB7: Instruction("OR A", { or(reg!"a"); }),
            0xF6: Instruction("OR d8", &or),

            0xA8: Instruction("XOR B", { xor(reg!"b"); }),
            0xA9: Instruction("XOR C", { xor(reg!"c"); }),
            0xAA: Instruction("XOR D", { xor(reg!"d"); }),
            0xAB: Instruction("XOR E", { xor(reg!"e"); }),
            0xAC: Instruction("XOR H", { xor(reg!"h"); }),
            0xAD: Instruction("XOR L", { xor(reg!"l"); }),
            0xAE: Instruction("XOR (HL)", { xor(mem[reg!"hl"]); }),
            0xAF: Instruction("XOR A", { xor(reg!"a"); }),
            0xEE: Instruction("XOR d8", &xor),

            0xB8: Instruction("CP B", { cp(reg!"b"); }),
            0xB9: Instruction("CP C", { cp(reg!"c"); }),
            0xBA: Instruction("CP D", { cp(reg!"d"); }),
            0xBB: Instruction("CP E", { cp(reg!"e"); }),
            0xBC: Instruction("CP H", { cp(reg!"h"); }),
            0xBD: Instruction("CP L", { cp(reg!"l"); }),
            0xBE: Instruction("CP (HL)", { cp(mem[reg!"hl"]); }),
            0xBF: Instruction("CP A", { cp(reg!"a"); }),
            0xFE: Instruction("CP d8", &cp),

            0x04: Instruction("INC B", &inc!"b"),
            0x0C: Instruction("INC C", &inc!"c"),
            0x14: Instruction("INC D", &inc!"d"),
            0x1C: Instruction("INC E", &inc!"e"),
            0x24: Instruction("INC H", &inc!"h"),
            0x2C: Instruction("INC L", &inc!"l"),
            0x34: Instruction("INC (HL)", { mem[reg!"hl"] = inc(mem[reg!"hl"]); }),
            0x3C: Instruction("INC A", &inc!"a"),

            0x05: Instruction("DEC B", &dec!"b"),
            0x0D: Instruction("DEC C", &dec!"c"),
            0x15: Instruction("DEC D", &dec!"d"),
            0x1D: Instruction("DEC E", &dec!"e"),
            0x25: Instruction("DEC H", &dec!"h"),
            0x2D: Instruction("DEC L", &dec!"l"),
            0x35: Instruction("DEC (HL)", { mem[reg!"hl"] = dec(mem[reg!"hl"]); }),
            0x3D: Instruction("DEC A", &dec!"a"),

            0xC1: Instruction("POP BC", { reg!"bc" = pop(); }),
            0xD1: Instruction("POP DE", { reg!"de" = pop(); }),
            0xE1: Instruction("POP HL", { reg!"hl" = pop(); }),
            0xF1: Instruction("POP AF", { reg!"af" = pop(); }),

            0x09: Instruction("ADD HL,BC", { addhl(reg!"bc"); }),
            0x19: Instruction("ADD HL,DE", { addhl(reg!"de"); }),
            0x29: Instruction("ADD HL,HL", { addhl(reg!"hl"); }),
            0x39: Instruction("ADD HL,SP", { addhl(reg!"sp"); }),

            0xE8: Instruction("ADD SP,r8", &addsp),

            0x03: Instruction("INC BC", &inc!"bc"),
            0x13: Instruction("INC DE", &inc!"de"),
            0x23: Instruction("INC HL", &inc!"hl"),
            0x33: Instruction("INC SP", &inc!"sp"),

            0x0B: Instruction("DEC BC", &dec!"bc"),
            0x1B: Instruction("DEC DE", &dec!"de"),
            0x2B: Instruction("DEC HL", &dec!"hl"),
            0x3B: Instruction("DEC SP", &dec!"sp"),

            0x27: Instruction("DAA", &daa),
            0x2F: Instruction("CPL", &cpl),
            0x3F: Instruction("CCF", &ccf),
            0x37: Instruction("SCF", &scf),

            0xF3: Instruction("DI", { interupts(false); }),
            0xFB: Instruction("EI", { interupts(true); }),

            0x07: Instruction("RLCA", &rlca),
            0x17: Instruction("RLA", &rla),
            0x0F: Instruction("RRCA", &rrca),
            0x1F: Instruction("RRA", &rra),

            0xC3: Instruction("JP a16", &jp),
            0xC2: Instruction("JP NZ,a16", (ushort n) { if (flag!'z' == 0) jp(n); }),
            0xCA: Instruction("JP Z,a16", (ushort n) { if (flag!'z' != 0) jp(n); }),
            0xD2: Instruction("JP NC,a16", (ushort n) { if (flag!'c' == 0) jp(n); }),
            0xDA: Instruction("JP C,a16", (ushort n) { if (flag!'c' != 0) jp(n); }),
            0xE9: Instruction("JP (HL)", { jp(reg!"hl"); }),

            0x18: Instruction("JR r8", &jr),
            0x20: Instruction("JR NZ,r8", (ubyte n) { if (flag!'z' == 0) jr(n); }),
            0x28: Instruction("JR Z,r8", (ubyte n) { if (flag!'z' != 0) jr(n); }),
            0x30: Instruction("JR NC,r8", (ubyte n) { if (flag!'c' == 0) jr(n); }),
            0x38: Instruction("JR C,r8", (ubyte n) { if (flag!'c' != 0) jr(n); }),

            0xCD: Instruction("CALL a16", &call),
            0xC4: Instruction("CALL NZ,a16", (ushort n) { if (flag!'z' == 0) call(n); }),
            0xCC: Instruction("CALL Z,a16", (ushort n) { if (flag!'z' != 0) call(n); }),
            0xD4: Instruction("CALL NC,a16", (ushort n) { if (flag!'c' == 0) call(n); }),
            0xDC: Instruction("CALL C,a16", (ushort n) { if (flag!'c' != 0) call(n); }),

            0xC7: Instruction("RST 00H", &rst!0x00),
            0xCF: Instruction("RST 08H", &rst!0x08),
            0xD7: Instruction("RST 10H", &rst!0x10),
            0xDF: Instruction("RST 18H", &rst!0x18),
            0xE7: Instruction("RST 20H", &rst!0x20),
            0xEF: Instruction("RST 28H", &rst!0x28),
            0xF7: Instruction("RST 30H", &rst!0x30),
            0xFF: Instruction("RST 38H", &rst!0x38),

            0xC9: Instruction("RET", &ret),
            0xC0: Instruction("RET NZ", { if (flag!'z' == 0) ret(); }),
            0xC8: Instruction("RET Z", { if (flag!'z' != 0) ret(); }),
            0xD0: Instruction("RET NC", { if (flag!'c' == 0) ret(); }),
            0xD8: Instruction("RET C", { if (flag!'c' != 0) ret(); }),
            0xD9: Instruction("RETI", { ret(); interupts(true); }),

            0xCB: Instruction("PREFIX CB", &cb)
        ];
        set.rehash();
        //TODO: finish this one way or another
        auto refs = [`reg!"b"`, `reg!"c"`, `reg!"d"`, `reg!"e"`, `reg!"h"`, `reg!"l"`, `mem[reg!"hl"]`, `reg!"a"`];
        auto vals = ["B", "C", "D", "E", "H", "L", "(HL)", "A"];
        auto opcs = ["RLC", "RRC", "RL", "RR", "SLA", "SRA", "SWAP", "SRL"];
        for (size_t i = 0x00; i <= 0x30; i += 0x10) {
            for (size_t r = 0x00; r <= 0x0F; r += 0x01) {
                auto opcode = cast(ubyte)(i + r);
                auto mnemonic = format("%s %s", opcs[opcode / 8], vals[opcode % 8]);
                writefln("0x%02X: %s", opcode, mnemonic);
                cbSet[opcode] = Instruction(mnemonic, &nop);
            }
        }
        cbSet.rehash();
    }

    unittest
    {
        //tests which instructions are implemented
        import std.algorithm : countUntil;
        auto cpu = new GameboyCPU(new GameboyMemory);
        ubyte[] none = [0xD3, 0xE3, 0xE4, 0xF4, 0xDB, 0xEB, 0xEC, 0xFC, 0xDD, 0xED, 0xFD];
        ubyte[] notdone = [];
        for (int i = 0x00; i <= 0xFF; i++) {
            auto key = cast(ubyte)i;
            if (key !in cpu.set) {
                if (countUntil(none, key) == -1) {
                    notdone ~= key;
                }
            } else {
                //writeln(cpu.set[key].mnemonic);
            }
        }
        writefln("NOT DONE: %(%02X %)", notdone);
    }

    @property
    T flag(char f)() inout
    if (flags.indexOf(f) != -1) {
        immutable i = flags.indexOf(f) + 4;
        return reg!"f".bit!i;
    }

    @property
    void flag(char f)(T value)
    if (flags.indexOf(f) != -1) {
        immutable i = flags.indexOf(f) + 4;
        auto f = reg!"f";
        f.bit!i = value;
        reg!"f" = f;
    }

    unittest {
        auto cpu = new GameboyCPU(new GameboyMemory);
                      //znhc ____
        cpu.reg!"f" = 0b0010_0000;
        assert(cpu.flag!'h' == 1);
        cpu.flag!'c' = 1;
        assert(cpu.flag!'c' == 1);
        cpu.flag!'z' = 1;
        cpu.flag!'n' = 1;
        assert(cpu.reg!"f" == 0b1111_0000);
    }

    void boot() {
        reg!"af" = 0x01B0;
        reg!"bc" = 0x0013;
        reg!"de" = 0x00D8;
        reg!"hl" = 0x014D;
        reg!"sp" = 0xFFFE;
        reg!"pc" = 0x100;
        mem[0xFF05] = 0x00;
        mem[0xFF06] = 0x00;
        mem[0xFF07] = 0x00;
        mem[0xFF10] = 0x80;
        mem[0xFF11] = 0xBF;
        mem[0xFF12] = 0xF3;
        mem[0xFF14] = 0xBF;
        mem[0xFF16] = 0x3F;
        mem[0xFF17] = 0x00;
        mem[0xFF19] = 0xBF;
        mem[0xFF1A] = 0x7F;
        mem[0xFF1B] = 0xFF;
        mem[0xFF1C] = 0x9F;
        mem[0xFF1E] = 0xBF;
        mem[0xFF20] = 0xFF;
        mem[0xFF21] = 0x00;
        mem[0xFF22] = 0x00;
        mem[0xFF23] = 0xBF;
        mem[0xFF24] = 0x77;
        mem[0xFF25] = 0xF3;
        mem[0xFF26] = 0xF1;
        mem[0xFF40] = 0x91;
        mem[0xFF42] = 0x00;
        mem[0xFF43] = 0x00;
        mem[0xFF45] = 0x00;
        mem[0xFF47] = 0xFC;
        mem[0xFF48] = 0xFF;
        mem[0xFF49] = 0xFF;
        mem[0xFF4A] = 0x00;
        mem[0xFF4B] = 0x00;
        mem[0xFFFF] = 0x00;
    }

    unittest {
        auto mem = new GameboyMemory;
        auto cpu = new GameboyCPU(mem);
        cpu.boot();
        assert(cpu.reg!"abcdefhl" == 0x01001300D8B0014D);
        assert(cpu.reg!"sp" == 0xFFFE);
        assert(cpu.reg!"pc" == 0x100);
    }

private:

    ubyte cary8(int res) {
        return (res & 0xff00) != 0 ? 1 : 0;
    }

    ubyte cary16(int res) {
        return (res & 0xffff0000) != 0 ? 1 : 0;
    }

    ubyte halfcary(int a, int b) {
        return (a & 0x0f) + (b & 0x0f) > 0x0f ? 1 : 0;
    }

    ubyte halfcary2(int a, int b) {
        return (a & 0x0f) > (b & 0x0f) ? 1 : 0;
    }

    ubyte zero(int res) {
        return res == 0 ? 1 : 0;
    }

protected:

    void nop() { }

    void halt() { }

    void stop(ubyte value) {
        if (value != 0)
            return;
        //stop the cpu
    }

    void ldhl(ubyte value) {
        int res = sp + cast(byte)value;
        flag!'c' = cary16(res);
        flag!'h' = halfcary(sp, value);
        flag!'z' = 0;
        flag!'n' = 0;
        reg!"hl" = cast(ushort)(res & 0xffff);
    }

    void ldsp(ushort value) {
        mem[value] = cast(ubyte)(sp & 0xFF);
        mem[value + 1] = cast(ubyte)(sp >> 8);
    }

    void push(ushort value) {
        sp -= 2;
        mem[sp] = cast(ubyte)(value & 0xFF);
        mem[sp + 1] = cast(ubyte)(value >> 8);
    }

    ushort pop() {
        auto value = cast(ushort)((mem[sp + 1] << 8) | mem[sp]);
        sp += 2;
        return value;
    }

    void add(ubyte value) {
        uint res = reg!"a" + value;
        flag!'c' = cary8(res);
        reg!"a" = cast(T)(res & 0xff);
        flag!'z' = zero(reg!"a");
        flag!'h' = halfcary(reg!"a", value);
        flag!'n' = 0;
    }

    void adc(ubyte value) {
        value += flag!'c';
        int res = reg!"a" + value;
        flag!'c' = cary8(res);
        flag!'z' = value == reg!"a" ? 1 : 0;
        flag!'h' = halfcary(reg!"a", value);
        flag!'n' = 0;
        reg!"a" = cast(T)(res & 0xff);
    }

    void sub(ubyte value) {
        flag!'n' = 1;
        flag!'c' = value > reg!"a" ? 1 : 0;
        flag!'h' = halfcary2(value, reg!"a");
        reg!"a" = cast(T)(reg!"a" - value);
        flag!'z' = zero(reg!"a");
    }

    void sbc(ubyte value) {
        value += flag!'c';
        flag!'n' = 1;
        flag!'c' = value > reg!"a" ? 1 : 0;
        flag!'z' = value == reg!"a" ? 1 : 0;
        flag!'h' = halfcary2(value, reg!"a");
        reg!"a" = cast(T)(reg!"a" - value);
    }

    void and(ubyte value) {
        reg!"a" = reg!"a" & value;
        flag!'z' = zero(reg!"a");
        flag!'n' = 0;
        flag!'h' = 1;
        flag!'c' = 0;
    }

    void or(ubyte value) {
        reg!"a" = reg!"a" | value;
        flag!'z' = zero(reg!"a");
        flag!'n' = 0;
        flag!'h' = 0;
        flag!'c' = 0;
    }

    void xor(ubyte value) {
        reg!"a" = reg!"a" ^ value;
        flag!'z' = zero(reg!"a");
        flag!'n' = 0;
        flag!'h' = 0;
        flag!'c' = 0;
    }

    void cp(ubyte value) {
        flag!'z' = reg!"a" == value ? 1 : 0;
        flag!'c' = value > reg!"a" ? 1 : 0;
        flag!'h' = halfcary2(value, reg!"a");
        flag!'n' = 1;
    }

    void dec(string r)() {
        static if (r.length == 1) {
            reg!r = dec(reg!r);
        } else static if (r.length == 2) {
            auto v = reg!r;
            reg!r = --v;
        }
    }

    ubyte dec(ubyte value) {
        flag!'h' = (value & 0x0f) != 0 ? 1 : 0;
        value--;
        flag!'z' = zero(value);
        flag!'n' = 1;
        return value;
    }

    void inc(string r)() {
        static if (r.length == 1) {
            reg!r = inc(reg!r);
        } else static if (r.length == 2) {
            auto v = reg!r;
            reg!r = ++v;
        }
    }

    ubyte inc(ubyte value) {
        flag!'h' = (value & 0x0f) == 0x0f ? 1 : 0;
        value++;
        flag!'z' = zero(value);
        flag!'n' = 0;
        return value;
    }

    void addhl(ushort value) {
        uint res = reg!"hl" + value;
        flag!'c' = cary16(res);
        reg!"hl" = cast(ushort)(res & 0xffff);
        flag!'h' = halfcary(reg!"hl", value);
        flag!'n' = 0;
    }

    void addsp(ubyte value) {
        int res = reg!"sp" + cast(byte)value;
        flag!'c' = cary16(res);
        reg!"sp" = cast(ushort)(res & 0xffff);
        flag!'h' = halfcary(reg!"sp", cast(byte)value);
        flag!'z' = 0;
        flag!'n' = 0;
    }

    void daa() {
        //TODO: implement
    }

    void cpl() {
        reg!"a" = ~reg!"a";
        flag!'n' = 1;
        flag!'h' = 1;
    }

    void ccf() {
        flag!'c' = flag!'c' ? 0 : 1;
        flag!'n' = 0;
        flag!'h' = 0;
    }

    void scf() {
        flag!'c' = 1;
        flag!'n' = 0;
        flag!'h' = 0;
    }

    void rlca() {
        ubyte cary = (reg!"a" & 0x80) >> 7;
        flag!'c' = cary;
        reg!"a" = cast(T)(reg!"a" << 1);
        reg!"a" = cast(T)(reg!"a" + cary);
        flag!'n' = 0;
        flag!'z' = 0;
        flag!'h' = 0;
    }

    void rla() {
        ubyte cary = flag!'c';
        flag!'c' = (reg!"a" & 0x80) != 0 ? 1 : 0;
        reg!"a" = cast(T)(reg!"a" << 1);
        reg!"a" = cast(T)(reg!"a" + cary);
        flag!'n' = 0;
        flag!'z' = 0;
        flag!'h' = 0;
    }

    void rrca() {
        ubyte cary = reg!"a" & 0x01;
        flag!'c' = cary;
        reg!"a" = cast(T)(reg!"a" >> 1);
        if (cary) {
            reg!"a" = cast(T)(reg!"a" | 0x80);
        }
        flag!'n' = 0;
        flag!'z' = 0;
        flag!'h' = 0;
    }

    void rra() {
        int cary = flag!'c' << 7;
        flag!'c' = (reg!"a" & 0x01);
        reg!"a" = cast(T)(reg!"a" >> 1);
        reg!"a" = cast(T)(reg!"a" + cary);
        flag!'n' = 0;
        flag!'z' = 0;
        flag!'h' = 0;
    }

    void jp(ushort value) {
        pc = value;
    }

    void jr(ubyte value) {
        pc += cast(byte)value;
    }

    void call(ushort value) {
        push(pc);
        pc = value;
    }

    void rst(ushort value)() {
        push(pc);
        pc = value;
    }

    void ret() {
        pc = pop();
    }

    void interupts(bool enable) {
        //TODO: enable or disable interupts
    }

    void cb(ubyte opcode) {
        //read next Instruction
        //execute on new set
        cbSet[opcode].nullary();
    }

private:
    Instruction[ubyte] cbSet;
}
