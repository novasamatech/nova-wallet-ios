import Foundation
import Keystore_iOS

final class GovAddDelegationTracksInteractor: GovernanceSelectTracksInteractor {
    private(set) var settings: SettingsManagerProtocol

    var presenter: GovAddDelegationTracksInteractorOutputProtocol? {
        get {
            basePresenter as? GovAddDelegationTracksInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    init(
        selectedAccount: ChainAccountResponse,
        subscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        fetchOperationFactory: ReferendumsOperationFactoryProtocol,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue,
        settings: SettingsManagerProtocol
    ) {
        self.settings = settings

        super.init(
            selectedAccount: selectedAccount,
            subscriptionFactory: subscriptionFactory,
            fetchOperationFactory: fetchOperationFactory,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
        )
    }

    override func setup() {
        presenter?.didReceiveRemoveVotesHintAllowed(
            !settings.skippedAddDelegationTracksHint
        )

        super.setup()
    }
}

extension GovAddDelegationTracksInteractor: GovAddDelegationTracksInteractorInputProtocol {
    func saveRemoveVotesSkipped() {
        settings.skippedAddDelegationTracksHint = true

        presenter?.didReceiveRemoveVotesHintAllowed(
            !settings.skippedAddDelegationTracksHint
        )
    }
}
