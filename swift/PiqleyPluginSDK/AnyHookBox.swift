import PiqleyCore

/// Internal type-erased container for a ``Hook``-conforming type.
struct AnyHookBox: Sendable {
    private let _resolve: @Sendable (String) -> (any Hook)?
    private let _allHooks: @Sendable () -> [any Hook]

    init<H: Hook>(_ type: H.Type) {
        _resolve = { H(rawValue: $0) }
        _allHooks = { Array(H.allCases) }
    }

    func resolve(_ rawValue: String) -> (any Hook)? { _resolve(rawValue) }
    var allHooks: [any Hook] { _allHooks() }
}
