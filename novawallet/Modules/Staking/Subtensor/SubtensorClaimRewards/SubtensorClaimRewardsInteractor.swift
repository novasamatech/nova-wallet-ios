import Foundation

final class SubtensorClaimRewardsInteractor: SubtensorBaseInteractor {
    var presenter: SubtensorClaimRewardsInteractorOutputProtocol? {
        get {
            basePresenter as? SubtensorClaimRewardsInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let pendingRootClaims: SubtensorPendingRootClaimsProtocol

    override init(
        flowServices: SubtensorFlowServices,
        state: SubtensorSharedStateProtocol,
        logger: LoggerProtocol
    ) {
        pendingRootClaims = state.flowState.pendingRootClaims

        super.init(flowServices: flowServices, state: state, logger: logger)
    }
}

extension SubtensorClaimRewardsInteractor: SubtensorClaimRewardsInteractorInputProtocol {
    func refreshPendingClaims(for claimable: [SubtensorRootClaimPreview]?) {
        let hotkeys = pendingRootClaims.pendingHotkeys(
            for: selectedAccount.accountId,
            at: Date(),
            claimable: claimable
        )

        presenter?.didReceive(pendingClaimHotkeys: hotkeys)
    }
}
