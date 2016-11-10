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
    alias ubyte T;
    enum bits = 8;
    enum flags = "chnz";

    this(Memory mem) {
        this.mem = mem;
        opSet = [
            0x00: Instruction("NOP", &nop),
            0x76: Instruction("HALT", &halt),
            0x10: Instruction("STOP 0", &stop),

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
            0xC2: Instruction("JP NZ,$%04X", (ushort n) { if (!flag!'z') jp(n); }),
            0xCA: Instruction("JP Z,$%04X", (ushort n) { if (flag!'z') jp(n); }),
            0xD2: Instruction("JP NC,$%04X", (ushort n) { if (!flag!'c') jp(n); }),
            0xDA: Instruction("JP C,$%04X", (ushort n) { if (flag!'c') jp(n); }),
            0xE9: Instruction("JP (HL)", { jp(reg!"hl"); }),

            0x18: Instruction("JR $%02X", &jr),
            0x20: Instruction("JR NZ,$%02X", (ubyte n) { if (!flag!'z') jr(n); }),
            0x28: Instruction("JR Z,$%02X", (ubyte n) { if (flag!'z') jr(n); }),
            0x30: Instruction("JR NC,$%02X", (ubyte n) { if (!flag!'c') jr(n); }),
            0x38: Instruction("JR C,$%02X", (ubyte n) { if (flag!'c') jr(n); }),

            0xCD: Instruction("CALL $%04X", &call),
            0xC4: Instruction("CALL NZ,$%04X", (ushort n) { if (!flag!'z') call(n); }),
            0xCC: Instruction("CALL Z,$%04X", (ushort n) { if (flag!'z') call(n); }),
            0xD4: Instruction("CALL NC,$%04X", (ushort n) { if (!flag!'c') call(n); }),
            0xDC: Instruction("CALL C,$%04X", (ushort n) { if (flag!'c') call(n); }),

            0xC7: Instruction("RST 00H", &rst!0x00),
            0xCF: Instruction("RST 08H", &rst!0x08),
            0xD7: Instruction("RST 10H", &rst!0x10),
            0xDF: Instruction("RST 18H", &rst!0x18),
            0xE7: Instruction("RST 20H", &rst!0x20),
            0xEF: Instruction("RST 28H", &rst!0x28),
            0xF7: Instruction("RST 30H", &rst!0x30),
            0xFF: Instruction("RST 38H", &rst!0x38),

            0xC9: Instruction("RET", &ret),
            0xC0: Instruction("RET NZ", { if (!flag!'z') ret(); }),
            0xC8: Instruction("RET Z", { if (flag!'z') ret(); }),
            0xD0: Instruction("RET NC", { if (!flag!'c') ret(); }),
            0xD8: Instruction("RET C", { if (flag!'c') ret(); }),
            0xD9: Instruction("RETI", { ret(); interrupts = true; }),

            0xCB: Instruction("PREFIX CB", &cb)
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
        ];
        immutable tbitn = [&tbit!0, &tbit!1, &tbit!2, &tbit!3, &tbit!4, &tbit!5, &tbit!6, &tbit!7];
        immutable resn = [&res!0, &res!1, &res!2, &res!3, &res!4, &res!5, &res!6, &res!7];
        immutable setn = [&set!0, &set!1, &set!2, &set!3, &set!4, &set!5, &set!6, &set!7];
        ubyte op = 0x40;
        for (size_t i = 0; i < 8; i++) {
            cbSet[op++] = Instruction(format("BIT %d,B", i), { tbitn[i](reg!"b"); });
            cbSet[op++] = Instruction(format("BIT %d,C", i), { tbitn[i](reg!"c"); });
            cbSet[op++] = Instruction(format("BIT %d,D", i), { tbitn[i](reg!"d"); });
            cbSet[op++] = Instruction(format("BIT %d,E", i), { tbitn[i](reg!"e"); });
            cbSet[op++] = Instruction(format("BIT %d,H", i), { tbitn[i](reg!"h"); });
            cbSet[op++] = Instruction(format("BIT %d,L", i), { tbitn[i](reg!"l"); });
            cbSet[op++] = Instruction(format("BIT %d,(HL)", i), { tbitn[i](reg!"(hl)"); });
            cbSet[op++] = Instruction(format("BIT %d,A", i), { tbitn[i](reg!"a"); });
        }
        assert(op == 0x80);
        for (size_t i = 0; i < 8; i++) {
            cbSet[op++] = Instruction(format("RES %d,B", i), { reg!"b" = resn[i](reg!"b"); });
            cbSet[op++] = Instruction(format("RES %d,C", i), { reg!"c" = resn[i](reg!"c"); });
            cbSet[op++] = Instruction(format("RES %d,D", i), { reg!"d" = resn[i](reg!"d"); });
            cbSet[op++] = Instruction(format("RES %d,E", i), { reg!"e" = resn[i](reg!"e"); });
            cbSet[op++] = Instruction(format("RES %d,H", i), { reg!"h" = resn[i](reg!"h"); });
            cbSet[op++] = Instruction(format("RES %d,L", i), { reg!"l" = resn[i](reg!"l"); });
            cbSet[op++] = Instruction(format("RES %d,(HL)", i), { reg!"(hl)" = resn[i](reg!"(hl)"); });
            cbSet[op++] = Instruction(format("RES %d,A", i), { reg!"a" = resn[i](reg!"a"); });
        }
        assert(op == 0xC0);
        for (size_t i = 0; i < 8; i++) {
            cbSet[op++] = Instruction(format("SET %d,B", i), { reg!"b" = setn[i](reg!"b"); });
            cbSet[op++] = Instruction(format("SET %d,C", i), { reg!"c" = setn[i](reg!"c"); });
            cbSet[op++] = Instruction(format("SET %d,D", i), { reg!"d" = setn[i](reg!"d"); });
            cbSet[op++] = Instruction(format("SET %d,E", i), { reg!"e" = setn[i](reg!"e"); });
            cbSet[op++] = Instruction(format("SET %d,H", i), { reg!"h" = setn[i](reg!"h"); });
            cbSet[op++] = Instruction(format("SET %d,L", i), { reg!"l" = setn[i](reg!"l"); });
            cbSet[op++] = Instruction(format("SET %d,(HL)", i), { reg!"(hl)" = setn[i](reg!"(hl)"); });
            cbSet[op++] = Instruction(format("SET %d,A", i), { reg!"a" = setn[i](reg!"a"); });
        }
        assert(op == 0x00);
        cbSet.rehash();
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
        ubyte opcode = mem[pc++];
        final switch (opSet[opcode].args) {
            case 0:
                writeln(opSet[opcode].mnemonic);
                opSet[opcode].nullary();
                break;
            case 1:
                ubyte arg = mem[pc++];
                writefln(opSet[opcode].mnemonic, arg);
                opSet[opcode].unary(arg);
                break;
            case 2:
                ushort arg = (mem[pc + 1] << 8) | mem[pc];
                pc += 2;
                writefln(opSet[opcode].mnemonic, arg);
                opSet[opcode].binary(arg);
                break;
        }
        //TODO: increment ticks
    }

    void fireInterrupts() {
        if (!interrupts)
            return;
        auto enable = mem[0xFFFF];
        auto flags = mem[0xFF0F];
        ubyte fired = enable & flags;
        // Vertical blank
        if (fired.bit!0) {
            flags.bit!0 = 0;
            //TODO: render here
            interrupt!0x40();
        }
        // LCD status
        if (fired.bit!1) {
            flags.bit!1 = 0;
            interrupt!0x48();
        }
        // Timer overflow
        if (fired.bit!2) {
            flags.bit!2 = 0;
            interrupt!0x50();
        }
        // Serial link
        if (fired.bit!3) {
            flags.bit!3 = 0;
            interrupt!0x58();
        }
        // Joypad press
        if (fired.bit!4) {
            flags.bit!4 = 0;
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
        //stop the cpu
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

    void interrupt(ushort value)() {
        interrupts = false;
        rst!value();
        //TODO: ticks
    }

    void cb(ubyte opcode) {
        //read next Instruction
        //execute on new set
        cbSet[opcode].nullary();
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
    bool interrupts;
    Memory mem;
    Instruction[ubyte] opSet;
    Instruction[ubyte] cbSet;
}
