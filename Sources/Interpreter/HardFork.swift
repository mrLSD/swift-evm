enum HardFork: UInt8, CustomStringConvertible, CaseIterable {
    case Istanbul
    case Berlin
    case London
    case Paris
    case Shanghai
    case Cancun
    case Prague
    case Osaka

    static func latest() -> Self {
        .Prague
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
            case .Istanbul:
                "Istanbul"
            case .Berlin:
                "Berlin"
            case .London:
                "London"
            case .Paris:
                "Paris"
            case .Shanghai:
                "Shanghai"
            case .Cancun:
                "Cancun"
            case .Prague:
                "Prague"
            case .Osaka:
                "Osaka"
        }
    }
}
