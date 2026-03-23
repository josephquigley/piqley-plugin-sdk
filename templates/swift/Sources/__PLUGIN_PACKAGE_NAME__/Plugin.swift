import PiqleyPluginSDK
import PiqleyCore
import PluginHooks

struct Plugin: PiqleyPlugin {
    let registry = pluginRegistry

    func handle(_ request: PluginRequest) async throws -> PluginResponse {
        switch request.hook {
        case let h as StandardHook:
            switch h {
            case .pipelineStart:
                return try await pipelineStart(request)
            case .preProcess:
                return try await preProcess(request)
            case .postProcess:
                return try await postProcess(request)
            case .publish:
                return try await publish(request)
            case .postPublish:
                return try await postPublish(request)
            case .pipelineFinished:
                return try await pipelineFinished(request)
            }
        default:
            throw SDKError.unhandledHook(request.hook.rawValue)
        }
    }

    private func pipelineStart(_ request: PluginRequest) async throws -> PluginResponse {
        // TODO: Add pipeline-start logic
        return .ok
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

    private func pipelineFinished(_ request: PluginRequest) async throws -> PluginResponse {
        // TODO: Add pipeline-finished logic
        return .ok
    }
}
