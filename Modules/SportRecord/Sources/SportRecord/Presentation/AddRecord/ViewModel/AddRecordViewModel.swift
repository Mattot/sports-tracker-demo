import Foundation
import Observation

@MainActor
@Observable
public final class AddRecordViewModel {
    private let saveUseCase: SaveSportRecordUseCase

    public var name = ""
    public var location = ""
    public var hours = 0
    public var minutes = 0
    public var seconds = 0
    public var storageType: StorageType = .local
    public private(set) var isSaving = false
    public var saveError: String?

    public init(save: SaveSportRecordUseCase) {
        self.saveUseCase = save
    }

    public var duration: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    public var canSave: Bool {
        !name.trimmed.isEmpty && !location.trimmed.isEmpty && duration > 0 && !isSaving
    }

    /// Returns `true` on success so the view can fire its `onSaved` navigation
    /// closure; on failure sets `saveError` and returns `false`, leaving the
    /// form intact for retry.
    public func save() async -> Bool {
        guard canSave else { return false }
        saveError = nil
        isSaving = true
        defer { isSaving = false }

        let record = SportRecord(
            id: UUID(),
            name: name.trimmed,
            location: location.trimmed,
            duration: duration,
            storageType: storageType,
            createdAt: Date()
        )
        do {
            try await saveUseCase.execute(record)
            return true
        } catch {
            saveError = message(for: storageType)
            return false
        }
    }

    private func message(for storageType: StorageType) -> String {
        switch storageType {
        case .remote: L10n.AddRecord.saveErrorRemote
        case .local: L10n.AddRecord.saveErrorLocal
        }
    }
}

extension String {
    fileprivate var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
