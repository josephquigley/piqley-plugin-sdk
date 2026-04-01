import Foundation

public struct ImageFingerprint: Codable, Sendable, Equatable {
    public let hash: String

    public init(hash: String) {
        self.hash = hash
    }

    public func distance(to other: ImageFingerprint) -> Int {
        guard let selfValue = UInt64(hash, radix: 16),
              let otherValue = UInt64(other.hash, radix: 16)
        else {
            return hash == other.hash ? 0 : 64
        }
        return (selfValue ^ otherValue).nonzeroBitCount
    }

    public enum Sensitivity: String, CaseIterable, Sendable {
        case conservative
        case moderate
        case aggressive

        public var threshold: Int {
            switch self {
            case .conservative: return 5
            case .moderate: return 10
            case .aggressive: return 18
            }
        }

        public static let `default`: Sensitivity = .moderate
    }
}
