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
}
