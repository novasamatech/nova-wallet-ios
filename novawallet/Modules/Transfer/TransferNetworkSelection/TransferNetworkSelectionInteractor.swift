import UIKit

final class TransferNetworkSelectionInteractor {
    weak var presenter: TransferNetworkSelectionInteractorOutputProtocol?

    let assetListObservable: AssetListModelObservable

    init(assetListObservable: AssetListModelObservable) {
        self.assetListObservable = assetListObservable
    }

    private func provideModel() {
        let balances = assetListObservable.state.value.balances.compactMapValues { balanceResult in
            switch balanceResult {
            case let .success(balance):
                return balance
            case .failure:
                return nil
            }
        }

        let prices = (try? assetListObservable.state.value.priceResult?.get()) ?? [:]

        presenter?.didReceive(balances: balances, prices: prices)
    }
}

extension TransferNetworkSelectionInteractor: TransferNetworkSelectionInteractorInputProtocol {
    func setup() {
        assetListObservable.addObserver(with: self, queue: .main) { [weak self] _, _ in
            self?.provideModel()
        }

        provideModel()
    }
}
