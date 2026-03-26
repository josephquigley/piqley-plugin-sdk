import Testing
import Foundation
import JSONSchema
@testable import PiqleyPluginSDK
import PiqleyCore

// MARK: - Schema conformance test suite

@Suite("Schema Conformance")
struct SchemaConformanceTests {

    // MARK: - Helpers

    /// Loads a JSON Schema from the test bundle's schemas resource directory.
    private func loadSchema(_ filename: String) throws -> [String: Any] {
        let url = Bundle.module.url(forResource: filename, withExtension: nil, subdirectory: "schemas")!
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data)
        return json as! [String: Any]
    }

    /// Parses encoded JSON Data into a JSONSerialization-compatible value.
    private func parseJSON(_ data: Data) throws -> Any {
        try JSONSerialization.jsonObject(with: data)
    }

    /// Validates a JSON instance against a schema and returns the validation result.
    private func validate(_ instance: Any, against schemaFile: String) throws -> ValidationResult {
        let schema = try loadSchema(schemaFile)
        return try JSONSchema.validate(instance, schema: schema)
    }

    // MARK: - Manifest schema tests

    @Test func validManifestConformsToSchema() throws {
        let manifest = try buildManifest {
            Identifier("com.test.my-plugin")
            Name("My Plugin")
            ProtocolVersion("1")
        }

        let data = try manifest.encode()
        let instance = try parseJSON(data)
        let result = try validate(instance, against: "manifest.schema.json")
        #expect(result.valid, "Minimal manifest should conform to schema: \(result.errors)")
    }

    @Test func manifestWithAllFieldsConformsToSchema() throws {
        let manifest = PluginManifest(
            identifier: "com.test.full-plugin",
            name: "Full Plugin",
            description: "A full-featured plugin",
            pluginSchemaVersion: "1",
            pluginVersion: SemanticVersion(major: 1, minor: 2, patch: 3),
            config: [
                .value(key: "quality", type: .int, value: .number(80), metadata: ConfigMetadata()),
                .secret(secretKey: "API_KEY", type: .string, metadata: ConfigMetadata()),
            ],
            setup: SetupConfig(command: "setup.sh", args: ["--verbose"]),
            dependencies: [
                PluginDependency(
                    url: "https://github.com/example/original.piqleyplugin",
                    version: VersionConstraint(
                        from: SemanticVersion(major: 1, minor: 0, patch: 0),
                        rule: .upToNextMajor
                    )
                ),
            ]
        )

        let data = try manifest.encode()
        let instance = try parseJSON(data)
        let result = try validate(instance, against: "manifest.schema.json")
        #expect(result.valid, "Full manifest should conform to schema: \(result.errors)")
    }

    @Test func invalidProtocolVersionRejectedBySchema() throws {
        let json: [String: Any] = [
            "identifier": "com.test.bad-plugin",
            "name": "bad-plugin",
            "pluginSchemaVersion": "99"
        ]

        let result = try validate(json, against: "manifest.schema.json")
        #expect(!result.valid, "Protocol version '99' should be rejected by the schema")
    }

    // MARK: - Config schema tests

    @Test func validConfigConformsToSchema() throws {
        let config = buildConfig {
            Values {
                "quality" => 80
                "enabled" => true
            }
        }

        let data = try JSONEncoder.piqleyPrettyPrint.encode(config)
        let instance = try parseJSON(data)
        let result = try validate(instance, against: "config.schema.json")
        #expect(result.valid, "Config should conform to schema: \(result.errors)")
    }

    // MARK: - Build manifest schema tests

    @Test func validBuildManifestConformsToSchema() throws {
        let json: [String: Any] = [
            "pluginName": "my-plugin",
            "pluginSchemaVersion": "1",
            "bin": [
                "macos-arm64": ["my-plugin"]
            ] as [String: Any],
            "data": [
                "macos-arm64": ["resources/template.txt"]
            ] as [String: Any],
            "dependencies": [
                [
                    "url": "https://github.com/example/dep.piqleyplugin",
                    "version": [
                        "from": "1.0.0",
                        "rule": "upToNextMajor"
                    ]
                ] as [String: Any]
            ]
        ]

        let result = try validate(json, against: "build-manifest.schema.json")
        #expect(result.valid, "Build manifest should conform to schema: \(result.errors)")
    }

    // MARK: - Plugin input schema tests

    @Test func validPluginInputConformsToSchema() throws {
        let json: [String: Any] = [
            "hook": "pre-process",
            "imageFolderPath": "/tmp/photos",
            "pluginConfig": ["quality": 80],
            "secrets": ["API_KEY": "secret-value"],
            "executionLogPath": "/tmp/log.json",
            "dataPath": "/tmp/data",
            "logPath": "/tmp/plugin.log",
            "dryRun": false,
            "pluginVersion": "1.0.0",
            "state": [
                "original": [
                    "img001.jpg": ["TIFF:Model": "Sony A7R"]
                ]
            ]
        ]

        let result = try validate(json, against: "plugin-input.schema.json")
        #expect(result.valid, "Plugin input should conform to schema: \(result.errors)")
    }

    // MARK: - Plugin output schema tests

    @Test func validPluginOutputProgressConformsToSchema() throws {
        let json: [String: Any] = [
            "type": "progress",
            "message": "Processing image 1 of 10"
        ]

        let result = try validate(json, against: "plugin-output.schema.json")
        #expect(result.valid, "Progress output should conform to schema: \(result.errors)")
    }

    @Test func validPluginOutputResultConformsToSchema() throws {
        let json: [String: Any] = [
            "type": "result",
            "success": true,
            "state": [
                "hashtag": [
                    "img001.jpg": ["tags": "nature, landscape"]
                ]
            ]
        ]

        let result = try validate(json, against: "plugin-output.schema.json")
        #expect(result.valid, "Result output should conform to schema: \(result.errors)")
    }
}
