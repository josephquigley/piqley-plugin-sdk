import Testing
@testable import PiqleyPluginSDK
import PiqleyCore

@Test func sdkImportsCore() {
    let hook: any Hook = StandardHook.publish
    #expect(hook.rawValue == "publish")
}

@Test func anyHookBoxCachesStageConfigs() {
    let box = AnyHookBox(StandardHook.self) { hook in
        switch hook {
        case .publish:
            return StageConfig(binary: HookConfig(command: "bin/test"))
        default:
            return nil
        }
    }
    #expect(box.stageConfigCache?["publish"] != nil)
    #expect(box.stageConfigCache?["publish"]?.binary?.command == "bin/test")
    #expect(box.stageConfigCache?["pre-process"] == nil)
}

@Test func anyHookBoxWithoutOverrideHasNilCache() {
    let box = AnyHookBox(StandardHook.self)
    #expect(box.stageConfigCache == nil)
}
