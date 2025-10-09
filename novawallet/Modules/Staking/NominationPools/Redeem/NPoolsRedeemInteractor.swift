import UIKit
import Operation_iOS
import SubstrateSdk
import BigInt

final class NPoolsRedeemInteractor: RuntimeConstantFetching, NominationPoolStakingMigrating,
    AnyProviderAutoCleaning, AnyCancellableCleaning {
    weak var presenter: NPoolsRedeemInteractorOutputProtocol?

    let selectedAccount: MetaChainAccountResponse
    let chainAsset: ChainAsset
    let extrinsicService: ExtrinsicServiceProtocol
    let extrinsicServiceMonitor: ExtrinsicSubmitMonitorFactoryProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let slashesOperationFactory: SlashesOperationFactoryProtocol
    let signingWrapper: SigningWrapperProtocol
    let operationQueue: OperationQueue

    let npoolsOperationFactory: NominationPoolsOperationFactoryProtocol
    let npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol

    var accountId: AccountId { selectedAccount.chainAccount.accountId }
    var chainId: ChainModel.Id { chainAsset.chain.chainId }
    var asset: AssetModel { chainAsset.asset }
    var assetId: AssetModel.Id { asset.assetId }

    private var poolMemberProvider: AnyDataProvider<DecodedPoolMember>?
    private var subPoolsProvider: AnyDataProvider<DecodedSubPools>?
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?
    private var delegatedStakingProvider: AnyDataProvider<DecodedDelegatedStakingDelegator>?
    private var cancellableNeedsMigration = CancellableCallStore()

    private var currentPoolId: NominationPools.PoolId?

    init(
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        extrinsicService: ExtrinsicServiceProtocol,
        extrinsicServiceMonitor: ExtrinsicSubmitMonitorFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        signingWrapper: SigningWrapperProtocol,
        slashesOperationFactory: SlashesOperationFactoryProtocol,
        npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        npoolsOperationFactory: NominationPoolsOperationFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.extrinsicService = extrinsicService
        self.extrinsicServiceMonitor = extrinsicServiceMonitor
        self.feeProxy = feeProxy
        self.signingWrapper = signingWrapper
        self.slashesOperationFactory = slashesOperationFactory
        self.npoolsLocalSubscriptionFactory = npoolsLocalSubscriptionFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.npoolsOperationFactory = npoolsOperationFactory
        self.connection = connection
        self.runtimeService = runtimeService
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    func setupPoolProviders() {
        guard let poolId = currentPoolId else {
            return
        }

        subPoolsProvider = subscribeSubPools(for: poolId, chainId: chainId)
    }

    func setupCurrencyProvider() {
        guard let priceId = asset.priceId else {
            presenter?.didReceive(price: nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    func setupBaseProviders() {
        subPoolsProvider = nil

        poolMemberProvider = subscribePoolMember(for: accountId, chainId: chainId)
        balanceProvider = subscribeToAssetBalanceProvider(for: accountId, chainId: chainId, assetId: assetId)
        activeEraProvider = subscribeActiveEra(for: chainId)

        clear(dataProvider: &delegatedStakingProvider)
        delegatedStakingProvider = subscribeDelegatedStaking(for: accountId, chainId: chainId)

        setupCurrencyProvider()
    }

    private func fetchSlashingSpansForStash(
        poolId: NominationPools.PoolId,
        completionClosure: @escaping (Result<Staking.SlashingSpans?, Error>) -> Void
    ) {
        let bondedAccountWrapper = npoolsOperationFactory.createBondedAccountsWrapper(
            for: { [poolId] },
            runtimeService: runtimeService
        )

        let accountIdClosure: () throws -> AccountId = {
            let accounts = try bondedAccountWrapper.targetOperation.extractNoCancellableResultData()

            if let accountId = accounts[poolId] {
                return accountId
            } else {
                throw CommonError.dataCorruption
            }
        }

        let slashingWrapper = slashesOperationFactory.createSlashingSpansOperationForStash(
            accountIdClosure,
            engine: connection,
            runtimeService: runtimeService
        )

        slashingWrapper.addDependency(wrapper: bondedAccountWrapper)

        slashingWrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async {
                if let result = slashingWrapper.targetOperation.result {
                    completionClosure(result)
                } else {
                    completionClosure(.failure(BaseOperationError.unexpectedDependentResult))
                }
            }
        }

        let allOperations = bondedAccountWrapper.allOperations + slashingWrapper.allOperations

        operationQueue.addOperations(allOperations, waitUntilFinished: false)
    }

    func createExtrinsicBuilderClosure(
        for accountId: AccountId,
        numOfSlashingSpans: UInt32,
        needsMigration: Bool
    ) -> ExtrinsicBuilderClosure {
        { builder in
            let currentBuilder = try NominationPools.migrateIfNeeded(
                needsMigration,
                accountId: accountId,
                builder: builder
            )

            let redeemCall = NominationPools.RedeemCall(
                memberAccount: .accoundId(accountId),
                numberOfSlashingSpans: numOfSlashingSpans
            )

            return try currentBuilder.adding(call: redeemCall.runtimeCall())
        }
    }

    func estimateFee(for numOfSlashingSpans: UInt32, needsMigration: Bool) {
        let identifier = "\(numOfSlashingSpans)" + "-" + "\(needsMigration)"

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: identifier,
            setupBy: createExtrinsicBuilderClosure(
                for: accountId,
                numOfSlashingSpans: numOfSlashingSpans,
                needsMigration: needsMigration
            )
        )
    }

    func submit(for numberOfSlashingSpans: UInt32, needsMigration: Bool) {
        let wrapper = extrinsicServiceMonitor.submitAndMonitorWrapper(
            extrinsicBuilderClosure: createExtrinsicBuilderClosure(
                for: accountId,
                numOfSlashingSpans: numberOfSlashingSpans,
                needsMigration: needsMigration
            ),
            signer: signingWrapper
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            self?.presenter?.didReceive(submissionResult: result.mapToExtrinsicSubmittedResult())
        }
    }

    func provideExistentialDeposit() {
        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeService,
            operationQueue: operationQueue
        ) { [weak self] (result: Result<BigUInt, Error>) in
            switch result {
            case let .success(existentialDeposit):
                self?.presenter?.didReceive(existentialDeposit: existentialDeposit)
            case let .failure(error):
                self?.presenter?.didReceive(error: .existentialDeposit(error))
            }
        }
    }
}

extension NPoolsRedeemInteractor: NPoolsRedeemInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self

        setupBaseProviders()
        provideExistentialDeposit()
    }

    func remakeSubscriptions() {
        setupBaseProviders()
    }

    func retryExistentialDeposit() {
        provideExistentialDeposit()
    }

    func estimateFee(needsMigration: Bool) {
        guard let poolId = currentPoolId else {
            return
        }

        fetchSlashingSpansForStash(poolId: poolId) { [weak self] result in
            switch result {
            case let .success(optSlashingSpans):
                self?.estimateFee(
                    for: optSlashingSpans?.numOfSlashingSpans ?? 0,
                    needsMigration: needsMigration
                )
            case let .failure(error):
                self?.presenter?.didReceive(error: .fee(error))
            }
        }
    }

    func submit(needsMigration: Bool) {
        guard let poolId = currentPoolId else {
            presenter?.didReceive(submissionResult: .failure(CommonError.dataCorruption))
            return
        }

        fetchSlashingSpansForStash(poolId: poolId) { [weak self] result in
            switch result {
            case let .success(optSlashingSpans):
                self?.submit(
                    for: optSlashingSpans?.numOfSlashingSpans ?? 0,
                    needsMigration: needsMigration
                )
            case let .failure(error):
                self?.presenter?.didReceive(submissionResult: .failure(error))
            }
        }
    }
}

