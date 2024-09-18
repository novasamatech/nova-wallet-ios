import Foundation
import SoraFoundation
import SubstrateSdk

final class SwipeGovVotingConfirmInteractor: ReferendumVoteInteractor {
    weak var presenter: SwipeGovVotingConfirmInteractorOutputProtocol?

    let signer: SigningWrapperProtocol

    init(
        referendumIndexes: [ReferendumIdLocal],
        selectedAccount: MetaChainAccountResponse,
        chain: ChainModel,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeFactory: BlockTimeOperationFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        currencyManager: CurrencyManagerProtocol,
        extrinsicFactory: GovernanceExtrinsicFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        signer: SigningWrapperProtocol,
        feeProxy: MultiExtrinsicFeeProxyProtocol,
        lockStateFactory: GovernanceLockStateFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.signer = signer

        super.init(
            referendumIndexes: referendumIndexes,
            selectedAccount: selectedAccount,
            chain: chain,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            referendumsSubscriptionFactory: referendumsSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            blockTimeService: blockTimeService,
            blockTimeFactory: blockTimeFactory,
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

// MARK: SwipeGovVotingConfirmInteractorInputProtocol

extension SwipeGovVotingConfirmInteractor: SwipeGovVotingConfirmInteractorInputProtocol {
    func submit(votingItems: [VotingBasketItemLocal]) {
        let votes = votingItems.mapToVotes()

        let splitter = createExtrinsicSplitter(for: votes)

        extrinsicService.submitWithTxSplitter(
            splitter,
            signer: signer,
            runningIn: .main
        ) { [weak self] result in
            if let result = result.results.compactMap({ try? $0.result.get() }).first {
                self?.presenter?.didReceiveVotingHash(result)
            } else if let error = result.errors().first {
                self?.presenter?.didReceiveError(.submitVoteFailed(error))
            }
        }
    }
}
