import Foundation
import SubstrateSdk
import RobinHood

final class GovRevokeDelegationConfirmInteractor: GovernanceDelegateInteractor {
    var presenter: GovernanceRevokeDelegationConfirmInteractorOutputProtocol? {
        get {
            basePresenter as? GovernanceRevokeDelegationConfirmInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let delegateId: AccountId
    let signer: SigningWrapperProtocol

    init(
        selectedAccount: MetaChainAccountResponse,
        delegateId: AccountId,
        chain: ChainModel,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeFactory: BlockTimeOperationFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        currencyManager: CurrencyManagerProtocol,
        extrinsicFactory: GovernanceExtrinsicFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: MultiExtrinsicFeeProxyProtocol,
        signer: SigningWrapperProtocol,
        lockStateFactory: GovernanceLockStateFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.signer = signer
        self.delegateId = delegateId

        super.init(
            selectedAccount: selectedAccount,
            chain: chain,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            referendumsSubscriptionFactory: referendumsSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            blockTimeService: blockTimeService,
            blockTimeFactory: blockTimeFactory,
            chainRegistry: chainRegistry,
            currencyManager: currencyManager,
            extrinsicFactory: extrinsicFactory,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            lockStateFactory: lockStateFactory,
            operationQueue: operationQueue
        )
    }
}

extension GovRevokeDelegationConfirmInteractor: GovernanceRevokeDelegationConfirmInteractorInputProtocol {
    func submitRevoke(for tracks: Set<TrackIdLocal>) {
        do {
            let actions = tracks.map { GovernanceDelegatorAction(delegateId: delegateId, trackId: $0, type: .undelegate) }

            let splitter = try createExtrinsicSplitter(for: actions)

            extrinsicService.submitWithTxSplitter(
                splitter,
                signer: signer,
                runningIn: .main
            ) { [weak self] result in
                self?.presenter?.didReceiveSubmissionResult(result)
            }
        } catch {
            presenter?.didReceiveError(.submitFailed(error))
        }
    }
}
