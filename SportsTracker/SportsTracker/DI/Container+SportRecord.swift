import FactoryKit
import SwiftData
import Core
import SportRecord

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

    var fetchSportRecordsUseCase: Factory<FetchSportRecordsUseCase> {
        self { DefaultFetchSportRecordsUseCase(repository: self.sportRecordRepository()) }.cached
    }

    var deleteSportRecordsUseCase: Factory<DeleteSportRecordsUseCase> {
        self { DefaultDeleteSportRecordsUseCase(repository: self.sportRecordRepository()) }.cached
    }
}
