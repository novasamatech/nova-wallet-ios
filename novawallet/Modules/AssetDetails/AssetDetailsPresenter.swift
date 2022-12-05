import Foundation
import BigInt
import RobinHood

final class AssetDetailsPresenter {
    weak var view: AssetDetailsViewProtocol?
    let wireframe: AssetDetailsWireframeProtocol
    let interactor: AssetDetailsInteractorInputProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let asset: AssetModel
    private var priceData: PriceData?
    private var balance: AssetBalance?
    private var locks: [AssetLocks] = []

    init(
        interactor: AssetDetailsInteractorInputProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizableManager: LocalizationManagerProtocol,
        asset: AssetModel,
        wireframe: AssetDetailsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.asset = asset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.localizableManager = localizableManager
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
            from: balance.available,
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
        view.didReceive(availableOperations: .all)
    }
}

extension AssetDetailsPresenter: AssetDetailsPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension AssetDetailsPresenter: AssetDetailsInteractorOutputProtocol {
    func didReceive(balance: AssetBalance?) {
        self.balance = balance
        updateView()
    }

    func didReceive(locks: [AssetLocks]) {
        self.locks = locks
        updateView()
    }

    func didReceive(price: PriceData) {
        priceData = price
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
