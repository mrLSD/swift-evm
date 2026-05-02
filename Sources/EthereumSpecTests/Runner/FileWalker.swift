import Foundation

/// Recursive `*.json` discovery, with dotfile / hidden-directory exclusion.
///
/// Mirrors Rust's `run_*_test_for_dir` walker semantics — entries whose name starts with
/// `.` are skipped, matching the Rust code's `if s.starts_with('.') { continue; }`.
public enum FileWalker {
    /// Enumerate JSON file paths reachable from `root`. If `root` is itself a JSON file,
    /// returns `[root]`. The skip list is applied at *both* the directory and file level
    /// to mirror Rust's `should_skip` checks in `run_test_for_dir` and `run_test_for_file`.
    public static func enumerateJSON(at root: String, enableSlowTests: Bool = false) -> [String] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root, isDirectory: &isDir) else { return [] }

        if !isDir.boolValue {
            return root.lowercased().hasSuffix(".json") ? [root] : []
        }

        if SkipList.shouldSkip(root, enableSlowTests: enableSlowTests) { return [] }

        var results: [String] = []
        guard let enumerator = fm.enumerator(atPath: root) else { return [] }

        while let rel = enumerator.nextObject() as? String {
            if rel.split(separator: "/").contains(where: { $0.hasPrefix(".") }) {
                if let url = enumerator.directoryAttributes,
                   (url[.type] as? FileAttributeType) == .typeDirectory {
                    enumerator.skipDescendants()
                }
                continue
            }
            let full = (root as NSString).appendingPathComponent(rel)
            var subIsDir: ObjCBool = false
            guard fm.fileExists(atPath: full, isDirectory: &subIsDir) else { continue }
            if subIsDir.boolValue {
                if SkipList.shouldSkip(full, enableSlowTests: enableSlowTests) {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard rel.lowercased().hasSuffix(".json") else { continue }
            if SkipList.shouldSkip(full, enableSlowTests: enableSlowTests) { continue }
            results.append(full)
        }
        return results
    }

    /// Render a "short" test file name suitable for human output. Strips any prefix up to and
    /// including `GeneralStateTests/` if present. Matches Rust's `short_test_file_name`.
    public static func shortName(_ path: String) -> String {
        if let range = path.range(of: "GeneralStateTests/") {
            return String(path[range.upperBound...])
        }
        if let range = path.range(of: "VMTests/") {
            return String(path[range.upperBound...])
        }
        return path
    }
}
