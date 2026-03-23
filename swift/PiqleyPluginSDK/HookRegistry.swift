import Foundation
import PiqleyCore

/// Resolves hook strings from JSON payloads into typed ``Hook`` values
/// and enumerates all registered hooks for stage file generation.
///
/// Create a registry at your plugin's entry point:
/// ```swift
/// let registry = HookRegistry { r in
///     r.register(StandardHook.self)
///     r.register(MyCustomHook.self)
/// }
/// ```
public final class HookRegistry: Sendable {
    private let boxes: [AnyHookBox]

    public init(_ registrations: (Registrar) -> Void) {
        let registrar = Registrar()
        registrations(registrar)
        self.boxes = registrar.boxes
    }

    /// Resolves a raw hook string into a typed ``Hook`` value.
    /// Returns `nil` if no registered type recognizes the string.
    public func resolve(_ rawValue: String) -> (any Hook)? {
        for box in boxes {
            if let hook = box.resolve(rawValue) {
                return hook
            }
        }
        return nil
    }

    /// All hooks across all registered types, preserving registration order.
    public var allHooks: [any Hook] {
        boxes.flatMap { $0.allHooks }
    }

    /// Builder used during ``HookRegistry`` initialization.
    public final class Registrar {
        fileprivate var boxes: [AnyHookBox] = []

        /// Register a ``Hook``-conforming enum type.
        public func register<H: Hook>(_ type: H.Type) {
            boxes.append(AnyHookBox(type))
        }
    }
}

/// Writes stage files for all hooks in the registry to the given directory.
///
/// Used by the SDK's `run()` method when the binary receives `--create-stage-files <dir>`.
extension HookRegistry {
    func writeStageFiles(to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        for hook in allHooks {
            let config = hook.stageConfig
            guard !config.isEmpty else { continue }
            let filename = "\(PluginFile.stagePrefix)\(hook.rawValue)\(PluginFile.stageSuffix)"
            let data = try encoder.encode(config)
            try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
        }
    }
}
