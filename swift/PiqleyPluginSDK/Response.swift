import PiqleyCore

// MARK: - PluginResponse

public struct PluginResponse: Sendable {
    public let success: Bool
    public let error: String?
    public let state: [String: PluginState]?

    public init(success: Bool, error: String? = nil, state: [String: PluginState]? = nil) {
        self.success = success
        self.error = error
        self.state = state
    }

    /// A successful response with no state changes.
    public static let ok = PluginResponse(success: true)

    /// Internal: convert to a result output line for serialisation.
    func toOutputLine() -> PluginOutputLine {
        let stateDict: [String: [String: JSONValue]]? = state?.mapValues { $0.toDict() }
        return PluginOutputLine(type: "result", success: success, error: error, state: stateDict)
    }
}
