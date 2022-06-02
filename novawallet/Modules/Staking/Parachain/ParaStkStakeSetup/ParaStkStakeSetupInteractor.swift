import UIKit
import RobinHood
import BigInt
import SubstrateSdk

final class ParaStkStakeSetupInteractor: RuntimeConstantFetching {
    weak var presenter: ParaStkStakeSetupInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let collatorService: ParachainStakingCollatorServiceProtocol
    let rewardService: ParaStakingRewardCalculatorServiceProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeCodingServiceProtocol
    let stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let operationQueue: OperationQueue

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var collatorSubscription: CallbackStorageSubscription<ParachainStaking.CandidateMetadata>?
    private var delegatorProvider: AnyDataProvider<ParachainStaking.DecodedDelegator>?

    private lazy var localKeyFactory = LocalStorageKeyFactory()

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        collatorService: ParachainStakingCollatorServiceProtocol,
        rewardService: ParaStakingRewardCalculatorServiceProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        identityOperationFactory _: IdentityOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.collatorService = collatorService
        self.rewardService = rewardService
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.repositoryFactory = repositoryFactory
        self.operationQueue = operationQueue
    }

    deinit {
        self.collatorSubscription = nil
    }

    private func provideRewardCalculator() {
        let operation = rewardService.fetchCalculatorOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let calculator = try operation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveRewardCalculator(calculator)
                } catch {
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        operationQueue.addOperation(operation)
    }

    private func subscribeAssetBalanceAndPrice() {
        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.chainAccount.accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }
    }

    private func subscribeDelegator() {
        delegatorProvider = subscribeToDelegatorState(
            for: chainAsset.chain.chainId,
            accountId: selectedAccount.chainAccount.accountId
        )
    }

    private func subscribeRemoteCollator(for accountId: AccountId) {
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
                    self?.presenter?.didReceiveCollator(metadata: collator)
                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
                }
            }
        } catch {
            presenter?.didReceiveError(error)
        }
    }

    private func provideMinTechStake() {
        fetchConstant(
            for: ParachainStaking.minDelegatorStk,
            runtimeCodingService: runtimeProvider,
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] (result: Result<BigUInt, Error>) in
            switch result {
            case let .success(minStake):
                self?.presenter?.didReceiveMinTechStake(minStake)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }
}

extension ParaStkStakeSetupInteractor: ParaStkStakeSetupInteractorInputProtocol {
    func setup() {
        subscribeAssetBalanceAndPrice()
        subscribeDelegator()

        provideRewardCalculator()

        feeProxy.delegate = self

        provideMinTechStake()

        presenter?.didCompleteSetup()
    }

    func applyCollator(with accountId: AccountId) {
        subscribeRemoteCollator(for: accountId)
    }

    func estimateFee(
        _ amount: BigUInt,
        collator: AccountId?,
        collatorDelegationsCount: UInt32,
        delegationsCount: UInt32,
        existingBond: BigUInt?
    ) {
        let candidate = collator ?? selectedAccount.chainAccount.accountId

        let identifier = candidate.toHex() + "-"
            + String(amount) + "-"
            + String(collatorDelegationsCount) + "-"
            + String(delegationsCount)

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: identifier) { builder in
            if existingBond != nil {
                let call = ParachainStaking.DelegatorBondMoreCall(
                    candidate: candidate,
                    more: amount
                )

                return try builder.adding(call: call.runtimeCall)
            } else {
                let call = ParachainStaking.DelegateCall(
                    candidate: candidate,
                    amount: amount,
                    candidateDelegationCount: collatorDelegationsCount,
                    delegationCount: delegationsCount
                )

                return try builder.adding(call: call.runtimeCall)
            }
        }
    }
}

extension ParaStkStakeSetupInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            presenter?.didReceiveAssetBalance(balance)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

extension ParaStkStakeSetupInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter?.didReceivePrice(priceData)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

extension ParaStkStakeSetupInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter?.didReceiveFee(result)
    }
}

extension ParaStkStakeSetupInteractor: ParastakingLocalStorageSubscriber, ParastakingLocalStorageHandler {
    func handleParastakingDelegatorState(
        result: Result<ParachainStaking.Delegator?, Error>,
        for _: ChainModel.Id,
        accountId _: AccountId
    ) {
        switch result {
        case let .success(delegator):
            presenter?.didReceiveDelegator(delegator)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}
