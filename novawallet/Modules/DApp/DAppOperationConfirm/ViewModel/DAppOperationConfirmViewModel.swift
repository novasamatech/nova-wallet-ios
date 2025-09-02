import Foundation
import SubstrateSdk

struct DAppOperationConfirmViewModel {
    let iconImageViewModel: ImageViewModelProtocol?
    let dApp: String
    let walletName: String
    let walletIcon: DrawableIcon?
    let address: String
    let addressIcon: DrawableIcon?
    let network: Network?
}

extension DAppOperationConfirmViewModel {
    struct Network {
        let name: String
        let iconViewModel: ImageViewModelProtocol?
    }
}

enum DAppOperationFeeViewModel {
    case loading
    case empty
    case loaded(value: BalanceViewModelProtocol?)
}
