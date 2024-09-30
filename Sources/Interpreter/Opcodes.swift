/// EVM Opcodes
public enum Opcode: UInt8, CustomStringConvertible {
    //
    // Stop and Arithmetic
    //
    case STOP = 0x00
    case ADD = 0x01
    case MUL = 0x02
    case SUB = 0x03
    case DIV = 0x04
    case SDIV = 0x05
    case MOD = 0x06
    case SMOD = 0x07
    case ADDMOD = 0x08
    case MULMOD = 0x09
    case EXP = 0x0a
    case SIGNEXTEND = 0x0b

    //
    // Comparison and Bitwise Logic
    //
    case LT = 0x10
    case GT = 0x11
    case SLT = 0x12
    case SGT = 0x13
    case EQ = 0x14
    case ISZERO = 0x15
    case AND = 0x16
    case OR = 0x17
    case XOR = 0x18
    case NOT = 0x19
    case BYTE = 0x1a
    case SHL = 0x1b
    case SHR = 0x1c
    case SAR = 0x1d

    //
    // Sha3
    //
    case SHA3 = 0x20

    //
    // Environment Information
    //
    case ADDRESS = 0x30
    case BALANCE = 0x31
    case ORIGIN = 0x32
    case CALLER = 0x33
    case CALLVALUE = 0x34
    case CALLDATALOAD = 0x35
    case CALLDATASIZE = 0x36
    case CALLDATACOPY = 0x37
    case CODESIZE = 0x38
    case CODECOPY = 0x39
    case GASPRICE = 0x3a
    case EXTCODESIZE = 0x3b
    case EXTCODECOPY = 0x3c
    case RETURNDATASIZE = 0x3d
    case RETURNDATACOPY = 0x3e
    case EXTCODEHASH = 0x3f

    //
    // Block Information
    //
    case BLOCKHASH = 0x40
    case COINBASE = 0x41
    case TIMESTAMP = 0x42
    case NUMBER = 0x43
    // EIP-4399: DIFFICULTY -> PREVRANDAO
    case PREVRANDAO = 0x44
    case GASLIMIT = 0x45

    //
    //  Block Information
    //
    case CHAINID = 0x46
    case SELFBALANCE = 0x47
    case BASEFEE = 0x48
    case BLOBHASH = 0x49
    case BLOBBASEFEE = 0x4a

    //
    // Stack, Memory, Storage and Flow Operations
    //
    case POP = 0x50
    case MLOAD = 0x51
    case MSTORE = 0x52
    case MSTORE8 = 0x53
    case SLOAD = 0x54
    case SSTORE = 0x55
    case JUMP = 0x56
    case JUMPI = 0x57
    case PC = 0x58
    case MSIZE = 0x59
    case GAS = 0x5a
    case JUMPDEST = 0x5b
    case TLOAD = 0x5c
    case TSTORE = 0x5d
    case MCOPY = 0x5e

    //
    // Push Operations
    //
    case PUSH0 = 0x5f
    case PUSH1 = 0x60
    case PUSH2 = 0x61
    case PUSH3 = 0x62
    case PUSH4 = 0x63
    case PUSH5 = 0x64
    case PUSH6 = 0x65
    case PUSH7 = 0x66
    case PUSH8 = 0x67
    case PUSH9 = 0x68
    case PUSH10 = 0x69
    case PUSH11 = 0x6a
    case PUSH12 = 0x6b
    case PUSH13 = 0x6c
    case PUSH14 = 0x6d
    case PUSH15 = 0x6e
    case PUSH16 = 0x6f
    case PUSH17 = 0x70
    case PUSH18 = 0x71
    case PUSH19 = 0x72
    case PUSH20 = 0x73
    case PUSH21 = 0x74
    case PUSH22 = 0x75
    case PUSH23 = 0x76
    case PUSH24 = 0x77
    case PUSH25 = 0x78
    case PUSH26 = 0x79
    case PUSH27 = 0x7a
    case PUSH28 = 0x7b
    case PUSH29 = 0x7c
    case PUSH30 = 0x7d
    case PUSH31 = 0x7e
    case PUSH32 = 0x7f

    //
    // Duplicate Operations
    //
    case DUP1 = 0x80
    case DUP2 = 0x81
    case DUP3 = 0x82
    case DUP4 = 0x83
    case DUP5 = 0x84
    case DUP6 = 0x85
    case DUP7 = 0x86
    case DUP8 = 0x87
    case DUP9 = 0x88
    case DUP10 = 0x89
    case DUP11 = 0x8a
    case DUP12 = 0x8b
    case DUP13 = 0x8c
    case DUP14 = 0x8d
    case DUP15 = 0x8e
    case DUP16 = 0x8f

