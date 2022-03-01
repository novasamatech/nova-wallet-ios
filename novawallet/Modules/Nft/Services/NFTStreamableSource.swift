import Foundation
import RobinHood

final class NftStreamableSource: StreamableSourceProtocol {
    typealias Model = NftModel

    let syncServices: [NftSyncServiceProtocol]

    init(syncServices: [NftSyncServiceProtocol]) {
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

        if let queue = queue {
            queue.async {
                closure(result)
            }
        } else {
            closure(result)
        }
    }

    func refresh(
        runningIn queue: DispatchQueue?,
        commitNotificationBlock: ((Result<Int, Error>?) -> Void)?
    ) {
        syncServices.forEach { $0.syncUp() }

        guard let closure = commitNotificationBlock else {
            return
        }

        let result: Result<Int, Error> = Result.success(0)

        if let queue = queue {
            queue.async {
                closure(result)
            }
        } else {
            closure(result)
        }
    }
}
