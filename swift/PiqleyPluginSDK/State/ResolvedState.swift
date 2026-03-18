import PiqleyCore

// MARK: - ResolvedState

/// The full resolved state passed to a plugin at invocation time.
///
/// The outer dictionary is keyed by image name. Each image has a dictionary
/// keyed by namespace (e.g. `"original"`, `"my-plugin"`), which in turn
/// holds key→value pairs for that namespace.
public struct ResolvedState: Sendable {

    /// Internal storage: [imageName: [namespace: [key: value]]]
    private let storage: [String: [String: [String: JSONValue]]]

    public init(_ storage: [String: [String: [String: JSONValue]]]) {
        self.storage = storage
    }

    /// An empty resolved state with no images.
    public static let empty = ResolvedState([:])

    /// All image names present in this state.
    public var imageNames: [String] {
        Array(storage.keys)
    }

    /// Returns the state for the named image, or an empty `ImageState` if absent.
    public subscript(imageName: String) -> ImageState {
        ImageState(storage[imageName] ?? [:])
    }

    /// Internal accessor used by mock/factory helpers.
    var rawDict: [String: [String: [String: JSONValue]]] {
        storage
    }
}

// MARK: - ImageState

/// State for a single image, organised by namespace.
public struct ImageState: Sendable {

    private let namespaces: [String: [String: JSONValue]]

    init(_ namespaces: [String: [String: JSONValue]]) {
        self.namespaces = namespaces
    }

    /// The original metadata namespace (keyed as `"original"`).
    public var original: Namespace {
        Namespace(namespaces["original"] ?? [:])
    }

    /// Returns the namespace for the given dependency plugin name.
    /// Returns an empty `Namespace` if the dependency is absent.
    public func dependency(_ name: String) -> Namespace {
        Namespace(namespaces[name] ?? [:])
    }
}

// MARK: - Namespace

/// A flat key→value store for a single namespace within an image's state.
public struct Namespace: Sendable {

    private let data: [String: JSONValue]

    init(_ data: [String: JSONValue]) {
        self.data = data
    }

    // MARK: Raw access

    /// Returns the raw `JSONValue` for the given string key, or `nil` if absent.
    public func raw(_ key: String) -> JSONValue? {
        data[key]
    }

    /// Returns the raw `JSONValue` for the given typed key, or `nil` if absent.
    public func raw<K: StateKey>(_ key: K) -> JSONValue? {
        raw(key.rawValue)
    }

    // MARK: String

    public func string(_ key: String) -> String? {
        guard case .string(let v) = data[key] else { return nil }
        return v
    }

    public func string<K: StateKey>(_ key: K) -> String? {
        string(key.rawValue)
    }

    // MARK: Int

    public func int(_ key: String) -> Int? {
        guard case .number(let v) = data[key] else { return nil }
        return Int(exactly: v) ?? (v.truncatingRemainder(dividingBy: 1) == 0 ? Int(v) : nil)
    }

    public func int<K: StateKey>(_ key: K) -> Int? {
        int(key.rawValue)
    }

    // MARK: Double

    public func double(_ key: String) -> Double? {
        guard case .number(let v) = data[key] else { return nil }
        return v
    }

    public func double<K: StateKey>(_ key: K) -> Double? {
        double(key.rawValue)
    }

    // MARK: Bool

    public func bool(_ key: String) -> Bool? {
        guard case .bool(let v) = data[key] else { return nil }
        return v
    }

    public func bool<K: StateKey>(_ key: K) -> Bool? {
        bool(key.rawValue)
    }

    // MARK: String array

    /// Returns a `[String]` if the value is an array of strings.
    /// Returns `nil` if the key is absent, not an array, or contains non-string elements.
    public func strings(_ key: String) -> [String]? {
        guard case .array(let elements) = data[key] else { return nil }
        var result: [String] = []
        for element in elements {
            guard case .string(let s) = element else { return nil }
            result.append(s)
        }
        return result
    }

    public func strings<K: StateKey>(_ key: K) -> [String]? {
        strings(key.rawValue)
    }
}
