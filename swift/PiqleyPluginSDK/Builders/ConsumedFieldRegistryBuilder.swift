import Foundation
import PiqleyCore

// MARK: - FieldRegistry

/// A registry of fields built with a result builder DSL.
///
/// Plugin authors declare the state fields their plugin works with:
/// ```swift
/// public let pluginFields = FieldRegistry {
///     Consumes(.title, type: "string", description: "Post title")
///     Outputs(.day_diff, type: "int", description: "Days difference")
/// }
/// ```
public struct FieldRegistry: Sendable {
    public let fields: [ConsumedField]

    public init(@FieldBuilder _ builder: () -> [ConsumedField]) {
        self.fields = builder()
    }

    /// Writes the registry's fields to `fields.json` in the given directory.
    public func writeFields(to directory: URL) throws {
        let data = try JSONEncoder.piqleyPrettyPrint.encode(fields)
        try data.write(
            to: directory.appendingPathComponent("fields.json"),
            options: .atomic
        )
    }
}

// MARK: - Consumes

/// A consumed (writable) field declaration for use in `FieldRegistry`.
public struct Consumes: Sendable {
    let fields: [ConsumedField]

    /// Declare a single consumed field from a `StateKey` case with optional metadata.
    public init<K: StateKey>(_ key: K, type: String? = nil, description: String? = nil) {
        self.fields = [ConsumedField(name: key.rawValue, type: type, description: description, readOnly: false)]
    }

    /// Bulk-declare all cases of a `StateKey & CaseIterable` enum.
    public init<K: StateKey & CaseIterable>(_ type: K.Type) {
        self.fields = K.allCases.map { ConsumedField(name: $0.rawValue, readOnly: false) }
    }

    /// Declare a consumed field by raw name with optional metadata.
    public init(_ name: String, type: String? = nil, description: String? = nil) {
        self.fields = [ConsumedField(name: name, type: type, description: description, readOnly: false)]
    }
}

// MARK: - Outputs

/// A read-only output field declaration for use in `FieldRegistry`.
///
/// Output fields are visible in match conditions but cannot be targeted
/// by emit or write actions in the rules editor.
public struct Outputs: Sendable {
    let fields: [ConsumedField]

    /// Declare a single output field from a `StateKey` case with optional metadata.
    public init<K: StateKey>(_ key: K, type: String? = nil, description: String? = nil) {
        self.fields = [ConsumedField(name: key.rawValue, type: type, description: description, readOnly: true)]
    }

    /// Bulk-declare all cases of a `StateKey & CaseIterable` enum as read-only output fields.
    public init<K: StateKey & CaseIterable>(_ type: K.Type) {
        self.fields = K.allCases.map { ConsumedField(name: $0.rawValue, readOnly: true) }
    }

    /// Declare an output field by raw name with optional metadata.
    public init(_ name: String, type: String? = nil, description: String? = nil) {
        self.fields = [ConsumedField(name: name, type: type, description: description, readOnly: true)]
    }
}

// MARK: - FieldBuilder

@resultBuilder
public enum FieldBuilder {
    public static func buildBlock(_ components: [ConsumedField]...) -> [ConsumedField] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: Consumes) -> [ConsumedField] {
        expression.fields
    }

    public static func buildExpression(_ expression: Outputs) -> [ConsumedField] {
        expression.fields
    }
}
