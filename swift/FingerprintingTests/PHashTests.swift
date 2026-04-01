import Testing
@testable import Fingerprinting

@Suite("PHash")
struct PHashTests {
    @Test("hash from uniform grayscale produces a valid 16-char hex string")
    func uniformGrayscale() {
        let pixels: [[Double]] = (0..<32).map { _ in [Double](repeating: 128.0, count: 32) }
        let hash = PHash.hash(from: pixels)
        #expect(hash.hash.count == 16)
        #expect(UInt64(hash.hash, radix: 16) != nil)
    }

    @Test("hash from gradient is deterministic")
    func gradientDeterministic() {
        let pixels: [[Double]] = (0..<32).map { row in
            (0..<32).map { col in Double(row * 32 + col) / 1024.0 * 255.0 }
        }
        let hash1 = PHash.hash(from: pixels)
        let hash2 = PHash.hash(from: pixels)
        #expect(hash1.hash == hash2.hash)
    }

    @Test("different images produce different hashes")
    func differentImages() {
        let horizontal: [[Double]] = (0..<32).map { row in
            (0..<32).map { col in Double(col) / 31.0 * 255.0 }
        }
        let vertical: [[Double]] = (0..<32).map { row in
            (0..<32).map { _ in Double(row) / 31.0 * 255.0 }
        }
        let h1 = PHash.hash(from: horizontal)
        let h2 = PHash.hash(from: vertical)
        #expect(h1.hash != h2.hash)
    }
}
