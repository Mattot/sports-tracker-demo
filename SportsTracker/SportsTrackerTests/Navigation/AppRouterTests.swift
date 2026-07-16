import Testing
@testable import SportsTracker

/// `Route` is an uninhabited enum today, so `path` can only ever be empty — the
/// pop tests therefore verify the empty-path guards rather than real pops. Add
/// push/pop-of-a-real-destination coverage alongside the first `Route` case.
@MainActor
struct AppRouterTests {

    // MARK: - Initial state

    @Test func startsWithEmptyPathAndNoSheet() {
        let router = AppRouter()
        #expect(router.path.isEmpty)
        #expect(router.sheet == nil)
    }

    // MARK: - Sheet presentation

    @Test func presentSetsTheSheet() {
        let router = AppRouter()
        router.present(.addRecord(onSaved: {}))
        #expect(router.sheet?.id == .addRecord)
    }

    @Test func dismissSheetClearsTheSheet() {
        let router = AppRouter()
        router.present(.addRecord(onSaved: {}))
        router.dismissSheet()
        #expect(router.sheet == nil)
    }

    @Test func presentReplacesAnExistingSheet() {
        let router = AppRouter()
        router.present(.addRecord(onSaved: {}))
        router.present(.addRecord(onSaved: {}))
        #expect(router.sheet?.id == .addRecord)  // still exactly one sheet
    }

    @Test func presentedSheetCarriesTheOnSavedCallback() {
        let router = AppRouter()
        var savedCount = 0
        router.present(.addRecord(onSaved: { savedCount += 1 }))

        guard case let .addRecord(onSaved)? = router.sheet else {
            Issue.record("expected an .addRecord sheet")
            return
        }
        onSaved()

        #expect(savedCount == 1)
    }

    @Test func dismissSheetWhenNothingPresentedIsANoOp() {
        let router = AppRouter()
        router.dismissSheet()
        #expect(router.sheet == nil)
    }

    // MARK: - Stack (empty-path guards)

    @Test func popOnEmptyPathIsANoOp() {
        let router = AppRouter()
        router.pop()
        #expect(router.path.isEmpty)
    }

    @Test func popToRootOnEmptyPathIsANoOp() {
        let router = AppRouter()
        router.popToRoot()
        #expect(router.path.isEmpty)
    }
}

// MARK: - Sheet identity

@MainActor
struct SheetTests {
    @Test func addRecordSheetIsIdentifiedByAddRecord() {
        let sheet = Sheet.addRecord(onSaved: {})
        #expect(sheet.id == .addRecord)
    }
}
