import Testing
@testable import SportRecord

@Suite("Localization")
struct LocalizationTests {
    @Test func listTitleResolvesToEnglishNotKey() {
        #expect(L10n.List.title == "Sport Records")
    }
}
