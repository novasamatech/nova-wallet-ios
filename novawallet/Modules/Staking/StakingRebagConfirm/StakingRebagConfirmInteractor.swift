import UIKit
import Operation_iOS
import BigInt

final class StakingRebagConfirmInteractor: AnyProviderAutoCleaning, AnyCancellableCleaning, AccountFetching {
    weak var presenter: StakingRebagConfirmInteractorOutputProtocol!

    let chainAsset: ChainAsset
    var chainId: ChainModel.Id { chainAsset.chain.chainId }

    let selectedAccount: MetaChainAccountResponse
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let networkInfoFactory: NetworkStakingInfoOperationFactoryProtocol
    let eraValidatorService: EraValidatorServiceProtocol
    let chainRegistry: ChainRegistryProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let accountRepositoryFactory: AccountRepositoryFactoryProtocol
    let callFactory: SubstrateCallFactoryProtocol
    let runtimeService: RuntimeProviderProtocol
    let moduleNameResolver: ModuleNameResolverProtocol

    private let operationQueue: OperationQueue

    private var networkInfoCancellable: CancellableCall?

    private var priceProvider: StreamableProvider<PriceData>?
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var bagListNodeProvider: AnyDataProvider<DecodedBagListNode>?
    private var totalIssuanceProvider: AnyDataProvider<DecodedBigUInt>?
    private var bagListModuleNameCancellable: CancellableCall?

    private var extrinsicService: ExtrinsicServiceProtocol?
    private var extrinsicMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol?
    private var signingWrapper: SigningWrapperProtocol?
    private var moduleName: String?

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        chainRegistry: ChainRegistryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        networkInfoFactory: NetworkStakingInfoOperationFactoryProtocol,
        eraValidatorService: EraValidatorServiceProtocol,
        runtimeService: RuntimeProviderProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        accountRepositoryFactory: AccountRepositoryFactoryProtocol,
        callFactory: SubstrateCallFactoryProtocol,
        moduleNameResolver: ModuleNameResolverProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.feeProxy = feeProxy
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.networkInfoFactory = networkInfoFactory
        self.eraValidatorService = eraValidatorService
        self.operationQueue = operationQueue
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.chainRegistry = chainRegistry
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.signingWrapperFactory = signingWrapperFactory
        self.accountRepositoryFactory = accountRepositoryFactory
        self.callFactory = callFactory
        self.runtimeService = runtimeService
        self.moduleNameResolver = moduleNameResolver
        self.currencyManager = currencyManager
    }

    private func subscribePrice() {
        clear(streamableProvider: &priceProvider)

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter?.didReceive(price: nil)
        }
    }

    private func subscribeAccountBalance() {
        clear(streamableProvider: &balanceProvider)

        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.chainAccount.accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )
    }

    private func handleStashMetaAccount(response: MetaChainAccountResponse?, stashItem: StashItem?) {
        guard let response = response else {
            return
        }
        let chain = chainAsset.chain

        let extrinsicService = extrinsicServiceFactory.createService(
            account: response.chainAccount,
            chain: chain
        )

        self.extrinsicService = extrinsicService

        extrinsicMonitorFactory = extrinsicServiceFactory.createExtrinsicSubmissionMonitor(
            with: extrinsicService
        )

        signingWrapper = signingWrapperFactory.createSigningWrapper(
            for: response.metaId,
            accountResponse: response.chainAccount
        )

        estimateFee(stashItem: stashItem)
    }

    private func stashAccountId(stashItem: StashItem?) -> AccountId? {
        guard let stashItem = stashItem else {
            return nil
        }
        return try? stashItem.stash.toAccountId()
    }

    private func subscribeStashItemSubscription() {
        clear(streamableProvider: &stashItemProvider)

        guard let address = selectedAccount.chainAccount.toAddress() else {
            subscribeBagListNode(stashItem: nil)
            return
        }

        stashItemProvider = subscribeStashItemProvider(for: address, chainId: chainAsset.chain.chainId)
    }

    private func subscribeBagListNode(stashItem: StashItem?) {
        clear(dataProvider: &bagListNodeProvider)

        guard let stashAccountId = stashAccountId(stashItem: stashItem) else {
            return
        }

        bagListNodeProvider = subscribeBagListNode(for: stashAccountId, chainId: chainId)
    }

    private func subscribeLedgerInfo(stashItem: StashItem?) {
        clear(dataProvider: &ledgerProvider)

        guard let stashItem = stashItem,
              let controllerId = try? stashItem.controller.toAccountId() else {
            return
        }

        ledgerProvider = subscribeLedgerInfo(for: controllerId, chainId: chainId)
    }

    private func provideMetaAccount(stashItem: StashItem?) {
        guard let stashAccountId = stashAccountId(stashItem: stashItem) else {
            return
        }

        fetchFirstMetaAccountResponse(
            for: stashAccountId,
            accountRequest: chainAsset.chain.accountRequest(),
            repositoryFactory: accountRepositoryFactory,
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] result in
            switch result {
            case let .success(response):
                self?.handleStashMetaAccount(response: response, stashItem: stashItem)
            case let .failure(error):
                self?.presenter.didReceive(error: .fetchStashItemFailed(error))
            }
        }
    }

    func subscribeTotalIssuanceSubscription() {
        clear(dataProvider: &totalIssuanceProvider)

        totalIssuanceProvider = subscribeTotalIssuance(for: chainId)
    }

    func provideNetworkStakingInfo() {
        clear(cancellable: &networkInfoCancellable)

        let wrapper = networkInfoFactory.networkStakingOperation(
            for: eraValidatorService,
            runtimeService: runtimeService
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.networkInfoCancellable === wrapper else {
                    return
                }

                self?.networkInfoCancellable = nil

                do {
                    let info = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter.didReceive(networkInfo: info)
                } catch {
                    self?.presenter?.didReceive(error: .fetchNetworkInfoFailed(error))
                }
            }
        }

        networkInfoCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func provideModuleName() {
        let wrapper = moduleNameResolver.resolveModuleName(possibleNames: BagList.possibleModuleNames)

        wrapper.targetOperation.completionBlock = { [weak self] in
            guard let self = self, self.bagListModuleNameCancellable === wrapper else {
                return
            }
            do {
                self.moduleName = try wrapper.targetOperation.extractNoCancellableResultData()
                self.continueSetup()
            } catch {
                DispatchQueue.main.async {
                    self.presenter.didReceive(error: .cantResolveModuleName(error))
                }
            }

            self.bagListModuleNameCancellable = nil
        }

        bagListModuleNameCancellable = wrapper
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func estimateFee(stashItem: StashItem?) {
        guard let extrinsicService = extrinsicService,
              let accountId = stashAccountId(stashItem: stashItem),
              let moduleName = moduleName else {
            presenter.didReceive(error: .fetchFeeFailed(CommonError.undefined))
            return
        }

        let rebagCall = callFactory.rebag(accountId: accountId, module: moduleName)
        let reuseIdentifier = rebagCall.callName + accountId.toHexString()
        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: reuseIdentifier) { builder in
            try builder.adding(call: rebagCall)
        }
    }

    private func confirmRebag(stashItem: StashItem?) {
        guard
            let extrinsicMonitorFactory,
            let signingWrapper,
            let accountId = stashAccountId(stashItem: stashItem),
            let moduleName = moduleName else {
            presenter.didReceive(error: .submitFailed(CommonError.undefined))
            return
        }

        let rebagCall = callFactory.rebag(accountId: accountId, module: moduleName)

        let closure: ExtrinsicBuilderClosure = { builder in
            try builder.adding(call: rebagCall)
        }

        let wrapper = extrinsicMonitorFactory.submitAndMonitorWrapper(
            extrinsicBuilderClosure: closure,
            signer: signingWrapper
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result.mapToExtrinsicSubmittedResult() {
            case .success:
                self?.presenter.didSubmitRebag()
            case let .failure(error):
                self?.presenter.didReceive(error: .submitFailed(error))
            }
        }
    }

    private func continueSetup() {
        subscribeAccountBalance()
        subscribePrice()
        subscribeStashItemSubscription()
        subscribeTotalIssuanceSubscription()
    }
}

