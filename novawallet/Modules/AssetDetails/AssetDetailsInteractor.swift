import UIKit
import Operation_iOS
import Keystore_iOS

final class AssetDetailsInteractor: AnyCancellableCleaning {
    weak var presenter: AssetDetailsInteractorOutputProtocol?

    let ahmInfoFactory: AHMFullInfoFactoryProtocol
    let settingsManager: SettingsManagerProtocol
    let chainAsset: ChainAsset
    let selectedMetaAccount: MetaAccountModel
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let externalBalancesSubscriptionFactory: ExternalBalanceLocalSubscriptionFactoryProtocol
    let swapState: SwapTokensFlowStateProtocol
    let rampProvider: RampProviderProtocol
    let assetMapper: CustomAssetMapper
    let operationQueue: OperationQueue

    private var assetLocksSubscription: StreamableProvider<AssetLock>?
    private var priceSubscription: StreamableProvider<PriceData>?
    private var assetBalanceSubscription: StreamableProvider<AssetBalance>?
    private var externalBalanceSubscription: StreamableProvider<ExternalAssetBalance>?
    private var assetHoldsSubscription: StreamableProvider<AssetHold>?
    private var swapsCall = CancellableCallStore()

    private var assetExchangeService: AssetsExchangeServiceProtocol?

    private var accountId: AccountId? {
        selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId
    }

    init(
        ahmInfoFactory: AHMFullInfoFactoryProtocol,
        settingsManager: SettingsManagerProtocol,
        selectedMetaAccount: MetaAccountModel,
        chainAsset: ChainAsset,
        rampProvider: RampProviderProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        externalBalancesSubscriptionFactory: ExternalBalanceLocalSubscriptionFactoryProtocol,
        swapState: SwapTokensFlowStateProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.ahmInfoFactory = ahmInfoFactory
        self.settingsManager = settingsManager
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.externalBalancesSubscriptionFactory = externalBalancesSubscriptionFactory
        self.selectedMetaAccount = selectedMetaAccount
        self.chainAsset = chainAsset
        self.rampProvider = rampProvider
        self.swapState = swapState
        self.operationQueue = operationQueue
        assetMapper = CustomAssetMapper(
            type: chainAsset.asset.type,
            typeExtras: chainAsset.asset.typeExtras
        )
        self.currencyManager = currencyManager
    }

    deinit {
        swapsCall.cancel()
    }
}

// MARK: Private

private extension AssetDetailsInteractor {
    func subscribePrice() {
        if let priceId = chainAsset.asset.priceId {
            priceSubscription = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter?.didReceive(price: nil)
        }
    }

    func fetchSwapsAndProvideOperations(for chainAsset: ChainAsset) {
        swapsCall.cancel()

        guard let assetExchangeService else {
            return
        }

        let wrapper = assetExchangeService.fetchAssetsOutWrapper(given: chainAsset.chainAssetId)

        let checkOperation = ClosureOperation<Bool> {
            let reachability = try wrapper.targetOperation.extractNoCancellableResultData()

            return !reachability.isEmpty
        }

        checkOperation.addDependency(wrapper.targetOperation)

        let totalWrapper = wrapper.insertingTail(operation: checkOperation)

        executeCancellable(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: swapsCall,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self = self else {
                return
            }

            switch result {
            case let .success(hasSwaps):
                self.setAvailableOperations(hasSwaps: hasSwaps)
            case let .failure(error):
                self.presenter?.didReceive(error: .swaps(error))
            }
        }
    }

    func setupSwapService() {
        assetExchangeService = swapState.setupAssetExchangeService()

        assetExchangeService?.subscribeUpdates(
            for: self,
            notifyingIn: .main
        ) { [weak self] in
            guard let self else {
                return
            }

            fetchSwapsAndProvideOperations(for: chainAsset)
        }
    }

