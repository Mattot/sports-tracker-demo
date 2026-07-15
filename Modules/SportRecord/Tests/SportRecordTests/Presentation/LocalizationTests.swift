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

    @Test func storageLabelsResolve() {
        #expect(StorageType.local.label == "Local")
        #expect(StorageType.remote.label == "Remote")
    }

    @Test func saveErrorMessagesKeepAssertedSubstrings() {
        #expect(L10n.AddRecord.saveErrorRemote.contains("backend"))
        #expect(L10n.AddRecord.saveErrorLocal.contains("locally"))
    }

    // Regression guards (requested in Task 2 code review): lock in the %@ format
    // accessors and the en one/other plural so a later refactor to String(format:)
    // for the plural, or a specifier arity change, fails loudly.
    @Test func emptyFilteredFormatAccessorsInterpolate() {
        #expect(L10n.List.emptyFilteredTitle("Local") == "No Local Records")
        #expect(L10n.List.emptyFilteredMessage("local") == "You have no local records yet.")
    }

    @Test func deleteConfirmTitlePluralizesInEnglish() {
        #expect(L10n.List.deleteConfirmTitle(1) == "Delete 1 record?")
        #expect(L10n.List.deleteConfirmTitle(5) == "Delete 5 records?")
    }
}
