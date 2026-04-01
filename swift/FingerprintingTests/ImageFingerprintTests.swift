import Foundation
import Testing
@testable import Fingerprinting

@Suite("ImageFingerprint")
struct ImageFingerprintTests {
    @Test("identical hashes have zero distance")
    func identicalDistance() {
        let a = ImageFingerprint(hash: "a1b2c3d4e5f67890")
        let b = ImageFingerprint(hash: "a1b2c3d4e5f67890")
        #expect(a.distance(to: b) == 0)
    }

    @Test("completely different hashes have distance 64")
    func maxDistance() {
        let a = ImageFingerprint(hash: "0000000000000000")
        let b = ImageFingerprint(hash: "ffffffffffffffff")
        #expect(a.distance(to: b) == 64)
    }

    @Test("single bit difference gives distance 1")
    func singleBitDistance() {
        let a = ImageFingerprint(hash: "0000000000000000")
        let b = ImageFingerprint(hash: "0000000000000001")
        #expect(a.distance(to: b) == 1)
    }

    @Test("non-hex hashes use filename fallback: exact match is 0")
    func filenameFallbackExactMatch() {
        let a = ImageFingerprint(hash: "sunset.jpg")
        let b = ImageFingerprint(hash: "sunset.jpg")
        #expect(a.distance(to: b) == 0)
    }

    @Test("non-hex hashes use filename fallback: mismatch is max")
    func filenameFallbackMismatch() {
        let a = ImageFingerprint(hash: "sunset.jpg")
        let b = ImageFingerprint(hash: "beach.jpg")
        #expect(a.distance(to: b) == 64)
    }

    @Test("Codable round-trip preserves hash")
    func codableRoundTrip() throws {
        let original = ImageFingerprint(hash: "a1b2c3d4e5f67890")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ImageFingerprint.self, from: data)
        #expect(original.hash == decoded.hash)
    }
}
