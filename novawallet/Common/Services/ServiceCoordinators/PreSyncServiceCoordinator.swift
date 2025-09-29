import Foundation
import Operation_iOS
import Keystore_iOS
import Foundation_iOS

protocol PreSyncServiceProtocol {
    func setup() -> CompoundOperationWrapper<Void>
    func throttle()
}

protocol PreSyncServiceCoordinatorProtocol: PreSyncServiceProtocol {
    var ahmInfoService: AHMInfoServiceProtocol { get }
}

final class PreSyncServiceCoordinator {
    var ahmInfoService: AHMInfoServiceProtocol {
        ahmInfoPreSyncService
    }

    private let ahmInfoPreSyncService: AHMInfoPreSyncServiceProtocol

    init(ahmInfoPreSyncService: AHMInfoPreSyncServiceProtocol) {
        self.ahmInfoPreSyncService = ahmInfoPreSyncService
    }
}

// MARK: - Private

private extension PreSyncServiceCoordinator {
    func createServiceArray() -> [PreSyncServiceProtocol] {
        [
            ahmInfoPreSyncService
        ]
    }
}

// MARK: - PreSyncServiceCoordinatorProtocol

extension PreSyncServiceCoordinator: PreSyncServiceCoordinatorProtocol {
    func setup() -> CompoundOperationWrapper<Void> {
        let services = createServiceArray()
        let setupWrappers = services.map { $0.setup() }

        let resultOperation: BaseOperation<Void> = ClosureOperation {
            _ = try setupWrappers.map { try $0.targetOperation.extractNoCancellableResultData() }
        }

        setupWrappers.forEach { resultOperation.addDependency($0.targetOperation) }

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: setupWrappers.flatMap(\.allOperations)
        )
    }

    func throttle() {
        createServiceArray().forEach { $0.throttle() }
    }
}

// MARK: - Factory

extension PreSyncServiceCoordinator {
    static func createDefault() -> PreSyncServiceCoordinatorProtocol {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let substrateStorage = SubstrateDataStorageFacade.shared
        let repositoryFactory = SubstrateRepositoryFactory(storageFacade: substrateStorage)

        let ahmInfoService = AHMInfoService(
            blockNumberOperationFactory: BlockNumberOperationFactory(
                chainRegistry: chainRegistry,
                operationQueue: operationQueue
            ),
            chainRegistry: chainRegistry,
            applicationHandler: ApplicationHandler(),
            ahmInfoRepository: AHMInfoRepository.shared,
            assetBalanceRepository: repositoryFactory.createAssetBalanceRepository(),
            settingsManager: SettingsManager.shared,
            operationQueue: operationQueue,
            workingQueue: .main,
            logger: Logger.shared
        )

        return PreSyncServiceCoordinator(ahmInfoPreSyncService: ahmInfoService)
    }
}
