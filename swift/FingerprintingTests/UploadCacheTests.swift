import Foundation
import Testing
@testable import Fingerprinting

@Suite("UploadCache")
struct UploadCacheTests {
    @Test("empty cache returns no match")
    func emptyCache() {
        let cache = UploadCache(filePath: "/tmp/test-upload-cache-empty.json")
        let fp = ImageFingerprint(hash: "a1b2c3d4e5f67890")
        #expect(cache.findMatch(for: fp, threshold: 10) == nil)
    }

    @Test("exact hash match returns entry")
    func exactMatch() {
        var cache = UploadCache(filePath: "/tmp/test-upload-cache-exact.json")
        cache.add(hash: "a1b2c3d4e5f67890", filename: "sunset.jpg", editorURL: "https://example.com/editor/1")
        let fp = ImageFingerprint(hash: "a1b2c3d4e5f67890")
        let match = cache.findMatch(for: fp, threshold: 10)
        #expect(match != nil)
        #expect(match?.filename == "sunset.jpg")
        #expect(match?.editorURL == "https://example.com/editor/1")
    }

    @Test("near match within threshold returns entry")
    func nearMatch() {
        var cache = UploadCache(filePath: "/tmp/test-upload-cache-near.json")
        cache.add(hash: "0000000000000000", filename: "sunset.jpg", editorURL: "https://example.com/editor/1")
        let fp = ImageFingerprint(hash: "000000000000000f")
        let match = cache.findMatch(for: fp, threshold: 10)
        #expect(match != nil)
    }

    @Test("match beyond threshold returns nil")
    func beyondThreshold() {
        var cache = UploadCache(filePath: "/tmp/test-upload-cache-beyond.json")
        cache.add(hash: "0000000000000000", filename: "sunset.jpg", editorURL: "https://example.com/editor/1")
        let fp = ImageFingerprint(hash: "ffffffffffffffff")
        let match = cache.findMatch(for: fp, threshold: 10)
        #expect(match == nil)
    }

    @Test("save and load round-trip preserves entries")
    func saveLoadRoundTrip() throws {
        let path = "/tmp/test-upload-cache-roundtrip.json"
        try? FileManager.default.removeItem(atPath: path)

        var cache = UploadCache(filePath: path)
        cache.add(hash: "a1b2c3d4e5f67890", filename: "sunset.jpg", editorURL: "https://example.com/editor/1")
        try cache.save()

        let loaded = UploadCache(filePath: path)
        let match = loaded.findMatch(for: ImageFingerprint(hash: "a1b2c3d4e5f67890"), threshold: 0)
        #expect(match != nil)
        #expect(match?.filename == "sunset.jpg")

        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("remove by hash filters out matching entries")
    func removeByHash() {
        var cache = UploadCache(filePath: "/tmp/test-upload-cache-remove.json")
        cache.add(hash: "aaaa000000000000", filename: "a.jpg", editorURL: "https://example.com/editor/1")
        cache.add(hash: "bbbb000000000000", filename: "b.jpg", editorURL: "https://example.com/editor/2")
        cache.remove(hash: "aaaa000000000000")
        let removed = cache.findMatch(for: ImageFingerprint(hash: "aaaa000000000000"), threshold: 0)
        let kept = cache.findMatch(for: ImageFingerprint(hash: "bbbb000000000000"), threshold: 0)
        #expect(removed == nil)
        #expect(kept != nil)
    }

    @Test("remove by hash handles multiple entries with same hash")
    func removeByHashMultiple() {
        var cache = UploadCache(filePath: "/tmp/test-upload-cache-remove-multi.json")
        cache.add(hash: "aaaa000000000000", filename: "a1.jpg", editorURL: "https://example.com/editor/1")
        cache.add(hash: "aaaa000000000000", filename: "a2.jpg", editorURL: "https://example.com/editor/2")
        cache.remove(hash: "aaaa000000000000")
        let match = cache.findMatch(for: ImageFingerprint(hash: "aaaa000000000000"), threshold: 0)
        #expect(match == nil)
    }

    @Test("filename fallback: exact match works")
    func filenameFallback() {
        var cache = UploadCache(filePath: "/tmp/test-upload-cache-fname.json")
        cache.add(hash: "sunset.jpg", filename: "sunset.jpg", editorURL: "https://example.com/editor/1")
        let fp = ImageFingerprint(hash: "sunset.jpg")
        let match = cache.findMatch(for: fp, threshold: 10)
        #expect(match != nil)
    }
}
