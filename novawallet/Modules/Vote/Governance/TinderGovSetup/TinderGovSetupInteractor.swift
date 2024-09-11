import SoraFoundation
import SubstrateSdk
import Operation_iOS

final class TinderGovSetupInteractor: ReferendumVoteInteractor {
    weak var presenter: TinderGovSetupInteractorOutputProtocol? {
        get {
            basePresenter as? TinderGovSetupInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    private let repository: AnyDataProviderRepository<VotingPowerLocal>

    init(
        repository: AnyDataProviderRepository<VotingPowerLocal>,
        referendumIndex: ReferendumIdLocal,
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
        feeProxy: ExtrinsicFeeProxyProtocol,
        lockStateFactory: GovernanceLockStateFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.repository = repository

        super.init(
            referendumIndex: referendumIndex,
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

extension TinderGovSetupInteractor: TinderGovSetupInteractorInputProtocol {
    func process(votingPower: VotingPowerLocal) {
        let saveOperation = repository.saveOperation(
            { [votingPower] },
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
