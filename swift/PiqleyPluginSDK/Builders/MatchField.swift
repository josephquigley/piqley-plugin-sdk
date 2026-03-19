import PiqleyCore

/// A typed reference to a state field for use in rule matching.
public struct MatchField: Sendable {
    /// The wire-format encoded field string ("namespace:field").
    public let encoded: String

    /// Match against core-extracted image metadata.
    public static func original(_ key: ImageMetadataKey) -> MatchField {
        MatchField(encoded: "\(ImageMetadataKey.namespace):\(key.rawValue)")
    }

    /// Match against a dependency's state using a typed key (namespace derived from StateKey).
    public static func dependency<K: StateKey>(_ key: K) -> MatchField {
        MatchField(encoded: "\(K.namespace):\(key.rawValue)")
    }

    /// Match against a dependency's state with raw strings.
    public static func dependency(_ plugin: String, key: String) -> MatchField {
        MatchField(encoded: "\(plugin):\(key)")
    }

    /// Match against current image file metadata (read: namespace).
    public static func read(_ key: String) -> MatchField {
        MatchField(encoded: "read:\(key)")
    }
}
