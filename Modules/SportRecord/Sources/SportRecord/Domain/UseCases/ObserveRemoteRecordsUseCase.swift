import Foundation

public protocol ObserveRemoteRecordsUseCase: Sendable {
    func callAsFunction() -> AsyncThrowingStream<[SportRecord], Error>
}

public struct DefaultObserveRemoteRecordsUseCase: ObserveRemoteRecordsUseCase {
    private let repository: SportRecordRepository

    public init(repository: SportRecordRepository) {
        self.repository = repository
    }

    public func callAsFunction() -> AsyncThrowingStream<[SportRecord], any Error> {
        repository.observeRemote()
    }
}
