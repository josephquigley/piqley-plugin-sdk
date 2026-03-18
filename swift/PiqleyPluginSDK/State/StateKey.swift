/// A typed key for reading from or writing to plugin state.
///
/// Conform your own string-backed enum to `StateKey` to get compile-time
/// safety when accessing state fields:
///
/// ```swift
/// enum MyKeys: String, StateKey {
///     static let namespace = "my-plugin"
///     case keywords
///     case caption
/// }
/// ```
public protocol StateKey: RawRepresentable, Sendable where RawValue == String {
    /// The namespace this key belongs to (plugin name, or "original" for image metadata).
    static var namespace: String { get }
}
