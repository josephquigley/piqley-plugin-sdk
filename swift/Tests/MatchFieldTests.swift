import Testing
@testable import PiqleyPluginSDK

// MARK: - Test helper

private enum HashtagKeys: String, StateKey {
    static let namespace = "hashtag"
    case tags
    case caption
}

// MARK: - MatchField tests

@Test func matchFieldOriginalModel() {
    let field = MatchField.original(.model)
    #expect(field.encoded == "original:TIFF:Model")
}

@Test func matchFieldOriginalKeywords() {
    let field = MatchField.original(.keywords)
    #expect(field.encoded == "original:IPTC:Keywords")
}

@Test func matchFieldDependencyTypedKey() {
    let field = MatchField.dependency(HashtagKeys.tags)
    #expect(field.encoded == "hashtag:tags")
}

@Test func matchFieldDependencyTypedKeyCaption() {
    let field = MatchField.dependency(HashtagKeys.caption)
    #expect(field.encoded == "hashtag:caption")
}

@Test func matchFieldDependencyRawStrings() {
    let field = MatchField.dependency("my-plugin", key: "some-key")
    #expect(field.encoded == "my-plugin:some-key")
}

// MARK: - MatchPattern tests

@Test func matchPatternExact() {
    let pattern = MatchPattern.exact("Sony")
    #expect(pattern.encoded == "Sony")
}

@Test func matchPatternGlob() {
    let pattern = MatchPattern.glob("*.jpg")
    #expect(pattern.encoded == "glob:*.jpg")
}

@Test func matchPatternRegex() {
    let pattern = MatchPattern.regex("^Canon.*")
    #expect(pattern.encoded == "regex:^Canon.*")
}
