import Foundation
import Operation_iOS

final class ExternalAssetBalanceStreambleSource: StreamableSourceProtocol {
    typealias Model = ExternalAssetBalance
    typealias CommitNotificationBlock = ((Result<Int, Error>?) -> Void)

    let automaticSyncServices: [SyncServiceProtocol]
    let pollingSyncServices: [SyncServiceProtocol]
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let eventCenter: EventCenterProtocol

    init(
        automaticSyncServices: [SyncServiceProtocol],
        pollingSyncServices: [SyncServiceProtocol],
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        eventCenter: EventCenterProtocol
    ) {
        self.automaticSyncServices = automaticSyncServices
        self.pollingSyncServices = pollingSyncServices
        self.chainAssetId = chainAssetId
        self.accountId = accountId
        self.eventCenter = eventCenter

        eventCenter.add(observer: self)

        (automaticSyncServices + pollingSyncServices).forEach {
            $0.setup()
        }
    }

    deinit {
        (automaticSyncServices + pollingSyncServices).forEach {
            $0.stopSyncUp()
        }
    }

    func fetchHistory(
        runningIn queue: DispatchQueue?,
        commitNotificationBlock: CommitNotificationBlock?
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
        commitNotificationBlock: CommitNotificationBlock?
    ) {
        pollingSyncServices.forEach {
            $0.syncUp()
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

extension ExternalAssetBalanceStreambleSource: EventVisitorProtocol {
    func processAssetBalanceChanged(event: AssetBalanceChanged) {
        guard event.accountId == accountId, event.chainAssetId == chainAssetId else {
            return
        }

        refresh(runningIn: nil, commitNotificationBlock: nil)
    }
}