    func setAvailableOperations(hasSwaps: Bool) {
        guard let accountId = accountId else {
            return
        }
        var operations: AssetDetailsOperation = .init()
        let isTransfersEnable = try? assetMapper.transfersEnabled()
        if isTransfersEnable == true {
            operations.insert(.send)
        }

        let rampActions: [RampAction] = rampProvider.buildRampActions(
            for: chainAsset,
            accountId: accountId
        )

        if rampActions.contains(where: { $0.type == .onRamp }) {
            operations.insert(.buy)
        }
        if rampActions.contains(where: { $0.type == .offRamp }) {
            operations.insert(.sell)
        }

        operations.insert(.receive)

        if hasSwaps {
            operations.insert(.swap)
        }

        presenter?.didReceive(rampActions: rampActions)
        presenter?.didReceive(availableOperations: operations)
    }

    func provideAHMInfo() {
        let fetchWrapper = ahmInfoFactory.fetch(by: chainAsset.chain.chainId)

        execute(
            wrapper: fetchWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(info):
                self?.presenter?.didReceive(ahmInfo: info)
            case let .failure(error):
                self?.presenter?.didReceive(error: .ahmInfo(error))
            }
        }
    }
}

// MARK: AssetDetailsInteractorInputProtocol

extension AssetDetailsInteractor: AssetDetailsInteractorInputProtocol {
    func setup() {
        guard let accountId = accountId else {
            return
        }

        provideAHMInfo()

        subscribePrice()

        assetBalanceSubscription = subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )

        assetLocksSubscription = subscribeToLocksProvider(
            for: accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )

        assetHoldsSubscription = subscribeToHoldsProvider(
            for: accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )

        if chainAsset.chain.chainAssetIdsWithExternalBalances().contains(chainAsset.chainAssetId) {
            externalBalanceSubscription = subscribeToExternalAssetBalancesProvider(
                for: accountId,
                chainAsset: chainAsset
            )
        } else {
            externalBalanceSubscription = nil
        }

        setAvailableOperations(hasSwaps: false)

        setupSwapService()
    }
}

// MARK: WalletLocalStorageSubscriber

extension AssetDetailsInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        guard chainId == chainAsset.chain.chainId,
              assetId == chainAsset.asset.assetId,
              accountId == self.accountId else {
            return
        }

        switch result {
        case let .success(balance):
            presenter?.didReceive(balance: balance ?? AssetBalance.createZero(
                for: chainAsset.chainAssetId,
                accountId: accountId
            ))
        case let .failure(error):
            presenter?.didReceive(error: .swaps(error))
        }
    }

    func handleAccountLocks(
        result: Result<[DataProviderChange<AssetLock>], Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        guard chainId == chainAsset.chain.chainId,
              assetId == chainAsset.asset.assetId,
              accountId == self.accountId else {
            return
        }

        switch result {
        case let .failure(error):
            presenter?.didReceive(error: .locks(error))
        case let .success(changes):
            presenter?.didReceive(lockChanges: changes)
        }
    }

    func handleAccountHolds(
        result: Result<[DataProviderChange<AssetHold>], Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        guard chainId == chainAsset.chain.chainId,
              assetId == chainAsset.asset.assetId,
              accountId == self.accountId else {
            return
        }

        switch result {
        case let .failure(error):
            presenter?.didReceive(error: .holds(error))
        case let .success(changes):
            presenter?.didReceive(holdsChanges: changes)
        }
    }
}

// MARK: PriceLocalStorageSubscriber

extension AssetDetailsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter?.didReceive(price: priceData)
        case let .failure(error):
            presenter?.didReceive(error: .price(error))
        }
    }
}

// MARK: SelectedCurrencyDepending

extension AssetDetailsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if presenter != nil, let priceId = chainAsset.asset.priceId {
            priceSubscription = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }
}

// MARK: ExternalAssetBalanceSubscriber

extension AssetDetailsInteractor: ExternalAssetBalanceSubscriber, ExternalAssetBalanceSubscriptionHandler {
    func handleExternalAssetBalances(
        result: Result<[DataProviderChange<ExternalAssetBalance>], Error>,
        accountId _: AccountId,
        chainAsset _: ChainAsset
    ) {
        switch result {
        case let .success(externalBalanceChanges):
            presenter?.didReceive(externalBalanceChanges: externalBalanceChanges)
        case let .failure(error):
            presenter?.didReceive(error: .externalBalances(error))
        }
    }
}
