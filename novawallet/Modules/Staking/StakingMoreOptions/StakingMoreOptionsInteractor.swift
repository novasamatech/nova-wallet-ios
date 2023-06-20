import UIKit
import RobinHood

final class StakingMoreOptionsInteractor {
    weak var presenter: StakingMoreOptionsInteractorOutputProtocol?

    let dAppProvider: AnySingleValueProvider<DAppList>
    let stakingStateObserver: Observable<StakingDashboardModel>
    private let operationQueue: OperationQueue

    init(
        dAppProvider: AnySingleValueProvider<DAppList>,
        stakingStateObserver: Observable<StakingDashboardModel>,
        operationQueue: OperationQueue
    ) {
        self.dAppProvider = dAppProvider
        self.stakingStateObserver = stakingStateObserver
        self.operationQueue = operationQueue
    }

    private func subscribeDApps() {
        dAppProvider.removeObserver(self)

        let updateClosure: ([DataProviderChange<DAppList>]) -> Void = { [weak self] changes in
            if let result = changes.reduceToLastChange() {
                let dApps = result.dApps.filter {
                    $0.categories.contains(KnownDAppCategory.staking.rawValue) == true
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

    private func subscribeStakingState() {
        presenter?.didReceive(moreOptions: stakingStateObserver.state.more)

        stakingStateObserver.addObserver(with: self, queue: .main) { [weak self] oldState, newState in
            if oldState.more != newState.more {
                self?.presenter?.didReceive(moreOptions: newState.more)
            }
        }
    }
}

extension StakingMoreOptionsInteractor: StakingMoreOptionsInteractorInputProtocol {
    func setup() {
        subscribeStakingState()
        subscribeDApps()
    }

    func remakeDAppsSubscription() {
        subscribeDApps()
    }
}
