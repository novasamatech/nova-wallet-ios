import UIKit

final class MythosStkYourCollatorsInteractor {
    weak var presenter: MythosStkYourCollatorsInteractorOutputProtocol?

    let stakingDetailsService: MythosStakingDetailsSyncServiceProtocol
    let operationQueue: OperationQueue

    init(
        stakingDetailsService: MythosStakingDetailsSyncServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.stakingDetailsService = stakingDetailsService
        self.operationQueue = operationQueue
    }
}

private extension MythosStkYourCollatorsInteractor {
    func makeDetailsSubscription() {
        stakingDetailsService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            if let newState {
                self?.provideCollators()
                self?.presenter?.didReceiveStakingDetails(newState)
            }
        }
    }

    func provideCollators() {}
}

extension MythosStkYourCollatorsInteractor: MythosStkYourCollatorsInteractorInputProtocol {
    func setup() {
        makeDetailsSubscription()
    }

    func retry() {
        provideCollators()
    }
}
