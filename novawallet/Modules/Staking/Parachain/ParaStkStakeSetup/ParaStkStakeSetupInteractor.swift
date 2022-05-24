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
    let identityOperationFactory: IdentityOperationFactoryProtocol
    let stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let operationQueue: OperationQueue

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var collatorSubscription: CallbackStorageSubscription<ParachainStaking.CandidateMetadata>?
    private var delegatorProvider: AnyDataProvider<ParachainStaking.DecodedDelegator>?

    private var collatorsInfo: SelectedRoundCollators?
    private var identities: [AccountAddress: AccountIdentity]?

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
        identityOperationFactory: IdentityOperationFactoryProtocol,
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
        self.identityOperationFactory = identityOperationFactory
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

    private func fetchRoundCollatorsAndCompleteSetup() {
        let collatorsOperation = collatorService.fetchInfoOperation()
        let identitiesWrapper = identityOperationFactory.createIdentityWrapper(
            for: {
                let collatorInfo = try collatorsOperation.extractNoCancellableResultData()
                return collatorInfo.collators.map(\.accountId)
            },
            engine: connection,
            runtimeService: runtimeProvider,
            chainFormat: chainAsset.chain.chainFormat
        )

        identitiesWrapper.addDependency(operations: [collatorsOperation])

        identitiesWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    self?.collatorsInfo = try collatorsOperation.extractNoCancellableResultData()
                    self?.identities = try identitiesWrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didCompleteSetup()
                } catch {
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        let operations = [collatorsOperation] + identitiesWrapper.allOperations

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }

    private func provideCollator(
        for accountId: AccountId,
        collatorMetadata: ParachainStaking.CandidateMetadata?
    ) {
        do {
            let chainFormat = chainAsset.chain.chainFormat
            let address = try accountId.toAddress(using: chainFormat)
            if let identity = identities?[address] {
                let displayAddress = DisplayAddress(
                    address: address,
                    username: identity.displayName
                )

                presenter?.didReceiveCollator(
                    metadata: collatorMetadata,
                    address: displayAddress
                )
            } else {
                let displayAddress = DisplayAddress(address: address, username: "")
                presenter?.didReceiveCollator(
                    metadata: collatorMetadata,
                    address: displayAddress
                )
            }
        } catch {
            presenter?.didReceiveError(error)
        }
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
                    self?.provideCollator(for: accountId, collatorMetadata: collator)
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

        fetchRoundCollatorsAndCompleteSetup()

        provideMinTechStake()
    }

    func rotateSelectedCollator() {
        guard
            let collatorsInfo = collatorsInfo,
            let collatorId = collatorsInfo.collators.randomElement()?.accountId else {
            return
        }

        subscribeRemoteCollator(for: collatorId)
    }

    func estimateFee(
        _ amount: BigUInt,
        collator: AccountId?,
        collatorDelegationsCount: UInt32,
        delegationsCount: UInt32
    ) {
        let candidate = collator ?? selectedAccount.chainAccount.accountId
        let call = ParachainStaking.DelegateCall(
            candidate: candidate,
            amount: amount,
            candidateDelegationCount: collatorDelegationsCount,
            delegationCount: delegationsCount
        )

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: call.extrinsicIdentifier
        ) { builder in
            try builder.adding(call: call.runtimeCall)
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
