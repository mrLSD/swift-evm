import Foundation

/// Hardcoded skip list — a port of `aurora-evm::evm-tests::main.rs::SKIPPED_CASES`.
///
/// Each entry is a path-suffix matched against the test JSON file path. The Rust harness
/// gates three entries behind the `enable-slow-tests` cargo feature; the Swift port surfaces
/// the same toggle via the `--enable-slow-tests` CLI flag, threaded into `shouldSkip(_,enableSlowTests:)`.
///
/// Mapping:
///   `cargo run -p aurora-evm-jsontests -F enable-slow-tests …`  ↔  `--enable-slow-tests`
///   (default Rust — no feature)                                 ↔  default Swift (no flag)
public enum SkipList {
    /// Cases that are skipped regardless of `--enable-slow-tests`. Mirrors the entries
    /// present in *both* the gated and ungated Rust lists.
    public static let alwaysSkipped: [String] = [
        "stTransactionTest/ValueOverflow",
        "stTransactionTest/ValueOverflowParis",
        "stRevertTest/RevertPrecompiledTouch",
        "stRevertTest/RevertPrecompiledTouch_storage",
        "eip7702_set_code_tx/set_code_txs/invalid_tx_invalid_auth_signature",
        "eip7702_set_code_tx/set_code_txs/tx_validity_nonce",
        "eip7702_set_code_tx/set_code_txs/set_code_to_non_empty_storage"
    ]

    /// Cases that are skipped *only* when slow tests are not opted in. Mirrors the
    /// `cfg(not(feature = "enable-slow-tests"))` extras in the Rust harness.
    public static let slowOnly: [String] = [
        "stTimeConsuming/static_Call50000_sha256",
        "vmPerformance/loopMul",
        "stTimeConsuming/CALLBlake2f_MaxRounds"
    ]

    /// Decide whether a given path should be skipped according to the active skip list.
    ///
    /// Mirrors Rust's `should_skip(path)`:
    /// 1. If the case ends in a stem (no parents), matches when the path's filename stem matches
    ///    *anywhere* in the tree.
    /// 2. If the case has parents, the parent components must match the path's parents as a suffix.
    /// 3. Or any *contiguous* component window of the case's length in the path matches it.
    public static func shouldSkip(_ path: String, enableSlowTests: Bool = false) -> Bool {
        let active = enableSlowTests ? alwaysSkipped : (alwaysSkipped + slowOnly)

        let pathComponents = components(of: path)
        let pathLen = pathComponents.count
        let pathStem = stem(of: pathComponents.last)

        for caseStr in active {
            let caseComponents = components(of: caseStr)
            let caseLen = caseComponents.count

            if caseLen > pathLen { continue }

            let caseStem = stem(of: caseComponents.last)
            if let ps = pathStem, let cs = caseStem, ps == cs {
                if caseLen == 1 { return true }
                if pathLen >= caseLen {
                    let parentsCase = caseComponents.dropLast()
                    let parentsPath = pathComponents[(pathLen - caseLen)..<(pathLen - 1)]
                    if Array(parentsCase) == Array(parentsPath) { return true }
                }
            }

            if caseLen < pathLen {
                for start in 0...(pathLen - caseLen) {
                    let window = Array(pathComponents[start..<start + caseLen])
                    if window == caseComponents { return true }
                }
            }
        }
        return false
    }

    private static func components(of path: String) -> [String] {
        path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    }

    /// File "stem" — the last path component minus a single trailing extension.
    private static func stem(of component: String?) -> String? {
        guard let c = component else { return nil }
        if let dot = c.lastIndex(of: ".") {
            return String(c[..<dot])
        }
        return c
    }
}
