import Core
import FactoryKit
import SportRecord
import SwiftData

extension Container {
    var networkMonitor: Factory<NetworkMonitor> {
        self { PathNetworkMonitor() }.singleton
    }

    var modelContainer: Factory<ModelContainer> {
        self {
            do {
                return try SportRecordStorage.makeModelContainer()
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }.singleton
    }

    var localSportRecordDataSource: Factory<LocalSportRecordDataSource> {
        self { SportRecordStorage.makeLocalDataSource(container: self.modelContainer()) }.singleton
    }

    var remoteSportRecordDataSource: Factory<RemoteSportRecordDataSource> {
        self { SportRecordStorage.makeRemoteDataSource() }.singleton
    }

    var sportRecordRepository: Factory<SportRecordRepository> {
        self {
            DefaultSportRecordRepository(
                local: self.localSportRecordDataSource(),
                remote: self.remoteSportRecordDataSource()
            )
        }.singleton
    }

    var deleteSportRecordsUseCase: Factory<DeleteSportRecordsUseCase> {
        self { DefaultDeleteSportRecordsUseCase(repository: self.sportRecordRepository()) }.cached
    }

    var saveSportRecordUseCase: Factory<SaveSportRecordUseCase> {
        self { DefaultSaveSportRecordUseCase(repository: self.sportRecordRepository()) }.cached
    }

    var fetchLocalRecordsUseCase: Factory<FetchLocalRecordsUseCase> {
        self { DefaultFetchLocalRecordsUseCase(repository: self.sportRecordRepository()) }.cached
    }

    var observeRemoteRecordsUseCase: Factory<ObserveRemoteRecordsUseCase> {
        self { DefaultObserveRemoteRecordsUseCase(repository: self.sportRecordRepository()) }.cached
    }
}
