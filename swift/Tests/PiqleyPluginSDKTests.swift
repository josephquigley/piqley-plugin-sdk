import Testing
@testable import PiqleyPluginSDK
import PiqleyCore

@Test func sdkImportsCore() {
    let hook = Hook.publish
    #expect(hook.rawValue == "publish")
}
