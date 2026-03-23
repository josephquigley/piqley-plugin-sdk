import Testing
import Foundation
import PiqleyCore
@testable import PiqleyPluginSDK

@Suite("ConfigRegistry")
struct ConfigRegistryTests {
    @Test("Config creates a value ConfigEntry")
    func configCreatesValueEntry() {
        let config = Config("siteUrl", type: .string, default: .string("https://example.com"))
        #expect(config.entry == ConfigEntry.value(key: "siteUrl", type: .string, value: .string("https://example.com")))
    }

    @Test("Secret creates a secret ConfigEntry")
    func secretCreatesSecretEntry() {
        let secret = Secret("API_KEY", type: .string)
        #expect(secret.entry == ConfigEntry.secret(secretKey: "API_KEY", type: .string))
    }

    @Test("ConfigRegistry collects entries from builder")
    func registryCollectsEntries() {
        let registry = ConfigRegistry {
            Config("quality", type: .int, default: .number(85))
            Secret("TOKEN", type: .string)
        }
        #expect(registry.entries.count == 2)
        #expect(registry.entries[0] == ConfigEntry.value(key: "quality", type: .int, value: .number(85)))
        #expect(registry.entries[1] == ConfigEntry.secret(secretKey: "TOKEN", type: .string))
    }

    @Test("ConfigRegistry writes config-entries.json")
    func writeConfigEntries() throws {
        let registry = ConfigRegistry {
            Config("url", type: .string, default: .string("https://example.com"))
            Secret("KEY", type: .string)
        }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try registry.writeConfigEntries(to: dir)

        let file = dir.appendingPathComponent("config-entries.json")
        let data = try Data(contentsOf: file)
        let decoded = try JSONDecoder().decode([ConfigEntry].self, from: data)
        #expect(decoded.count == 2)
        #expect(decoded[0] == ConfigEntry.value(key: "url", type: .string, value: .string("https://example.com")))
        #expect(decoded[1] == ConfigEntry.secret(secretKey: "KEY", type: .string))
    }

    @Test("Empty ConfigRegistry writes empty array")
    func emptyRegistryWritesEmptyArray() throws {
        let registry = ConfigRegistry {}
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try registry.writeConfigEntries(to: dir)

        let data = try Data(contentsOf: dir.appendingPathComponent("config-entries.json"))
        let decoded = try JSONDecoder().decode([ConfigEntry].self, from: data)
        #expect(decoded.isEmpty)
    }
}
