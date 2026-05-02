import Foundation
import Interpreter
import PrimitiveTypes

/// `InterpreterHandler` implementation used by the test runner.
///
/// Delegates env queries to a captured `Vicinity` + `TestBackend`. Returns `nil` from
/// `beforeOpcodeExecution` — the runner does not (yet) inject pre-opcode hooks.
final class TestHandler: InterpreterHandler {
    let backend: TestBackend

    init(backend: TestBackend) { self.backend = backend }

    func beforeOpcodeExecution(machine: Machine, opcode: Opcode?) -> Machine.ExitError? {
        return nil
    }

    func balance(address: H160) -> U256 { backend.basic(address: address).balance }
    func gasPrice() -> U256 { backend.gasPrice() }
    func origin() -> H160 { backend.origin() }
    func chainId() -> U256 { backend.chainId() }
    func coinbase() -> H160 { backend.blockCoinbase() }
}
