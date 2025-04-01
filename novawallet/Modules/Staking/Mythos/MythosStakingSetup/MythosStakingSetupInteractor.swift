import UIKit
import SubstrateSdk
import Operation_iOS

final class MythosStakingSetupInteractor: MythosStakingBaseInteractor {
    var presenter: MythosStakingSetupInteractorOutputProtocol? {
        get {
            basePresenter as? MythosStakingSetupInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let preferredCollatorFactory: PreferredStakingCollatorFactoryProtocol?
    let rewardService: CollatorStakingRewardCalculatorServiceProtocol
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let connection: JSONRPCEngine
    let identityProxyFactory: IdentityProxyFactoryProtocol

    private var collatorSubscription: CallbackStorageSubscription<MythosStakingPallet.CandidateInfo>?
    private var delegatorIdentityCancellable = CancellableCallStore()

    private lazy var localKeyFactory = LocalStorageKeyFactory()

    init(
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        stakingDetailsService: MythosStakingDetailsSyncServiceProtocol,
        claimableRewardsService: MythosStakingClaimableRewardsServiceProtocol,
        stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        rewardService: CollatorStakingRewardCalculatorServiceProtocol,
        preferredCollatorFactory: PreferredStakingCollatorFactoryProtocol?,
        extrinsicService: ExtrinsicServiceProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        identityProxyFactory: IdentityProxyFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.preferredCollatorFactory = preferredCollatorFactory
        self.rewardService = rewardService
        self.repositoryFactory = repositoryFactory
        self.connection = connection
        self.identityProxyFactory = identityProxyFactory

        super.init(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            stakingDetailsService: stakingDetailsService,
            claimableRewardsService: claimableRewardsService,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            extrinsicService: extrinsicService,
            runtimeProvider: runtimeProvider,
            currencyManager: currencyManager,
            operationQueue: operationQueue,
            logger: logger
        )
    }

    deinit {
        delegatorIdentityCancellable.cancel()
    }

    override func onSetup() {
        super.onSetup()

        providePreferredCollator()
        provideRewardCalculator()
    }

    override func onStakingDetails(_ stakingDetails: MythosStakingDetails?) {
        super.onStakingDetails(stakingDetails)

        if let stakingDetails, !stakingDetails.stakeDistribution.isEmpty {
            provideIdentities(for: Array(stakingDetails.stakeDistribution.keys))
        }
    }
}

private extension MythosStakingSetupInteractor {
    func provideRewardCalculator() {
        let operation = rewardService.fetchCalculatorOperation()

        execute(
            operation: operation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(calculator):
                self?.presenter?.didReceiveRewardCalculator(calculator)
            case let .failure(error):
                self?.logger.error("Reward calculator error: \(error)")
            }
        }
    }

    func subscribeRemoteCollator(for accountId: AccountId) {
        collatorSubscription = nil

        do {
            let storagePath = MythosStakingPallet.candidatesPath
            let localKey = try localKeyFactory.createFromStoragePath(
                storagePath,
                accountId: accountId,
                chainId: chainAsset.chain.chainId
            )

            let repository = repositoryFactory.createChainStorageItemRepository()

            let request = MapSubscriptionRequest(
                storagePath: storagePath,
                localKey: localKey,
                keyParamClosure: { BytesCodable(wrappedValue: accountId) }
            )

            collatorSubscription = CallbackStorageSubscription(
                request: request,
                connection: connection,
                runtimeService: runtimeProvider,
                repository: repository,
                operationQueue: operationQueue,
                callbackQueue: .main
            ) { [weak self] result in
                switch result {
                case let .success(collator):
                    self?.presenter?.didReceiveCandidateInfo(collator)
                case let .failure(error):
                    self?.logger.error("Collator info subscription failed: \(error)")
                }
            }
        } catch {
            logger.error("Unexpected collator subscription failed: \(error)")
        }
    }

    func provideIdentities(for delegations: [AccountId]) {
        delegatorIdentityCancellable.cancel()

        let wrapper = identityProxyFactory.createIdentityWrapperByAccountId(for: { delegations })

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: delegatorIdentityCancellable,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(identities):
                self?.presenter?.didReceiveDelegationIdentities(identities)
            case let .failure(error):
                self?.logger.error("Identities error: \(error)")
            }
        }
    }

    func providePreferredCollator() {
        guard let operationFactory = preferredCollatorFactory else {
            presenter?.didReceivePreferredCollator(nil)
            return
        }

        let wrapper = operationFactory.createPreferredCollatorWrapper()

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(optCollator):
                self?.presenter?.didReceivePreferredCollator(optCollator)
            case let .failure(error):
                self?.logger.error("Preferred collator error: \(error)")
                self?.presenter?.didReceivePreferredCollator(nil)
            }
        }
    }
}

extension MythosStakingSetupInteractor: MythosStakingSetupInteractorInputProtocol {
    func applyCollator(with accountId: AccountId) {
        subscribeRemoteCollator(for: accountId)
    }
}
