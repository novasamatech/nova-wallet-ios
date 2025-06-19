import UIKit
import Operation_iOS

final class ParitySignerUpdateWalletInteractor {
    weak var presenter: ParitySignerUpdateWalletInteractorOutputProtocol?
    
    let wallet: MetaAccountModel
    let walletSettings: SelectedWalletSettings
    let walletRepository: AnyDataProviderRepository<MetaAccountModel>
    let 
    
    init(wallet: MetaAccountModel) {
        
    }
}

extension ParitySignerUpdateWalletInteractor: ParitySignerUpdateWalletInteractorInputProtocol {}
