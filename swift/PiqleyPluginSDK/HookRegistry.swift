import Foundation
import PiqleyCore

/// Resolves hook strings from JSON payloads into typed ``Hook`` values
/// and enumerates all registered hooks for stage file generation.
///
/// Create a registry at your plugin's entry point:
/// ```swift
/// let registry = HookRegistry { r in
///     r.register(StandardHook.self) { hook in
///         switch hook {
///         case .publish:
///             return buildStage { Binary(command: "bin/my-plugin") }
///         default:
///             return nil
///         }
///     }
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

        /// Register a ``Hook``-conforming enum type with a stage config override.
        /// The closure is evaluated eagerly for each case. Return a ``StageConfig``
        /// for hooks the plugin handles, or `nil` to skip.
        public func register<H: Hook>(_ type: H.Type, stageConfig: @escaping (H) -> StageConfig?) {
            boxes.append(AnyHookBox(type, stageConfigProvider: stageConfig))
        }
    }
}

/// Writes stage files for registered hooks to the given directory.
///
/// For hooks registered with a stage config override closure, the cached
/// configs are used. For hooks without an override, falls back to
/// ``Hook/stageConfig``. Effectively empty configs are skipped.
extension HookRegistry {
    public func writeStageFiles(to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        for box in boxes {
            if let cache = box.stageConfigCache {
                // Override path: write cached configs
                for (hookName, config) in cache {
                    guard !config.isEffectivelyEmpty else { continue }
                    let filename = "\(PluginFile.stagePrefix)\(hookName)\(PluginFile.stageSuffix)"
                    let data = try encoder.encode(config)
                    try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
                }
            } else {
                // Fallback path: use hook.stageConfig
                for hook in box.allHooks {
                    let config = hook.stageConfig
                    guard !config.isEffectivelyEmpty else { continue }
                    let filename = "\(PluginFile.stagePrefix)\(hook.rawValue)\(PluginFile.stageSuffix)"
                    let data = try encoder.encode(config)
                    try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
                }
            }
        }
    }
}
