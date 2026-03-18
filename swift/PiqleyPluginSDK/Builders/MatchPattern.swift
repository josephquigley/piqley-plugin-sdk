import PiqleyCore

/// A typed match pattern that encodes to the wire format.
public enum MatchPattern: Sendable {
    case exact(String)
    case glob(String)
    case regex(String)

    /// The wire-format encoded pattern string.
    public var encoded: String {
        switch self {
        case let .exact(value): value
        case let .glob(value): "\(PatternPrefix.glob)\(value)"
        case let .regex(value): "\(PatternPrefix.regex)\(value)"
        }
    }
}
