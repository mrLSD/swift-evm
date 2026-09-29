# Project scope

This is an Ethereum Virtual Machine implementation in Swift. Optimize for EVM
correctness, the highest practical Swift performance, low memory use, safety,
and reliability. Keep code clean, simple, explicit, readable, and elegant.
Performance claims require measurements; complexity must earn its place.

- EELS defines observable execution behavior for the selected hard fork:
  <https://github.com/ethereum/execution-specs>.
- `~/dev/rs/aurora-evm/` is the local implementation reference. Check the relevant
  implementation and dependency versions before adapting an algorithm.
- Rust `primitive-types` / `uint` informs the integer algorithms. Adapt them to
  Swift's layout, overflow, dispatch, availability, and optimization behavior;
  a mechanical translation is not evidence of correctness or performance.
- Resolve semantic discrepancies against EELS. Distinguish primitive API
  preconditions from opcode behavior, including division by zero.

# PrimitiveTypes design

`Sources/PrimitiveTypes` intentionally implements only the arithmetic and byte
operations needed by the EVM. It is not a general-purpose mathematics library.

- Preserve inline, fixed-size value storage in explicit machine-word fields or
  tuples. This minimal substitute for fixed arrays is deliberate; do not replace
  it with a general-purpose fixed-array or big-integer dependency.
- Keep the PrimitiveTypes target free of external dependencies. Do not broaden
  numeric protocols or add unrelated mathematics just for API completeness.
- Computed `BYTES` arrays are conversion views, not the stored representation.
  Avoid creating them in hot paths when direct field operations suffice. Check
  optimized output and allocations before claiming that Swift eliminates them.
- Unsigned limbs are little-endian. Address/hash byte order and external EVM
  encoding must remain explicit. Preserve carry/borrow propagation, modular
  widths, and full intermediate precision for ADDMOD/MULMOD.
- I256 uses a magnitude plus a sign flag internally; EVM words use two's
  complement. Preserve conversion boundaries, canonical nonnegative zero,
  signed division/remainder, and arithmetic-shift semantics.
- Review every supported OS path. Availability-gated fast and fallback paths
  must compute identical results on their valid input domains.
- Measure optimizations in release builds at realistic Interpreter call sites.
  Consider time, allocations, value stride, and code size together. Do not
  trade correctness or clarity for an unmeasured micro-optimization.

# Code and test style

- Read neighboring implementations and existing tests before editing. Follow
  the project's naming, layout, access control, assertions, and abstractions.
- Separate consecutive loops at the same nesting level with a blank line.
  This rule concerns sibling loops, not nested loops.
- Omit explicit `internal` modifiers; use Swift's default access level. Put
  internal helpers in an unqualified extension, not a `public extension`.
- SwiftFormat for Xcode owns formatting. Keep SwiftLint compatible with its
  multiline braces and per-file inferred comma style; avoid formatting-only churn.
- Tests use Quick and Nimble: `QuickSpec`, `describe`, `context`, `it`, `expect`.
  Extend the existing relevant specs in `Tests/PrimitiveTypesTests` and
  `Tests/InterpreterTests`. Do not introduce parallel XCTest/Swift Testing
  suites or separate files merely to avoid extending existing tests.
- Keep code comments and doc comments concise and informative. Explain a
  contract, invariant, algorithmic reason, or non-obvious boundary; avoid
  narrating statements, repeating signatures, or preserving obsolete history.
- Keep changes focused. Preserve unrelated working-tree and staged changes.
  An audit-only request does not authorize implementation or test changes.
- Do not build with `-Ounchecked`. Release builds use `-O`: checked unwraps
  and preconditions must trap if an invariant is violated, rather than allow
  undefined behavior. Unwraps after validation must explain the invariant.

# Test requirements

- Require 100% test coverage of implemented functionality, including changed
  behavior, boundary conditions, and failure paths. Inspect executable-line
  and region coverage; explicitly account for platform-specific paths. Do not
  omit difficult code from reports to manufacture 100%.
- Coverage percentages do not prove arithmetic correctness. Assert values,
  signs, carry/borrow flags, and invariants using independent expected results.
- Include zero, one, maxima, signed minimum, every limb boundary, long carry
  and borrow chains, oversized shifts, endian conversions, and invalid inputs
  where applicable to the operation's contract.
- Division tests must validate `a = q*b + r` without accidental fixed-width
  truncation and `0 <= r < b`; exercise normalization, quotient correction,
  add-back and small divisors. Word division uses `UInt64.dividingFullWidth`
  on all supported OS versions; test its `hi < divisor` precondition domain.
- Use reproducible random/property tests with a fixed seed and failing inputs
  in diagnostics. Cover U256 and U512, not only U128. Reference-generated
  fixtures may use Rust or independent arbitrary-precision arithmetic without
  adding a production dependency.
- Bind generic operator results to local values before passing them to Nimble;
  its optional autoclosures can change overload resolution. Check external-module
  dispatch when changing protocol operators.
- For EVM-visible changes, verify opcode behavior as well as primitive helpers.
  A regression test must fail for the defect it is intended to prevent.
- Assert the specific failure, not merely that something failed: match the
  concrete error case of a `Result`, and for traps capture stderr and match the
  message fragment that names the violated contract. A bare `throwAssertion()`
  is acceptable only for a trap that carries no message, such as the arithmetic
  overflow in `BasicAccount.incNonce`.

# CI gates

The sources of truth are `.github/workflows/swift.yaml` and `.codecov.yml`.
The workflow currently uses
`macos-latest` and Swift latest, with these checks:

1. `swift build`
2. `swiftlint` using `.swiftlint.yml` (CI installs SwiftLint with Homebrew).
3. `swift test --verbose --enable-code-coverage`
4. Export LCOV with `xcrun llvm-cov export -format="lcov"` using the test bundle
   binary and `codecov/default.profdata` under `swift build --show-bin-path`,
   excluding `\.build|Tests`, to `coverage/lcov.info`; use the workflow's exact
   discovery/export script.
5. Upload LCOV through Codecov with `fail_ci_if_error: true` in CI.

Run the applicable local checks after changes and report failures honestly.
Codecov requires 100% patch and project coverage with zero threshold and ignores
only `Tests`. Inspect raw region coverage locally; do not add a separate CI
coverage gate or checker script. Swift branch counters are not emitted by the current
toolchain; do not describe 0/0 branches as measured branch coverage.
Release benchmarks and additional OS testing are useful validation, but are
not currently CI gates. Do not claim a local run verifies Codecov upload.

# Git and reporting

- Never stage or unstage files, or modify the Git index through any command or
  API. Preserve the user's staged/unstaged boundaries; completing fixes, reviews,
  or checks does not authorize staging.
- Do not run `git commit` or `git push`, and do not create pull requests.
- After changes, review the final diff again for correctness, scope, style,
  test quality, and unnecessary comments. State what was actually verified.
- Report to the user in Russian. Always include `ВЫВОДЫ`; include
  `РЕКОМЕНДАЦИИ` when follow-up actions are needed. Separate confirmed defects,
  measured results, and hypotheses or limitations.
- If source or test code changed, provide five concise, informative git commit
  message options, without creating a commit.
