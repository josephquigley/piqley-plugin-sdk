import PiqleyCore

/// Internal type-erased container for a ``Hook``-conforming type.
struct AnyHookBox: Sendable {
    private let _resolve: @Sendable (String) -> (any Hook)?
    private let _allHooks: @Sendable () -> [any Hook]

    /// Cached stage configs from the override closure, keyed by hook rawValue.
    /// nil when no override closure was provided.
    let stageConfigCache: [String: StageConfig]?

    init<H: Hook>(_ type: H.Type) {
        _resolve = { H(rawValue: $0) }
        _allHooks = { Array(H.allCases) }
        stageConfigCache = nil
    }

    init<H: Hook>(_ type: H.Type, stageConfigProvider: @escaping (H) -> StageConfig?) {
        _resolve = { H(rawValue: $0) }
        _allHooks = { Array(H.allCases) }
        var cache: [String: StageConfig] = [:]
        for hook in H.allCases {
            if let config = stageConfigProvider(hook) {
                cache[hook.rawValue] = config
            }
        }
        stageConfigCache = cache
    }

    func resolve(_ rawValue: String) -> (any Hook)? { _resolve(rawValue) }
    var allHooks: [any Hook] { _allHooks() }
}
