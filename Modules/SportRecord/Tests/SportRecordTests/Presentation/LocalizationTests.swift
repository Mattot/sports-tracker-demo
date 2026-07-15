import Testing
@testable import SportRecord

@Suite("Localization")
struct LocalizationTests {
    @Test func listTitleResolvesToEnglishNotKey() {
        #expect(L10n.List.title == "Sport Records")
    }

    @Test func filterTitlesResolve() {
        #expect(RecordsFilter.all.title == "All")
        #expect(RecordsFilter.local.title == "Local")
        #expect(RecordsFilter.remote.title == "Remote")
    }

    @Test func commonStringsResolve() {
        #expect(L10n.Common.ok == "OK")
        #expect(L10n.Common.cancel == "Cancel")
        #expect(L10n.Common.delete == "Delete")
    }

    @Test func deleteSelectionButtonInterpolatesCount() {
        #expect(L10n.List.deleteSelectionButton(3) == "Delete Records (3)")
    }
}
