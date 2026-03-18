import PiqleyCore

/// Mutable state written by a plugin during a hook invocation.
///
/// Use the typed setters to populate state, then call `toDict()` to obtain
/// the raw dictionary for serialisation.
public struct PluginState: Sendable {

    private var data: [String: JSONValue] = [:]

    public init() {}

    /// Returns the underlying dictionary of all set values.
    public func toDict() -> [String: JSONValue] {
        data
    }

    // MARK: - String-keyed setters

    public mutating func set(_ key: String, to value: String) {
        data[key] = .string(value)
    }

    public mutating func set(_ key: String, to values: [String]) {
        data[key] = .array(values.map { .string($0) })
    }

    public mutating func set(_ key: String, to value: Int) {
        data[key] = .number(Double(value))
    }

    public mutating func set(_ key: String, to value: Bool) {
        data[key] = .bool(value)
    }

    public mutating func set(_ key: String, to value: Double) {
        data[key] = .number(value)
    }

    public mutating func set(_ key: String, to value: JSONValue) {
        data[key] = value
    }

    // MARK: - Typed StateKey overloads

    public mutating func set<K: StateKey>(_ key: K, to value: String) {
        set(key.rawValue, to: value)
    }

    public mutating func set<K: StateKey>(_ key: K, to values: [String]) {
        set(key.rawValue, to: values)
    }

    public mutating func set<K: StateKey>(_ key: K, to value: Int) {
        set(key.rawValue, to: value)
    }

    public mutating func set<K: StateKey>(_ key: K, to value: Bool) {
        set(key.rawValue, to: value)
    }

    public mutating func set<K: StateKey>(_ key: K, to value: Double) {
        set(key.rawValue, to: value)
    }

    public mutating func set<K: StateKey>(_ key: K, to value: JSONValue) {
        set(key.rawValue, to: value)
    }
}
