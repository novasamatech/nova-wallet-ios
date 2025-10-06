import UIKit
import SubstrateSdk
import Operation_iOS
import BigInt

final class ParaStkUnstakeInteractor: ParaStkBaseUnstakeInteractor, AnyCancellableCleaning, RuntimeConstantFetching {
    var presenter: ParaStkUnstakeInteractorOutputProtocol? {
        basePresenter as? ParaStkUnstakeInteractorOutputProtocol
    }

    let identityProxyFactory: IdentityProxyFactoryProtocol

    private var collatorSubscription: CallbackStorageSubscription<ParachainStaking.CandidateMetadata>?
    private var identitiesCancellable: CancellableCall?

    private lazy var localKeyFactory = LocalStorageKeyFactory()

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        identityProxyFactory: IdentityProxyFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        stakingDurationFactory: ParaStkDurationOperationFactoryProtocol,
        blocktimeEstimationService: BlockTimeEstimationServiceProtocol,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.identityProxyFactory = identityProxyFactory

        super.init(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            connection: connection,
            runtimeProvider: runtimeProvider,
            stakingDurationFactory: stakingDurationFactory,
            blocktimeEstimationService: blocktimeEstimationService,
            repositoryFactory: repositoryFactory,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }

    deinit {
        self.collatorSubscription = nil

        clear(cancellable: &identitiesCancellable)
    }

    private func subscribeCollator(for accountId: AccountId) {
        collatorSubscription = nil

        do {
            let storagePath = ParachainStaking.candidateMetadataPath
            let localKey = try localKeyFactory.createFromStoragePath(
                storagePath,
                accountId: accountId,
                chainId: chainAsset.chain.chainId
            )

            let repository = repositoryFactory.createChainStorageItemRepository()

            let request = MapSubscriptionRequest(
                storagePath: ParachainStaking.candidateMetadataPath,
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
                    self?.presenter?.didReceiveCollator(metadata: collator)
                case let .failure(error):
                    self?.basePresenter?.didReceiveError(error)
                }
            }
        } catch {
            basePresenter?.didReceiveError(error)
        }
    }

    private func provideMinTechStake() {
        fetchConstant(
            oneOfPaths: [ParachainStaking.minDelegatorStk, ParachainStaking.minDelegation],
            runtimeCodingService: runtimeProvider,
            operationQueue: operationQueue
        ) { [weak self] (result: Result<BigUInt, Error>) in
            switch result {
            case let .success(minStake):
                self?.presenter?.didReceiveMinTechStake(minStake)
            case let .failure(error):
                self?.basePresenter?.didReceiveError(error)
            }
        }
    }

    private func provideMinDelegationAmount() {
        fetchConstant(
            for: ParachainStaking.minDelegation,
            runtimeCodingService: runtimeProvider,
            operationQueue: operationQueue
        ) { [weak self] (result: Result<BigUInt, Error>) in
            switch result {
            case let .success(minDelegation):
                self?.presenter?.didReceiveMinDelegationAmount(minDelegation)
            case let .failure(error):
                self?.basePresenter?.didReceiveError(error)
            }
        }
    }

    override func setup() {
        super.setup()

        provideMinTechStake()
        provideMinDelegationAmount()
    }
}

extension ParaStkUnstakeInteractor: ParaStkUnstakeInteractorInputProtocol {
    func applyCollator(with accountId: AccountId) {
        subscribeCollator(for: accountId)
    }

    func fetchIdentities(for collatorIds: [AccountId]) {
        clear(cancellable: &identitiesCancellable)

        let wrapper = identityProxyFactory.createIdentityWrapperByAccountId(for: { collatorIds })

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.identitiesCancellable === wrapper else {
                    return
                }

                self?.identitiesCancellable = nil

                do {
                    let identites = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveDelegationIdentities(identites)
                } catch {
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        identitiesCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}
