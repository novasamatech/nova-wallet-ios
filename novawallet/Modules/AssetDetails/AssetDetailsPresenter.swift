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
    private var priceData: PriceData?
    private var balance: AssetBalance?
    private var locks: [AssetLock] = []
    private var purchaseActions: [PurchaseAction] = []
    private var availableOperations: Operations = []
    private var selectedAccountType: MetaAccountModelType

    init(
        interactor: AssetDetailsInteractorInputProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
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

    private func updateView() {
        guard let view = view else {
            return
        }
        guard let balance = balance else {
            return
        }

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
        view.didReceive(lockedBalance: lockedBalance, isSelectable: !locks.isEmpty)
        view.didReceive(availableOperations: availableOperations)
    }
}

extension AssetDetailsPresenter: AssetDetailsPresenterProtocol {
    func setup() {
        interactor.setup()
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
                action: purchaseActions[0]
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
        wireframe.showLocks(from: view)
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

    func didReceive(error _: AssetDetailsError) {}
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
            action: purchaseActions[index]
        )
    }
}
