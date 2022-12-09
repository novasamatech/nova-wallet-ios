import Foundation
import BigInt
import SoraFoundation

final class AssetDetailsPresenter {
    weak var view: AssetDetailsViewProtocol?
    let wireframe: AssetDetailsWireframeProtocol
    let viewModelFactory: AssetDetailsViewModelFactoryProtocol,
        let interactor: AssetDetailsInteractorInputProtocol
    let chainAsset: ChainAsset
    let selectedAccountType: MetaAccountModelType
    let logger: LoggerProtocol?

    private var priceData: PriceData?
    private var balance: AssetBalance?
    private var locks: [AssetLock] = []
    private var crowdloans: [CrowdloanContributionData] = []
    private var purchaseActions: [PurchaseAction] = []
    private var availableOperations: AssetDetailsOperation = []

    init(
        interactor: AssetDetailsInteractorInputProtocol,
        localizableManager: LocalizationManagerProtocol,
        chainAsset: ChainAsset,
        selectedAccountType: MetaAccountModelType,
        viewModelFactory: AssetDetailsViewModelFactoryProtocol,
        wireframe: AssetDetailsWireframeProtocol,
        logger: LoggerProtocol?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.selectedAccountType = selectedAccountType
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        localizationManager = localizableManager
    }

    private func updateView() {
        guard let view = view else {
            return
        }

        guard let balance = balance else {
            return
        }

        let assetDetailsModel = viewModelFactory.createAssetDetailsModel(
            balance: balance,
            priceData: priceData,
            chainAsset: chainAsset,
            locale: selectedLocale
        )
        view.didReceive(assetModel: assetDetailsModel)

        let totalBalance = viewModelFactory.createBalanceViewModel(
            from: balance.totalInPlank,
            precision: chainAsset.asset.precision,
            priceData: priceData,
            locale: selectedLocale
        )

        let transferableBalance = viewModelFactory.createBalanceViewModel(
            from: balance.transferable,
            precision: chainAsset.asset.precision,
            priceData: priceData,
            locale: selectedLocale
        )

        let lockedBalance = viewModelFactory.createBalanceViewModel(
            from: balance.locked,
            precision: chainAsset.asset.precision,
            priceData: priceData,
            locale: selectedLocale
        )

        view.didReceive(totalBalance: totalBalance)
        view.didReceive(transferableBalance: transferableBalance)
        view.didReceive(lockedBalance: lockedBalance, isSelectable: !locks.isEmpty || !crowdloans.isEmpty)
        view.didReceive(availableOperations: availableOperations)
    }
}

extension AssetDetailsPresenter: AssetDetailsPresenterProtocol {
    func setup() {
        interactor.setup()
        updateView()
    }

    func didTapSendButton() {
        wireframe.showSendTokens(
            from: view,
            chainAsset: ChainAsset(chain: chain, asset: asset)
        )
    }

    func didTapReceiveButton() {
        switch selectedAccountType {
        case .secrets, .paritySigner:
            wireframe.showReceiveTokens(from: view)
        case .ledger:
            if let assetRawType = asset.type, case .orml = AssetType(rawValue: assetRawType) {
                wireframe.showLedgerNotSupport(for: asset.symbol, from: view)
            } else {
                wireframe.showReceiveTokens(from: view)
            }

        case .watchOnly:
            wireframe.showNoSigning(from: view)
        }
    }

    func didTapBuyButton() {
        guard !purchaseActions.isEmpty else {
            return
        }

        switch selectedAccountType {
        case .secrets, .paritySigner:
            showPurchase()
        case .ledger:
            if let assetRawType = asset.type, case .orml = AssetType(rawValue: assetRawType) {
                wireframe.showLedgerNotSupport(for: asset.symbol, from: view)
            } else {
                showPurchase()
            }
        case .watchOnly:
            wireframe.showNoSigning(from: view)
        }
    }

    private func showPurchase() {
        guard !purchaseActions.isEmpty else {
            return
        }
        if purchaseActions.count == 1 {
            wireframe.showPurchaseTokens(
                from: view,
                action: purchaseActions[0],
                delegate: self
            )
        } else {
            wireframe.showPurchaseProviders(
                from: view,
                actions: purchaseActions,
                delegate: self
            )
        }
    }

    func didTapLocks() {
        guard let balance = balance else {
            return
        }
        let precision = chainAsset.asset.precision
        let balanceContext = BalanceContext(
            free: balance.freeInPlank.decimal(precision: precision),
            reserved: balance.reservedInPlank.decimal(precision: precision),
            frozen: balance.frozenInPlank.decimal(precision: precision),
            crowdloans: crowdloans.reduce(0) { $0 + $1.amount }.decimal(precision: precision),
            price: priceData.map { Decimal(string: $0.price) ?? 0 } ?? 0,
            priceChange: priceData?.dayChange ?? 0,
            priceId: priceData?.currencyId,
            balanceLocks: locks
        )
        let model = AssetDetailsLocksViewModel(
            balanceContext: balanceContext,
            amountFormatter: viewModelFactory.amountFormatter,
            priceFormatter: viewModelFactory.priceFormatter,
            precision: Int16(precision)
        )
        wireframe.showLocks(from: view, model: model)
    }
}

extension AssetDetailsPresenter: AssetDetailsInteractorOutputProtocol {
    func didReceive(balance: AssetBalance?) {
        self.balance = balance
        updateView()
    }

    func didReceive(locks: [AssetLock]) {
        self.locks = locks
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

    func didReceive(crowdloans: [CrowdloanContributionData]) {
        self.crowdloans = crowdloans
        updateView()
    }

    func didReceive(error: AssetDetailsError) {
        logger?.error(error.localizedDescription)
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
        wireframe.showPurchaseTokens(
            from: view,
            action: purchaseActions[index],
            delegate: self
        )
    }
}

extension AssetDetailsPresenter: PurchaseDelegate {
    func purchaseDidComplete() {
        let languages = selectedLocale.rLanguages
        let message = R.string.localizable
            .buyCompleted(preferredLanguages: languages)
        wireframe.presentSuccessAlert(from: view, message: message)
    }
}
