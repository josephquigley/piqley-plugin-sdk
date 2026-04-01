import Testing
import Foundation
import PiqleyCore
@testable import PiqleyPluginSDK

@Suite("ConfigRegistry")
struct ConfigRegistryTests {
    let fm = InMemoryFileManager()

    @Test("Config creates a value ConfigEntry")
    func configCreatesValueEntry() {
        let config = Config("siteUrl", type: .string, default: .string("https://example.com"))
        #expect(config.entry == ConfigEntry.value(key: "siteUrl", type: .string, value: .string("https://example.com"), metadata: ConfigMetadata()))
    }

    @Test("Secret creates a secret ConfigEntry")
    func secretCreatesSecretEntry() {
        let secret = Secret("API_KEY", type: .string)
        #expect(secret.entry == ConfigEntry.secret(secretKey: "API_KEY", type: .string, metadata: ConfigMetadata()))
    }

    @Test("ConfigRegistry collects entries from builder")
    func registryCollectsEntries() {
        let registry = ConfigRegistry {
            Config("quality", type: .int, default: .number(85))
            Secret("TOKEN", type: .string)
        }
        #expect(registry.entries.count == 2)
        #expect(registry.entries[0] == ConfigEntry.value(key: "quality", type: .int, value: .number(85), metadata: ConfigMetadata()))
        #expect(registry.entries[1] == ConfigEntry.secret(secretKey: "TOKEN", type: .string, metadata: ConfigMetadata()))
    }

    @Test("ConfigRegistry writes config-entries.json")
    func writeConfigEntries() throws {
        let registry = ConfigRegistry {
            Config("url", type: .string, default: .string("https://example.com"))
            Secret("KEY", type: .string)
        }
        let dir = URL(fileURLWithPath: "/test/config-registry")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        try registry.writeConfigEntries(to: dir, fileManager: fm)

        let file = dir.appendingPathComponent("config-entries.json")
        let data = try fm.contents(of: file)
        let decoded = try JSONDecoder.piqley.decode([ConfigEntry].self, from: data)
        #expect(decoded.count == 2)
        #expect(decoded[0] == ConfigEntry.value(key: "url", type: .string, value: .string("https://example.com"), metadata: ConfigMetadata()))
        #expect(decoded[1] == ConfigEntry.secret(secretKey: "KEY", type: .string, metadata: ConfigMetadata()))
    }

    @Test("Empty ConfigRegistry writes empty array")
    func emptyRegistryWritesEmptyArray() throws {
        let registry = ConfigRegistry {}
        let dir = URL(fileURLWithPath: "/test/config-registry-empty")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        try registry.writeConfigEntries(to: dir, fileManager: fm)

        let data = try fm.contents(of: dir.appendingPathComponent("config-entries.json"))
        let decoded = try JSONDecoder.piqley.decode([ConfigEntry].self, from: data)
        #expect(decoded.isEmpty)
    }
}
