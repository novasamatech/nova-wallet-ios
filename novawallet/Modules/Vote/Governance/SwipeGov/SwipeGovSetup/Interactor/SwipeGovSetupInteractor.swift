import Foundation
import Foundation_iOS
import SubstrateSdk
import Operation_iOS

class SwipeGovSetupInteractor: BaseSwipeGovSetupInteractor {
    private let repository: AnyDataProviderRepository<VotingPowerLocal>

    init(
        repository: AnyDataProviderRepository<VotingPowerLocal>,
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
        let saveOperation = repository.saveOperation({ [votingPower] }, { [] })

        execute(
            operation: saveOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.didProcessVotingPower(votingPower)
            case let .failure(error):
                self?.presenter?.didReceiveBaseError(.votingPowerSaveFailed(error))
            }
        }
    }
}
