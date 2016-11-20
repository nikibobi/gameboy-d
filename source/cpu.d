module gameboy.cpu;

import std.stdio;
import std.conv;
import std.string : indexOf;
import std.format : format;
import gameboy.memory;
import gameboy.instruction;
import gameboy.utils : bitness, isPowerOf2, bit;

class Processor
{
    alias T = ubyte;
    enum bits = 8;
    enum flags = "chnz";

    this(Memory mem) {
        this.mem = mem;
        mem.mount(interruptFlags, 0xFF0F);
        mem.mount(interruptEnable, 0xFFFF);
        opSet = [
            0x00: Instruction("NOP", &nop),
            0x76: Instruction("HALT", &halt),
            0x10: Instruction("STOP %X", &stop),

            0x01: Instruction("LD BC,$%04X", (ushort n) { reg!"bc" = n; }),
            0x11: Instruction("LD DE,$%04X", (ushort n) { reg!"de" = n; }),
            0x21: Instruction("LD HL,$%04X", (ushort n) { reg!"hl" = n; }),
            0x31: Instruction("LD SP,$%04X", (ushort n) { reg!"sp" = n; }),

            0x06: Instruction("LD B,$%02X", (ubyte n) { reg!"b" = n; }),
            0x0E: Instruction("LD C,$%02X", (ubyte n) { reg!"c" = n; }),
            0x16: Instruction("LD D,$%02X", (ubyte n) { reg!"d" = n; }),
            0x1E: Instruction("LD E,$%02X", (ubyte n) { reg!"e" = n; }),
            0x26: Instruction("LD H,$%02X", (ubyte n) { reg!"h" = n; }),
            0x2E: Instruction("LD L,$%02X", (ubyte n) { reg!"l" = n; }),
            0x36: Instruction("LD (HL),$%02X", (ubyte n) { reg!"(hl)" = n; }),
            0x3E: Instruction("LD A,$%02X", (ubyte n) { reg!"a" = n; }),

            0x40: Instruction("LD B,B", { reg!"b" = reg!"b"; }),
            0x41: Instruction("LD B,C", { reg!"b" = reg!"c"; }),
            0x42: Instruction("LD B,D", { reg!"b" = reg!"d"; }),
            0x43: Instruction("LD B,E", { reg!"b" = reg!"e"; }),
            0x44: Instruction("LD B,H", { reg!"b" = reg!"h"; }),
            0x45: Instruction("LD B,L", { reg!"b" = reg!"l"; }),
            0x46: Instruction("LD B,(HL)", { reg!"b" = reg!"(hl)"; }),
            0x47: Instruction("LD B,A", { reg!"b" = reg!"a"; }),

            0x48: Instruction("LD C,B", { reg!"c" = reg!"b"; }),
            0x49: Instruction("LD C,C", { reg!"c" = reg!"c"; }),
            0x4A: Instruction("LD C,D", { reg!"c" = reg!"d"; }),
            0x4B: Instruction("LD C,E", { reg!"c" = reg!"e"; }),
            0x4C: Instruction("LD C,H", { reg!"c" = reg!"h"; }),
            0x4D: Instruction("LD C,L", { reg!"c" = reg!"l"; }),
            0x4E: Instruction("LD C,(HL)", { reg!"c" = reg!"(hl)"; }),
            0x4F: Instruction("LD C,A", { reg!"c" = reg!"a"; }),

            0x50: Instruction("LD D,B", { reg!"d" = reg!"b"; }),
            0x51: Instruction("LD D,C", { reg!"d" = reg!"c"; }),
            0x52: Instruction("LD D,D", { reg!"d" = reg!"d"; }),
            0x53: Instruction("LD D,E", { reg!"d" = reg!"e"; }),
            0x54: Instruction("LD D,H", { reg!"d" = reg!"h"; }),
            0x55: Instruction("LD D,L", { reg!"d" = reg!"l"; }),
            0x56: Instruction("LD D,(HL)", { reg!"d" = reg!"(hl)"; }),
            0x57: Instruction("LD D,A", { reg!"d" = reg!"a"; }),

            0x58: Instruction("LD E,B", { reg!"e" = reg!"b"; }),
            0x59: Instruction("LD E,C", { reg!"e" = reg!"c"; }),
            0x5A: Instruction("LD E,D", { reg!"e" = reg!"d"; }),
            0x5B: Instruction("LD E,E", { reg!"e" = reg!"e"; }),
            0x5C: Instruction("LD E,H", { reg!"e" = reg!"h"; }),
            0x5D: Instruction("LD E,L", { reg!"e" = reg!"l"; }),
            0x5E: Instruction("LD E,(HL)", { reg!"e" = reg!"(hl)"; }),
            0x5F: Instruction("LD E,A", { reg!"e" = reg!"a"; }),

            0x60: Instruction("LD H,B", { reg!"h" = reg!"b"; }),
            0x61: Instruction("LD H,C", { reg!"h" = reg!"c"; }),
            0x62: Instruction("LD H,D", { reg!"h" = reg!"d"; }),
            0x63: Instruction("LD H,E", { reg!"h" = reg!"e"; }),
            0x64: Instruction("LD H,H", { reg!"h" = reg!"h"; }),
            0x65: Instruction("LD H,L", { reg!"h" = reg!"l"; }),
            0x66: Instruction("LD H,(HL)", { reg!"h" = reg!"(hl)"; }),
            0x67: Instruction("LD H,A", { reg!"h" = reg!"a"; }),
            
            0x68: Instruction("LD L,B", { reg!"l" = reg!"b"; }),
            0x69: Instruction("LD L,C", { reg!"l" = reg!"c"; }),
            0x6A: Instruction("LD L,D", { reg!"l" = reg!"d"; }),
            0x6B: Instruction("LD L,E", { reg!"l" = reg!"e"; }),
            0x6C: Instruction("LD L,H", { reg!"l" = reg!"h"; }),
            0x6D: Instruction("LD L,L", { reg!"l" = reg!"l"; }),
            0x6E: Instruction("LD L,(HL)", { reg!"l" = reg!"(hl)"; }),
            0x6F: Instruction("LD L,A", { reg!"l" = reg!"a"; }),

            0x70: Instruction("LD (HL),B", { reg!"(hl)" = reg!"b"; }),
            0x71: Instruction("LD (HL),C", { reg!"(hl)" = reg!"c"; }),
            0x72: Instruction("LD (HL),D", { reg!"(hl)" = reg!"d"; }),
            0x73: Instruction("LD (HL),E", { reg!"(hl)" = reg!"e"; }),
            0x74: Instruction("LD (HL),H", { reg!"(hl)" = reg!"h"; }),
            0x75: Instruction("LD (HL),L", { reg!"(hl)" = reg!"l"; }),
            0x77: Instruction("LD (HL),A", { reg!"(hl)" = reg!"a"; }),

            0x78: Instruction("LD A,B", { reg!"a" = reg!"b"; }),
            0x79: Instruction("LD A,C", { reg!"a" = reg!"c"; }),
            0x7A: Instruction("LD A,D", { reg!"a" = reg!"d"; }),
            0x7B: Instruction("LD A,E", { reg!"a" = reg!"e"; }),
            0x7C: Instruction("LD A,H", { reg!"a" = reg!"h"; }),
            0x7D: Instruction("LD A,L", { reg!"a" = reg!"l"; }),
            0x7E: Instruction("LD A,(HL)", { reg!"a" = reg!"(hl)"; }),
            0x7F: Instruction("LD A,A", { reg!"a" = reg!"a"; }),

            0x0A: Instruction("LD A,(BC)", { reg!"a" = mem[reg!"bc"]; }),
            0x1A: Instruction("LD A,(DE)", { reg!"a" = mem[reg!"de"]; }),
            0xFA: Instruction("LD A,($%04X)", (ushort n) { reg!"a" = mem[n]; }),
            0x02: Instruction("LD (BC),A", { mem[reg!"bc"] = reg!"a"; }),
            0x12: Instruction("LD (DE),A", { mem[reg!"de"] = reg!"a"; }),
            0xEA: Instruction("LD ($%04X),A", (ushort n) { mem[n] = reg!"a"; }),

            0xF2: Instruction("LD A,(C)", { reg!"a" = mem[0xFF00 + reg!"c"]; }),
            0xE2: Instruction("LD (C),A", { mem[0xFF00 + reg!"c"] = reg!"a"; }),

            0x22: Instruction("LD (HL+),A", { reg!"(hl)" = reg!"a"; inc!"hl"; }),
            0x32: Instruction("LD (HL-),A", { reg!"(hl)" = reg!"a"; dec!"hl"; }),
            0x2A: Instruction("LD A,(HL+)", { reg!"a" = reg!"(hl)"; inc!"hl"; }),
            0x3A: Instruction("LD A,(HL-)", { reg!"a" = reg!"(hl)"; dec!"hl"; }),

            0xE0: Instruction("LDH ($%02X),A", (ubyte n) { mem[0xFF00 + n] = reg!"a"; }),
            0xF0: Instruction("LDH A,($%02X)", (ubyte n) { reg!"a" = mem[0xFF00 + n]; }),

            0xF9: Instruction("LD SP,HL", { reg!"sp" = reg!"hl"; }),
            0xF8: Instruction("LD HL,SP+$%02X", &ldhl),
            0x08: Instruction("LD ($%04X),SP", &ldsp),

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
            0x86: Instruction("ADD A,(HL)", { add(reg!"(hl)"); }),
            0x87: Instruction("ADD A,A", { add(reg!"a"); }),
            0xC6: Instruction("ADD A,$%02X", &add),

            0x88: Instruction("ADC A,B", { adc(reg!"b"); }),
            0x89: Instruction("ADC A,C", { adc(reg!"c"); }),
            0x8A: Instruction("ADC A,D", { adc(reg!"d"); }),
            0x8B: Instruction("ADC A,E", { adc(reg!"e"); }),
            0x8C: Instruction("ADC A,H", { adc(reg!"h"); }),
            0x8D: Instruction("ADC A,L", { adc(reg!"l"); }),
            0x8E: Instruction("ADC A,(HL)", { adc(reg!"(hl)"); }),
            0x8F: Instruction("ADC A,A", { adc(reg!"a"); }),
            0xCE: Instruction("ADC A,$%02X", &adc),

            0x90: Instruction("SUB B", { sub(reg!"b"); }),
            0x91: Instruction("SUB C", { sub(reg!"c"); }),
            0x92: Instruction("SUB D", { sub(reg!"d"); }),
            0x93: Instruction("SUB E", { sub(reg!"e"); }),
            0x94: Instruction("SUB H", { sub(reg!"h"); }),
            0x95: Instruction("SUB L", { sub(reg!"l"); }),
            0x96: Instruction("SUB (HL)", { sub(reg!"(hl)"); }),
            0x97: Instruction("SUB A", { sub(reg!"a"); }),
            0xD6: Instruction("SUB $%02X", &sub),

            0x98: Instruction("SBC A,B", { sbc(reg!"b"); }),
            0x99: Instruction("SBC A,C", { sbc(reg!"c"); }),
            0x9A: Instruction("SBC A,D", { sbc(reg!"d"); }),
            0x9B: Instruction("SBC A,E", { sbc(reg!"e"); }),
            0x9C: Instruction("SBC A,H", { sbc(reg!"h"); }),
            0x9D: Instruction("SBC A,L", { sbc(reg!"l"); }),
            0x9E: Instruction("SBC A,(HL)", { sbc(reg!"(hl)"); }),
            0x9F: Instruction("SBC A,A", { sbc(reg!"a"); }),
            0xDE: Instruction("SBC A,$%02X", &sbc),

            0xA0: Instruction("AND B", { and(reg!"b"); }),
            0xA1: Instruction("AND C", { and(reg!"c"); }),
            0xA2: Instruction("AND D", { and(reg!"d"); }),
            0xA3: Instruction("AND E", { and(reg!"e"); }),
            0xA4: Instruction("AND H", { and(reg!"h"); }),
            0xA5: Instruction("AND L", { and(reg!"l"); }),
            0xA6: Instruction("AND (HL)", { and(reg!"(hl)"); }),
            0xA7: Instruction("AND A", { and(reg!"a"); }),
            0xE6: Instruction("AND $%02X", &and),

            0xB0: Instruction("OR B", { or(reg!"b"); }),
            0xB1: Instruction("OR C", { or(reg!"c"); }),
            0xB2: Instruction("OR D", { or(reg!"d"); }),
            0xB3: Instruction("OR E", { or(reg!"e"); }),
            0xB4: Instruction("OR H", { or(reg!"h"); }),
            0xB5: Instruction("OR L", { or(reg!"l"); }),
            0xB6: Instruction("OR (HL)", { or(reg!"(hl)"); }),
            0xB7: Instruction("OR A", { or(reg!"a"); }),
            0xF6: Instruction("OR $%02X", &or),

            0xA8: Instruction("XOR B", { xor(reg!"b"); }),
            0xA9: Instruction("XOR C", { xor(reg!"c"); }),
            0xAA: Instruction("XOR D", { xor(reg!"d"); }),
            0xAB: Instruction("XOR E", { xor(reg!"e"); }),
            0xAC: Instruction("XOR H", { xor(reg!"h"); }),
            0xAD: Instruction("XOR L", { xor(reg!"l"); }),
            0xAE: Instruction("XOR (HL)", { xor(reg!"(hl)"); }),
            0xAF: Instruction("XOR A", { xor(reg!"a"); }),
            0xEE: Instruction("XOR $%02X", &xor),

            0xB8: Instruction("CP B", { cp(reg!"b"); }),
            0xB9: Instruction("CP C", { cp(reg!"c"); }),
            0xBA: Instruction("CP D", { cp(reg!"d"); }),
            0xBB: Instruction("CP E", { cp(reg!"e"); }),
            0xBC: Instruction("CP H", { cp(reg!"h"); }),
            0xBD: Instruction("CP L", { cp(reg!"l"); }),
            0xBE: Instruction("CP (HL)", { cp(reg!"(hl)"); }),
            0xBF: Instruction("CP A", { cp(reg!"a"); }),
            0xFE: Instruction("CP $%02X", &cp),

            0x04: Instruction("INC B", &inc!"b"),
            0x0C: Instruction("INC C", &inc!"c"),
            0x14: Instruction("INC D", &inc!"d"),
            0x1C: Instruction("INC E", &inc!"e"),
            0x24: Instruction("INC H", &inc!"h"),
            0x2C: Instruction("INC L", &inc!"l"),
            0x34: Instruction("INC (HL)", { reg!"(hl)" = inc(reg!"(hl)"); }),
            0x3C: Instruction("INC A", &inc!"a"),

            0x05: Instruction("DEC B", &dec!"b"),
            0x0D: Instruction("DEC C", &dec!"c"),
            0x15: Instruction("DEC D", &dec!"d"),
            0x1D: Instruction("DEC E", &dec!"e"),
            0x25: Instruction("DEC H", &dec!"h"),
            0x2D: Instruction("DEC L", &dec!"l"),
            0x35: Instruction("DEC (HL)", { reg!"(hl)" = dec(reg!"(hl)"); }),
            0x3D: Instruction("DEC A", &dec!"a"),

            0xC1: Instruction("POP BC", { reg!"bc" = pop(); }),
            0xD1: Instruction("POP DE", { reg!"de" = pop(); }),
            0xE1: Instruction("POP HL", { reg!"hl" = pop(); }),
            0xF1: Instruction("POP AF", { reg!"af" = pop(); }),

            0x09: Instruction("ADD HL,BC", { addhl(reg!"bc"); }),
            0x19: Instruction("ADD HL,DE", { addhl(reg!"de"); }),
            0x29: Instruction("ADD HL,HL", { addhl(reg!"hl"); }),
            0x39: Instruction("ADD HL,SP", { addhl(reg!"sp"); }),

            0xE8: Instruction("ADD SP,$%02X", &addsp),

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

            0xF3: Instruction("DI", { interrupts = false; }),
            0xFB: Instruction("EI", { interrupts = true; }),

            0x07: Instruction("RLCA", &rlca),
            0x17: Instruction("RLA", &rla),
            0x0F: Instruction("RRCA", &rrca),
            0x1F: Instruction("RRA", &rra),

            0xC3: Instruction("JP $%04X", &jp),
            0xC2: Instruction("JP NZ,$%04X", &jpif!('z', 0)),
            0xCA: Instruction("JP Z,$%04X", &jpif!('z', 1)),
            0xD2: Instruction("JP NC,$%04X", &jpif!('c', 0)),
            0xDA: Instruction("JP C,$%04X", &jpif!('c', 1)),
            0xE9: Instruction("JP (HL)", { jp(reg!"hl"); }),

            0x18: Instruction("JR $%02X", &jr),
            0x20: Instruction("JR NZ,$%02X", &jrif!('z', 0)),
            0x28: Instruction("JR Z,$%02X", &jrif!('z', 1)),
            0x30: Instruction("JR NC,$%02X", &jrif!('c', 0)),
            0x38: Instruction("JR C,$%02X", &jrif!('c', 1)),

            0xCD: Instruction("CALL $%04X", &call),
            0xC4: Instruction("CALL NZ,$%04X", &callif!('z', 0)),
            0xCC: Instruction("CALL Z,$%04X", &callif!('z', 1)),
            0xD4: Instruction("CALL NC,$%04X", &callif!('c', 0)),
            0xDC: Instruction("CALL C,$%04X", &callif!('c', 1)),

            0xC7: Instruction("RST 00H", &rst!0x00),
            0xCF: Instruction("RST 08H", &rst!0x08),
            0xD7: Instruction("RST 10H", &rst!0x10),
            0xDF: Instruction("RST 18H", &rst!0x18),
            0xE7: Instruction("RST 20H", &rst!0x20),
            0xEF: Instruction("RST 28H", &rst!0x28),
            0xF7: Instruction("RST 30H", &rst!0x30),
            0xFF: Instruction("RST 38H", &rst!0x38),

            0xC9: Instruction("RET", &ret),
            0xC0: Instruction("RET NZ", &retif!('z', 0)),
            0xC8: Instruction("RET Z", &retif!('z', 1)),
            0xD0: Instruction("RET NC", &retif!('c', 0)),
            0xD8: Instruction("RET C", &retif!('c', 1)),
            0xD9: Instruction("RETI", { ret(); interrupts = true; }),

            0xCB: Instruction("PREFIX CB %02X", &cb)
        ];
        opSet.rehash();
        cbSet = [
            0x00: Instruction("RLC B", { reg!"b" = rlc(reg!"b"); }),
            0x01: Instruction("RLC C", { reg!"c" = rlc(reg!"c"); }),
            0x02: Instruction("RLC D", { reg!"d" = rlc(reg!"d"); }),
            0x03: Instruction("RLC E", { reg!"e" = rlc(reg!"e"); }),
            0x04: Instruction("RLC H", { reg!"h" = rlc(reg!"h"); }),
            0x05: Instruction("RLC L", { reg!"l" = rlc(reg!"l"); }),
            0x06: Instruction("RLC (HL)", { reg!"(hl)" = rlc(reg!"(hl)"); }),
            0x07: Instruction("RLC A", { reg!"a" = rlc(reg!"a"); }),

            0x08: Instruction("RRC B", { reg!"b" = rrc(reg!"b"); }),
            0x09: Instruction("RRC C", { reg!"c" = rrc(reg!"c"); }),
            0x0A: Instruction("RRC D", { reg!"d" = rrc(reg!"d"); }),
            0x0B: Instruction("RRC E", { reg!"e" = rrc(reg!"e"); }),
            0x0C: Instruction("RRC H", { reg!"h" = rrc(reg!"h"); }),
            0x0D: Instruction("RRC L", { reg!"l" = rrc(reg!"l"); }),
            0x0E: Instruction("RRC (HL)", { reg!"(hl)" = rrc(reg!"(hl)"); }),
            0x0F: Instruction("RRC A", { reg!"a" = rrc(reg!"a"); }),

            0x10: Instruction("RL B", { reg!"b" = rl(reg!"b"); }),
            0x11: Instruction("RL C", { reg!"c" = rl(reg!"c"); }),
            0x12: Instruction("RL D", { reg!"d" = rl(reg!"d"); }),
            0x13: Instruction("RL E", { reg!"e" = rl(reg!"e"); }),
            0x14: Instruction("RL H", { reg!"h" = rl(reg!"h"); }),
            0x15: Instruction("RL L", { reg!"l" = rl(reg!"l"); }),
            0x16: Instruction("RL (HL)", { reg!"(hl)" = rl(reg!"(hl)"); }),
            0x17: Instruction("RL A", { reg!"a" = rl(reg!"a"); }),

            0x18: Instruction("RR B", { reg!"b" = rr(reg!"b"); }),
            0x19: Instruction("RR C", { reg!"c" = rr(reg!"c"); }),
            0x1A: Instruction("RR D", { reg!"d" = rr(reg!"d"); }),
            0x1B: Instruction("RR E", { reg!"e" = rr(reg!"e"); }),
            0x1C: Instruction("RR H", { reg!"h" = rr(reg!"h"); }),
            0x1D: Instruction("RR L", { reg!"l" = rr(reg!"l"); }),
            0x1E: Instruction("RR (HL)", { reg!"(hl)" = rr(reg!"(hl)"); }),
            0x1F: Instruction("RR A", { reg!"a" = rr(reg!"a"); }),

            0x20: Instruction("SLA B", { reg!"b" = sla(reg!"b"); }),
            0x21: Instruction("SLA C", { reg!"c" = sla(reg!"c"); }),
            0x22: Instruction("SLA D", { reg!"d" = sla(reg!"d"); }),
            0x23: Instruction("SLA E", { reg!"e" = sla(reg!"e"); }),
            0x24: Instruction("SLA H", { reg!"h" = sla(reg!"h"); }),
            0x25: Instruction("SLA L", { reg!"l" = sla(reg!"l"); }),
            0x26: Instruction("SLA (HL)", { reg!"(hl)" = sla(reg!"(hl)"); }),
            0x27: Instruction("SLA A", { reg!"a" = sla(reg!"a"); }),

            0x28: Instruction("SRA B", { reg!"b" = sra(reg!"b"); }),
            0x29: Instruction("SRA C", { reg!"c" = sra(reg!"c"); }),
            0x2A: Instruction("SRA D", { reg!"d" = sra(reg!"d"); }),
            0x2B: Instruction("SRA E", { reg!"e" = sra(reg!"e"); }),
            0x2C: Instruction("SRA H", { reg!"h" = sra(reg!"h"); }),
            0x2D: Instruction("SRA L", { reg!"l" = sra(reg!"l"); }),
            0x2E: Instruction("SRA (HL)", { reg!"(hl)" = sra(reg!"(hl)"); }),
            0x2F: Instruction("SRA A", { reg!"a" = sra(reg!"a"); }),

            0x30: Instruction("SWAP B", { reg!"b" = swap(reg!"b"); }),
            0x31: Instruction("SWAP C", { reg!"c" = swap(reg!"c"); }),
            0x32: Instruction("SWAP D", { reg!"d" = swap(reg!"d"); }),
            0x33: Instruction("SWAP E", { reg!"e" = swap(reg!"e"); }),
            0x34: Instruction("SWAP H", { reg!"h" = swap(reg!"h"); }),
            0x35: Instruction("SWAP L", { reg!"l" = swap(reg!"l"); }),
            0x36: Instruction("SWAP (HL)", { reg!"(hl)" = swap(reg!"(hl)"); }),
            0x37: Instruction("SWAP A", { reg!"a" = swap(reg!"a"); }),

            0x38: Instruction("SRL B", { reg!"b" = srl(reg!"b"); }),
            0x39: Instruction("SRL C", { reg!"c" = srl(reg!"c"); }),
            0x3A: Instruction("SRL D", { reg!"d" = srl(reg!"d"); }),
            0x3B: Instruction("SRL E", { reg!"e" = srl(reg!"e"); }),
            0x3C: Instruction("SRL H", { reg!"h" = srl(reg!"h"); }),
            0x3D: Instruction("SRL L", { reg!"l" = srl(reg!"l"); }),
            0x3E: Instruction("SRL (HL)", { reg!"(hl)" = srl(reg!"(hl)"); }),
            0x3F: Instruction("SRL A", { reg!"a" = srl(reg!"a"); }),

            0x40: Instruction("BIT 0,B", { tbit!0(reg!"b"); }),
            0x41: Instruction("BIT 0,C", { tbit!0(reg!"c"); }),
            0x42: Instruction("BIT 0,D", { tbit!0(reg!"d"); }),
            0x43: Instruction("BIT 0,E", { tbit!0(reg!"e"); }),
            0x44: Instruction("BIT 0,H", { tbit!0(reg!"h"); }),
            0x45: Instruction("BIT 0,L", { tbit!0(reg!"l"); }),
            0x46: Instruction("BIT 0,(HL)", { tbit!0(reg!"(hl)"); }),
            0x47: Instruction("BIT 0,A", { tbit!0(reg!"a"); }),

            0x48: Instruction("BIT 1,B", { tbit!1(reg!"b"); }),
            0x49: Instruction("BIT 1,C", { tbit!1(reg!"c"); }),
            0x4A: Instruction("BIT 1,D", { tbit!1(reg!"d"); }),
            0x4B: Instruction("BIT 1,E", { tbit!1(reg!"e"); }),
            0x4C: Instruction("BIT 1,H", { tbit!1(reg!"h"); }),
            0x4D: Instruction("BIT 1,L", { tbit!1(reg!"l"); }),
            0x4E: Instruction("BIT 1,(HL)", { tbit!1(reg!"(hl)"); }),
            0x4F: Instruction("BIT 1,A", { tbit!1(reg!"a"); }),

            0x50: Instruction("BIT 2,B", { tbit!2(reg!"b"); }),
            0x51: Instruction("BIT 2,C", { tbit!2(reg!"c"); }),
            0x52: Instruction("BIT 2,D", { tbit!2(reg!"d"); }),
            0x53: Instruction("BIT 2,E", { tbit!2(reg!"e"); }),
            0x54: Instruction("BIT 2,H", { tbit!2(reg!"h"); }),
            0x55: Instruction("BIT 2,L", { tbit!2(reg!"l"); }),
            0x56: Instruction("BIT 2,(HL)", { tbit!2(reg!"(hl)"); }),
            0x57: Instruction("BIT 2,A", { tbit!2(reg!"a"); }),

            0x58: Instruction("BIT 3,B", { tbit!3(reg!"b"); }),
            0x59: Instruction("BIT 3,C", { tbit!3(reg!"c"); }),
            0x5A: Instruction("BIT 3,D", { tbit!3(reg!"d"); }),
            0x5B: Instruction("BIT 3,E", { tbit!3(reg!"e"); }),
            0x5C: Instruction("BIT 3,H", { tbit!3(reg!"h"); }),
            0x5D: Instruction("BIT 3,L", { tbit!3(reg!"l"); }),
            0x5E: Instruction("BIT 3,(HL)", { tbit!3(reg!"(hl)"); }),
            0x5F: Instruction("BIT 3,A", { tbit!3(reg!"a"); }),

            0x60: Instruction("BIT 4,B", { tbit!4(reg!"b"); }),
            0x61: Instruction("BIT 4,C", { tbit!4(reg!"c"); }),
            0x62: Instruction("BIT 4,D", { tbit!4(reg!"d"); }),
            0x63: Instruction("BIT 4,E", { tbit!4(reg!"e"); }),
            0x64: Instruction("BIT 4,H", { tbit!4(reg!"h"); }),
            0x65: Instruction("BIT 4,L", { tbit!4(reg!"l"); }),
            0x66: Instruction("BIT 4,(HL)", { tbit!4(reg!"(hl)"); }),
            0x67: Instruction("BIT 4,A", { tbit!4(reg!"a"); }),

            0x68: Instruction("BIT 5,B", { tbit!5(reg!"b"); }),
            0x69: Instruction("BIT 5,C", { tbit!5(reg!"c"); }),
            0x6A: Instruction("BIT 5,D", { tbit!5(reg!"d"); }),
            0x6B: Instruction("BIT 5,E", { tbit!5(reg!"e"); }),
            0x6C: Instruction("BIT 5,H", { tbit!5(reg!"h"); }),
            0x6D: Instruction("BIT 5,L", { tbit!5(reg!"l"); }),
            0x6E: Instruction("BIT 5,(HL)", { tbit!5(reg!"(hl)"); }),
            0x6F: Instruction("BIT 5,A", { tbit!5(reg!"a"); }),

            0x70: Instruction("BIT 6,B", { tbit!6(reg!"b"); }),
            0x71: Instruction("BIT 6,C", { tbit!6(reg!"c"); }),
            0x72: Instruction("BIT 6,D", { tbit!6(reg!"d"); }),
            0x73: Instruction("BIT 6,E", { tbit!6(reg!"e"); }),
            0x74: Instruction("BIT 6,H", { tbit!6(reg!"h"); }),
            0x75: Instruction("BIT 6,L", { tbit!6(reg!"l"); }),
            0x76: Instruction("BIT 6,(HL)", { tbit!6(reg!"(hl)"); }),
            0x77: Instruction("BIT 6,A", { tbit!6(reg!"a"); }),

            0x78: Instruction("BIT 7,B", { tbit!7(reg!"b"); }),
            0x79: Instruction("BIT 7,C", { tbit!7(reg!"c"); }),
            0x7A: Instruction("BIT 7,D", { tbit!7(reg!"d"); }),
            0x7B: Instruction("BIT 7,E", { tbit!7(reg!"e"); }),
            0x7C: Instruction("BIT 7,H", { tbit!7(reg!"h"); }),
            0x7D: Instruction("BIT 7,L", { tbit!7(reg!"l"); }),
            0x7E: Instruction("BIT 7,(HL)", { tbit!7(reg!"(hl)"); }),
            0x7F: Instruction("BIT 7,A", { tbit!7(reg!"a"); }),

            0x80: Instruction("RES 0,B", { reg!"b" = res!0(reg!"b"); }),
            0x81: Instruction("RES 0,C", { reg!"c" = res!0(reg!"c"); }),
            0x82: Instruction("RES 0,D", { reg!"d" = res!0(reg!"d"); }),
            0x83: Instruction("RES 0,E", { reg!"e" = res!0(reg!"e"); }),
            0x84: Instruction("RES 0,H", { reg!"h" = res!0(reg!"h"); }),
            0x85: Instruction("RES 0,L", { reg!"l" = res!0(reg!"l"); }),
            0x86: Instruction("RES 0,(HL)", { reg!"(hl)" = res!0(reg!"(hl)"); }),
            0x87: Instruction("RES 0,A", { reg!"a" = res!0(reg!"a"); }),

            0x88: Instruction("RES 1,B", { reg!"b" = res!1(reg!"b"); }),
            0x89: Instruction("RES 1,C", { reg!"c" = res!1(reg!"c"); }),
            0x8A: Instruction("RES 1,D", { reg!"d" = res!1(reg!"d"); }),
            0x8B: Instruction("RES 1,E", { reg!"e" = res!1(reg!"e"); }),
            0x8C: Instruction("RES 1,H", { reg!"h" = res!1(reg!"h"); }),
            0x8D: Instruction("RES 1,L", { reg!"l" = res!1(reg!"l"); }),
            0x8E: Instruction("RES 1,(HL)", { reg!"(hl)" = res!1(reg!"(hl)"); }),
            0x8F: Instruction("RES 1,A", { reg!"a" = res!1(reg!"a"); }),

            0x90: Instruction("RES 2,B", { reg!"b" = res!2(reg!"b"); }),
            0x91: Instruction("RES 2,C", { reg!"c" = res!2(reg!"c"); }),
            0x92: Instruction("RES 2,D", { reg!"d" = res!2(reg!"d"); }),
            0x93: Instruction("RES 2,E", { reg!"e" = res!2(reg!"e"); }),
            0x94: Instruction("RES 2,H", { reg!"h" = res!2(reg!"h"); }),
            0x95: Instruction("RES 2,L", { reg!"l" = res!2(reg!"l"); }),
            0x96: Instruction("RES 2,(HL)", { reg!"(hl)" = res!2(reg!"(hl)"); }),
            0x97: Instruction("RES 2,A", { reg!"a" = res!2(reg!"a"); }),

            0x98: Instruction("RES 3,B", { reg!"b" = res!3(reg!"b"); }),
            0x99: Instruction("RES 3,C", { reg!"c" = res!3(reg!"c"); }),
            0x9A: Instruction("RES 3,D", { reg!"d" = res!3(reg!"d"); }),
            0x9B: Instruction("RES 3,E", { reg!"e" = res!3(reg!"e"); }),
            0x9C: Instruction("RES 3,H", { reg!"h" = res!3(reg!"h"); }),
            0x9D: Instruction("RES 3,L", { reg!"l" = res!3(reg!"l"); }),
            0x9E: Instruction("RES 3,(HL)", { reg!"(hl)" = res!3(reg!"(hl)"); }),
            0x9F: Instruction("RES 3,A", { reg!"a" = res!3(reg!"a"); }),

            0xA0: Instruction("RES 4,B", { reg!"b" = res!4(reg!"b"); }),
            0xA1: Instruction("RES 4,C", { reg!"c" = res!4(reg!"c"); }),
            0xA2: Instruction("RES 4,D", { reg!"d" = res!4(reg!"d"); }),
            0xA3: Instruction("RES 4,E", { reg!"e" = res!4(reg!"e"); }),
            0xA4: Instruction("RES 4,H", { reg!"h" = res!4(reg!"h"); }),
            0xA5: Instruction("RES 4,L", { reg!"l" = res!4(reg!"l"); }),
            0xA6: Instruction("RES 4,(HL)", { reg!"(hl)" = res!4(reg!"(hl)"); }),
            0xA7: Instruction("RES 4,A", { reg!"a" = res!4(reg!"a"); }),

            0xA8: Instruction("RES 5,B", { reg!"b" = res!5(reg!"b"); }),
            0xA9: Instruction("RES 5,C", { reg!"c" = res!5(reg!"c"); }),
            0xAA: Instruction("RES 5,D", { reg!"d" = res!5(reg!"d"); }),
            0xAB: Instruction("RES 5,E", { reg!"e" = res!5(reg!"e"); }),
            0xAC: Instruction("RES 5,H", { reg!"h" = res!5(reg!"h"); }),
            0xAD: Instruction("RES 5,L", { reg!"l" = res!5(reg!"l"); }),
            0xAE: Instruction("RES 5,(HL)", { reg!"(hl)" = res!5(reg!"(hl)"); }),
            0xAF: Instruction("RES 5,A", { reg!"a" = res!5(reg!"a"); }),

            0xB0: Instruction("RES 6,B", { reg!"b" = res!6(reg!"b"); }),
            0xB1: Instruction("RES 6,C", { reg!"c" = res!6(reg!"c"); }),
            0xB2: Instruction("RES 6,D", { reg!"d" = res!6(reg!"d"); }),
            0xB3: Instruction("RES 6,E", { reg!"e" = res!6(reg!"e"); }),
            0xB4: Instruction("RES 6,H", { reg!"h" = res!6(reg!"h"); }),
            0xB5: Instruction("RES 6,L", { reg!"l" = res!6(reg!"l"); }),
            0xB6: Instruction("RES 6,(HL)", { reg!"(hl)" = res!6(reg!"(hl)"); }),
            0xB7: Instruction("RES 6,A", { reg!"a" = res!6(reg!"a"); }),

            0xB8: Instruction("RES 7,B", { reg!"b" = res!7(reg!"b"); }),
            0xB9: Instruction("RES 7,C", { reg!"c" = res!7(reg!"c"); }),
            0xBA: Instruction("RES 7,D", { reg!"d" = res!7(reg!"d"); }),
            0xBB: Instruction("RES 7,E", { reg!"e" = res!7(reg!"e"); }),
            0xBC: Instruction("RES 7,H", { reg!"h" = res!7(reg!"h"); }),
            0xBD: Instruction("RES 7,L", { reg!"l" = res!7(reg!"l"); }),
            0xBE: Instruction("RES 7,(HL)", { reg!"(hl)" = res!7(reg!"(hl)"); }),
            0xBF: Instruction("RES 7,A", { reg!"a" = res!7(reg!"a"); }),

            0xC0: Instruction("SET 0,B", { reg!"b" = set!0(reg!"b"); }),
            0xC1: Instruction("SET 0,C", { reg!"c" = set!0(reg!"c"); }),
            0xC2: Instruction("SET 0,D", { reg!"d" = set!0(reg!"d"); }),
            0xC3: Instruction("SET 0,E", { reg!"e" = set!0(reg!"e"); }),
            0xC4: Instruction("SET 0,H", { reg!"h" = set!0(reg!"h"); }),
            0xC5: Instruction("SET 0,L", { reg!"l" = set!0(reg!"l"); }),
            0xC6: Instruction("SET 0,(HL)", { reg!"(hl)" = set!0(reg!"(hl)"); }),
            0xC7: Instruction("SET 0,A", { reg!"a" = set!0(reg!"a"); }),

            0xC8: Instruction("SET 1,B", { reg!"b" = set!1(reg!"b"); }),
            0xC9: Instruction("SET 1,C", { reg!"c" = set!1(reg!"c"); }),
            0xCA: Instruction("SET 1,D", { reg!"d" = set!1(reg!"d"); }),
            0xCB: Instruction("SET 1,E", { reg!"e" = set!1(reg!"e"); }),
            0xCC: Instruction("SET 1,H", { reg!"h" = set!1(reg!"h"); }),
            0xCD: Instruction("SET 1,L", { reg!"l" = set!1(reg!"l"); }),
            0xCE: Instruction("SET 1,(HL)", { reg!"(hl)" = set!1(reg!"(hl)"); }),
            0xCF: Instruction("SET 1,A", { reg!"a" = set!1(reg!"a"); }),

            0xD0: Instruction("SET 2,B", { reg!"b" = set!2(reg!"b"); }),
            0xD1: Instruction("SET 2,C", { reg!"c" = set!2(reg!"c"); }),
            0xD2: Instruction("SET 2,D", { reg!"d" = set!2(reg!"d"); }),
            0xD3: Instruction("SET 2,E", { reg!"e" = set!2(reg!"e"); }),
            0xD4: Instruction("SET 2,H", { reg!"h" = set!2(reg!"h"); }),
            0xD5: Instruction("SET 2,L", { reg!"l" = set!2(reg!"l"); }),
            0xD6: Instruction("SET 2,(HL)", { reg!"(hl)" = set!2(reg!"(hl)"); }),
            0xD7: Instruction("SET 2,A", { reg!"a" = set!2(reg!"a"); }),

            0xD8: Instruction("SET 3,B", { reg!"b" = set!3(reg!"b"); }),
            0xD9: Instruction("SET 3,C", { reg!"c" = set!3(reg!"c"); }),
            0xDA: Instruction("SET 3,D", { reg!"d" = set!3(reg!"d"); }),
            0xDB: Instruction("SET 3,E", { reg!"e" = set!3(reg!"e"); }),
            0xDC: Instruction("SET 3,H", { reg!"h" = set!3(reg!"h"); }),
            0xDD: Instruction("SET 3,L", { reg!"l" = set!3(reg!"l"); }),
            0xDE: Instruction("SET 3,(HL)", { reg!"(hl)" = set!3(reg!"(hl)"); }),
            0xDF: Instruction("SET 3,A", { reg!"a" = set!3(reg!"a"); }),

            0xE0: Instruction("SET 4,B", { reg!"b" = set!4(reg!"b"); }),
            0xE1: Instruction("SET 4,C", { reg!"c" = set!4(reg!"c"); }),
            0xE2: Instruction("SET 4,D", { reg!"d" = set!4(reg!"d"); }),
            0xE3: Instruction("SET 4,E", { reg!"e" = set!4(reg!"e"); }),
            0xE4: Instruction("SET 4,H", { reg!"h" = set!4(reg!"h"); }),
            0xE5: Instruction("SET 4,L", { reg!"l" = set!4(reg!"l"); }),
            0xE6: Instruction("SET 4,(HL)", { reg!"(hl)" = set!4(reg!"(hl)"); }),
            0xE7: Instruction("SET 4,A", { reg!"a" = set!4(reg!"a"); }),

            0xE8: Instruction("SET 5,B", { reg!"b" = set!5(reg!"b"); }),
            0xE9: Instruction("SET 5,C", { reg!"c" = set!5(reg!"c"); }),
            0xEA: Instruction("SET 5,D", { reg!"d" = set!5(reg!"d"); }),
            0xEB: Instruction("SET 5,E", { reg!"e" = set!5(reg!"e"); }),
            0xEC: Instruction("SET 5,H", { reg!"h" = set!5(reg!"h"); }),
            0xED: Instruction("SET 5,L", { reg!"l" = set!5(reg!"l"); }),
            0xEE: Instruction("SET 5,(HL)", { reg!"(hl)" = set!5(reg!"(hl)"); }),
            0xEF: Instruction("SET 5,A", { reg!"a" = set!5(reg!"a"); }),

            0xF0: Instruction("SET 6,B", { reg!"b" = set!6(reg!"b"); }),
            0xF1: Instruction("SET 6,C", { reg!"c" = set!6(reg!"c"); }),
            0xF2: Instruction("SET 6,D", { reg!"d" = set!6(reg!"d"); }),
            0xF3: Instruction("SET 6,E", { reg!"e" = set!6(reg!"e"); }),
            0xF4: Instruction("SET 6,H", { reg!"h" = set!6(reg!"h"); }),
            0xF5: Instruction("SET 6,L", { reg!"l" = set!6(reg!"l"); }),
            0xF6: Instruction("SET 6,(HL)", { reg!"(hl)" = set!6(reg!"(hl)"); }),
            0xF7: Instruction("SET 6,A", { reg!"a" = set!6(reg!"a"); }),

            0xF8: Instruction("SET 7,B", { reg!"b" = set!7(reg!"b"); }),
            0xF9: Instruction("SET 7,C", { reg!"c" = set!7(reg!"c"); }),
            0xFA: Instruction("SET 7,D", { reg!"d" = set!7(reg!"d"); }),
            0xFB: Instruction("SET 7,E", { reg!"e" = set!7(reg!"e"); }),
            0xFC: Instruction("SET 7,H", { reg!"h" = set!7(reg!"h"); }),
            0xFD: Instruction("SET 7,L", { reg!"l" = set!7(reg!"l"); }),
            0xFE: Instruction("SET 7,(HL)", { reg!"(hl)" = set!7(reg!"(hl)"); }),
            0xFF: Instruction("SET 7,A", { reg!"a" = set!7(reg!"a"); }),
        ];
        cbSet.rehash();
    }

