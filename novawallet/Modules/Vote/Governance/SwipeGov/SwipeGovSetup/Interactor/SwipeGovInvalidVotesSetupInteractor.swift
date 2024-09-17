import Foundation
import SoraFoundation
import Operation_iOS
import SubstrateSdk

final class SwipeGovInvalidVotesSetupInteractor: BaseSwipeGovSetupInteractor {
    private let repository: AnyDataProviderRepository<VotingBasketItemLocal>
    private let invalidItems: [VotingBasketItemLocal]

    init(
        repository: AnyDataProviderRepository<VotingBasketItemLocal>,
        invalidItems: [VotingBasketItemLocal],
        selectedAccount: MetaChainAccountResponse,
        observableState: ReferendumsObservableState,
        chain: ChainModel,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeFactory: BlockTimeOperationFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        currencyManager: CurrencyManagerProtocol,
        lockStateFactory: GovernanceLockStateFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.repository = repository
        self.invalidItems = invalidItems

        super.init(
            selectedAccount: selectedAccount,
            observableState: observableState,
            chain: chain,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            blockTimeService: blockTimeService,
            blockTimeFactory: blockTimeFactory,
            connection: connection,
            runtimeProvider: runtimeProvider,
            currencyManager: currencyManager,
            lockStateFactory: lockStateFactory,
            operationQueue: operationQueue
        )
    }

    override func process(votingPower: VotingPowerLocal) {
        let updatedItems = invalidItems.map { $0.replacing(votingPower) }

        let saveOperation = repository.saveOperation(
            { updatedItems },
            { [] }
        )

        execute(
            operation: saveOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.didProcessVotingPower()
            case let .failure(error):
                self?.presenter?.didReceiveBaseError(.votingPowerSaveFailed(error))
            }
        }
    }
}
