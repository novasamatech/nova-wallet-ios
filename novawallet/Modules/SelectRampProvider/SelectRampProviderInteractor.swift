import UIKit

final class SelectRampProviderInteractor {
    weak var presenter: SelectRampProviderInteractorOutputProtocol?
    let rampProvider: PurchaseProviderProtocol
    let chainAsset: ChainAsset
    let accountId: AccountId

    init(
        rampProvider: PurchaseProviderProtocol,
        chainAsset: ChainAsset,
        accountId: AccountId
    ) {
        self.rampProvider = rampProvider
        self.chainAsset = chainAsset
        self.accountId = accountId
    }
}

// MARK: SelectRampProviderInteractorInputProtocol

extension SelectRampProviderInteractor: SelectRampProviderInteractorInputProtocol {
    func setup() {
        let rampActions = rampProvider.buildRampActions(
            for: chainAsset,
            accountId: accountId
        )

        presenter?.didReceive(rampActions)
    }
}
