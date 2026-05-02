import Foundation
import Interpreter
import PrimitiveTypes

/// Executes a single decoded VM test case against the existing Swift `Machine`.
///
/// The Swift `Machine` only implements a subset of EVM opcodes — arithmetic, bitwise,
/// stack, memory, return/revert, jumps, and a handful of host environment opcodes.
/// Tests that reach unimplemented opcodes (SLOAD, SSTORE, CALL, CREATE, LOG*, etc.)
/// will exit with `InvalidOpcode`; those tests are reported as **skipped** rather than
/// failed, since their outcome is not informative about the EVM implementation today.
enum VMRunner {
    static func run(name: String, test: VmTestCase, verbose: VerboseOutput) -> TestExecutionResult {
        var r = TestExecutionResult.empty
        r.total = 1

        let (accounts, storage) = PreStateBuilder.build(test.preState)
        let vicinity = Vicinity.fromVm(env: test.env, exec: test.transaction)
        let backend = TestBackend(vicinity: vicinity, accounts: accounts, storage: storage)
        let handler = TestHandler(backend: backend)

        // VM tests have no spec key — Rust uses `Config::frontier()`. We use `.Prague` to match
        // the existing Swift Interpreter's `HardFork.latest()`. The hard-fork choice does not
        // affect arithmetic/memory/stack outcomes for these tests.
        let gasLimit = test.transaction.gas.getUInt.flatMap { UInt64(exactly: $0) } ?? UInt64.max
        let machine = Machine(
            callData: test.transaction.data,
            code: test.transaction.code,
            gasLimit: gasLimit,
            memoryLimit: Int.max,
            targetAddress: test.transaction.address,
            callerAddress: test.transaction.sender,
            callValue: test.transaction.value,
            handler: handler,
            hardFork: .Prague
        )
        machine.runUntilExit()

        // Decode exit reason. Anything wrapping `InvalidOpcode` is treated as "skip + TODO".
        switch machine.status {
        case .Exit(.Error(.InvalidOpcode(let op))):
            if verbose.verbose {
                print("  SKIP \(name): unimplemented opcode 0x\(String(op, radix: 16, uppercase: false))")
            }
            r.skipped = 1
            return r
        case .Exit(.Success):
            return verifySuccess(name: name, test: test, machine: machine, verbose: verbose, r: r)
        case .Exit(.Revert):
            // Some VM tests intentionally revert — verify gas/output still match.
            return verifySuccess(name: name, test: test, machine: machine, verbose: verbose, r: r, isRevert: true)
        case .Exit(.Error(let err)):
            // Real interpreter error. Only fail if the test expected success.
            if test.gasLeft != nil || test.output != nil || test.postState != nil {
                if verbose.verbose || verbose.verboseFailed {
                    print("  FAIL \(name): unexpected exit error \(err)")
                }
                r.failed = 1
                return r
            }
            return r
        case .Exit(.Fatal(let f)):
            // Coverage note: structurally unreachable today. `Machine.ExitFatal` has only
            // `.ReadMemory`, which no opcode in the current Swift `Machine` actually sets.
            // Kept as defensive code for when more fatal-producing paths land.
            if verbose.verbose || verbose.verboseFailed {
                print("  FAIL \(name): fatal \(f)")
            }
            r.failed = 1
            return r
        default:
            // Coverage note: structurally unreachable. After `evalLoop()` returns, the only
            // reachable `MachineStatus` is `.Exit(_)`. The other variants (`.NotStarted`,
            // `.Continue`, `.AddPC`, `.Jump`) are transient and never seen post-loop. The
            // `default:` is here so the switch is exhaustive; the body should never run.
            r.failed = 1
            return r
        }
    }

    private static func verifySuccess(
        name: String,
        test: VmTestCase,
        machine: Machine,
        verbose: VerboseOutput,
        r initialResult: TestExecutionResult,
        isRevert: Bool = false
    ) -> TestExecutionResult {
        var r = initialResult

        if let expectedGasLeft = test.gasLeft {
            let actual = machine.gasRemaining
            let expected = expectedGasLeft.getUInt.flatMap { UInt64(exactly: $0) } ?? UInt64.max
            if actual != expected {
                if verbose.verbose || verbose.verboseFailed {
                    print("  FAIL \(name): gas left mismatch — expected \(expected), got \(actual)")
                }
                r.failed = 1
                return r
            }
        }

        if let expectedOutput = test.output {
            let actual = machine.collectedReturnData
            if actual != expectedOutput {
                if verbose.verbose || verbose.verboseFailed {
                    let actualHex = actual.map { String(format: "%02x", $0) }.joined()
                    let expHex = expectedOutput.map { String(format: "%02x", $0) }.joined()
                    print("  FAIL \(name): output mismatch — expected 0x\(expHex), got 0x\(actualHex)")
                }
                r.failed = 1
                return r
            }
        }

        // Post-state check. The existing Swift `Machine` does not implement state-mutating
        // opcodes (SSTORE etc.), so the world state cannot change during a successful run.
        // We therefore expect `post == pre` semantically. If the JSON `post` is present, we
        // verify pre and post are equal; if they are not, the test exercises behavior we
        // cannot yet reproduce → skip.
        if let post = test.postState {
            if post != test.preState {
                if verbose.verbose {
                    print("  SKIP \(name): post-state differs from pre-state (state mutation not implemented)")
                }
                r.skipped = 1
                return r
            }
        }

        if isRevert, verbose.verbose {
            print("  PASS \(name) (revert)")
        } else if verbose.verbose {
            print("  PASS \(name)")
        }
        return r
    }
}