    static this() {
        opTicks = [
        // _0 _1 _2 _3 _4 _5 _6 _7 _8 _9 _A _B _C _D _E _F
            4,12, 8, 8, 4, 4, 8, 4,20, 8, 8, 8, 4, 4, 8, 4, // 0_
            4,12, 8, 8, 4, 4, 8, 4,12, 8, 8, 8, 4, 4, 8, 4, // 1_
            8,12, 8, 8, 4, 4, 8, 4, 8, 8, 8, 8, 4, 4, 8, 4, // 2_
            8,12, 8, 8,12,12,12, 4, 8, 8, 8, 8, 4, 4, 8, 4, // 3_
            4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4, // 4_
            4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4, // 5_
            4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4, // 6_
            8, 8, 8, 8, 8, 8, 4, 8, 4, 4, 4, 4, 4, 4, 8, 4, // 7_
            4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4, // 8_
            4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4, // 9_
            4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4, // A_
            4, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4, 4, 4, 8, 4, // B_
            8,12,12,16,12,16, 8,16, 8,16,12, 4,12,24, 8,16, // C_
            8,12,12, 0,12,16, 8,16, 8,16,12, 0,12, 0, 8,16, // D_
           12,12, 8, 0, 0,16, 8,16,16, 4,16, 0, 0, 0, 8,16, // E_
           12,12, 8, 4, 0,16, 8,16,12, 8,16, 4, 0, 0, 8,16  // F_
        ];
        cbTicks = [
        // _0 _1 _2 _3 _4 _5 _6 _7 _8 _9 _A _B _C _D _E _F
            8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8, // 0_
            8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8, // 1_
            8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8, // 2_
            8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8, // 3_
            8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8, // 4_
            8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8, // 5_
            8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8, // 6_
            8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8, // 7_
            8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8, // 8_
            8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8, // 9_
            8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8, // A_
            8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8, // B_
            8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8, // C_
            8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8, // D_
            8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8, // E_
            8, 8, 8, 8, 8, 8,16, 8, 8, 8, 8, 8, 8, 8,16, 8  // F_
        ];
    }

