import Foundation
import Keystore_iOS
import Operation_iOS
import BigInt
import SubstrateSdk

final class StakingUnbondConfirmInteractor: RuntimeConstantFetching, AccountFetching, StakingDurationFetching {
    weak var presenter: StakingUnbondConfirmInteractorOutputProtocol!

    let selectedAccount: ChainAccountResponse
    let chainAsset: ChainAsset
    let chainRegistry: ChainRegistryProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let stakingDurationOperationFactory: StakingDurationOperationFactoryProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let accountRepositoryFactory: AccountRepositoryFactoryProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let operationQueue: OperationQueue

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var minBondedProvider: AnyDataProvider<DecodedBigUInt>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var nominationProvider: AnyDataProvider<DecodedNomination>?
    private var payeeProvider: AnyDataProvider<DecodedPayee>?
    private var priceProvider: StreamableProvider<PriceData>?

    private var extrinsicService: ExtrinsicServiceProtocol?
    private var extrinsicMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol?
    private var signingWrapper: SigningWrapperProtocol?

    private var operationManager: OperationManagerProtocol {
        OperationManager(operationQueue: operationQueue)
    }

    private lazy var callFactory = SubstrateCallFactory()

    init(
        selectedAccount: ChainAccountResponse,
        chainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingDurationOperationFactory: StakingDurationOperationFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        accountRepositoryFactory: AccountRepositoryFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.chainRegistry = chainRegistry
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.signingWrapperFactory = signingWrapperFactory
        self.stakingDurationOperationFactory = stakingDurationOperationFactory
        self.accountRepositoryFactory = accountRepositoryFactory
        self.feeProxy = feeProxy
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    func handleControllerMetaAccount(response: MetaChainAccountResponse) {
        let chain = chainAsset.chain

        let extrinsicService = extrinsicServiceFactory.createService(
            account: response.chainAccount,
            chain: chain
        )

        self.extrinsicService = extrinsicService

        extrinsicMonitorFactory = extrinsicServiceFactory.createExtrinsicSubmissionMonitor(with: extrinsicService)

        signingWrapper = signingWrapperFactory.createSigningWrapper(
            for: response.metaId,
            accountResponse: response.chainAccount
        )
    }

    private func setupExtrinsicBuiler(
        _ builder: ExtrinsicBuilderProtocol,
        amount: Decimal,
        resettingRewardDestination: Bool,
        chilling: Bool
    ) throws -> ExtrinsicBuilderProtocol {
        guard let amountValue = amount.toSubstrateAmount(
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) else {
            throw CommonError.undefined
        }

        var resultBuilder = builder

        if chilling {
            resultBuilder = try builder.adding(call: callFactory.chill())
        }

        resultBuilder = try resultBuilder.adding(call: callFactory.unbond(amount: amountValue))

        if resettingRewardDestination {
            resultBuilder = try resultBuilder.adding(call: callFactory.setPayee(for: .stash))
        }

        return resultBuilder
    }
}

extension StakingUnbondConfirmInteractor: StakingUnbondConfirmInteractorInputProtocol {
    func setup() {
        if let address = selectedAccount.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address, chainId: chainAsset.chain.chainId)
        } else {
            presenter.didReceiveStashItem(result: .failure(ChainAccountFetchingError.accountNotExists))
        }

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter.didReceivePriceData(result: .success(nil))
        }

        minBondedProvider = subscribeToMinNominatorBond(for: chainAsset.chain.chainId)

        fetchStakingDuration(
            operationFactory: stakingDurationOperationFactory,
            operationManager: operationManager
        ) { [weak self] result in
            self?.presenter.didReceiveStakingDuration(result: result)
        }

        if let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) {
            fetchConstant(
                for: .existentialDeposit,
                runtimeCodingService: runtimeService,
                operationManager: operationManager
            ) { [weak self] (result: Result<BigUInt, Error>) in
                self?.presenter.didReceiveExistentialDeposit(result: result)
            }
        } else {
            let error = ChainRegistryError.runtimeMetadaUnavailable
            presenter.didReceiveExistentialDeposit(result: .failure(error))
            presenter.didReceiveStakingDuration(result: .failure(error))
        }

        feeProxy.delegate = self
    }

    func estimateFee(for amount: Decimal, resettingRewardDestination: Bool, chilling: Bool) {
        guard let extrinsicService = extrinsicService else {
            presenter.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        let reuseIdentifier = amount.description + resettingRewardDestination.description

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: reuseIdentifier
        ) { [weak self] builder in
            guard let strongSelf = self else {
                throw CommonError.undefined
            }

            return try strongSelf.setupExtrinsicBuiler(
                builder,
                amount: amount,
                resettingRewardDestination: resettingRewardDestination,
                chilling: chilling
            )
        }
    }

    func submit(for amount: Decimal, resettingRewardDestination: Bool, chilling: Bool) {
        guard
            let extrinsicMonitorFactory,
            let signingWrapper = signingWrapper else {
            presenter.didSubmitUnbonding(result: .failure(CommonError.undefined))
            return
        }

        let builderClosure: ExtrinsicBuilderClosure = { [weak self] builder in
            guard let strongSelf = self else {
                throw CommonError.undefined
            }

            return try strongSelf.setupExtrinsicBuiler(
                builder,
                amount: amount,
                resettingRewardDestination: resettingRewardDestination,
                chilling: chilling
            )
        }

        let wrapper = extrinsicMonitorFactory.submitAndMonitorWrapper(
            extrinsicBuilderClosure: builderClosure,
            signer: signingWrapper
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            self?.presenter.didSubmitUnbonding(result: result.mapToExtrinsicSubmittedResult())
        }
    }
}

