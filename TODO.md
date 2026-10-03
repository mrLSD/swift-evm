# TODO list

## Add support for Opcodes

### System
- [ ] EXTCODESIZE
- [ ] EXTCODEHASH
- [ ] EXTCODECOPY
- [ ] SLOAD
- [ ] SSTORE
- [ ] TLOAD
- [ ] TSTORE
- [ ] RETURNDATASIZE
- [ ] RETURNDATACOPY
- [ ] PREVRANDAO

### Memory
- [ ] MCOPY

### Host
- [ ] BLOCKHASH
- [ ] TIMESTAMP
- [ ] GASLIMIT
- [ ] DIFFICULTY
- [ ] BASEFEE
- [ ] NUMBER
- [ ] BLOBHASH
- [ ] BLOBBASEFEE

### Other
- [ ] STATICCALL
- [ ] SELFDESTRUCT
- [ ] CREATE
- [ ] CREATE2
- [ ] CALL
- [ ] CALLCODE
- [ ] DELEGATECALL

## isStatic

At the moment in Handler as temporary solution.
But when Runtime will implemented, it should be moved to the EVM runtime, 
and the EVM runtime should be aware of the static context.
