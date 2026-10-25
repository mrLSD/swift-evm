# TODO list

## Add support for Opcodes

### System
- [ ] SLOAD
- [ ] SSTORE
- [ ] TLOAD
- [ ] TSTORE
- [ ] RETURNDATACOPY

### Memory
- [ ] MCOPY

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

№№ RETURN

After implementing CALL/CREATE - decide ReturnData.length, ReturnData.offset 
