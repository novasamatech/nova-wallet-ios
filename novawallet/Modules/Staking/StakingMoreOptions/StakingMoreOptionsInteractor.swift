import UIKit
import RobinHood

final class StakingMoreOptionsInteractor {
    weak var presenter: StakingMoreOptionsInteractorOutputProtocol?

    let dAppProvider: AnySingleValueProvider<DAppList>
    let logger: LoggerProtocol
    private let operationQueue: OperationQueue

    init(
        dAppProvider: AnySingleValueProvider<DAppList>,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.dAppProvider = dAppProvider
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func subscribeDApps() {
        let updateClosure: ([DataProviderChange<DAppList>]) -> Void = { [weak self] changes in
            if let result = changes.reduceToLastChange() {
                let dApps = result.dApps.filter {
                    $0.categories.contains("staking") == true
                }
                let stakingDApps = DAppList(categories: result.categories, dApps: dApps)
                self?.presenter?.didReceive(dAppsResult: .success(stakingDApps))
            } else {
                self?.presenter?.didReceive(dAppsResult: nil)
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter?.didReceive(dAppsResult: .failure(error))
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true, waitsInProgressSyncOnAdd: false)

        dAppProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }
}

extension StakingMoreOptionsInteractor: StakingMoreOptionsInteractorInputProtocol {}
