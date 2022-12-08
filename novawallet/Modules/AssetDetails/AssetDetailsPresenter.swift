import Foundation
import BigInt
import SoraFoundation

final class AssetDetailsPresenter {
    weak var view: AssetDetailsViewProtocol?
    let wireframe: AssetDetailsWireframeProtocol
    let interactor: AssetDetailsInteractorInputProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let asset: AssetModel
    let chain: ChainModel
    let amountFormatter: LocalizableResource<TokenFormatter>
    let priceFormatter: LocalizableResource<TokenFormatter>

    private var priceData: PriceData?
    private var balance: AssetBalance?
    private var locks: [AssetLock] = []
    private var crowdloans: [CrowdloanContributionData] = []
    private var purchaseActions: [PurchaseAction] = []
    private var availableOperations: Operations = []
    private var selectedAccountType: MetaAccountModelType

    init(
        interactor: AssetDetailsInteractorInputProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        amountFormatter: LocalizableResource<TokenFormatter>,
        priceFormatter: LocalizableResource<TokenFormatter>,
        localizableManager: LocalizationManagerProtocol,
        asset: AssetModel,
        chain: ChainModel,
        selectedAccountType: MetaAccountModelType,
        wireframe: AssetDetailsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.asset = asset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chain = chain
        self.selectedAccountType = selectedAccountType
        self.amountFormatter = amountFormatter
        self.priceFormatter = priceFormatter
        localizationManager = localizableManager
    }

    private func createBalanceViewModel(
        from plank: BigUInt,
        precision: UInt16,
        priceData: PriceData?
    ) -> BalanceViewModelProtocol {
        let amount = Decimal.fromSubstrateAmount(
            plank,
            precision: Int16(precision)
        ) ?? 0.0

        return balanceViewModelFactory.balanceFromPrice(
            amount,
            priceData: priceData
        ).value(for: selectedLocale)
    }

    private func createPriceState(priceData: PriceData?) -> AssetPriceViewModel? {
        guard let balance = balance else {
            return nil
        }
        guard let priceData = priceData else {
            return nil
        }
        let amount = Decimal.fromSubstrateAmount(
            balance.totalInPlank,
            precision: Int16(asset.precision)
        ) ?? 0.0
        let price = Decimal(string: priceData.price)
        let priceChangeValue = (priceData.dayChange ?? 0.0) / 100.0
        let priceChangeString = NumberFormatter.signedPercent.localizableResource().value(for: selectedLocale).stringFromDecimal(priceChangeValue) ?? ""
        let priceChange: ValueDirection<String> = priceChangeValue >= 0.0
            ? .increase(value: priceChangeString) : .decrease(value: priceChangeString)
        let priceString = balanceViewModelFactory.priceFromAmount(1, priceData: priceData).value(for: selectedLocale)
        return AssetPriceViewModel(amount: priceString, change: priceChange)
    }

    private func createAssetDetailsModel() -> AssetDetailsModel {
        let networkViewModel = NetworkViewModelFactory().createViewModel(from: chain)
        let assetIcon = asset.icon.map { RemoteImageViewModel(url: $0) }
        return AssetDetailsModel(
            tokenName: asset.symbol,
            assetIcon: assetIcon,
            price: createPriceState(priceData: priceData),
            network: networkViewModel
        )
    }

    private func updateView() {
        guard let view = view else {
            return
        }

        guard let balance = balance else {
            return
        }

        let assetDetailsModel = createAssetDetailsModel()
        view.didReceive(assetModel: assetDetailsModel)

        let totalBalance = createBalanceViewModel(
            from: balance.totalInPlank,
            precision: asset.precision,
            priceData: priceData
        )

        let transferableBalance = createBalanceViewModel(
            from: balance.transferable,
            precision: asset.precision,
            priceData: priceData
        )

        let lockedBalance = createBalanceViewModel(
            from: balance.locked,
            precision: asset.precision,
            priceData: priceData
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
        let precision = asset.precision
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
            amountFormatter: amountFormatter,
            priceFormatter: priceFormatter,
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

    func didReceive(availableOperations: Operations) {
        self.availableOperations = availableOperations
        updateView()
    }

    func didReceive(crowdloans: [CrowdloanContributionData]) {
        self.crowdloans = crowdloans
        updateView()
    }

    func didReceive(error _: AssetDetailsError) {
        // logger
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

extension BigUInt {
    func decimal(precision: UInt16) -> Decimal {
        Decimal.fromSubstrateAmount(
            self,
            precision: Int16(precision)
        ) ?? 0
    }
}