    //
    // Exchange Operations
    //
    case SWAP1 = 0x90
    case SWAP2 = 0x91
    case SWAP3 = 0x92
    case SWAP4 = 0x93
    case SWAP5 = 0x94
    case SWAP6 = 0x95
    case SWAP7 = 0x96
    case SWAP8 = 0x97
    case SWAP9 = 0x98
    case SWAP10 = 0x99
    case SWAP11 = 0x9a
    case SWAP12 = 0x9b
    case SWAP13 = 0x9c
    case SWAP14 = 0x9d
    case SWAP15 = 0x9e
    case SWAP16 = 0x9f

    //
    // Logging
    //
    case LOG0 = 0xa0
    case LOG1 = 0xa1
    case LOG2 = 0xa2
    case LOG3 = 0xa3
    case LOG4 = 0xa4

    //
    // EOF Data instructions
    //
    case DATALOAD = 0xd0
    case DATALOADN = 0xd1
    case DATASIZE = 0xd2
    case DATACOPY = 0xd3

    //
    // EOFv1 instrucitons
    //
    case RJUMP = 0xe0
    case RJUMPI = 0xe1
    case RJUMPV = 0xe2
    case CALLF = 0xe3
    case RETF = 0xe4
    case JUMPF = 0xe5
    case DUPN = 0xe6
    case SWAPN = 0xe7
    case EXCHANGE = 0xe8
    case EOFCREATE = 0xec
    case RETURNCONTRACT = 0xee

    //
    // System
    //
    case CREATE = 0xf0
    case CALL = 0xf1
    case CALLCODE = 0xf2
    case RETURN = 0xf3
    case DELEGATECALL = 0xf4
    case CREATE2 = 0xf5
    case RETURNDATALOAD = 0xf7
    case EXTCALL = 0xf8
    case EXTDELEGATECALL = 0xf9
    case STATICCALL = 0xfa
    case EXTSTATICCALL = 0xfb
    case REVERT = 0xfd
    case INVALID = 0xfe
    case SELFDESTRUCT = 0xff

    /// Opcode index
    var index: Int { Int(rawValue) }

