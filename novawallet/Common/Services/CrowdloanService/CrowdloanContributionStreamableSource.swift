import Foundation
import RobinHood

final class CrowdloanContributionStreamableSource: StreamableSourceProtocol {
    typealias Model = CrowdloanContributionData

    let syncServices: [SyncServiceProtocol]

    init(syncServices: [SyncServiceProtocol]) {
        self.syncServices = syncServices
    }

    func fetchHistory(
        runningIn queue: DispatchQueue?,
        commitNotificationBlock: ((Result<Int, Error>?) -> Void)?
    ) {
        guard let closure = commitNotificationBlock else {
            return
        }

        let result: Result<Int, Error> = Result.success(0)

        dispatchInQueueWhenPossible(queue) {
            closure(result)
        }
    }

    func refresh(
        runningIn queue: DispatchQueue?,
        commitNotificationBlock: ((Result<Int, Error>?) -> Void)?
    ) {
        syncServices.forEach {
            $0.isActive ? $0.performSyncUp() : $0.setup()
        }

        guard let closure = commitNotificationBlock else {
            return
        }

        let result: Result<Int, Error> = Result.success(0)

        dispatchInQueueWhenPossible(queue) {
            closure(result)
        }
    }
}