extension StakingRebagConfirmInteractor: StakingRebagConfirmInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self
        provideNetworkStakingInfo()
        provideModuleName()
    }

    func refreshFee(stashItem: StashItem) {
        estimateFee(stashItem: stashItem)
    }

    func submit(stashItem: StashItem) {
        confirmRebag(stashItem: stashItem)
    }

    func remakeSubscriptions() {
        continueSetup()
    }

    func retryNetworkInfo() {
        provideNetworkStakingInfo()
    }

    func retryModuleName() {
        provideModuleName()
    }
}

extension StakingRebagConfirmInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(
        result: Result<PriceData?, Error>,
        priceId _: AssetModel.PriceId
    ) {
        switch result {
        case let .success(priceData):
            presenter?.didReceive(price: priceData)
        case let .failure(error):
            presenter?.didReceive(error: .fetchPriceFailed(error))
        }
    }
}

extension StakingRebagConfirmInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            presenter?.didReceive(assetBalance: balance)
        case let .failure(error):
            presenter?.didReceive(error: .fetchBalanceFailed(error))
        }
    }
}

extension StakingRebagConfirmInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        switch result {
        case let .success(stashItem):
            subscribeBagListNode(stashItem: stashItem)
            subscribeLedgerInfo(stashItem: stashItem)
            provideMetaAccount(stashItem: stashItem)
            presenter.didReceive(stashItem: stashItem)
        case let .failure(error):
            presenter?.didReceive(error: .fetchStashItemFailed(error))
        }
    }

    func handleLedgerInfo(
        result: Result<Staking.Ledger?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(ledgerInfo):
            presenter.didReceive(ledgerInfo: ledgerInfo)
        case let .failure(error):
            presenter?.didReceive(error: .fetchLedgerInfoFailed(error))
        }
    }

    func handleBagListNode(
        result: Result<BagList.Node?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(node):
            presenter.didReceive(currentBagListNode: node)
        case let .failure(error):
            presenter.didReceive(error: .fetchBagListNodeFailed(error))
        }
    }

    func handleTotalIssuance(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(totalIssuance):
            presenter.didReceive(totalIssuance: totalIssuance)
        case let .failure(error):
            presenter?.didReceive(error: .fetchBagListScoreFactorFailed(error))
        }
    }
}

extension StakingRebagConfirmInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        switch result {
        case let .success(feeInfo):
            presenter?.didReceive(fee: feeInfo)
        case let .failure(error):
            presenter?.didReceive(error: .fetchFeeFailed(error))
        }
    }
}

extension StakingRebagConfirmInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
