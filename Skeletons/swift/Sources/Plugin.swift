import PiqleyPluginSDK

@main
struct Plugin: PiqleyPlugin {
    static func main() async {
        await Plugin().run()
    }

    func handle(_ request: PluginRequest) async throws -> PluginResponse {
        switch request.hook {
        case .preProcess:
            return try await preProcess(request)
        case .postProcess:
            return try await postProcess(request)
        case .publish:
            return try await publish(request)
        case .postPublish:
            return try await postPublish(request)
        }
    }

    private func preProcess(_ request: PluginRequest) async throws -> PluginResponse {
        // TODO: Add pre-process logic
        return .ok
    }

    private func postProcess(_ request: PluginRequest) async throws -> PluginResponse {
        // TODO: Add post-process logic
        return .ok
    }

    private func publish(_ request: PluginRequest) async throws -> PluginResponse {
        // TODO: Add publish logic
        return .ok
    }

    private func postPublish(_ request: PluginRequest) async throws -> PluginResponse {
        // TODO: Add post-publish logic
        return .ok
    }
}
