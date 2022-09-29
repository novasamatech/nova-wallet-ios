import Foundation
import RobinHood

final class CrowdloanContributionStreamableSource: StreamableSourceProtocol {
    typealias Model = CrowdloanContributionData
    typealias CommitNotificationBlock = ((Result<Int, Error>?) -> Void)

    let syncServices: [SyncServiceProtocol]
    let chainId: ChainModel.Id
    let accountId: AccountId
    let eventCenter: EventCenterProtocol

    init(
        syncServices: [SyncServiceProtocol],
        chainId: ChainModel.Id,
        accountId: AccountId,
        eventCenter: EventCenterProtocol
    ) {
        self.syncServices = syncServices
        self.eventCenter = eventCenter
        self.chainId = chainId
        self.accountId = accountId

        self.eventCenter.add(observer: self)

        syncServices.forEach {
            $0.setup()
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
        syncServices.forEach {
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

extension CrowdloanContributionStreamableSource: EventVisitorProtocol {
    func processAssetBalanceChanged(event: AssetBalanceChanged) {
        guard event.accountId == accountId, event.chainAssetId.chainId == chainId else {
            return
        }
        refresh(runningIn: nil, commitNotificationBlock: nil)
    }
}
