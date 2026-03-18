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

    public mutating func set(_ key: String, _ value: String) {
        data[key] = .string(value)
    }

    public mutating func set(_ key: String, _ value: [String]) {
        data[key] = .array(value.map { .string($0) })
    }

    public mutating func set(_ key: String, _ value: Int) {
        data[key] = .number(Double(value))
    }

    public mutating func set(_ key: String, _ value: Bool) {
        data[key] = .bool(value)
    }

    public mutating func set(_ key: String, _ value: Double) {
        data[key] = .number(value)
    }

    public mutating func set(_ key: String, _ value: JSONValue) {
        data[key] = value
    }

    // MARK: - Typed StateKey overloads

    public mutating func set<K: StateKey>(_ key: K, _ value: String) {
        set(key.rawValue, value)
    }

    public mutating func set<K: StateKey>(_ key: K, _ value: [String]) {
        set(key.rawValue, value)
    }

    public mutating func set<K: StateKey>(_ key: K, _ value: Int) {
        set(key.rawValue, value)
    }

    public mutating func set<K: StateKey>(_ key: K, _ value: Bool) {
        set(key.rawValue, value)
    }

    public mutating func set<K: StateKey>(_ key: K, _ value: Double) {
        set(key.rawValue, value)
    }

    public mutating func set<K: StateKey>(_ key: K, _ value: JSONValue) {
        set(key.rawValue, value)
    }
}
