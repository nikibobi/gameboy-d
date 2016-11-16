module gameboy.instruction;

struct Instruction
{
    @disable this();

    this(string mnemonic, void delegate() op) {
        this.mnemonic = mnemonic;
        nullary = op;
        bytes = 0;
    }

    this(string mnemonic, void delegate(ubyte) op) {
        this.mnemonic = mnemonic;
        unary = op;
        bytes = 1;
    }

    this(string mnemonic, void delegate(ushort) op) {
        this.mnemonic = mnemonic;
        binary = op;
        bytes = 2;
    }

    string mnemonic;

    union
    {
        void delegate() nullary;
        void delegate(ubyte) unary;
        void delegate(ushort) binary;
    }

    @property
    size_t args() inout {
        return this.bytes;
    }

    private size_t bytes;
}