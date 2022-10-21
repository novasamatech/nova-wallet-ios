import UIKit
import SubstrateSdk

final class ReferendumVoteConfirmInteractor: ReferendumVoteInteractor {
    weak var presenter: ReferendumVoteConfirmInteractorOutputProtocol?

    let signer: SigningWrapperProtocol

    init(
        referendumIndex: ReferendumIdLocal,
        selectedAccount: MetaChainAccountResponse,
        chain: ChainModel,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        currencyManager: CurrencyManagerProtocol,
        extrinsicFactory: GovernanceExtrinsicFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        signer: SigningWrapperProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        lockStateFactory: GovernanceLockStateFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.signer = signer

        super.init(
            referendumIndex: referendumIndex,
            selectedAccount: selectedAccount,
            chain: chain,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            referendumsSubscriptionFactory: referendumsSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            blockTimeService: blockTimeService,
            connection: connection,
            runtimeProvider: runtimeProvider,
            currencyManager: currencyManager,
            extrinsicFactory: extrinsicFactory,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            lockStateFactory: lockStateFactory,
            operationQueue: operationQueue
        )
    }
}

extension ReferendumVoteConfirmInteractor: ReferendumVoteConfirmInteractorInputProtocol {
    func submit(vote: ReferendumVoteAction) {
        let closure: ExtrinsicBuilderClosure = { [weak self] builder in
            guard let strongSelf = self else {
                return builder
            }

            return try strongSelf.extrinsicFactory.vote(
                vote,
                referendum: strongSelf.referendumIndex,
                builder: builder
            )
        }

        extrinsicService.submit(closure, signer: signer, runningIn: .main) { [weak self] result in

        }
    }
}