extension NPoolsRedeemInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        switch result {
        case let .success(feeInfo):
            presenter?.didReceive(fee: feeInfo)
        case let .failure(error):
            presenter?.didReceive(error: .fee(error))
        }
    }
}

extension NPoolsRedeemInteractor: NPoolsLocalStorageSubscriber, NPoolsLocalSubscriptionHandler {
    func handlePoolMember(
        result: Result<NominationPools.PoolMember?, Error>,
        accountId _: AccountId, chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(optPoolMember):
            if currentPoolId != optPoolMember?.poolId {
                currentPoolId = optPoolMember?.poolId

                setupPoolProviders()
            }

            presenter?.didReceive(poolMember: optPoolMember)
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "pool member"))
        }
    }

    func handleSubPools(
        result: Result<NominationPools.SubPools?, Error>,
        poolId _: NominationPools.PoolId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(subPools):
            presenter?.didReceive(subPools: subPools)
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "sub pools"))
        }
    }

    func handleDelegatedStaking(
        result: Result<DelegatedStakingPallet.Delegation?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(delegation):
            cancellableNeedsMigration.cancel()

            needsPoolStakingMigration(
                for: delegation,
                runtimeProvider: runtimeService,
                cancellableStore: cancellableNeedsMigration,
                operationQueue: operationQueue
            ) { [weak self] result in
                switch result {
                case let .success(needsMigration):
                    self?.presenter?.didReceive(needsMigration: needsMigration)
                case let .failure(error):
                    self?.presenter?.didReceive(error: .subscription(error, "Needs Migration"))
                }
            }
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "Delegated Staking"))
        }
    }
}

extension NPoolsRedeemInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleActiveEra(result: Result<Staking.ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(activeEra):
            presenter?.didReceive(activeEra: activeEra)
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "active era"))
        }
    }
}

extension NPoolsRedeemInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        switch result {
        case let .success(assetBalance):
            // we can have case when user have np staking but no native balance
            let balanceOrZero = assetBalance ?? .createZero(
                for: .init(chainId: chainId, assetId: assetId),
                accountId: accountId
            )

            presenter?.didReceive(assetBalance: balanceOrZero)
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "balance"))
        }
    }
}

extension NPoolsRedeemInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter?.didReceive(price: priceData)
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "price"))
        }
    }
}

extension NPoolsRedeemInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        setupCurrencyProvider()
    }
}
