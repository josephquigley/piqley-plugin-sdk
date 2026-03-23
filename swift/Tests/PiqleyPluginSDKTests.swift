import Testing
@testable import PiqleyPluginSDK
import PiqleyCore

@Test func sdkImportsCore() {
    let hook: any Hook = StandardHook.publish
    #expect(hook.rawValue == "publish")
}
