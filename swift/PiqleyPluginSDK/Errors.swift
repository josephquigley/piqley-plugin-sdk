import Foundation

/// Errors thrown by the PiqleyPluginSDK.
public enum SDKError: Error, Sendable {
    case stdinReadFailed
    case payloadDecodeFailed(String)
    case unknownHook(String)
    case manifestValidationFailed([String])
}
