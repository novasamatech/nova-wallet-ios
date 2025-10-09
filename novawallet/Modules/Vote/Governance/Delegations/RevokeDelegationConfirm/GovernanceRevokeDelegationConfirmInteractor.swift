import Foundation
import SubstrateSdk
import Operation_iOS

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
        timelineService: ChainTimelineFacadeProtocol,
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
            timelineService: timelineService,
            chainRegistry: chainRegistry,
            currencyManager: currencyManager,
            extrinsicFactory: extrinsicFactory,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            lockStateFactory: lockStateFactory,
            operationQueue: operationQueue
        )
    }

    func handleMultiExtrinsicSubmission(result: SubmitIndexedExtrinsicResult) {
        presenter?.didReceiveSubmissionResult(result)
    }
}

extension GovRevokeDelegationConfirmInteractor: GovernanceRevokeDelegationConfirmInteractorInputProtocol {
    func submitRevoke(for tracks: Set<TrackIdLocal>) {
        do {
            let actions = tracks.map { trackId in
                GovernanceDelegatorAction(delegateId: delegateId, trackId: trackId, type: .undelegate)
            }

            let splitter = try createExtrinsicSplitter(for: actions)

            extrinsicService.submitWithTxSplitter(
                splitter,
                signer: signer,
                runningIn: .main
            ) { [weak self] result in
                self?.handleMultiExtrinsicSubmission(result: result)
            }
        } catch {
            presenter?.didReceiveError(.submitFailed(error))
        }
    }
}
