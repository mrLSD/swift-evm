public struct I256: BigUInt {
    private let bytes: [UInt64]

    public static let numberBytes: UInt8 = 32
    public static let MAX: Self = getMax
    public static let ZERO: Self = getZero
    public static let SIGN_BIT_MASK: U256 = .init(from: [
        0xffff_ffff_ffff_ffff,
        0xffff_ffff_ffff_ffff,
        0xffff_ffff_ffff_ffff,
        0x7fff_ffff_ffff_ffff
    ])
    public private(set) var signExtend: Bool

    public var BYTES: [UInt64] { self.bytes }

    public init(from value: [UInt64]) {
        precondition(value.count == Self.numberBase, "I256 must be initialized with \(Self.numberBase) UInt64 values.")
        self.bytes = value
        self.signExtend = false
    }

    public init(from value: [UInt64], signExtend: Bool) {
        precondition(value.count == Self.numberBase, "I256 must be initialized with \(Self.numberBase) UInt64 values.")
        self.bytes = value
        self.signExtend = signExtend
    }

    public static func fromU256(_ val: U256) -> Self {
        if (val & self.SIGN_BIT_MASK) == val {
            return I256(from: val.BYTES)
        } else {
            let n = ~val + U256(from: 1)
            return I256(from: n.BYTES, signExtend: true)
        }
    }

    public var toU256: U256 {
        if self.signExtend {
            let n = ~self + Self(from: 1)
            return U256(from: n.BYTES)
        } else {
            return U256(from: self.BYTES)
        }
    }

    /// Bitwise operations. Only shifting right, as for negative number it will be Shift Arithmetic Right (SAR).
    func shiftRight(_ shift: Int) -> Self {
        if self.isZero || shift >= 256 {
            if self.signExtend {
                // value is `< 0`, pushing `-1`
                return Self(from: [1, 0, 0, 0], signExtend: true)
            } else {
                // value is 0 or `>= 1`, pushing 0
                return Self.ZERO
            }
        } else {
            // `Value < 0`
            if self.signExtend {
                let val = ((U256(from: self.BYTES) - U256(from: 1)) >> shift) + U256(from: 1)
                return Self(from: val.BYTES, signExtend: true)
            } else {
                let val = self.toU256 >> shift
                return Self(from: val.BYTES)
            }
        }
    }

    /// Minimum value of I256.
    public static let minValue: Self =
        .init(from: ((U256.MAX & Self.SIGN_BIT_MASK) + U256(from: 1)).BYTES, signExtend: true)

    /// `I256` division operation
    func div(rhs: Self) -> Self {
        if rhs.isZero {
            return Self.ZERO
        }

        // MIN_VALUE / 1  == MIN_VALUE
        if self == Self.minValue, rhs.BYTES == [1, 0, 0, 0] {
            return Self.minValue
        }

        var d = self.divRem(divisor: rhs).quotient & I256(from: Self.SIGN_BIT_MASK.BYTES)
        if d.isZero {
            return Self.ZERO
        }

        switch (self.signExtend, rhs.signExtend) {
        case (true, true):
            return d
        case (false, false):
            return d
        default:
            // `positive / negative` or `negative / positive` division returns negative number.
            // Return value with minus flag
            d.signExtend = true
            return d
        }
    }

    /// `I256` remainder operation
    func rem(rhs: Self) -> Self {
        var r = self.divRem(divisor: rhs).remainder & I256(from: Self.SIGN_BIT_MASK.BYTES)
        if r.isZero {
            return Self.ZERO
        }
        // Set `signExtend` from initial value
        r.signExtend = self.signExtend
        return r
    }
}

/// Implementation of `Equatable`
/// NOTE: Other `Equatable` functions related to `BigUInt`
public extension I256 {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs.signExtend, rhs.signExtend) {
        case (true, true):
            lhs.BYTES == rhs.BYTES
        case (false, false):
            lhs.BYTES == rhs.BYTES
        case (true, false):
            false
        case (false, true):
            false
        }
    }

    /// Operator `!=`: Check if two `BigUInt` values are not equal
    static func != (lhs: Self, rhs: Self) -> Bool {
        !(lhs == rhs)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        switch (lhs.signExtend, rhs.signExtend) {
        case (true, true):
            self.cmpLess(lhs: rhs, rhs: lhs)
        case (false, false):
            self.cmpLess(lhs: lhs, rhs: rhs)
        case (true, false):
            true
        case (false, true):
            false
        }
    }

    /// Operator `>`: Compare two `BigUInt` values
    static func > (lhs: Self, rhs: Self) -> Bool {
        rhs < lhs
    }

    /// Operator `<=`: Compare two `BigUInt` values for less than or equal
    static func <= (lhs: Self, rhs: Self) -> Bool {
        !(lhs > rhs)
    }

    /// Operator `>=`: Compare two `BigUInt` values for less than or equal
    static func >= (lhs: Self, rhs: Self) -> Bool {
        !(lhs < rhs)
    }
}

/// Bitwise operations. Only shifting right, as for negative number it will be Shift Arithmetic Right (SAR).
/// Other shifting operations related to `BigUInt`.
public extension I256 {
    static func >> (lhs: Self, shift: Int) -> Self {
        lhs.shiftRight(shift)
    }
}

public extension I256 {
    /// Division of two values of the same type.
    static func / (lhs: Self, rhs: Self) -> Self {
        lhs.div(rhs: rhs)
    }

    /// Remainder of two values of the same type.
    static func % (lhs: Self, rhs: Self) -> Self {
        lhs.rem(rhs: rhs)
    }
}