    var name: String {
        switch self {
        case .STOP: "STOP"
        case .ADD: "ADD"
        case .MUL: "MUL"
        case .SUB: "SUB"
        case .DIV: "DIV"
        case .SDIV: "SDIV"
        case .MOD: "MOD"
        case .SMOD: "SMOD"
        case .ADDMOD: "ADDMOD"
        case .MULMOD: "MULMOD"
        case .EXP: "EXP"
        case .SIGNEXTEND: "SIGNEXTEND"
        case .LT: "LT"
        case .GT: "GT"
        case .SLT: "SLT"
        case .SGT: "SGT"
        case .EQ: "EQ"
        case .ISZERO: "ISZERO"
        case .AND: "AND"
        case .OR: "OR"
        case .XOR: "XOR"
        case .NOT: "NOT"
        case .BYTE: "BYTE"
        case .SHL: "SHL"
        case .SHR: "SHR"
        case .SAR: "SAR"
        case .SHA3: "SHA3"
        case .ADDRESS: "ADDRESS"
        case .BALANCE: "BALANCE"
        case .ORIGIN: "ORIGIN"
        case .CALLER: "CALLER"
        case .CALLVALUE: "CALLVALUE"
        case .CALLDATALOAD: "CALLDATALOAD"
        case .CALLDATASIZE: "CALLDATASIZE"
        case .CALLDATACOPY: "CALLDATACOPY"
        case .CODESIZE: "CODESIZE"
        case .CODECOPY: "CODECOPY"
        case .GASPRICE: "GASPRICE"
        case .EXTCODESIZE: "EXTCODESIZE"
        case .EXTCODECOPY: "EXTCODECOPY"
        case .RETURNDATASIZE: "RETURNDATASIZE"
        case .RETURNDATACOPY: "RETURNDATACOPY"
        case .EXTCODEHASH: "EXTCODEHASH"
        case .BLOCKHASH: "BLOCKHASH"
        case .COINBASE: "COINBASE"
        case .TIMESTAMP: "TIMESTAMP"
        case .NUMBER: "NUMBER"
        case .PREVRANDAO: "PREVRANDAO"
        case .GASLIMIT: "GASLIMIT"
        case .CHAINID: "CHAINID"
        case .SELFBALANCE: "SELFBALANCE"
        case .BASEFEE: "BASEFEE"
        case .BLOBHASH: "BLOBHASH"
        case .BLOBBASEFEE: "BLOBBASEFEE"
        case .POP: "POP"
        case .MLOAD: "MLOAD"
        case .MSTORE: "MSTORE"
        case .MSTORE8: "MSTORE8"
        case .SLOAD: "SLOAD"
        case .SSTORE: "SSTORE"
        case .JUMP: "JUMP"
        case .JUMPI: "JUMPI"
        case .PC: "PC"
        case .MSIZE: "MSIZE"
        case .GAS: "GAS"
        case .JUMPDEST: "JUMPDEST"
        case .TLOAD: "TLOAD"
        case .TSTORE: "TSTORE"
        case .MCOPY: "MCOPY"
        case .PUSH0: "PUSH0"
        case .PUSH1: "PUSH1"
        case .PUSH2: "PUSH2"
        case .PUSH3: "PUSH3"
        case .PUSH4: "PUSH4"
        case .PUSH5: "PUSH5"
        case .PUSH6: "PUSH6"
        case .PUSH7: "PUSH7"
        case .PUSH8: "PUSH8"
        case .PUSH9: "PUSH9"
        case .PUSH10: "PUSH10"
        case .PUSH11: "PUSH11"
        case .PUSH12: "PUSH12"
        case .PUSH13: "PUSH13"
        case .PUSH14: "PUSH14"
        case .PUSH15: "PUSH15"
        case .PUSH16: "PUSH16"
        case .PUSH17: "PUSH17"
        case .PUSH18: "PUSH18"
        case .PUSH19: "PUSH19"
        case .PUSH20: "PUSH20"
        case .PUSH21: "PUSH21"
        case .PUSH22: "PUSH22"
        case .PUSH23: "PUSH23"
        case .PUSH24: "PUSH24"
        case .PUSH25: "PUSH25"
        case .PUSH26: "PUSH26"
        case .PUSH27: "PUSH27"
        case .PUSH28: "PUSH28"
        case .PUSH29: "PUSH29"
        case .PUSH30: "PUSH30"
        case .PUSH31: "PUSH31"
        case .PUSH32: "PUSH32"
        case .DUP1: "DUP1"
        case .DUP2: "DUP2"
        case .DUP3: "DUP3"
        case .DUP4: "DUP4"
        case .DUP5: "DUP5"
        case .DUP6: "DUP6"
        case .DUP7: "DUP7"
        case .DUP8: "DUP8"
        case .DUP9: "DUP9"
        case .DUP10: "DUP10"
        case .DUP11: "DUP11"
        case .DUP12: "DUP12"
        case .DUP13: "DUP13"
        case .DUP14: "DUP14"
        case .DUP15: "DUP15"
        case .DUP16: "DUP16"
        case .SWAP1: "SWAP1"
        case .SWAP2: "SWAP2"
        case .SWAP3: "SWAP3"
        case .SWAP4: "SWAP4"
        case .SWAP5: "SWAP5"
        case .SWAP6: "SWAP6"
        case .SWAP7: "SWAP7"
        case .SWAP8: "SWAP8"
        case .SWAP9: "SWAP9"
        case .SWAP10: "SWAP10"
        case .SWAP11: "SWAP11"
        case .SWAP12: "SWAP12"
        case .SWAP13: "SWAP13"
        case .SWAP14: "SWAP14"
        case .SWAP15: "SWAP15"
        case .SWAP16: "SWAP16"
        case .LOG0: "LOG0"
        case .LOG1: "LOG1"
        case .LOG2: "LOG2"
        case .LOG3: "LOG3"
        case .LOG4: "LOG4"
        case .DATALOAD: "DATALOAD"
        case .DATALOADN: "DATALOADN"
        case .DATASIZE: "DATASIZE"
        case .DATACOPY: "DATACOPY"
        case .RJUMP: "RJUMP"
        case .RJUMPI: "RJUMPI"
        case .RJUMPV: "RJUMPV"
        case .CALLF: "CALLF"
        case .RETF: "RETF"
        case .JUMPF: "JUMPF"
        case .DUPN: "DUPN"
        case .SWAPN: "SWAPN"
        case .EXCHANGE: "EXCHANGE"
        case .EOFCREATE: "EOFCREATE"
        case .RETURNCONTRACT: "RETURNCONTRACT"
        case .CREATE: "CREATE"
        case .CALL: "CALL"
        case .CALLCODE: "CALLCODE"
        case .RETURN: "RETURN"
        case .DELEGATECALL: "DELEGATECALL"
        case .CREATE2: "CREATE2"
        case .RETURNDATALOAD: "RETURNDATALOAD"
        case .EXTCALL: "EXTCALL"
        case .EXTDELEGATECALL: "EXTDELEGATECALL"
        case .STATICCALL: "STATICCALL"
        case .EXTSTATICCALL: "EXTSTATICCALL"
        case .REVERT: "REVERT"
        case .INVALID: "INVALID"
        case .SELFDESTRUCT: "SELFDESTRUCT"
        }
    }

    /// Represent attributes as `String`: `OPCODE(0xNN)`
    public var description: String {
        "\(name)(0x\(String(format: "%02x", rawValue)))"
    }
}