extension StakingUnbondConfirmInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            clear(streamableProvider: &balanceProvider)
            clear(dataProvider: &ledgerProvider)
            clear(dataProvider: &payeeProvider)
            clear(dataProvider: &nominationProvider)

            let maybeStashItem = try result.get()
            let maybeStashId = try maybeStashItem.map { try $0.stash.toAccountId() }
            let maybeControllerId = try maybeStashItem.map { try $0.controller.toAccountId() }

            presenter.didReceiveStashItem(result: result)

            if let stashId = maybeStashId, let controllerId = maybeControllerId {
                ledgerProvider = subscribeLedgerInfo(for: controllerId, chainId: chainAsset.chain.chainId)

                balanceProvider = subscribeToAssetBalanceProvider(
                    for: controllerId,
                    chainId: chainAsset.chain.chainId,
                    assetId: chainAsset.asset.assetId
                )

                payeeProvider = subscribePayee(for: stashId, chainId: chainAsset.chain.chainId)

                nominationProvider = subscribeNomination(for: stashId, chainId: chainAsset.chain.chainId)

                fetchFirstMetaAccountResponse(
                    for: controllerId,
                    accountRequest: chainAsset.chain.accountRequest(),
                    repositoryFactory: accountRepositoryFactory,
                    operationManager: operationManager
                ) { [weak self] result in
                    switch result {
                    case let .success(response):
                        if let response = response {
                            self?.handleControllerMetaAccount(response: response)
                        }

                        if let account = response {
                            self?.presenter.didReceiveController(result: .success(account))
                        }
                    case let .failure(error):
                        self?.presenter.didReceiveController(result: .failure(error))
                    }
                }
            } else {
                presenter.didReceiveStakingLedger(result: .success(nil))
                presenter.didReceiveAccountBalance(result: .success(nil))
                presenter.didReceivePayee(result: .success(nil))
                presenter.didReceiveNomination(result: .success(nil))
            }

        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
            presenter.didReceiveAccountBalance(result: .failure(error))
            presenter.didReceiveStakingLedger(result: .failure(error))
            presenter.didReceivePayee(result: .failure(error))
            presenter.didReceiveNomination(result: .failure(error))
        }
    }

    func handleLedgerInfo(
        result: Result<Staking.Ledger?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        presenter.didReceiveStakingLedger(result: result)
    }

    func handlePayee(
        result: Result<Staking.RewardDestinationArg?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        presenter.didReceivePayee(result: result)
    }

    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        presenter.didReceiveMinBonded(result: result)
    }

    func handleNomination(
        result: Result<Staking.Nomination?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        presenter.didReceiveNomination(result: result)
    }
}

extension StakingUnbondConfirmInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        presenter.didReceiveAccountBalance(result: result)
    }
}

extension StakingUnbondConfirmInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension StakingUnbondConfirmInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        presenter.didReceiveFee(result: result)
    }
}

extension StakingUnbondConfirmInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
