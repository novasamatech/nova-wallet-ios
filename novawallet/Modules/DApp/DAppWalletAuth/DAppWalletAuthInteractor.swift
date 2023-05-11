import UIKit

final class DAppWalletAuthInteractor {
    weak var presenter: DAppWalletAuthInteractorOutputProtocol?

    let balancesStore: BalancesStoreProtocol

    private var wallet: MetaAccountModel?
    private var calculator: BalancesCalculating?

    init(balancesStore: BalancesStoreProtocol) {
        self.balancesStore = balancesStore
    }

    private func provideTotalValue() {
        guard let wallet = wallet, let calculator = calculator else {
            return
        }

        let totalValue = calculator.calculateTotalValue(for: wallet)
        presenter?.didFetchTotalValue(totalValue, wallet: wallet)
    }
}

extension DAppWalletAuthInteractor: DAppWalletAuthInteractorInputProtocol {
    func setup() {
        balancesStore.delegate = self
        balancesStore.setup()
    }

    func apply(wallet: MetaAccountModel) {
        self.wallet = wallet

        provideTotalValue()
    }
}

extension DAppWalletAuthInteractor: BalancesStoreDelegate {
    func balancesStore(_: BalancesStoreProtocol, didUpdate calculator: BalancesCalculating) {
        self.calculator = calculator

        provideTotalValue()
    }

    func balancesStore(_: BalancesStoreProtocol, didReceive error: BalancesStoreError) {
        presenter?.didReceive(error: error)
    }
}
