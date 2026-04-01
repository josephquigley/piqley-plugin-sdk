import Foundation

/// Errors thrown by the PiqleyPluginSDK.
public enum SDKError: Error, Sendable {
    case stdinReadFailed
    case payloadDecodeFailed(String)
    case unknownHook(String)
    case unhandledHook(String)
    case manifestValidationFailed([String])
}

extension SDKError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .stdinReadFailed:
            return "Failed to read payload from standard input."
        case .payloadDecodeFailed(let detail):
            return "Failed to decode plugin payload: \(detail)"
        case .unknownHook(let hook):
            return "Unknown hook '\(hook)'. The plugin does not recognize this hook."
        case .unhandledHook(let hook):
            return "Unhandled hook '\(hook)'. The plugin has no handler registered for this hook."
        case .manifestValidationFailed(let errors):
            return "Manifest validation failed: \(errors.joined(separator: "; "))"
        }
    }
}
