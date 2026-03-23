import PiqleyPluginSDK
import PiqleyCore

extension PluginDirectory {
    static let pluginBinary = "\(bin)/__PLUGIN_PACKAGE_NAME__"
}

public let pluginConfig = ConfigRegistry {}

public let pluginRegistry = HookRegistry { r in
    r.register(StandardHook.self) { hook in
        switch hook {
        case .pipelineStart:
            return nil
        case .preProcess:
            return nil
        case .postProcess:
            return nil
        case .publish:
            return nil
        case .postPublish:
            return nil
        case .pipelineFinished:
            return nil
        }
    }
}
