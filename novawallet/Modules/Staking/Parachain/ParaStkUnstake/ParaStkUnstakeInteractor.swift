import UIKit
import SubstrateSdk
import RobinHood

final class ParaStkUnstakeInteractor: ParaStkBaseUnstakeInteractor {
    var presenter: ParaStkUnstakeInteractorOutputProtocol? {
        basePresenter as? ParaStkUnstakeInteractorOutputProtocol
    }

    let identityOperationFactory: IdentityOperationFactoryProtocol

    private var collatorSubscription: CallbackStorageSubscription<ParachainStaking.CandidateMetadata>?
    private var identitiesCancellable: CancellableCall?

    private lazy var localKeyFactory = LocalStorageKeyFactory()

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        stakingDurationFactory: ParaStkDurationOperationFactoryProtocol,
        blocktimeEstimationService: BlockTimeEstimationServiceProtocol,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.identityOperationFactory = identityOperationFactory

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
            operationQueue: operationQueue
        )
    }

    deinit {
        self.collatorSubscription = nil

        cancelIdentities()
    }

    override func subscribeCollator(for accountId: AccountId) {
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
                storagePath: ParachainStaking.candidateMetadataPath,
                connection: connection,
                runtimeService: runtimeProvider,
                repository: repository,
                operationQueue: operationQueue,
                callbackQueue: .main
            ) { [weak self] result in
                switch result {
                case let .success(collator):
                    self?.basePresenter?.didReceiveCollator(metadata: collator)
                case let .failure(error):
                    self?.basePresenter?.didReceiveError(error)
                }
            }
        } catch {
            basePresenter?.didReceiveError(error)
        }
    }

    private func cancelIdentities() {
        let cancellable = identitiesCancellable
        identitiesCancellable = nil
        cancellable?.cancel()
    }
}

extension ParaStkUnstakeInteractor: ParaStkUnstakeInteractorInputProtocol {
    func applyCollator(with accountId: AccountId) {
        subscribeCollator(for: accountId)
    }

    func fetchIdentities(for collatorIds: [AccountId]) {
        cancelIdentities()

        let wrapper = identityOperationFactory.createIdentityWrapperByAccountId(
            for: { collatorIds },
            engine: connection,
            runtimeService: runtimeProvider,
            chainFormat: chainAsset.chain.chainFormat
        )

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
