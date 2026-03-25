import Foundation
import PiqleyCore

// MARK: - ConsumedFieldRegistry

/// A registry of consumed fields built with a result builder DSL.
///
/// Plugin authors declare the state fields their plugin works with:
/// ```swift
/// public let pluginConsumedFields = ConsumedFieldRegistry {
///     Consumes(GhostField.self)  // auto-extracts all cases
///     // or individual fields with metadata:
///     Consumes(.title, type: "string", description: "Post title")
///     Consumes(.tags, type: "csv", description: "Comma-separated tag names")
/// }
/// ```
public struct ConsumedFieldRegistry: Sendable {
    public let fields: [ConsumedField]

    public init(@ConsumedFieldBuilder _ builder: () -> [ConsumedField]) {
        self.fields = builder()
    }

    /// Writes the registry's consumed fields to `consumed-fields.json` in the given directory.
    public func writeConsumedFields(to directory: URL) throws {
        let data = try JSONEncoder.piqleyPrettyPrint.encode(fields)
        try data.write(
            to: directory.appendingPathComponent("consumed-fields.json"),
            options: .atomic
        )
    }
}

// MARK: - Consumes

/// A single consumed field declaration for use in `ConsumedFieldRegistry`.
public struct Consumes: Sendable {
    let consumed: [ConsumedField]

    /// Declare a single consumed field from a `StateKey` case with optional metadata.
    public init<K: StateKey>(_ key: K, type: String? = nil, description: String? = nil) {
        self.consumed = [ConsumedField(name: key.rawValue, type: type, description: description)]
    }

    /// Bulk-declare all cases of a `StateKey & CaseIterable` enum.
    public init<K: StateKey & CaseIterable>(_ type: K.Type) {
        self.consumed = K.allCases.map { ConsumedField(name: $0.rawValue) }
    }

    /// Declare a consumed field by raw name with optional metadata.
    public init(_ name: String, type: String? = nil, description: String? = nil) {
        self.consumed = [ConsumedField(name: name, type: type, description: description)]
    }
}

// MARK: - ConsumedFieldBuilder

@resultBuilder
public enum ConsumedFieldBuilder {
    public static func buildBlock(_ components: Consumes...) -> [ConsumedField] {
        components.flatMap(\.consumed)
    }

    public static func buildExpression(_ expression: Consumes) -> Consumes {
        expression
    }
}
