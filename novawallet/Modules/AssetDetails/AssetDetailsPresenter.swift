import Foundation
import BigInt
import SoraFoundation
import Operation_iOS

final class AssetDetailsPresenter: PurchaseFlowManaging, AssetPriceChartInputOwnerProtocol {
    weak var view: AssetDetailsViewProtocol?
    weak var assetPriceChartModule: AssetPriceChartModuleInputProtocol?

    let wireframe: AssetDetailsWireframeProtocol
    let viewModelFactory: AssetDetailsViewModelFactoryProtocol
    let interactor: AssetDetailsInteractorInputProtocol
    let chainAsset: ChainAsset
    let selectedAccount: MetaAccountModel
    let logger: LoggerProtocol?

    private var priceData: PriceData?
    private var balance: AssetBalance?
    private var locks: [AssetLock] = []
    private var holds: [AssetHold] = []
    private var externalAssetBalances: [ExternalAssetBalance] = []
    private var purchaseActions: [PurchaseAction] = []
    private var availableOperations: AssetDetailsOperation = []

    init(
        interactor: AssetDetailsInteractorInputProtocol,
        localizableManager: LocalizationManagerProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaAccountModel,
        viewModelFactory: AssetDetailsViewModelFactoryProtocol,
        wireframe: AssetDetailsWireframeProtocol,
        logger: LoggerProtocol?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        localizationManager = localizableManager
    }

    private func calculateTotalExternalBalances(for externalBalances: [ExternalAssetBalance]) -> BigUInt {
        externalBalances.reduce(0) { $0 + $1.amount }
    }

    private func updateView() {
        guard let view, let balance else {
            return
        }

        let assetDetailsModel = viewModelFactory.createAssetDetailsModel(chainAsset: chainAsset)
        view.didReceive(assetModel: assetDetailsModel)

        let totalExternalBalances = calculateTotalExternalBalances(for: externalAssetBalances)

        let balanceModel = viewModelFactory.createBalanceViewModel(
            params: .init(
                total: balance.totalInPlank + totalExternalBalances,
                locked: balance.locked + totalExternalBalances,
                transferrable: balance.transferable,
                externalBalances: externalAssetBalances,
                assetDisplayInfo: chainAsset.assetDisplayInfo,
                priceData: priceData,
                locale: selectedLocale
            )
        )

        view.didReceive(balance: balanceModel)
        view.didReceive(availableOperations: availableOperations)
    }

    private func showPurchase() {
        startPuchaseFlow(
            from: view,
            purchaseActions: purchaseActions,
            wireframe: wireframe,
            locale: selectedLocale
        )
    }

    private func showReceiveTokens() {
        guard let view = view,
              let metaChainAccountResponse = selectedAccount.fetchMetaChainAccount(
                  for: chainAsset.chain.accountRequest()
              ) else {
            return
        }

        wireframe.showReceiveTokens(
            from: view,
            chainAsset: chainAsset,
            metaChainAccountResponse: metaChainAccountResponse
        )
    }
}

extension AssetDetailsPresenter: AssetDetailsPresenterProtocol {
    func setup() {
        interactor.setup()
        updateView()
    }

    func handleSend() {
        wireframe.showSendTokens(
            from: view,
            chainAsset: chainAsset
        )
    }

    func handleReceive() {
        switch selectedAccount.type {
        case .secrets, .paritySigner, .polkadotVault, .proxied:
            showReceiveTokens()
        case .ledger, .genericLedger:
            if let assetRawType = chainAsset.asset.type, case .orml = AssetType(rawValue: assetRawType) {
                wireframe.showLedgerNotSupport(for: chainAsset.asset.symbol, from: view)
            } else {
                showReceiveTokens()
            }

        case .watchOnly:
            wireframe.showNoSigning(from: view)
        }
    }

    func handleBuy() {
        guard !purchaseActions.isEmpty else {
            return
        }

        switch selectedAccount.type {
        case .secrets, .paritySigner, .polkadotVault, .proxied:
            showPurchase()
        case .ledger, .genericLedger:
            if let assetRawType = chainAsset.asset.type, case .orml = AssetType(rawValue: assetRawType) {
                wireframe.showLedgerNotSupport(for: chainAsset.asset.symbol, from: view)
            } else {
                showPurchase()
            }
        case .watchOnly:
            wireframe.showNoSigning(from: view)
        }
    }

    func handleLocks() {
        guard let balance = balance else {
            return
        }
        let precision = chainAsset.asset.precision

        let groupedExternalBalances = externalAssetBalances
            .groupByAssetType()
            .mapValues { $0.decimal(precision: precision) }

        let balanceContext = BalanceContext(
            free: balance.freeInPlank.decimal(precision: precision),
            reserved: balance.reservedInPlank.decimal(precision: precision),
            frozen: balance.frozenInPlank.decimal(precision: precision),
            external: groupedExternalBalances,
            price: priceData.map { Decimal(string: $0.price) ?? 0 } ?? 0,
            priceChange: priceData?.dayChange ?? 0,
            priceId: priceData?.currencyId,
            balanceLocks: locks,
            balanceHolds: holds
        )
        let model = AssetDetailsLocksViewModel(
            balanceContext: balanceContext,
            amountFormatter: viewModelFactory.amountFormatter(assetDisplayInfo: chainAsset.assetDisplayInfo),
            priceFormatter: viewModelFactory.priceFormatter(priceId: priceData?.currencyId),
            precision: Int16(precision)
        )
        wireframe.showLocks(from: view, model: model)
    }

    func handleSwap() {
        wireframe.showSwaps(from: view, chainAsset: chainAsset)
    }
}

extension AssetDetailsPresenter: AssetDetailsInteractorOutputProtocol {
    func didReceive(balance: AssetBalance?) {
        self.balance = balance
        updateView()
    }

    func didReceive(lockChanges: [DataProviderChange<AssetLock>]) {
        locks = locks.applying(changes: lockChanges)
        updateView()
    }

    func didReceive(holdsChanges: [DataProviderChange<AssetHold>]) {
        holds = holds.applying(changes: holdsChanges)
        updateView()
    }

    func didReceive(price: PriceData?) {
        priceData = price
        updateView()
    }

    func didReceive(purchaseActions: [PurchaseAction]) {
        self.purchaseActions = purchaseActions
        updateView()
    }

    func didReceive(availableOperations: AssetDetailsOperation) {
        self.availableOperations = availableOperations
        updateView()
    }

    func didReceive(externalBalanceChanges: [DataProviderChange<ExternalAssetBalance>]) {
        externalAssetBalances = externalAssetBalances.applying(changes: externalBalanceChanges)
        updateView()
    }

    func didReceive(error: AssetDetailsError) {
        logger?.error("Did receive error: \(error)")
    }
}

extension AssetDetailsPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}

extension AssetDetailsPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context _: AnyObject?) {
        startPuchaseFlow(
            from: view,
            purchaseAction: purchaseActions[index],
            wireframe: wireframe,
            locale: selectedLocale
        )
    }
}

extension AssetDetailsPresenter: PurchaseDelegate {
    func purchaseDidComplete() {
        wireframe.presentPurchaseDidComplete(view: view, locale: selectedLocale)
    }
}

extension AssetDetailsPresenter: AssetPriceChartModuleOutputProtocol {
    func didReceiveChartState(_ state: AssetPriceChartState) {
        switch state {
        case .loading, .available:
            view?.didReceiveChartAvailable(true)
        case .unavailable:
            view?.didReceiveChartAvailable(false)
        }
    }
}
