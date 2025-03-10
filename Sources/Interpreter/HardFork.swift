enum HardFork: UInt8, CustomStringConvertible, CaseIterable {
    // Frontier               0
    case Frontier
    // Homestead              1150000
    case Homestead
    // Tangerine Whistle      2463000
    case Tangerine
    // Spurious Dragon        267500
    case SpuriousDragon
    // Byzantium              4370000
    case Byzantium
    // Constantinople         7280000
    case Constantinople
    // Istanbul               9069000
    case Istanbul
    // Berlin                 12244000
    case Berlin
    // London                 2965000
    case London
    // Paris/Merge            15537394
    case Paris
    // Shanghai               17034870
    case Shanghai
    // Cancun                 19426587 (Timestamp: 1710338135)
    case Cancun
    // Prague                 TBD
    case Prague
    // Osaka                  TBD
    case Osaka

    static func latest() -> Self {
        .Prague
    }

    func isFrontier() -> Bool {
        self.rawValue >= Self.Frontier.rawValue
    }

    func isHomestead() -> Bool {
        self.rawValue >= Self.Homestead.rawValue
    }

    func isTangerine() -> Bool {
        self.rawValue >= Self.Tangerine.rawValue
    }

    func isSpuriousDragon() -> Bool {
        self.rawValue >= Self.SpuriousDragon.rawValue
    }

    func isByzantium() -> Bool {
        self.rawValue >= Self.Byzantium.rawValue
    }

    func isConstantinople() -> Bool {
        self.rawValue >= Self.Constantinople.rawValue
    }

    func isIstanbul() -> Bool {
        self.rawValue >= Self.Istanbul.rawValue
    }

    func isBerlin() -> Bool {
        self.rawValue >= Self.Berlin.rawValue
    }

    func isLondon() -> Bool {
        self.rawValue >= Self.London.rawValue
    }

    func isParis() -> Bool {
        self.rawValue >= Self.Paris.rawValue
    }

    func isShanghai() -> Bool {
        self.rawValue >= Self.Shanghai.rawValue
    }

    func isCancun() -> Bool {
        self.rawValue >= Self.Cancun.rawValue
    }

    func isPrague() -> Bool {
        self.rawValue >= Self.Prague.rawValue
    }

    func isOsaka() -> Bool {
        self.rawValue >= Self.Osaka.rawValue
    }

    public var description: String {
        switch self {
        case .Frontier: "Frontier"
        case .Homestead: "Homestead"
        case .Tangerine: "Tangerine"
        case .SpuriousDragon: "SpuriousDragon"
        case .Byzantium: "Byzantium"
        case .Constantinople: "Constantinople"
        case .Istanbul: "Istanbul"
        case .Berlin: "Berlin"
        case .London: "London"
        case .Paris: "Paris"
        case .Shanghai: "Shanghai"
        case .Cancun: "Cancun"
        case .Prague: "Prague"
        case .Osaka: "Osaka"
        }
    }
}
