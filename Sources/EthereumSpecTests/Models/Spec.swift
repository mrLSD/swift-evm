import Interpreter

/// Ethereum hard-fork descriptor used in spec test JSON.
///
/// Mirrors `aurora-evm::Spec` 1:1, including `Petersburg` which the existing
/// Swift `HardFork` enum does **not** distinguish. `toHardFork()` collapses
/// `Petersburg` → `Constantinople` so the rest of the runtime can stay on the
/// existing `HardFork` API.
///
/// Conforms to `Decodable` from a single JSON string. The string accepts the
/// canonical fork names plus the historical aliases used in the corpus
/// (e.g. `EIP150`, `BerlinToLondonAt5`).
public enum Spec: UInt8, CaseIterable, Comparable, Hashable, Sendable {
    case Frontier
    case Homestead
    /// EIP-150
    case Tangerine
    /// EIP-158
    case SpuriousDragon
    case Byzantium
    case Constantinople
    case Petersburg
    case Istanbul
    case Berlin
    case London
    /// Paris (the Merge)
    case Merge
    case Shanghai
    case Cancun
    case Prague
    case Osaka

    public static func < (lhs: Spec, rhs: Spec) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Parse from the JSON spec name, accepting the historical aliases used in
    /// upstream Ethereum tests (`EIP150`, `BerlinToLondonAt5`, etc.).
    public init?(rawString: String) {
        switch rawString {
        case "Frontier": self = .Frontier
        case "Homestead", "FrontierToHomesteadAt5": self = .Homestead
        case "EIP150", "HomesteadToDaoAt5", "HomesteadToEIP150At5": self = .Tangerine
        case "EIP158": self = .SpuriousDragon
        case "Byzantium", "EIP158ToByzantiumAt5": self = .Byzantium
        case "Constantinople",
             "ConstantinopleFix",
             "ByzantiumToConstantinopleAt5",
             "ByzantiumToConstantinopleFixAt5":
            self = .Constantinople
        case "Petersburg": self = .Petersburg
        case "Istanbul": self = .Istanbul
        case "Berlin": self = .Berlin
        case "London", "BerlinToLondonAt5": self = .London
        case "Merge", "Paris": self = .Merge
        case "Shanghai": self = .Shanghai
        case "Cancun": self = .Cancun
        case "Prague": self = .Prague
        case "Osaka": self = .Osaka
        default: return nil
        }
    }

    /// Canonical name (matches Rust's `Spec` enum variant name).
    public var canonicalName: String {
        switch self {
        case .Frontier: "Frontier"
        case .Homestead: "Homestead"
        case .Tangerine: "Tangerine"
        case .SpuriousDragon: "SpuriousDragon"
        case .Byzantium: "Byzantium"
        case .Constantinople: "Constantinople"
        case .Petersburg: "Petersburg"
        case .Istanbul: "Istanbul"
        case .Berlin: "Berlin"
        case .London: "London"
        case .Merge: "Merge"
        case .Shanghai: "Shanghai"
        case .Cancun: "Cancun"
        case .Prague: "Prague"
        case .Osaka: "Osaka"
        }
    }

    /// Map to the existing Swift `HardFork` enum.
    /// Petersburg has no dedicated `HardFork` case; behaviorally it equals Constantinople
    /// for opcode-level execution, so we collapse it.
    public func toHardFork() -> HardFork {
        switch self {
        case .Frontier: .Frontier
        case .Homestead: .Homestead
        case .Tangerine: .Tangerine
        case .SpuriousDragon: .SpuriousDragon
        case .Byzantium: .Byzantium
        case .Constantinople, .Petersburg: .Constantinople
        case .Istanbul: .Istanbul
        case .Berlin: .Berlin
        case .London: .London
        case .Merge: .Paris
        case .Shanghai: .Shanghai
        case .Cancun: .Cancun
        case .Prague: .Prague
        case .Osaka: .Osaka
        }
    }

    /// Mirrors Rust's `get_gasometer_config()`: returns `nil` for pre-Istanbul forks
    /// because aurora-evm has no `Config::*` constructor for them. The runner uses
    /// this signal to *skip* such tests rather than execute them.
    public var hasExecutableConfig: Bool {
        switch self {
        case .Frontier, .Homestead, .Tangerine, .SpuriousDragon,
             .Byzantium, .Constantinople, .Petersburg:
            false
        case .Istanbul, .Berlin, .London, .Merge,
             .Shanghai, .Cancun, .Prague, .Osaka:
            true
        }
    }
}

extension Spec: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let parsed = Spec(rawString: raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown Spec value: '\(raw)'"
            )
        }
        self = parsed
    }
}