    @property
    ushort reg(string select : "pc")() inout {
        return pc;
    }

    @property
    ushort reg(string select : "sp")() inout {
        return sp;
    }

    @property
    ubyte reg(string select : "(hl)")() inout {
        return mem[reg!"hl"];
    }

    @property
    auto reg(string select)() inout {
        bitness!(select.length * bits) res = 0;
        foreach (i, r; select) {
            auto shift = (select.length - i - 1) * bits;
            res |= cast(typeof(res))regs[r] << shift;
        }
        return res;
    }

    unittest {
        auto mem = new Memory;
        auto cpu = new Processor(mem);
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
    void reg(string select : "pc")(ushort value) {
        pc = value;
    }

    @property
    void reg(string select : "sp")(ushort value) {
        sp = value;
    }

    @property
    void reg(string select : "(hl)")(ubyte value) {
        mem[reg!"hl"] = value;
    }

    @property
    void reg(string select)(bitness!(select.length * bits) value) {
        foreach (i, r; select) {
            auto shift = (select.length - i - 1) * bits;
            regs[r] = T.max & (value >> shift);
        }
    }

    unittest {
        auto mem = new Memory;
        auto cpu = new Processor(mem);
        cpu.reg!"abcdefhl" = 0x0001020304050607;

        assert(cpu.reg!"baef" == 0x01000405);
        cpu.reg!"ab" = cpu.reg!"ba";
        assert(cpu.reg!"ab" == 0x0100);
        assert(cpu.reg!"aaa" == 0x010101);
        cpu.reg!"af" = cpu.reg!"bc";
        assert(cpu.reg!"a" == cpu.reg!"b" && cpu.reg!"f" == cpu.reg!"c");
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
        auto cpu = new Processor(new Memory);
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
        interrupts = true;
        interruptEnable = 0;
        interruptFlags = 0;
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
        auto mem = new Memory;
        auto cpu = new Processor(mem);
        cpu.boot();
        assert(cpu.reg!"abcdefhl" == 0x01001300D8B0014D);
        assert(cpu.reg!"sp" == 0xFFFE);
        assert(cpu.reg!"pc" == 0x100);
    }

    void step() {
        if (stopped)
            return;
        immutable opcode = mem[pc++];
        step(opSet, opTicks, opcode);
    }

    private void step(const Instruction[ubyte] set, ref const ubyte[0x100] times, ubyte opcode) {
        immutable instr = set[opcode];
        string mnemonic;
        final switch (instr.args) {
            case 0:
                mnemonic = instr.mnemonic;
                pc += instr.args;
                instr.nullary();
                break;
            case 1:
                ubyte arg = mem[pc];
                mnemonic = format(instr.mnemonic, arg);
                pc += instr.args;
                instr.unary(arg);
                break;
            case 2:
                ushort arg = (mem[pc + 1] << 8) | mem[pc];
                mnemonic = format(instr.mnemonic, arg);
                pc += instr.args;
                instr.binary(arg);
                break;
        }
        debug writeln(mnemonic);
        ticks += times[opcode];
    }

    void fireInterrupts() {
        if (!interrupts)
            return;
        ubyte fired = interruptEnable & interruptFlags;
        // Vertical blank
        if (fired.bit!0) {
            interruptFlags.bit!0 = 0;
            interrupt!0x40();
        }
        // LCD status
        if (fired.bit!1) {
            interruptFlags.bit!1 = 0;
            interrupt!0x48();
        }
        // Timer overflow
        if (fired.bit!2) {
            interruptFlags.bit!2 = 0;
            interrupt!0x50();
        }
        // Serial link
        if (fired.bit!3) {
            interruptFlags.bit!3 = 0;
            interrupt!0x58();
        }
        // Joypad press
        if (fired.bit!4) {
            interruptFlags.bit!4 = 0;
            interrupt!0x60();
        }
    }

private:

    ubyte carry8(int res) {
        return (res & 0xFF00) != 0 ? 1 : 0;
    }

    ubyte carry16(int res) {
        return (res & 0xFFFF0000) != 0 ? 1 : 0;
    }

    ubyte halfcarry(int a, int b) {
        return (a & 0x0F) + (b & 0x0F) > 0x0F ? 1 : 0;
    }

    ubyte halfcarry2(int a, int b) {
        return (a & 0x0F) > (b & 0x0F) ? 1 : 0;
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
        stopped = true;
    }

    void ldhl(ubyte value) {
        int res = sp + cast(byte)value;
        flag!'c' = carry16(res);
        flag!'h' = halfcarry(sp, value);
        flag!'z' = 0;
        flag!'n' = 0;
        reg!"hl" = cast(ushort)(res & 0xFFFF);
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
        flag!'c' = carry8(res);
        reg!"a" = cast(T)(res & 0xFF);
        flag!'z' = zero(reg!"a");
        flag!'h' = halfcarry(reg!"a", value);
        flag!'n' = 0;
    }

    void adc(ubyte value) {
        value += flag!'c';
        int res = reg!"a" + value;
        flag!'c' = carry8(res);
        flag!'z' = value == reg!"a" ? 1 : 0;
        flag!'h' = halfcarry(reg!"a", value);
        flag!'n' = 0;
        reg!"a" = cast(T)(res & 0xFF);
    }

    void sub(ubyte value) {
        flag!'n' = 1;
        flag!'c' = value > reg!"a" ? 1 : 0;
        flag!'h' = halfcarry2(value, reg!"a");
        reg!"a" = cast(T)(reg!"a" - value);
        flag!'z' = zero(reg!"a");
    }

    void sbc(ubyte value) {
        value += flag!'c';
        flag!'n' = 1;
        flag!'c' = value > reg!"a" ? 1 : 0;
        flag!'z' = value == reg!"a" ? 1 : 0;
        flag!'h' = halfcarry2(value, reg!"a");
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
        flag!'h' = halfcarry2(value, reg!"a");
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
        flag!'h' = (value & 0x0F) != 0 ? 1 : 0;
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
        flag!'h' = (value & 0x0F) == 0x0F ? 1 : 0;
        value++;
        flag!'z' = zero(value);
        flag!'n' = 0;
        return value;
    }

    void addhl(ushort value) {
        uint res = reg!"hl" + value;
        flag!'c' = carry16(res);
        reg!"hl" = cast(ushort)(res & 0xFFFF);
        flag!'h' = halfcarry(reg!"hl", value);
        flag!'n' = 0;
    }

    void addsp(ubyte value) {
        int res = reg!"sp" + cast(byte)value;
        flag!'c' = carry16(res);
        reg!"sp" = cast(ushort)(res & 0xFFFF);
        flag!'h' = halfcarry(reg!"sp", cast(byte)value);
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
        ubyte carry = (reg!"a" & 0x80) >> 7;
        flag!'c' = carry;
        reg!"a" = cast(T)(reg!"a" << 1);
        reg!"a" = cast(T)(reg!"a" + carry);
        flag!'n' = 0;
        flag!'z' = 0;
        flag!'h' = 0;
    }

    void rla() {
        ubyte carry = flag!'c';
        flag!'c' = (reg!"a" & 0x80) != 0 ? 1 : 0;
        reg!"a" = cast(T)(reg!"a" << 1);
        reg!"a" = cast(T)(reg!"a" + carry);
        flag!'n' = 0;
        flag!'z' = 0;
        flag!'h' = 0;
    }

    void rrca() {
        ubyte carry = reg!"a" & 0x01;
        flag!'c' = carry;
        reg!"a" = cast(T)(reg!"a" >> 1);
        if (carry) {
            reg!"a" = cast(T)(reg!"a" | 0x80);
        }
        flag!'n' = 0;
        flag!'z' = 0;
        flag!'h' = 0;
    }

    void rra() {
        int carry = flag!'c' << 7;
        flag!'c' = (reg!"a" & 0x01);
        reg!"a" = cast(T)(reg!"a" >> 1);
        reg!"a" = cast(T)(reg!"a" + carry);
        flag!'n' = 0;
        flag!'z' = 0;
        flag!'h' = 0;
    }

    void jp(ushort value) {
        pc = value;
    }

    void jpif(char f, bool test)(ushort value) {
        if (flag!f == test) {
            jp(value);
            ticks += 4;
        }
    }

    void jr(ubyte value) {
        pc += cast(byte)value;
    }

    void jrif(char f, bool test)(ubyte value) {
        if (flag!f == test) {
            jr(value);
            ticks += 4;
        }
    }

    void call(ushort value) {
        push(pc);
        pc = value;
    }

    void callif(char f, bool test)(ushort value) {
        if (flag!f == test) {
            call(value);
            ticks += 12;
        }
    }

    void rst(ushort value)() {
        push(pc);
        pc = value;
    }

    void ret() {
        pc = pop();
    }

    void retif(char f, bool test)() {
        if (flag!f == test) {
            ret();
            ticks += 12;
        }
    }

    void interrupt(ushort value)() {
        interrupts = false;
        rst!value();
        ticks += 12;
    }

    void cb(ubyte opcode) {
        step(cbSet, cbTicks, opcode);
    }

    ubyte rlc(ubyte value) {
        int carry = (value & 0x80) >> 7;
        flag!'c' = (value & 0x80) != 0 ? 1 : 0;
        value <<= 1;
        value += carry;
        flag!'z' = zero(value);
        flag!'n' = 0;
        flag!'h' = 0;
        return value;
    }

    ubyte rl(ubyte value) {
        int carry = flag!'c';
        flag!'c' = (value & 0x80) != 0 ? 1 : 0;
        value <<= 1;
        value += carry;
        flag!'z' = zero(value);
        flag!'n' = 0;
        flag!'h' = 0;
        return value;
    }

    ubyte rrc(ubyte value) {
        int carry = value & 0x01;
        value >>= 1;
        value |= carry ? 0x80 : 0;
        flag!'c' = carry ? 1 : 0;
        flag!'z' = zero(value);
        flag!'n' = 0;
        flag!'h' = 0;
        return value;
    }

    ubyte rr(ubyte value) {
        value >>= 1;
        value |= flag!'c' ? 0x80 : 0;
        flag!'c' = value & 0x01;
        flag!'z' = zero(value);
        flag!'n' = 0;
        flag!'h' = 0;
        return value;
    }

    ubyte sla(ubyte value) {
        flag!'c' = (value & 0x80) != 0 ? 1 : 0;
        value <<= 1;
        flag!'z' = zero(value);
        flag!'n' = 0;
        flag!'h' = 0;
        return value;
    }

    ubyte sra(ubyte value) {
        flag!'c' = value & 0x01;
        value = (value & 0x80) | (value >> 1);
        flag!'z' = zero(value);
        flag!'n' = 0;
        flag!'h' = 0;
        return value;
    }

    ubyte srl(ubyte value) {
        flag!'c' = value & 0x01;
        value >>= 1;
        flag!'z' = zero(value);
        flag!'n' = 0;
        flag!'h' = 0;
        return value;
    }

    ubyte swap(ubyte value) {
        value = ((value & 0xF) << 4) | ((value & 0xF0) >> 4);
        flag!'z' = zero(value);
        flag!'c' = 0;
        flag!'n' = 0;
        flag!'h' = 0;
        return value;
    }

    void tbit(size_t i)(ubyte value) {
        flag!'z' = zero(value.bit!i);
        flag!'n' = 0;
        flag!'h' = 1;
    }

    ubyte set(size_t i)(ubyte value) {
        value.bit!i = 1;
        return value;
    }

    ubyte res(size_t i)(ubyte value) {
        value.bit!i = 0;
        return value;
    }

private:
    T[char] regs;
    ushort pc, sp;
    size_t ticks;
    bool stopped;
    bool interrupts;
    ubyte interruptEnable, interruptFlags;
    Memory mem;
    Instruction[ubyte] opSet, cbSet;
    static immutable ubyte[0x100] opTicks, cbTicks;
}
