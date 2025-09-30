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

    func updateOnAppBecomeActive() -> CompoundOperationWrapper<Void>
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
    var allServices: [PreSyncServiceProtocol] {
        [
            ahmInfoPreSyncService
        ]
    }

    var appBecomeActiveUpdateGroup: [PreSyncServiceProtocol] {
        [
            ahmInfoPreSyncService
        ]
    }

    func setup(serviceGroup: [PreSyncServiceProtocol]) -> CompoundOperationWrapper<Void> {
        let setupWrappers = serviceGroup.map { $0.setup() }

        let resultOperation: BaseOperation<Void> = ClosureOperation {
            _ = try setupWrappers.map { try $0.targetOperation.extractNoCancellableResultData() }
        }

        setupWrappers.forEach { resultOperation.addDependency($0.targetOperation) }

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: setupWrappers.flatMap(\.allOperations)
        )
    }
}

// MARK: - PreSyncServiceCoordinatorProtocol

extension PreSyncServiceCoordinator: PreSyncServiceCoordinatorProtocol {
    func setup() -> CompoundOperationWrapper<Void> {
        setup(serviceGroup: allServices)
    }

    func throttle() {
        allServices.forEach { $0.throttle() }
    }

    func updateOnAppBecomeActive() -> CompoundOperationWrapper<Void> {
        let group = appBecomeActiveUpdateGroup
        group.forEach { $0.throttle() }

        return setup(serviceGroup: group)
    }
}

// MARK: - Factory

extension PreSyncServiceCoordinator {
    static func createDefault() -> PreSyncServiceCoordinatorProtocol {
        let snapshot = AHMInfoService.Snapshot(
            initialBalances: [:],
            ahmInfoRepository: AHMInfoRepository.shared
        )

        return PreSyncServiceCoordinator(
            ahmInfoPreSyncService: snapshot.restoreService(with: \.ahmInfoShownChains)
        )
    }
}
