import UIKit

final class DAppWalletAuthInteractor {
    weak var presenter: DAppWalletAuthInteractorOutputProtocol?
}

extension DAppWalletAuthInteractor: DAppWalletAuthInteractorInputProtocol {
    func fetchTotalValue(for _: MetaAccountModel) {}
}
