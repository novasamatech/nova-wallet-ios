import UIKit
import Operation_iOS

final class ParitySignerUpdateWalletInteractor {
    weak var presenter: ParitySignerUpdateWalletInteractorOutputProtocol?

    let wallet: MetaAccountModel
    let walletSettings: SelectedWalletSettings
    let walletRepository: AnyDataProviderRepository<MetaAccountModel>

    init(
        wallet: MetaAccountModel,
        walletSettings: SelectedWalletSettings,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>
    ) {
        self.wallet = wallet
        self.walletSettings = walletSettings
        self.walletRepository = walletRepository
    }
}

extension ParitySignerUpdateWalletInteractor: ParitySignerUpdateWalletInteractorInputProtocol {}
