/// Errors that can occur when dealing with hex strings.
public enum HexStringError: Error, Equatable {
    /// An invalid character was found. Valid ones are: `0...9`, `a...f`
    /// or `A...F`.
    /// The associated `String` contains the invalid character or the two-character
    /// hex substring that couldn't be parsed (e.g. "0G").
    case InvalidHexCharacter(String)

    /// If the hex string is decoded into a fixed sized container, such as an
    /// array, the hex string's length has to match the container's length * 2.
    case InvalidStringLength
}
