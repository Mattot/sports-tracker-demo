import Testing
import Foundation
@testable import SportRecord

@MainActor
private func makeSUT() -> (AddRecordViewModel, FakeSaveSportRecordUseCase) {
    let save = FakeSaveSportRecordUseCase()
    return (AddRecordViewModel(save: save), save)
}

@Test @MainActor func canSaveRequiresNameLocationAndPositiveDuration() {
    let (sut, _) = makeSUT()
    #expect(!sut.canSave)
    sut.name = "Run";      #expect(!sut.canSave)
    sut.location = "Park"; #expect(!sut.canSave)   // duration still 0
    sut.minutes = 30;      #expect(sut.canSave)
}

@Test @MainActor func canSaveRejectsWhitespaceOnlyFields() {
    let (sut, _) = makeSUT()
    sut.name = "   "; sut.location = "   "; sut.minutes = 5
    #expect(!sut.canSave)
}

@Test @MainActor func durationComposesHoursMinutesSeconds() {
    let (sut, _) = makeSUT()
    sut.hours = 1; sut.minutes = 2; sut.seconds = 3
    #expect(sut.duration == 3723)
}

@Test @MainActor func saveSuccessBuildsTrimmedRecordAndReturnsTrue() async {
    let (sut, save) = makeSUT()
    sut.name = "  Swim  "; sut.location = "  Pool "; sut.hours = 1; sut.storageType = .remote

    let ok = await sut.save()

    #expect(ok)
    #expect(save.saved.count == 1)
    let record = save.saved.first
    #expect(record?.name == "Swim")
    #expect(record?.location == "Pool")
    #expect(record?.duration == 3600)
    #expect(record?.storageType == .remote)
    #expect(sut.saveError == nil)
}

@Test @MainActor func saveFailureSetsStorageSpecificMessageAndReturnsFalse() async {
    let (sut, save) = makeSUT()
    save.errorToThrow = AnyError()
    sut.name = "Run"; sut.location = "Park"; sut.minutes = 10; sut.storageType = .remote

    let ok = await sut.save()

    #expect(!ok)
    #expect(sut.saveError?.contains("backend") == true)   // remote-specific message
}

@Test @MainActor func saveDoesNothingWhenInvalid() async {
    let (sut, save) = makeSUT()
    let ok = await sut.save()
    #expect(!ok)
    #expect(save.saved.isEmpty)
}

@Test @MainActor func saveFailureLocalSetsLocalMessage() async {
    let (sut, save) = makeSUT()
    save.errorToThrow = AnyError()
    sut.name = "Run"; sut.location = "Park"; sut.minutes = 10; sut.storageType = .local

    let ok = await sut.save()

    #expect(!ok)
    #expect(sut.saveError?.contains("locally") == true)   // local-specific message
}

@Test @MainActor func saveSuccessClearsPriorError() async {
    let (sut, save) = makeSUT()
    save.errorToThrow = AnyError()
    sut.name = "Run"; sut.location = "Park"; sut.minutes = 10
    _ = await sut.save()
    #expect(sut.saveError != nil)

    save.errorToThrow = nil
    let ok = await sut.save()

    #expect(ok)
    #expect(sut.saveError == nil)
}
